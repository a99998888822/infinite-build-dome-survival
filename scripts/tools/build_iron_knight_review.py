"""Render an animation contact sheet from installed Boss art into temp."""
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw
from install_combat_picxel_assets import ASSETS, BOSS_ACTIONS, BOSS_FRAME_SIZE, check_installed


def main():
    check_installed(("boss",))
    target = Path(tempfile.mkdtemp(prefix="dome-iron-knight-preview-"))
    size = BOSS_FRAME_SIZE
    board = Image.new("RGB", (120 + size * max(spec[0] for spec in BOSS_ACTIONS.values()), size * len(BOSS_ACTIONS)), "#203030")
    draw = ImageDraw.Draw(board)
    for row, action in enumerate(BOSS_ACTIONS):
        draw.text((10, row * size + size // 2), action, fill="white")
        with Image.open(ASSETS / f"sprites/enemies/iron_knight/knight_{action}.png") as sheet:
            board.paste(sheet, (120, row * size), sheet)
    board.save(target / "boss-frames.png")
    print(target)


if __name__ == "__main__":
    main()
