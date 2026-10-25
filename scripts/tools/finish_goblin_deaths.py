"""Frame the recorded native portrait and speech as two reusable ending inserts."""
import json
from pathlib import Path
import subprocess

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2] / "artifacts/previews/goblin_death_promo_20261024"
FFMPEG = Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe")
PROBE = FFMPEG.with_name("ffprobe.exe")


def main():
    results = []
    sheet = Image.new("RGB", (1280, 1140), (20, 20, 20))
    draw = ImageDraw.Draw(sheet)
    for column, take in enumerate(["followed", "refused"]):
        number = column + 1
        source = ROOT / f"{number:02d}_goblin_death_{take}.mp4"
        dest = ROOT / f"{number:02d}_goblin_death_{take}_closeup.mp4"
        report = json.loads((ROOT / take / "report.json").read_text(encoding="utf-8"))
        capture = json.loads((ROOT / take / "capture.json").read_text(encoding="utf-8"))
        assert not report["failures"]
        assert capture["exit_code"] == 0 and capture["foreground_samples"] == 0
        assert capture["private_desktop"] == capture["verified_desktop"]
        sx, sy, sw, sh = report["speech_rect"]
        px, py, pw, ph = report["portrait_rect"]
        # Crop both complete native controls, with a little of their own backdrop.
        x, y, width, height = int(sx - 8), int(sy - 24), int(sw + 16), int(py + ph + 12 - sy + 24)
        sample = Image.open(ROOT / take / "frame_150.png").convert("RGB")
        color = "0x" + "".join(f"{v:02x}" for v in sample.getpixel((x, y)))
        assert x <= px and px + pw <= x + width and py + ph <= y + height
        assert height * 2 <= 1080
        graph = f"crop={width}:{height}:{x}:{y},scale=iw*2:ih*2:flags=neighbor,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color={color}"
        subprocess.run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-y", "-i", str(source), "-vf", graph,
                        "-map", "0:v:0", "-map", "0:a:0", "-c:v", "libx264", "-crf", "16", "-preset", "slow",
                        "-pix_fmt", "yuv420p", "-c:a", "copy", "-movflags", "+faststart", str(dest)], check=True)
        probe = json.loads(subprocess.check_output([str(PROBE), "-v", "error", "-show_streams", "-show_format", "-of", "json", str(dest)]))
        video = next(s for s in probe["streams"] if s["codec_type"] == "video")
        assert (video["width"], video["height"], video["nb_frames"], video["avg_frame_rate"]) == (1920, 1080, "240", "60/1")
        assert abs(float(probe["format"]["duration"]) - 4.0) < 0.01
        pcm = subprocess.check_output([str(FFMPEG), "-v", "error", "-i", str(dest), "-map", "0:a:0", "-f", "f32le", "-"])
        audio = np.frombuffer(pcm, dtype=np.float32)
        peak, rms = float(np.max(np.abs(audio))), float(np.sqrt(np.mean(audio * audio)))
        assert 0 < rms < 1 and peak < 1
        for row, second in enumerate([0.4, 1.4, 2.8]):
            shot = ROOT / f"{take}_{row}.png"
            subprocess.run([str(FFMPEG), "-v", "error", "-y", "-ss", str(second), "-i", str(dest), "-frames:v", "1", str(shot)], check=True)
            sheet.paste(Image.open(shot).convert("RGB").resize((640, 360)), (column * 640, row * 380))
            draw.text((column * 640 + 8, row * 380 + 364), f"{take} / {second:.1f}s", fill="white")
        results.append({"file": str(dest), "seconds": 4, "fps": 60, "frames": 240, "speech": report["speech"],
                        "reaction_row": report["reaction_row"], "voice_path": report["voice_path"],
                        "sfx_percent": 100, "bgm_percent": 0, "audio_peak": peak, "audio_rms": rms,
                        "crop": [x, y, width, height], "scale": 2, "foreground_samples": 0})
        print("FINISHED", dest, flush=True)
    sheet.save(ROOT / "delivery_contact.jpg", quality=95)
    (ROOT / "delivery_validation.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
