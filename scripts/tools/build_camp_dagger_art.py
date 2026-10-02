"""Validate installed dagger art; --write exports the adjacent editable PXG files."""
import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = {
    'assets/ui/icons/weapons/weapon_camp_dagger.png': (64, 16),
    'assets/sprites/weapons/camp_dagger.png': (32, 12),
    'assets/sprites/weapons/effects/camp_dagger_slash.png': (64, 3),
}


def render_grid(path, size):
    header, grid = path.read_text(encoding='utf-8').split('---', 1)
    palette = {'.': (0, 0, 0, 0)}
    for line in header.splitlines():
        key, sep, value = line.partition(':')
        value = value.strip()
        if sep and len(key) == 1 and value.startswith('#'):
            palette[key] = (*bytes.fromhex(value[1:]), 255)
    rows = grid.strip().splitlines()
    if len(rows) != size or any(len(row) != size for row in rows):
        raise ValueError(f'Invalid pixel grid dimensions: {path}')
    image = Image.new('RGBA', (size, size))
    image.putdata([palette[symbol] for row in rows for symbol in row])
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='regenerate PNGs from editable sources')
    args = parser.parse_args()
    # Validate every source before writing any asset.
    images = []
    for relative, (size, max_colors) in ASSETS.items():
        path = ROOT / relative
        image = render_grid(path.with_suffix('.pxg'), size)
        colors = {rgba for _count, rgba in image.getcolors(size * size) if rgba[3]}
        if len(colors) > max_colors:
            raise ValueError(f'Too many colors: {relative}')
        images.append((path, image))
    for path, image in images:
        if args.write:
            image.save(path)
        with Image.open(path) as installed:
            if installed.mode != 'RGBA' or installed.size != image.size or installed.tobytes() != image.tobytes():
                raise ValueError(f'PNG does not match editable source: {path}')
        print(f'OK {path.relative_to(ROOT).as_posix()} {image.width}x{image.height}')


if __name__ == '__main__':
    main()
