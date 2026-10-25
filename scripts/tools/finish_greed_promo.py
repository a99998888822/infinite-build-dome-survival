"""Frame the banker transaction, join its consequence, and verify delivery media."""
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
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/greed_promo_20261024")
    parser.add_argument("--ffmpeg", type=Path, default=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"))
    args = parser.parse_args()
    root = args.output.resolve()
    story = root / "02_goblin_buyout_story.mp4"
    command = [str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-y",
               "-i", str(root / "02_sell_the_best_weapon.mp4"), "-i", str(root / "03_price_of_the_deal.mp4")]
    graph = ("[0:v]split=2[near][wide];"
             "[near]trim=start_frame=0:end_frame=372,setpts=PTS-STARTPTS,crop=1120:630:32:180,scale=1920:1080:flags=neighbor,setsar=1[v0];"
             "[wide]trim=start_frame=372:end_frame=480,setpts=PTS-STARTPTS,setsar=1[v1];"
             "[1:v]setpts=PTS-STARTPTS,setsar=1[v2];"
             "[v0][v1][v2]concat=n=3:v=1:a=0[v];"
             "[0:a]atrim=duration=8,asetpts=PTS-STARTPTS[a0];"
             "[1:a]atrim=duration=3.5,asetpts=PTS-STARTPTS[a1];"
             "[a0][a1]concat=n=2:v=0:a=1[a]")
    subprocess.run(command + ["-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-r", "60",
                             "-fps_mode", "cfr", "-c:v", "libx264", "-crf", "16", "-preset", "slow",
                             "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(story)], check=True)
    validation = {"sfx_percent": 100, "bgm_percent": 0, "added_audio": False, "added_subtitles": False, "files": []}
    specs = [("01_one_more_coin.mp4", 600), (story.name, 690), ("02_sell_the_best_weapon.mp4", 480), ("03_price_of_the_deal.mp4", 210)]
    probe = args.ffmpeg.with_name("ffprobe.exe")
    for name, frames in specs:
        path = root / name
        metadata = json.loads(subprocess.check_output([str(probe), "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)], encoding="utf-8"))
        video = next(s for s in metadata["streams"] if s["codec_type"] == "video")
        audio = next(s for s in metadata["streams"] if s["codec_type"] == "audio")
        assert (video["width"], video["height"], int(video["nb_frames"])) == (1920, 1080, frames)
        assert video["r_frame_rate"] == "60/1" and audio["codec_name"] == "aac"
        pcm = array.array("f", subprocess.check_output([str(args.ffmpeg), "-v", "error", "-i", str(path), "-vn", "-f", "f32le", "-acodec", "pcm_f32le", "-"]))
        peak = max(abs(value) for value in pcm)
        rms = math.sqrt(sum(value * value for value in pcm) / len(pcm))
        assert 0.0001 < peak < 1.0 and rms > 0.000001, (name, peak, rms)
        validation["files"].append({"name": name, "frames": frames, "duration": frames / 60,
                                    "resolution": [1920, 1080], "peak_dbfs": 20 * math.log10(peak), "rms_dbfs": 20 * math.log10(rms)})
    review = root / "delivery_review"
    review.mkdir(exist_ok=True)
    sheets = [("01_one_more_coin.mp4", [0.2, 2.0, 3.2, 5.0, 7.5, 9.5]),
              (story.name, [0.2, 3.0, 5.4, 5.8, 7.0, 10.0])]
    sheet = Image.new("RGB", (1440, 1200), "#13131b")
    draw = ImageDraw.Draw(sheet)
    for take_index, (name, times) in enumerate(sheets):
        for i, seconds in enumerate(times):
            frame = review / f"{take_index}_{i}.png"
            subprocess.run([str(args.ffmpeg), "-v", "error", "-y", "-ss", str(seconds), "-i", str(root / name), "-frames:v", "1", str(frame)], check=True)
            x, y = (i % 3) * 480, take_index * 600 + (i // 3) * 300
            sheet.paste(Image.open(frame).resize((480, 270)), (x, y))
            draw.text((x + 8, y + 278), f"{'NIGHT' if take_index == 0 else 'BUYOUT'} {seconds:.1f}s", fill="white")
    sheet.save(root / "delivery_contact.jpg")
    for take in ["night", "sale", "cost"]:
        capture = json.loads((root / take / "capture.json").read_text(encoding="utf-8"))
        assert capture["exit_code"] == 0 and capture["foreground_samples"] == 0
        assert capture["verified_desktop"] == capture["private_desktop"]
    (root / "delivery_validation.json").write_text(json.dumps(validation, indent=2), encoding="utf-8")
    print(json.dumps(validation, indent=2), flush=True)


if __name__ == "__main__":
    main()
