"""Export current approved Boss previews to temp; never redraw obsolete art."""
import shutil
import tempfile
from pathlib import Path
from install_combat_picxel_assets import PACKAGE, validated_assets


def main():
    validated_assets(("boss",))
    target = Path(tempfile.mkdtemp(prefix="dome-iron-knight-preview-"))
    for name in ("boss_walk.gif", "boss_attack.gif", "boss_walk-frames.png", "boss_attack-frames.png", "manifest.json"):
        shutil.copyfile(PACKAGE / name, target / name)
    print(target)


if __name__ == "__main__":
    main()
