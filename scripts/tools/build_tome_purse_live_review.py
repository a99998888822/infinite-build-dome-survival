"""Export actual production captures, preserving complete game UI in MP4."""
from pathlib import Path
import argparse
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/tome_purse_implementation"
TEMP = Path("C:/Users/mi/AppData/Local/Temp")
FFMPEG = "D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"
LABELS = {
    "tome": ("坤舆秘仪书 · 指纹弧纹爆发", "蓝白色五道指纹弧纹 / 命中瞬间扩张 / 少量方粒消散"),
    "purse": ("食利者钱袋 · 正式游戏实录", "默认三枚金币环射 / 本金400，每枚伤害10 / 不消耗本金"),
    "combined": ("双武器 · 分裂＋火焰附魔实录", "领域追加点名 / 金币分裂一代 / 命中触发火焰效果"),
}


def export(kind):
    source = TEMP / f"codex-tome-purse-live-{kind}"
    manifest = json.loads((source / "capture.json").read_text(encoding="utf-8"))
    assert manifest["valid"] and manifest["production"]
    (OUT / f"{kind}_capture.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    frames = TEMP / f"codex-tome-purse-live-export-{kind}"
    frames.mkdir(parents=True, exist_ok=True)
    title, subtitle = LABELS[kind]
    for index in range(manifest["frames"]):
        board = Image.new("RGB", (640, 540), "#10191e")
        with Image.open(source / f"frame_{index:04d}.png") as frame:
            board.paste(frame.crop((255, 84, 895, 564)), (0, 60))
        draw = ImageDraw.Draw(board)
        draw.text((18, 6), title, font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22), fill="#b9d8d9")
        draw.text((18, 36), subtitle, font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14), fill="#a6b5ad")
        board.save(frames / f"frame_{index:04d}.png")
        if index in [15, 60, 120, 180]: board.save(OUT / f"{kind}_frame_{index:03d}.png")
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "warning", "-framerate", "30", "-i", str(frames / "frame_%04d.png"),
                    "-filter_complex", "fps=20,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=none",
                    "-loop", "0", "-final_delay", "5", "-y", str(OUT / f"{kind}_live.gif")], check=True)
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "warning", "-framerate", "30", "-i", str(source / "frame_%04d.png"),
                    "-frames:v", str(manifest["frames"]), "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                    "-y", str(OUT / f"{kind}_live.mp4")], check=True)
    with Image.open(OUT / f"{kind}_live.gif") as gif:
        duration = sum(gif.seek(i) or gif.info.get("duration", 0) for i in range(gif.n_frames))
        assert gif.n_frames == 160 and duration == 8000
        return {"frames": gif.n_frames, "duration_ms": duration, "size": list(gif.size)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", nargs="+", default=list(LABELS))
    parser.add_argument("--revision", default="")
    args = parser.parse_args()
    if args.revision:
        OUT = OUT / args.revision
        OUT.mkdir(parents=True, exist_ok=True)
    report_path = OUT / "media_validation.json"
    result = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    result.update({kind: export(kind) for kind in args.variants})
    report_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
