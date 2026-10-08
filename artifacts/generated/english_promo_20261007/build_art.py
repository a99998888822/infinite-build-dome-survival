"""Draw custom English lettering and compose a cover from project-owned art.

No model/API image generation or installed skill is used by this script.
The letter contours below are drawn specifically for this title.
"""

from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, PngImagePlugin

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TITLE = "Goblin's Guide to Dungeons"
BACKGROUND = ROOT / 'assets/ui/main_menu/bg_main_menu.png'
ORIGINAL_TITLE = ROOT / 'assets/ui/main_menu/title_main_menu.png'

# Polygon contours in a 100-unit cap-height drawing space; holes follow outers.
# The asymmetry and wedge cuts follow the original gold brush-lettering.
GLYPHS = {
    'G': (88, [
        [(82, 7), (75, 28), (60, 21), (34, 22), (23, 34), (23, 68), (35, 80), (63, 80), (65, 64), (47, 65), (44, 48), (87, 45), (84, 88), (68, 100), (22, 97), (2, 78), (4, 23), (22, 3), (59, 0)],
    ]),
    'O': (86, [
        [(20, 3), (63, 0), (83, 18), (85, 77), (66, 98), (21, 100), (1, 79), (3, 24)],
        [(29, 23), (23, 33), (24, 69), (33, 80), (57, 78), (63, 68), (61, 30), (52, 20)],
    ]),
    'B': (82, [
        [(2, 5), (55, 1), (77, 13), (80, 38), (66, 48), (81, 58), (82, 83), (61, 97), (1, 100), (7, 79), (7, 22)],
        [(29, 22), (28, 42), (52, 41), (58, 34), (55, 25), (46, 20)],
        [(28, 60), (27, 80), (54, 78), (60, 69), (53, 59)],
    ]),
    'L': (73, [
        [(1, 5), (34, 0), (29, 19), (26, 77), (44, 78), (73, 70), (67, 98), (1, 100), (7, 80), (8, 22)],
    ]),
    'I': (42, [
        [(1, 5), (41, 0), (38, 17), (31, 21), (29, 78), (41, 80), (38, 96), (0, 100), (2, 83), (11, 79), (13, 23), (1, 22)],
    ]),
    'N': (87, [
        [(2, 5), (27, 1), (65, 61), (64, 21), (57, 6), (85, 0), (84, 99), (63, 95), (24, 36), (25, 81), (31, 96), (0, 100), (6, 80), (7, 23)],
    ]),
    'S': (80, [
        [(76, 8), (69, 29), (54, 22), (33, 21), (22, 29), (24, 39), (62, 48), (79, 63), (76, 85), (57, 98), (20, 100), (0, 87), (8, 68), (24, 80), (48, 80), (56, 73), (53, 65), (19, 55), (2, 40), (6, 17), (25, 3), (56, 0)],
    ]),
    'U': (86, [
        [(1, 6), (33, 1), (27, 21), (24, 70), (34, 81), (54, 80), (63, 69), (63, 19), (56, 5), (85, 0), (84, 77), (66, 98), (24, 100), (3, 80), (7, 22)],
    ]),
    'D': (86, [
        [(1, 5), (57, 1), (80, 18), (85, 72), (70, 91), (52, 98), (0, 100), (7, 80), (8, 23)],
        [(30, 23), (28, 80), (49, 77), (61, 64), (59, 32), (49, 22)],
    ]),
    'E': (74, [
        [(1, 5), (73, 0), (67, 22), (30, 22), (29, 40), (63, 36), (60, 58), (28, 60), (27, 80), (74, 74), (68, 97), (0, 100), (7, 79), (8, 24)],
    ]),
    'T': (81, [
        [(1, 5), (81, 0), (77, 24), (53, 23), (50, 78), (57, 94), (23, 100), (29, 80), (31, 25), (0, 29)],
    ]),
    "'": (22, [
        [(5, 0), (22, 5), (17, 24), (1, 36), (6, 17)],
    ]),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def shifted(mask: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new('L', mask.size)
    out.paste(mask, (dx, dy))
    return out


def paint_glyph(character: str, height: int, seed: int) -> Image.Image:
    width, contours = GLYPHS[character]
    rng = random.Random(seed)
    scale = height / 100
    pad = max(14, round(scale * 10))
    box = (round((width + 12) * scale) + pad * 2, height + pad * 2 + round(10 * scale))
    mask = Image.new('L', box)
    draw = ImageDraw.Draw(mask)
    shear = rng.uniform(0.015, 0.045)
    for index, contour in enumerate(contours):
        points = [(round((x + shear * (100 - y)) * scale) + pad,
                   round(y * scale) + pad) for x, y in contour]
        draw.polygon(points, fill=255 if index == 0 else 0)

    face = Image.new('RGBA', box, '#d4b16d')
    fd = ImageDraw.Draw(face)
    # Broad planes establish the uneven painted-gold surface.
    golds = ['#e9cc88', '#dcbc78', '#c6a15e', '#e3c37f', '#f3d99a', '#b99655', '#cfac66']
    for _ in range(44):
        x = rng.randrange(pad - 2, max(pad + 1, box[0] - pad))
        y = rng.randrange(pad - 2, pad + height)
        brush_width = rng.randint(max(3, round(scale * 2)), max(4, round(scale * 8)))
        length = rng.randint(max(5, round(scale * 5)), max(8, round(scale * 23)))
        dx = rng.randint(-round(scale * 3), round(scale * 4))
        fd.polygon([(x, y), (x + brush_width, y - round(scale)),
                    (x + brush_width + dx, y + length), (x + dx, y + length - round(scale * 2))],
                   fill=rng.choice(golds))
    for _ in range(10):
        x = rng.randrange(pad, max(pad + 1, box[0] - pad))
        y = rng.randrange(pad, pad + height)
        w = rng.randint(max(4, round(scale * 6)), max(6, round(scale * 18)))
        fd.polygon([(x, y), (x + w, y - round(scale * 2)),
                    (x + w - round(scale), y + round(scale * 2)), (x, y + round(scale * 3))],
                   fill=rng.choice(['#ad9e66', '#f4dda1', '#c39b58']))

    # Discrete directional bevels, preserving flat paint instead of a metal gradient.
    alpha = np.asarray(mask)
    rim = max(2, round(scale * 2.4))
    top = (alpha > 0) & (np.asarray(shifted(mask, rim, rim)) == 0)
    bottom = (alpha > 0) & (np.asarray(shifted(mask, -rim, -rim)) == 0)
    rgb = np.array(face)
    rgb[bottom] = (162, 128, 68, 255)
    rgb[top] = (248, 224, 159, 255)
    face = Image.fromarray(rgb)
    face.putalpha(mask)

    out = Image.new('RGBA', box)
    outline_width = max(2, round(scale * 2.3))
    outline = mask.filter(ImageFilter.MaxFilter(outline_width * 2 + 1))
    for d in range(round(scale * 4.8), -1, -1):
        layer = Image.new('RGBA', box, '#191820' if d > 3 else '#352e20')
        layer.putalpha(shifted(outline, round(d * 0.55), d))
        out.alpha_composite(layer)
    out.alpha_composite(face)
    rotation = rng.uniform(-1.7, 1.7)
    out = out.rotate(rotation, resample=Image.Resampling.NEAREST, expand=True)
    return out.crop(out.getbbox())


def make_line(text: str, cap_height: int, target_width: int, seed: int) -> Image.Image:
    glyphs = []
    rng = random.Random(seed)
    gap = round(cap_height * 0.035)
    for index, char in enumerate(text):
        if char == ' ':
            glyphs.append((None, round(cap_height * 0.33), 0))
        else:
            glyph = paint_glyph(char, cap_height, seed + index * 131)
            y = round(cap_height * rng.uniform(-0.02, 0.02))
            glyphs.append((glyph, glyph.width + gap, y))
    width = sum(item[1] for item in glyphs)
    line = Image.new('RGBA', (width, round(cap_height * 1.35)))
    x = 0
    for glyph, advance, dy in glyphs:
        if glyph is not None:
            # An apostrophe sits at cap-height instead of dropping to the baseline.
            line.alpha_composite(glyph, (x, round(cap_height * 0.04) + dy))
        x += advance
    line = line.crop(line.getbbox())
    return line.resize((target_width, round(line.height * target_width / line.width)), Image.Resampling.NEAREST)


def save_png(image: Image.Image, path: Path, description: str) -> None:
    metadata = PngImagePlugin.PngInfo()
    metadata.add_itxt('Title', TITLE)
    metadata.add_itxt('Description', description)
    metadata.add_itxt('Creation method', 'Custom polygon lettering and local composition of existing project artwork; no image-generation API.')
    image.save(path, pnginfo=metadata, optimize=True)


def build_title() -> Image.Image:
    first = make_line("GOBLIN'S", 260, 1440, 702)
    second = make_line('GUIDE TO DUNGEONS', 138, 1620, 971)
    width = 1760
    gap = 26
    height = first.height + second.height + gap + 92
    canvas = Image.new('RGBA', (width, height))
    canvas.alpha_composite(first, ((width - first.width) // 2 - 25, 32))
    canvas.alpha_composite(second, ((width - second.width) // 2, first.height + 32 + gap))
    save_png(canvas, HERE / 'title_en.png', 'Standalone English gold lettering, transparent RGBA master.')
    pixel_width = 480
    pixel = canvas.resize((pixel_width, round(canvas.height * pixel_width / canvas.width)), Image.Resampling.NEAREST)
    save_png(pixel, HERE / 'title_en_pixel_480.png', '480-pixel-wide optional menu candidate. Nearest-neighbor sampling; not installed.')
    preview = Image.new('RGBA', (1760, height + 64), '#211d29')
    preview.alpha_composite(canvas, (0, 32))
    save_png(preview.convert('RGB'), HERE / 'title_en_preview.png', 'Title on a dark preview background; use title_en.png for transparency.')
    return canvas


def square_base() -> Image.Image:
    source = Image.open(BACKGROUND).convert('RGB')
    # Preserve the actual goblin, his complete hat and hands, and the round vault.
    side = min(source.size)
    crop = source.crop((source.width - side, 0, source.width, side))
    # Shade at the original pixel resolution before any nearest-neighbor scaling.
    pixels = np.asarray(crop).astype(np.float32) / 255.0
    y, x = np.mgrid[0:side, 0:side]
    # Quiet the upper wall for gold lettering, with a continuous transition.
    t = np.clip((y / side - 0.14) / 0.35, 0, 1)
    top_shade = (1 - t * t * (3 - 2 * t)) * 0.66
    tint = np.array([24, 19, 32], dtype=np.float32) / 255
    pixels = pixels * (1 - top_shade[..., None]) + tint * top_shade[..., None]
    # A restrained edge falloff keeps face and lettering central.
    radius = ((x / side - 0.50) / 0.73) ** 2 + ((y / side - 0.53) / 0.85) ** 2
    vignette = np.clip((radius - 0.42) * 0.15, 0, 0.2)
    pixels *= (1 - vignette[..., None])
    pixels = np.clip(pixels * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(pixels).convert('RGBA')


def build_cover(title: Image.Image) -> Image.Image:
    background = square_base()
    # Save the independent image layer for subsequent language localizations.
    save_png(background.convert('RGB').resize((2048, 2048), Image.Resampling.NEAREST),
             HERE / 'cover_background_pixel_2048.png', 'Text-free square crop of assets/ui/main_menu/bg_main_menu.png, scaled with nearest-neighbor sampling.')
    for edge in (2048, 1024, 512, 256):
        # Composite each export independently so title filtering never blurs the background.
        cover = background.resize((edge, edge), Image.Resampling.NEAREST)
        logo_width = round(910 * edge / 1024)
        logo = title.resize((logo_width, round(title.height * logo_width / title.width)), Image.Resampling.LANCZOS)
        cover.alpha_composite(logo, ((edge - logo.width) // 2, round(49 * edge / 1024)))
        result = cover.convert('RGB')
        save_png(result, HERE / f'cover_en_pixel_{edge}.png', f'{edge} x {edge} English cover using the production pixel-art menu background.')
        if edge == 2048:
            master = result
    return master


def main() -> None:
    inputs = {str(p.relative_to(ROOT)): sha256(p) for p in (BACKGROUND, ORIGINAL_TITLE)}
    title = Image.open(HERE / 'title_en.png').convert('RGBA') if (HERE / 'title_en.png').is_file() else build_title()
    cover = build_cover(title)
    outputs = {}
    for path in sorted(HERE.glob('*.png')):
        if not (path.name.startswith('title_en') or '_pixel_' in path.name):
            continue
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            record = {'size': list(im.size), 'mode': im.mode, 'sha256': sha256(path)}
            if im.mode == 'RGBA':
                alpha = np.asarray(im.getchannel('A'))
                record['alpha_values'] = sorted(int(v) for v in np.unique(alpha))
                record['content_bounds'] = list(im.getbbox())
            outputs[path.name] = record
    assert inputs == {str(p.relative_to(ROOT)): sha256(p) for p in (BACKGROUND, ORIGINAL_TITLE)}
    assert cover.size == (2048, 2048)
    manifest = {
        'title': TITLE,
        'locale': 'en',
        'status': 'review_candidate',
        'method': 'Custom hand-defined glyph polygons, flat-color brush facets, local raster drawing and composition.',
        'image_generation_api_used': False,
        'background_method': 'Crop of the production pixel-art assets/ui/main_menu/bg_main_menu.png. Color adjustments at native resolution; nearest-neighbor background scaling for every export.',
        'source_assets_unchanged': True,
        'runtime_integration': False,
        'inputs': inputs,
        'outputs': outputs,
    }
    (HERE / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'title_size': title.size, 'cover_size': cover.size, 'outputs': list(outputs)}, indent=2))


if __name__ == '__main__':
    main()
