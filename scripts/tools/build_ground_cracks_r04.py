"""Retouch the authored PXG pixels: thicker original fissures and short fine forks.

No generated-model imagery, recoloring, glow, or smoothing. The original atlas
and editable sources stay intact; the candidate has its own import path.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/sprites/weapons/ground_cracks'
OUTPUT = SOURCE / 'review_r04'
NAMES = [f'ground_crack_{i:02}-64' for i in range(3)] + ['ground_branch-64']


def decode(path):
    head, body = path.read_text(encoding='utf-8').split('\n---\n')
    rows = [list(row) for row in body.splitlines()]
    fields = dict(line.split(':', 1) for line in head.splitlines())
    palette = {key: tuple(bytes.fromhex(value.strip()[1:])) + (255,)
               for key, value in fields.items() if len(key) == 1}
    assert len(rows) == 64 and all(len(row) == 64 for row in rows)
    return head, rows, palette


def raster(rows, palette):
    image = Image.new('RGBA', (64, 64))
    image.putdata([palette.get(pixel, (0, 0, 0, 0)) for row in rows for pixel in row])
    return image


def retouch(rows, dark, main):
    result = [row.copy() for row in rows]

    def add(x, y):
        if 1 <= x < 63 and 1 <= y < 63 and result[y][x] == '.':
            result[y][x] = dark

    # Preserve every authored pixel and bend. Widen the main trunk downwards
    # by one pixel, with a few wider broken patches instead of a uniform band.
    for y, row in enumerate(rows):
        for x, pixel in enumerate(row):
            if pixel == dark and (not main or 30 <= y <= 34):
                add(x, y + 1)
                if main and (x // 4) % 3 == 1:
                    add(x, y - 1)
    if main:
        # Four short one-pixel forks; rooted on the original dark trunk.
        # Coordinates stay the same through the three aging frames.
        for x, dx, dy in [(10, -3, -4), (18, 3, 5), (35, 3, -4), (54, -2, 5)]:
            candidates = [y for y in range(29, 35) if rows[y][x] == dark]
            assert candidates, (x, dark)
            y = min(candidates, key=lambda value: abs(value - 32))
            fork = Image.new('1', (64, 64))
            draw = ImageDraw.Draw(fork)
            elbow = (x + dx // 2, y + (2 if dy > 0 else -2))
            draw.line([(x, y), elbow, (x + dx, y + dy)], fill=1, width=1)
            for py in range(64):
                for px in range(64):
                    if fork.getpixel((px, py)):
                        add(px, py)
    return result


def main():
    (OUTPUT / 'source').mkdir(parents=True, exist_ok=True)
    before = Image.new('RGBA', (256, 64))
    after = Image.new('RGBA', (256, 64))
    facts = []
    for index, name in enumerate(NAMES):
        head, rows, palette = decode(SOURCE / 'source' / (name + '.pxg'))
        dark = 'B' if index == 2 else 'A'
        edited = retouch(rows, dark, index < 3)
        original = raster(rows, palette)
        revised = raster(edited, palette)
        assert all(rows[y][x] == '.' or rows[y][x] == edited[y][x]
                   for y in range(64) for x in range(64))
        box = revised.getbbox()
        assert box and min(box[:2]) > 0 and max(box[2:]) < 64
        assert all(pixel == '.' or pixel in palette for row in edited for pixel in row)
        (OUTPUT / 'source' / (name + '.pxg')).write_text(
            head + '\n---\n' + '\n'.join(''.join(row) for row in edited) + '\n', encoding='utf-8')
        before.paste(original, (index * 64, 0))
        after.paste(revised, (index * 64, 0))
        facts.append(dict(frame=name, original_pixels=sum(c != '.' for row in rows for c in row),
                          revised_pixels=sum(c != '.' for row in edited for c in row),
                          bbox=box, original_pixels_preserved=True, palette_unchanged=True))
    after.save(OUTPUT / 'ground_cracks_r04.png')
    # Magnified reference plate, separate from the actual transparent atlas.
    preview = ROOT / 'artifacts/previews/active_combat/ground_cracks_r04'
    preview.mkdir(parents=True, exist_ok=True)
    plate = Image.new('RGB', (1024, 240), '#696d5c')
    draw = ImageDraw.Draw(plate)
    draw.text((12, 8), 'ORIGINAL - authored palette and path', fill='#eef0d8')
    draw.text((12, 127), 'R04 - thicker trunk, fine short forks', fill='#eef0d8')
    for i, source in enumerate([before, after]):
        crop = source.crop((0, 20, 256, 44)).resize((1024, 96), Image.Resampling.NEAREST)
        plate.paste(crop, (0, 26 + i * 119), crop)
    plate.save(preview / 'source_comparison.png')
    (preview / 'validation.json').write_text(json.dumps(facts, indent=2), encoding='utf-8')
    print(json.dumps(facts), flush=True)


if __name__ == '__main__':
    main()
