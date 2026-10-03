"""Validate installed art, or install reviewed PNGs from an explicit --source.

The source directory uses the same relative layout as assets/ (sprites/, ui/).
No arguments, or --check, validates current assets without modifying anything.
Existing Godot import files stay put. No review-directory dependency is retained.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
SUBJECTS = ("beginner", "capitalist", "enemy", "boss")
BOSS_ACTIONS = {
    "idle": (1, 1.0, True), "move": (6, 6.0, True),
    "windup": (7, 8.75, False), "dash": (2, 12.5, False), "recover": (1, 2.0, False),
}
BOSS_FRAME_SIZE = 128
BOSS_TARGET = "assets/sprites/enemies/iron_knight"


def asset_pairs(subjects=SUBJECTS):
    for character, prefix in (("beginner", "void_hunter"), ("capitalist", "capitalist")):
        if character not in subjects:
            continue
        for destination, size in (
            (f"sprites/player/combat/{prefix}_idle_right.png", (64, 64)),
            (f"sprites/player/combat/{prefix}_walk_right_spritesheet.png", (384 if character == "beginner" else 448, 64)),
            (f"sprites/player/{prefix}_idle_right.png", (256, 256)),
            (f"ui/icons/characters/icon_{prefix}.png", (128, 128)),
        ):
            yield destination, size
    if "enemy" in subjects:
        for name, size in (("enemy_gloom_mite_idle.png", (32, 32)), ("enemy_gloom_mite_move.png", (224, 32))):
            yield f"sprites/enemies/combat/{name}", size
    if "boss" in subjects:
        for action, (count, _, _) in BOSS_ACTIONS.items():
            name = f"knight_{action}.png"
            yield f"sprites/enemies/iron_knight/{name}", (BOSS_FRAME_SIZE * count, BOSS_FRAME_SIZE)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validated_assets(subjects=SUBJECTS, source_root=ASSETS):
    records = []
    for destination, size in asset_pairs(subjects):
        path = Path(source_root) / destination
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != size:
                raise ValueError(f"Unexpected sprite format: {path}")
            colors = {pixel for _, pixel in image.getcolors(maxcolors=image.width * image.height)}
            if {pixel[3] for pixel in colors} != {0, 255} or len({pixel[:3] for pixel in colors if pixel[3]}) > 16:
                raise ValueError(f"Sprite must use binary alpha and at most 16 visible colors: {path}")
        records.append({"source": str(path), "destination": destination, "sha256": digest(path)})
    return records


def boss_resource():
    steps = 1 + len(BOSS_ACTIONS) + sum(spec[0] for spec in BOSS_ACTIONS.values())
    lines = [f'[gd_resource type="SpriteFrames" load_steps={steps} format=3]', ""]
    for action in BOSS_ACTIONS:
        lines.append(f'[ext_resource type="Texture2D" path="res://{BOSS_TARGET}/knight_{action}.png" id="tex_{action}"]')
    animations = []
    for action, (count, speed, loop) in BOSS_ACTIONS.items():
        frames = []
        for index in range(count):
            lines += ["", f'[sub_resource type="AtlasTexture" id="{action}_{index}"]',
                      f'atlas = ExtResource("tex_{action}")', f'region = Rect2({BOSS_FRAME_SIZE * index}, 0, {BOSS_FRAME_SIZE}, {BOSS_FRAME_SIZE})']
            frames.append(f'{{"duration": 1.0, "texture": SubResource("{action}_{index}")}}')
        animations.append('"frames": [\n' + ',\n'.join(frames) + '\n],\n"loop": ' + str(loop).lower()
                          + f',\n"name": &"{action}",\n"speed": {speed}')
    lines += ["", "[resource]", 'animations = [{\n' + '\n}, {\n'.join(animations) + '\n}]', ""]
    return '\n'.join(lines)


def check_installed(subjects=SUBJECTS, asset_root=ASSETS):
    records = validated_assets(subjects, asset_root)
    if "boss" in subjects:
        actual = (Path(asset_root) / "sprites/enemies/iron_knight/iron_knight_sprite_frames.tres").read_text(encoding="utf-8")
        if actual != boss_resource():
            raise ValueError("Boss SpriteFrames differs from approved animation layout")
    print(f"PASS: {len(records)} installed textures have valid dimensions, palette and alpha")
    return records


def install_assets(subjects=SUBJECTS, source=None, asset_root=ASSETS):
    if source is None:
        return check_installed(subjects, asset_root)
    records = validated_assets(subjects, Path(source).resolve())  # Validate the whole batch before overwriting.
    for record in records:
        target = Path(asset_root) / record["destination"]
        target.parent.mkdir(parents=True, exist_ok=True)
        if Path(record["source"]).resolve() != target.resolve():
            shutil.copyfile(record["source"], target)
        if digest(target) != record["sha256"]:
            raise ValueError(f"Installed bytes differ from input: {target}")
        print(f"INSTALLED: {record['destination']}")
    if "boss" in subjects:
        target = Path(asset_root) / "sprites/enemies/iron_knight"
        (target / "iron_knight_sprite_frames.tres").write_text(boss_resource(), encoding="utf-8")
        report = {"frame_size": [BOSS_FRAME_SIZE, BOSS_FRAME_SIZE], "movement_foot_anchor": [64, 118], "death": "freeze_current_pose_and_fade",
                  "actions": {name: {"frames": n, "fps": fps, "loop": loop} for name, (n, fps, loop) in BOSS_ACTIONS.items()}}
        (target / "manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    check_installed(subjects, asset_root)
    return records


def run_cli(subjects=SUBJECTS):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--source", type=Path, help="Reviewed input directory with assets-compatible paths")
    args = parser.parse_args()
    install_assets(subjects, source=args.source)


if __name__ == "__main__":
    run_cli()
