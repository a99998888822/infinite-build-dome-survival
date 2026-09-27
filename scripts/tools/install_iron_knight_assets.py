"""Install the approved pixel sheets without changing their pixels or resolution."""
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image
from build_iron_knight_review import ANCHOR, ROOT, SIZE, SPECS, draw_frame


def main():
    approved = ROOT / "artifacts/previews/iron_knight"
    target = ROOT / "assets/sprites/enemies/iron_knight"
    target.mkdir(parents=True, exist_ok=True)
    report = {"frame_size": [SIZE, SIZE], "anchor": ANCHOR, "actions": {}}
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1+len(SPECS)+sum(len(v[0]) for v in SPECS.values())} format=3]', '']
    for action, (durations, _) in SPECS.items():
        name = f"knight_{action}.png"
        with Image.open(approved / name) as sheet:
            assert sheet.size == (SIZE * len(durations), SIZE)
            for i in range(len(durations)):
                assert sheet.crop((SIZE*i, 0, SIZE*(i+1), SIZE)).tobytes() == draw_frame(action, i).tobytes(), (action, i)
        shutil.copyfile(approved / name, target / name)
        report["actions"][action] = {"frames": len(durations), "durations_ms": durations,
                                    "sha256": hashlib.sha256((target / name).read_bytes()).hexdigest()}
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/iron_knight/{name}" id="tex_{action}"]')
    for action, (durations, _) in SPECS.items():
        for i in range(len(durations)):
            lines += ['', f'[sub_resource type="AtlasTexture" id="{action}_{i}"]',
                      f'atlas = ExtResource("tex_{action}")', f'region = Rect2({SIZE*i}, 0, {SIZE}, {SIZE})']
    lines += ['', '[resource]', 'animations = [{']
    records = []
    for action, (durations, loop) in SPECS.items():
        frames = ',\n'.join('{"duration": %.2f, "texture": SubResource("%s_%d")}' % (dt/100, action, i) for i, dt in enumerate(durations))
        records.append('"frames": [\n'+frames+'\n],\n"loop": '+str(loop).lower()+',\n"name": &"'+action+'",\n"speed": 10.0')
    lines += ['\n}, {\n'.join(records), '}]', '']
    (target / "iron_knight_sprite_frames.tres").write_text('\n'.join(lines), encoding="utf-8")
    (target / "manifest.json").write_text(json.dumps(report, indent=2)+'\n', encoding="utf-8")
    print(json.dumps({"installed": str(target), "frames": sum(len(v[0]) for v in SPECS.values()), "approved_pixels_verified": True}))


if __name__ == "__main__":
    main()
