"""Install approved Picxel exports byte-for-byte; --check verifies without writes.

The new package owns beginner/enemy/Boss; player_picxel still owns capitalist.
Export and review edited grids before installing. Existing Godot imports stay put.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "artifacts/previews/combat_picxel_3838180"
PLAYER_PACKAGE = ROOT / "artifacts/previews/player_picxel"
SUBJECTS = ("beginner", "capitalist", "enemy", "boss")
BOSS_ACTIONS = {
    "idle": (1, 1.0, True), "move": (11, 11.0, True),
    "windup": (7, 8.75, False), "dash": (2, 12.5, False), "recover": (2, 4.0, False),
}
BOSS_TARGET = "assets/sprites/enemies/iron_knight"


def asset_pairs(subjects=SUBJECTS):
    for character, prefix in (("beginner", "void_hunter"), ("capitalist", "capitalist")):
        if character not in subjects:
            continue
        package = PACKAGE if character == "beginner" else PLAYER_PACKAGE
        walk = f"{prefix}_walk_right_all_frames.png" if character == "beginner" else f"{prefix}_walk_right_spritesheet.png"
        for source, destination, size in (
            (f"combat/{prefix}_idle_right.png", f"sprites/player/combat/{prefix}_idle_right.png", (54, 54)),
            (f"combat/{walk}", f"sprites/player/combat/{prefix}_walk_right_spritesheet.png", (432 if character == "beginner" else 216, 54)),
            (f"ui/{prefix}_idle_right.png", f"sprites/player/{prefix}_idle_right.png", (256, 256)),
            (f"ui/icon_{prefix}.png", f"ui/icons/characters/icon_{prefix}.png", (128, 128)),
        ):
            yield package, f"delivery/{character}/{source}", f"assets/{destination}", size
    if "enemy" in subjects:
        for source, name, size in (("enemy_gloom_mite_idle.png", "enemy_gloom_mite_idle.png", (86, 86)),
                                   ("enemy_gloom_mite_move_all_frames.png", "enemy_gloom_mite_move.png", (602, 86))):
            yield PACKAGE, f"delivery/enemy/combat/{source}", f"assets/sprites/enemies/combat/{name}", size
    if "boss" in subjects:
        for action, (count, _, _) in BOSS_ACTIONS.items():
            name = f"knight_{action}.png"
            yield PACKAGE, f"delivery/boss/combat/{name}", f"{BOSS_TARGET}/{name}", (160 * count, 160)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validated_assets(subjects=SUBJECTS):
    records = []
    for package, source, destination, size in asset_pairs(subjects):
        manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
        expected = next(row for row in manifest["files"] if row["path"] == source)
        path = package / source
        if digest(path) != expected["sha256"] or tuple(expected["size"]) != size:
            raise ValueError(f"Review manifest mismatch: {path}")
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != size:
                raise ValueError(f"Unexpected sprite format: {path}")
            colors = {pixel for _, pixel in image.getcolors(maxcolors=image.width * image.height)}
            if {pixel[3] for pixel in colors} != {0, 255} or len({pixel[:3] for pixel in colors if pixel[3]}) > 16:
                raise ValueError(f"Sprite must use binary alpha and at most 16 visible colors: {path}")
        records.append({"package": package.relative_to(ROOT).as_posix(), "source": source,
                        "destination": destination, "sha256": expected["sha256"]})
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
                      f'atlas = ExtResource("tex_{action}")', f'region = Rect2({160 * index}, 0, 160, 160)']
            frames.append(f'{{"duration": 1.0, "texture": SubResource("{action}_{index}")}}')
        animations.append('"frames": [\n' + ',\n'.join(frames) + '\n],\n"loop": ' + str(loop).lower()
                          + f',\n"name": &"{action}",\n"speed": {speed}')
    lines += ["", "[resource]", 'animations = [{\n' + '\n}, {\n'.join(animations) + '\n}]', ""]
    return '\n'.join(lines)


def check_installed(subjects=SUBJECTS):
    records = validated_assets(subjects)
    for record in records:
        target = ROOT / record["destination"]
        if not target.is_file() or digest(target) != record["sha256"]:
            raise ValueError(f"Texture differs from approved package: {target}")
    if "boss" in subjects:
        actual = (ROOT / BOSS_TARGET / "iron_knight_sprite_frames.tres").read_text(encoding="utf-8")
        if actual != boss_resource():
            raise ValueError("Boss SpriteFrames differs from approved animation layout")
    print(f"PASS: {len(records)} installed Picxel textures match approved packages")
    return records


def install_assets(subjects=SUBJECTS):
    records = validated_assets(subjects)  # Validate the complete batch before any overwrite.
    for record in records:
        target = ROOT / record["destination"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / record["package"] / record["source"], target)
        print(f"INSTALLED: {record['destination']}")
    if "boss" in subjects:
        target = ROOT / BOSS_TARGET
        (target / "iron_knight_sprite_frames.tres").write_text(boss_resource(), encoding="utf-8")
        report = {"frame_size": [160, 160], "movement_foot_anchor": [80, 128], "death": "freeze_current_pose_and_fade",
                  "actions": {name: {"frames": n, "fps": fps, "loop": loop} for name, (n, fps, loop) in BOSS_ACTIONS.items()}}
        (target / "manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    check_installed(subjects)
    for package in {record["package"] for record in records}:
        manifest_path = ROOT / package / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        current = [record for record in validated_assets() if record["package"] == package]
        installed = [record for record in current if (ROOT / record["destination"]).is_file()
                     and digest(ROOT / record["destination"]) == record["sha256"]]
        manifest.update(status="installed" if len(installed) == len(current) else "partially_installed",
                        runtime_assets_modified=True, installed_assets=installed)
        if ROOT / package == PLAYER_PACKAGE:
            manifest["active_subjects"] = ["capitalist"]
            manifest["superseded_subjects"] = {"beginner": PACKAGE.relative_to(ROOT).as_posix()}
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    check_installed() if args.check else install_assets()
