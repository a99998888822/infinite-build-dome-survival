"""Render the approval-only draft without replacing any production resource."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TEMP = Path(os.environ["TEMP"]) / "codex-water-expansion-preview-r3-20260925"
PROJECT = TEMP / "project"
FRAMES = TEMP / "frames"
GODOT = Path("D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")


def run(command, log):
    TEMP.mkdir(parents=True, exist_ok=True)
    with (TEMP / log).open("w", encoding="utf-8") as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=150)
    text = (TEMP / log).read_text(encoding="utf-8")
    assert result.returncode == 0 and not any(x in text for x in ["SCRIPT ERROR", "Parse Error", "Compile Error"]), log
    print("OK", log, flush=True)


def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    protected = [*(ROOT / "scripts/effects").glob("*.gd"), ROOT / "data_config/augmentations.json",
                 *(ROOT / "artifacts/reviews/effects").glob("water_*.gif")]
    before = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    (TEMP / "production_before.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
    for folder in ["scripts", "scenes", "autoloads", "data_config", "assets", "shaders"]:
        shutil.copytree(ROOT / folder, PROJECT / folder, dirs_exist_ok=True)
    shutil.copytree(ROOT / ".godot/imported", PROJECT / ".godot/imported", dirs_exist_ok=True)
    shutil.copy2(ROOT / "icon.svg", PROJECT / "icon.svg")
    settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    settings = settings.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CodexWaterExpansionDraftR320260925"')
    (PROJECT / "project.godot").write_text(settings, encoding="utf-8")
    for source in ["expanding_water_draft.gd", "capture_draft.gd"]:
        destination = PROJECT / "scripts/debug" / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(HERE / source, destination)
    scene = PROJECT / "scenes/debug/water_expansion_draft.tscn"
    scene.parent.mkdir(parents=True, exist_ok=True)
    scene.write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/debug/capture_draft.gd" id="1"]\n\n[node name="WaterExpansionDraft" type="Node"]\nscript = ExtResource("1")\n', encoding="utf-8")
    run([str(GODOT), "--headless", "--editor", "--path", str(PROJECT), "--quit"], "editor.log")


def capture():
    FRAMES.mkdir(parents=True, exist_ok=True)
    base = [str(GODOT), "--path", str(PROJECT), "--scene", "res://scenes/debug/water_expansion_draft.tscn", "--fixed-fps", "30", "--quit-after", "600"]
    run(base + ["--headless"], "headless.log")
    run(base + ["--rendering-driver", "opengl3_angle", "--", f"--capture-dir={FRAMES}"], "capture.log")


def encode(name, rate):
    ffmpeg = shutil.which("ffmpeg")
    assert ffmpeg
    graph = "fps=20,crop=480:360:466:159,scale=960:720:flags=neighbor,split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];[b][p]paletteuse=dither=none"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-framerate", str(rate), "-i", str(FRAMES / "frame_%04d.png"), "-filter_complex", graph, "-loop", "0", "-y", str(HERE / name)], check=True)


def export():
    encode("water_expansion.gif", 30)
    specs = {}
    for name in ["water_expansion.gif"]:
        with Image.open(HERE / name) as gif:
            duration = sum(gif.seek(i) or gif.info.get("duration", 0) for i in range(gif.n_frames))
            specs[name] = {"frames": gif.n_frames, "duration_ms": duration, "size": list(gif.size)}
            assert duration == 4000
    before = json.loads((TEMP / "production_before.json").read_text(encoding="utf-8"))
    changed = [name for name, digest in before.items() if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]
    assert not changed, changed
    specs["preview_only"] = True
    specs["production_and_approved_media_unchanged"] = len(before)
    proof = json.loads((FRAMES / "range_check.json").read_text(encoding="utf-8"))
    assert proof["passed"] and abs(proof["actual_damage_radius"] - proof["visual_max_radius"]) < 0.001
    shutil.copy2(FRAMES / "range_check.json", HERE / "range_check.json")
    specs["draft_radius"] = proof["visual_max_radius"]
    specs["radius_scale"] = proof["radius_scale"]
    specs["isolated_damage_range_verified"] = True
    specs["draft_duration_seconds"] = 0.85
    (TEMP / "verification.json").write_text(json.dumps(specs, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(specs), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["prepare", "capture", "export"])
    action = parser.parse_args().action
    {"prepare": prepare, "capture": capture, "export": export}[action]()
