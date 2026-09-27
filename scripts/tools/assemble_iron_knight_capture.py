"""Crop actual Godot viewport frames; keep raw captures outside the repository."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture_dir", type=Path)
    args = parser.parse_args()
    capture = json.loads((args.capture_dir / "capture.json").read_text(encoding="utf-8"))
    assert capture["production"] and capture["valid"] and capture["loot_seen"]
    assert len(list(args.capture_dir.glob("frame_*.png"))) == capture["frames"]
    out = ROOT / "artifacts/reviews/effects/iron_knight"
    out.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    assert ffmpeg, "ffmpeg required"
    filters = "fps=50,crop=520:270:150:160,scale=1040:540:flags=neighbor,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=none"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "warning", "-framerate", str(capture["fps"]),
                    "-i", str(args.capture_dir / "frame_%04d.png"), "-filter_complex", filters,
                    "-loop", "0", "-y", str(out / "game.gif")], check=True)
    warning = [sample for sample in capture["samples"] if sample["state"] == "windup"]
    dash = [sample for sample in capture["samples"] if sample["state"] == "dash"]
    still = warning[len(warning) * 3 // 4]["frame"]
    shutil.copyfile(args.capture_dir / f"frame_{still:04d}.png", out / "game.png")
    summary = {key: capture[key] for key in ["production", "valid", "fps", "frames", "states", "loot_seen", "sprite_frames"]}
    summary.update({"windup_start_distance": warning[0]["distance"], "dash_render_frames": len(dash),
                    "driver": "opengl3_angle", "crop": [150,160,520,270], "nearest_scale": 2})
    assert warning[0]["distance"] <= 240.0
    with Image.open(out / "game.gif") as gif:
        duration = 0
        for i in range(gif.n_frames):
            gif.seek(i)
            duration += gif.info["duration"]
        assert duration == 7000
        summary["gif"] = {"frames": gif.n_frames, "duration_ms": duration, "size": gif.size}
    (out / "capture_summary.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
