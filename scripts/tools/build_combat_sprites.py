"""Build native-size combat sprites from the retained high-resolution originals.

Run from any directory with Python and Pillow. No runtime dependency on Python.
Nearest sampling, one shared player palette, binary alpha and a one-pixel
contour keep all animation frames on the same pixel grid without dithering.
"""

from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"
OUTLINE = (20, 27, 30, 255)
PLAYER_SIZE = 54  # Previously 256 * 0.21 = 53.76 world units.
ENEMY_SIZE = 86  # Previously 128 * 0.675 = 86.4 world units.


def read_frames(path: Path, frame_size: int, count: int) -> list[Image.Image]:
    with Image.open(path) as source:
        source = source.convert("RGBA")
        if source.size != (frame_size * count, frame_size):
            raise ValueError(f"Unexpected sprite sheet size: {path}: {source.size}")
        return [
            source.crop((i * frame_size, 0, (i + 1) * frame_size, frame_size))
            for i in range(count)
        ]


def native_frame(source: Image.Image, size: int) -> Image.Image:
    result = source.resize((size, size), Image.Resampling.NEAREST)
    result.putalpha(result.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return result


def shared_palette(frames: list[Image.Image]) -> Image.Image:
    visible = [
        frame.getpixel((x, y))[:3]
        for frame in frames
        for y in range(frame.height)
        for x in range(frame.width)
        if frame.getpixel((x, y))[3]
    ]
    training = Image.new("RGB", (len(visible), 1))
    training.putdata(visible)
    return training.quantize(colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def finish_frame(frame: Image.Image, palette: Image.Image | None = None) -> Image.Image:
    alpha = frame.getchannel("A")
    if palette is not None:
        frame = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        frame.putalpha(alpha)
    # Four neighbours preserve diagonal corners and do not introduce a glow.
    expanded = alpha.copy()
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        shifted = Image.new("L", frame.size)
        shifted.paste(alpha, (dx, dy))
        expanded = ImageChops.lighter(expanded, shifted)
    contour = Image.new("RGBA", frame.size, OUTLINE)
    contour.putalpha(ImageChops.subtract(expanded, alpha))
    result = Image.alpha_composite(contour, frame)
    # Canonical transparent pixels prevent invisible RGB from polluting palettes.
    clean = Image.new("RGBA", frame.size)
    clean.paste(result, (0, 0), result.getchannel("A"))
    return clean


def save_sheet(frames: list[Image.Image], path: Path) -> None:
    size = frames[0].width
    sheet = Image.new("RGBA", (size * len(frames), size))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * size, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)
    print(f"Built {path.relative_to(ROOT)}: {sheet.width}x{sheet.height}")


def main() -> None:
    player_path = SPRITES / "player"
    idle_name = "void_hunter_idle_right.png"
    walk_name = "void_hunter_walk_right_spritesheet.png"
    sources = read_frames(player_path / idle_name, 256, 1) + read_frames(player_path / walk_name, 256, 4)
    player = [native_frame(frame, PLAYER_SIZE) for frame in sources]
    # Align the final shadow/foot row across idle and every walk frame.
    baseline = player[0].getbbox()[3]
    for i, frame in enumerate(player):
        aligned = Image.new("RGBA", frame.size)
        aligned.paste(frame, (0, baseline - frame.getbbox()[3]))
        player[i] = aligned
    palette = shared_palette(player)
    player = [finish_frame(frame, palette) for frame in player]
    save_sheet(player[:1], player_path / "combat" / idle_name)
    save_sheet(player[1:], player_path / "combat" / walk_name)

    enemy_path = SPRITES / "enemies"
    for name, count in (("enemy_gloom_mite_idle.png", 1), ("enemy_gloom_mite_move.png", 3)):
        frames = read_frames(enemy_path / name, 128, count)
        frames = [finish_frame(native_frame(frame, ENEMY_SIZE)) for frame in frames]
        save_sheet(frames, enemy_path / "combat" / name)


if __name__ == "__main__":
    main()
