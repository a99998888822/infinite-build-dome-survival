"""Copy approved references into a separate Godot project; never edit sources."""
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REFERENCE = HERE / "sandbox" / "reference"
REFERENCE.mkdir(parents=True, exist_ok=True)
manifest = {}

def copy_reference(relative, name):
    source = ROOT / relative
    target = REFERENCE / name
    shutil.copyfile(source, target)
    manifest[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
    return target

for pose in ["idle", "move", "windup", "dash", "recover"]:
    copy_reference(f"assets/sprites/enemies/iron_knight/knight_{pose}.png", f"knight_{pose}.png")
copy_reference("assets/font/ark-pixel-12px-monospaced-zh_cn.otf", "chinese.otf")
source = ROOT / "assets/sprites/enemies/iron_knight/iron_knight_sprite_frames.tres"
frames = source.read_text(encoding="utf-8").replace("res://assets/sprites/enemies/iron_knight/", "res://reference/")
(REFERENCE / "frames.tres").write_text(frames, encoding="utf-8")
manifest[str(source.relative_to(ROOT)).replace("\\", "/")] = hashlib.sha256(source.read_bytes()).hexdigest()
ground = ROOT / "assets/sprites/background/meadow/meadow-ground.png"
with Image.open(ground) as im:
    im.crop((350, 350, 942, 648)).save(REFERENCE / "ground.png")
manifest[str(ground.relative_to(ROOT)).replace("\\", "/")] = hashlib.sha256(ground.read_bytes()).hexdigest()
(HERE / "reference_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("PREPARED_ISOLATED_REFERENCES", len(manifest))
