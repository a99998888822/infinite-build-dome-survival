"""Join contract decisions to their consequences; verify video, audio and capture."""
import argparse
import array
import json
import math
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/goblin_contracts_20261024")
    parser.add_argument("--ffmpeg", type=Path, default=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"))
    args = parser.parse_args()
    root = args.output.resolve()
    ffmpeg = str(args.ffmpeg)
    validation = {"sfx_percent": 100, "bgm_percent": 0, "added_audio": False,
                  "added_subtitles": False, "controls": "RMB move, number key select, LMB cast", "files": []}
    specs = [
        ("01_debt_hunter_story.mp4", "debt_bank", "debt_fight", 495, 300),
        ("02_vault_rescue_story.mp4", "vault_offer", "vault_rescue", 225, 360),
    ]
    for name, bank, fight, bank_frames, fight_frames in specs:
        if bank == "debt_bank":
            # Preserve the empty wallet and purchase context in the wide views;
            # move closer only while the loan/contract text is visible.
            graph = (
                "[0:v]split=4[s0][s1][s2][s3];"
                "[s0]trim=end_frame=84,setpts=PTS-STARTPTS,setsar=1[v0];"
                "[s1]trim=start_frame=84:end_frame=200,setpts=PTS-STARTPTS,crop=1280:720:320:210,scale=1920:1080:flags=neighbor,setsar=1[v1];"
                "[s2]trim=start_frame=200:end_frame=288,setpts=PTS-STARTPTS,setsar=1[v2];"
                "[s3]trim=start_frame=288:end_frame=495,setpts=PTS-STARTPTS,crop=1280:720:320:180,scale=1920:1080:flags=neighbor,setsar=1[v3];"
                "[1:v]trim=end_frame=300,setpts=PTS-STARTPTS,setsar=1[v4];"
                "[v0][v1][v2][v3][v4]concat=n=5:v=1:a=0[v];"
            )
        else:
            graph = (
                "[0:v]trim=end_frame=225,setpts=PTS-STARTPTS,crop=1280:720:320:180,scale=1920:1080:flags=neighbor,setsar=1[v0];"
                "[1:v]trim=end_frame=360,setpts=PTS-STARTPTS,setsar=1[v1];"
                "[v0][v1]concat=n=2:v=1:a=0[v];"
            )
        graph += (
            f"[0:a]atrim=duration={bank_frames/60},asetpts=PTS-STARTPTS[a0];"
            f"[1:a]atrim=duration={fight_frames/60},asetpts=PTS-STARTPTS[a1];"
            "[a0][a1]concat=n=2:v=0:a=1[a]"
        )
        path = root / name
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(root / f"{bank}.mp4"),
                        "-i", str(root / f"{fight}.mp4"), "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
                        "-r", "60", "-fps_mode", "cfr", "-c:v", "libx264", "-crf", "16", "-preset", "slow",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(path)], check=True)
        metadata = json.loads(subprocess.check_output([str(args.ffmpeg.with_name("ffprobe.exe")), "-v", "error",
                                                      "-show_streams", "-of", "json", str(path)], encoding="utf-8"))
        video = next(s for s in metadata["streams"] if s["codec_type"] == "video")
        audio = next(s for s in metadata["streams"] if s["codec_type"] == "audio")
        count = bank_frames + fight_frames
        assert (video["width"], video["height"], int(video["nb_frames"]), video["r_frame_rate"]) == (1920, 1080, count, "60/1")
        assert audio["codec_name"] == "aac"
        pcm = array.array("f", subprocess.check_output([ffmpeg, "-v", "error", "-i", str(path), "-vn", "-f", "f32le", "-acodec", "pcm_f32le", "-"]))
        peak = max(abs(x) for x in pcm)
        rms = math.sqrt(sum(x*x for x in pcm) / len(pcm))
        assert 0.0001 < peak < 1 and rms > 0.000001, (name, peak, rms)
        validation["files"].append({"name": name, "frames": count, "duration": count/60, "resolution": [1920, 1080],
                                    "peak_dbfs": 20*math.log10(peak), "rms_dbfs": 20*math.log10(rms)})
    for take in ["debt_bank", "debt_fight", "vault_offer", "vault_rescue"]:
        capture = json.loads((root / take / "capture.json").read_text(encoding="utf-8"))
        report = json.loads((root / take / "report.json").read_text(encoding="utf-8"))
        log = (root / take / "capture.log").read_text(encoding="utf-8")
        assert capture["exit_code"] == 0 and capture["foreground_samples"] == 0
        assert capture["verified_desktop"] == capture["private_desktop"]
        assert not report["failures"]
        assert not any(e in log for e in ["SCRIPT ERROR", "Parse Error", "Compile Error", "\nERROR:"])
        assert report["audio"]["bgm_muted"] and report["audio"]["bgm_db"] == -80
        assert report["audio"]["sfx_db"] == 2
    review = root / "delivery_review"
    review.mkdir(exist_ok=True)
    sheet = Image.new("RGB", (1920, 1680), "#13131b")
    draw = ImageDraw.Draw(sheet)
    for row, (name, times) in enumerate([
        (specs[0][0], [0.4, 2.7, 4.1, 7.9, 9.7, 12.7]),
        (specs[1][0], [0.4, 3.4, 4.5, 5.7, 7.7, 9.4]),
    ]):
        for i, seconds in enumerate(times):
            frame = review / f"{row}_{i}.png"
            subprocess.run([ffmpeg, "-v", "error", "-y", "-ss", str(seconds), "-i", str(root / name), "-frames:v", "1", str(frame)], check=True)
            x, y = (i % 3)*640, row*840+(i//3)*420
            sheet.paste(Image.open(frame).resize((640, 360)), (x, y))
            draw.text((x+10, y+374), f"{'DEBT' if row == 0 else 'VAULT'} {seconds:.2f}s", fill="white")
    sheet.save(root / "delivery_contact.jpg")
    (root / "delivery_validation.json").write_text(json.dumps(validation, indent=2), encoding="utf-8")
    print(json.dumps(validation, indent=2), flush=True)


if __name__ == "__main__":
    main()
