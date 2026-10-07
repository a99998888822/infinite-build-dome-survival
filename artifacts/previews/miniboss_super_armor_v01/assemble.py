"""Build review media directly from GPU frames; preserve pixel edges."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ffmpeg = shutil.which("ffmpeg")
assert ffmpeg
summary = {"preview_only": True, "version": 2, "fps": 30, "cycle_seconds": 2.8,
           "armor_seconds": 2.0, "text_seconds": 0.8, "text_scale": 0.7,
           "palette": ["yellow", "orange", "red"], "color_speed_multiplier": 4,
           "source_outline_pixels": 3, "game_outline_pixels": 1.68,
           "variants": {}, "references_unchanged": True}
manifest = json.loads((HERE / "reference_manifest.json").read_text(encoding="utf-8"))
for relative, expected in manifest.items():
    assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, relative

for name in ["idle", "move", "mirrored"]:
    frames = HERE / "frames" / "v02" / name
    if not frames.is_dir():
        continue
    paths = sorted(frames.glob("frame_*.png"))
    assert len(paths) == 84, (name, len(paths))
    gpu = json.loads((HERE / f"gpu_v02_{name}.json").read_text(encoding="utf-8"))
    assert gpu["exit_code"] == 0 and gpu["foreground_samples"] == 0
    assert gpu["private_desktop"] == gpu["verified_desktop"]
    log = (HERE / f"gpu_v02_{name}.log").read_text(encoding="utf-8")
    assert not any(word in log for word in ["SCRIPT ERROR", "ERROR:", "Parse Error", "SHADER ERROR"])
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                    "-i", str(frames / "frame_%04d.png"), "-c:v", "libx264", "-preset", "slow",
                    "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                    str(HERE / f"{name}_v02.mp4")], check=True)
    summary["variants"][name] = {"frames": len(paths), "foreground_samples": 0, "gpu_errors": 0}

subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
                "-i", str(HERE / "frames/v02/idle/frame_%04d.png"), "-filter_complex",
                "fps=20,split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=none",
                "-loop", "0", str(HERE / "armor_preview_v02.gif")], check=True)
shutil.copyfile(HERE / "frames/v02/idle/frame_0019.png", HERE / "poster_v02.png")
for title, frame in [("trigger", 12), ("rise", 23), ("flow", 62), ("normal", 4)]:
    with Image.open(HERE / f"frames/v02/idle/frame_{frame:04d}.png") as image:
        image.crop((464, 174, 816, 447)).save(HERE / f"{title}_v02.png")
with Image.open(HERE / "armor_preview_v02.gif") as image:
    assert image.size == (960, 540)
    duration = 0
    for i in range(image.n_frames):
        image.seek(i)
        duration += image.info["duration"]
    assert duration == 2800, duration
summary["gif_duration_ms"] = duration
(HERE / "validation.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary))
