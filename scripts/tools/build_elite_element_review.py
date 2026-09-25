"""Isolated production validation and GIF export; source frames remain in temp."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/elite_elements_20260925"
TEMP = Path(os.environ["TEMP"]) / "codex-elite-elements-20260925"
PROJECT = TEMP / "project"
GODOT = Path("D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = shutil.which("ffmpeg")


def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").write_text("\n", encoding="utf-8")
    for folder in ["scripts", "scenes", "autoloads", "data_config", "assets", "shaders"]:
        shutil.copytree(ROOT / folder, PROJECT / folder, dirs_exist_ok=True)
    shutil.copytree(ROOT / ".godot/imported", PROJECT / ".godot/imported", dirs_exist_ok=True)
    shutil.copy2(ROOT / "icon.svg", PROJECT / "icon.svg")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    project = project.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CodexEliteElementsReview20260925"')
    (PROJECT / "project.godot").write_text(project, encoding="utf-8")
    print(PROJECT)


def export(variant, output=OUT):
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").write_text("\n", encoding="utf-8")
    frames = TEMP / variant
    manifest = json.loads((frames / "capture.json").read_text(encoding="utf-8"))
    assert manifest["production"] and manifest["failures"] == 0
    # Crop the recorded world around the player and effect, then nearest upscale.
    # No animation is synthesized: every frame is a viewport capture from Godot.
    crop = "crop=460:300:400:175,scale=920:600:flags=neighbor" if variant == "elite" else "crop=360:270:480:200,scale=720:540:flags=neighbor"
    filters = f"fps=20,{crop},split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];[b][p]paletteuse=dither=none"
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "warning", "-framerate", "30", "-i", str(frames / "frame_%04d.png"),
                    "-filter_complex", filters, "-loop", "0", "-y", str(output / f"{variant}.gif")], check=True)
    still_index = 190 if variant == "elite" else (30 if variant == "steam" else 20)
    shutil.copy2(frames / f"frame_{still_index:04d}.png", output / f"{variant}_full.png")
    (output / f"{variant}_capture.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    with Image.open(output / f"{variant}.gif") as gif:
        duration = sum(gif.seek(i) or gif.info.get("duration", 0) for i in range(gif.n_frames))
        result = {"frames": gif.n_frames, "duration_ms": duration, "size": list(gif.size)}
        assert gif.n_frames > 40 and duration >= 5900
    print(json.dumps({variant: result}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["prepare", "export"])
    parser.add_argument("variants", nargs="*")
    parser.add_argument("--output", type=Path, default=OUT)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare()
    else:
        for variant in args.variants or ["elite", "water", "steam", "frost"]:
            export(variant, args.output)
