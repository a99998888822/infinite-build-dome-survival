"""Export production plasma footage and a tracked close-up from the same frames."""
from pathlib import Path
import argparse
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path("C:/Users/mi/AppData/Local/Temp/codex-plasma-ball-live")
STAGING = Path("C:/Users/mi/AppData/Local/Temp/codex-plasma-ball-export")
OUT = ROOT / "artifacts/plasma_ball_implementation"
FFMPEG = "D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"


def encode_gif(folder, name, count, fps):
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "warning", "-framerate", "30",
                    "-i", str(folder / "frame_%04d.png"), "-filter_complex",
                    f"trim=end_frame={count},fps={fps},split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=none",
                    "-loop", "0", "-final_delay", "5", "-y", str(OUT / name)], check=True)
    with Image.open(OUT / name) as gif:
        duration = sum(gif.seek(i) or gif.info.get("duration", 0) for i in range(gif.n_frames))
        return {"frames": gif.n_frames, "duration_ms": duration, "size": list(gif.size)}


def main():
    manifest = json.loads((SOURCE / "capture.json").read_text(encoding="utf-8"))
    assert manifest["valid"] and manifest["production"] and manifest["pause_verified"]
    assert manifest["contact_verified"] and manifest["contacts"]
    assert all(hit["surface_gap"] <= 0.25 for hit in manifest["contacts"])
    OUT.mkdir(parents=True, exist_ok=True)
    full = STAGING / "full"
    detail = STAGING / "detail"
    full.mkdir(parents=True, exist_ok=True)
    detail.mkdir(parents=True, exist_ok=True)
    title_font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22)
    caption_font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)
    samples = manifest["samples"]
    first_id = samples[0]["id"]
    track = {s["frame"]: s for s in samples if s["id"] == first_id}
    detail_count = 0
    for index in range(manifest["frames"]):
        with Image.open(SOURCE / f"frame_{index:04d}.png") as frame:
            board = Image.new("RGB", (640, 540), "#10191e")
            board.paste(frame.crop((400, 100, 1040, 580)), (0, 60))
            draw = ImageDraw.Draw(board)
            draw.text((18, 6), "电浆炮 · 接触后持续灼击", font=title_font, fill="#b9d8e9")
            draw.text((18, 36), "球体与判定同为半径12 / 接触才扣血 / 接地电弧仅为表现", font=caption_font, fill="#a6b5bd")
            board.save(full / f"frame_{index:04d}.png")
            if index in (24, 36, 48):
                board.save(OUT / f"plasma_frame_{index:03d}.png")
            if index == manifest["contacts"][0]["frame"]:
                board.save(OUT / "first_contact.png")
            if index in track:
                x, y = track[index]["center"]
                left, top = round(x) - 64, round(y) - 48
                closeup = frame.crop((left, top, left + 128, top + 128)).resize((384, 384), Image.Resampling.NEAREST)
                closeup.save(detail / f"frame_{detail_count:04d}.png")
                if detail_count in (8, 14, 20, 26, 32, 38):
                    closeup.save(OUT / f"detail_frame_{detail_count:03d}.png")
                detail_count += 1
    result = {"full": encode_gif(full, "plasma_live.gif", manifest["frames"], 20),
              "detail": encode_gif(detail, "plasma_detail.gif", detail_count, 30)}
    assert result["full"]["frames"] == 160 and result["full"]["duration_ms"] == 8000
    assert result["detail"]["frames"] > 30
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "warning", "-framerate", "30", "-i", str(SOURCE / "frame_%04d.png"),
                    "-frames:v", str(manifest["frames"]), "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", "-y", str(OUT / "plasma_live.mp4")], check=True)
    (OUT / "capture.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (OUT / "media_validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", default="")
    args = parser.parse_args()
    if args.revision:
        OUT = OUT / args.revision
    main()
