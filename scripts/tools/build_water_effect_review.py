"""Capture production water combinations; retain raw frames outside the repo."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TEMP = Path(os.environ["TEMP"]) / "codex-water-combinations-20260925"
PROJECT = TEMP / "project"
OUT = ROOT / "artifacts/water_combinations_20260925"
GODOT = Path("D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = shutil.which("ffmpeg")
VARIANTS = {
    "water": "单独水流",
    "fire": "水流 + 火焰：汽化",
    "ice": "水流 + 结霜：冻结",
    "chain": "水流 + 电火花：导电",
    "wind": "水流 + 风刃：潮湿扩散",
    "thunder": "水流 + 落雷：导电",
    "light": "水流 + 光辉剑",
    "dark": "水流 + 黑洞",
    "explosion": "水流 + 爆裂",
}


def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    PROJECT.mkdir(parents=True, exist_ok=True)
    for folder in ["scripts", "scenes", "autoloads", "data_config", "assets", "shaders"]:
        shutil.copytree(ROOT / folder, PROJECT / folder, dirs_exist_ok=True)
    shutil.copytree(ROOT / ".godot/imported", PROJECT / ".godot/imported", dirs_exist_ok=True)
    shutil.copy2(ROOT / "icon.svg", PROJECT / "icon.svg")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    project = project.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CodexWaterCombinationReview20260925"')
    (PROJECT / "project.godot").write_text(project, encoding="utf-8")
    print(PROJECT, flush=True)


def capture(variants):
    for variant in variants:
        destination = TEMP / "frames" / variant
        destination.mkdir(parents=True, exist_ok=True)
        command = [str(GODOT), "--path", str(PROJECT), "--rendering-driver", "opengl3_angle",
                   "--scene", "res://scenes/tests/water_effect_live_capture.tscn", "--fixed-fps", "30",
                   "--", f"--variant={variant}", f"--capture-dir={destination}"]
        with (OUT / f"{variant}.log").open("w", encoding="utf-8") as log:
            completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        report = json.loads((destination / "capture.json").read_text(encoding="utf-8"))
        assert completed.returncode == 0 and report["failures"] == 0, variant
        shutil.copy2(destination / "capture.json", OUT / f"{variant}_capture.json")
        print("CAPTURE_OK", variant, report["checks"], flush=True)


def encode(pattern, destination, filters):
    assert FFMPEG, "ffmpeg is required"
    graph = filters + ",split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];[b][p]paletteuse=dither=none"
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-framerate", "30",
                    "-i", str(pattern), "-filter_complex", graph, "-loop", "0", "-y", str(destination)], check=True)


def export(variants):
    for variant in variants:
        frames = TEMP / "frames" / variant
        encode(frames / "frame_%04d.png", OUT / f"{variant}.gif",
               "fps=20,crop=480:360:416:129,scale=960:720:flags=neighbor")
        shutil.copy2(frames / "frame_0020.png", OUT / f"{variant}_full.png")
        print("EXPORT_OK", variant, flush=True)
    if set(variants) == set(VARIANTS):
        montage(["fire", "ice", "chain", "wind"], "reactions")
        montage(["thunder", "light", "dark", "explosion"], "combinations")
    specs = {}
    for path in OUT.glob("*.gif"):
        with Image.open(path) as gif:
            duration = sum(gif.seek(i) or gif.info.get("duration", 0) for i in range(gif.n_frames))
            assert gif.n_frames == 120 and duration == 6000, path
            specs[path.name] = {"frames": gif.n_frames, "duration_ms": duration, "size": list(gif.size), "bytes": path.stat().st_size}
    specs["production_water_sha256"] = hashlib.sha256((ROOT / "scripts/effects/water_wave_effect.gd").read_bytes()).hexdigest()
    assert (ROOT / "scripts/effects/water_wave_effect.gd").read_bytes() == (PROJECT / "scripts/effects/water_wave_effect.gd").read_bytes()
    (OUT / "media_validation.json").write_text(json.dumps(specs, indent=2) + "\n", encoding="utf-8")


def montage(variants, name):
    destination = TEMP / "montages" / name
    destination.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 21)
    for index in range(180):
        image = Image.new("RGB", (960, 800), "#142128")
        draw = ImageDraw.Draw(image)
        for panel, variant in enumerate(variants):
            x, y = panel % 2 * 480, panel // 2 * 400
            with Image.open(TEMP / "frames" / variant / f"frame_{index:04d}.png") as frame:
                image.paste(frame.crop((416, 129, 896, 489)).convert("RGB"), (x, y + 40))
            draw.text((x + 14, y + 7), VARIANTS[variant], font=font, fill="#d8eeee")
        image.save(destination / f"frame_{index:04d}.png")
    encode(destination / "frame_%04d.png", OUT / f"{name}.gif", "fps=20")
    print("MONTAGE_OK", name, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["prepare", "capture", "export"])
    parser.add_argument("--variants", nargs="+", choices=list(VARIANTS), default=list(VARIANTS))
    args = parser.parse_args()
    if args.action == "prepare": prepare()
    elif args.action == "capture": capture(args.variants)
    else: export(args.variants)
