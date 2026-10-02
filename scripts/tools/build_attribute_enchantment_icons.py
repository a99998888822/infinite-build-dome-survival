"""Build the seven 32px attribute glyphs and editable pixel sources locally.

No image model is used. Integer geometry, a small palette, binary alpha and
native-size PNGs follow the existing transparent enchantment-icon system.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/ui/icons/augmentations'
COLORS = {
    'might': ('#542c32', '#cd654b', '#ffa86a', '#ffe2a2'),
    'wisdom': ('#23335e', '#497cbc', '#85d4ed', '#defaff'),
    'multishot': ('#59432c', '#bc872e', '#f2c55e', '#fff0b5'),
    'domain': ('#493065', '#9061b5', '#c595eb', '#f0d6ff'),
    'precision': ('#214b42', '#48976b', '#93d795', '#e4ffd0'),
    'lethality': ('#4f263d', '#b34b71', '#f28b9c', '#ffe2df'),
    'haste': ('#234e5b', '#4e9fad', '#8be3d0', '#e0fff1'),
}


def build(name):
    image = Image.new('RGBA', (32, 32))
    draw = ImageDraw.Draw(image)
    dark, shade, main, light = COLORS[name]
    if name == 'might':
        draw.polygon([(6, 10), (10, 6), (22, 6), (26, 10), (25, 19), (22, 22), (22, 27), (11, 27), (11, 23), (6, 18)], fill=dark)
        draw.rectangle((9, 10, 23, 18), fill=main)
        draw.rectangle((12, 19, 21, 25), fill=shade)
        for x in [10, 14, 18, 22]:
            draw.rectangle((x, 8, x+2, 13), fill=light)
        draw.rectangle((8, 15, 13, 18), fill=shade)
        draw.rectangle((14, 21, 19, 22), fill=main)
    elif name == 'wisdom':
        draw.polygon([(16, 3), (25, 12), (24, 21), (16, 28), (7, 21), (6, 12)], fill=dark)
        draw.polygon([(16, 5), (23, 13), (16, 25), (9, 13)], fill=main)
        draw.polygon([(16, 5), (16, 25), (22, 14)], fill=shade)
        draw.line([(15, 7), (11, 13), (14, 18)], fill=light, width=2)
        draw.rectangle((3, 7, 4, 10), fill=main)
        draw.rectangle((27, 22, 28, 25), fill=light)
    elif name == 'multishot':
        for x, y in [(7, 10), (15, 5), (23, 10)]:
            draw.polygon([(x, y), (x+4, y+5), (x+2, y+5), (x+2, 25), (x-1, 25), (x-1, y+5), (x-3, y+5)], fill=dark)
            draw.line((x, y+3, x, 24), fill=main, width=2)
            draw.line([(x-2, y+5), (x, y+2), (x+2, y+5)], fill=light)
            draw.line((x-2, 23, x, 25), fill=shade, width=2)
    elif name == 'domain':
        draw.polygon([(16, 5), (27, 16), (16, 27), (5, 16)], outline=shade, width=2)
        for x, y, dx, dy in [(3, 3, 1, 1), (28, 3, -1, 1), (3, 28, 1, -1), (28, 28, -1, -1)]:
            draw.line([(x+5*dx, y), (x, y), (x, y+5*dy)], fill=main, width=2)
        draw.rectangle((14, 14, 18, 18), fill=light)
        draw.rectangle((15, 15, 17, 17), fill=main)
    elif name == 'precision':
        draw.polygon([(3, 16), (9, 10), (22, 10), (29, 16), (22, 22), (9, 22)], fill=dark)
        draw.line([(5, 16), (10, 12), (21, 12), (26, 16), (21, 20), (10, 20), (5, 16)], fill=main, width=2)
        draw.rectangle((13, 12, 19, 20), fill=shade)
        draw.rectangle((15, 13, 17, 19), fill=light)
        draw.line((16, 5, 16, 8), fill=light, width=2)
        draw.line((16, 24, 16, 27), fill=main, width=2)
    elif name == 'lethality':
        draw.polygon([(24, 3), (25, 12), (14, 23), (9, 18)], fill=dark)
        draw.polygon([(23, 6), (23, 12), (13, 21), (11, 18)], fill=main)
        draw.line((22, 7, 12, 18), fill=light, width=2)
        draw.line((7, 17, 16, 26), fill=shade, width=3)
        draw.line((11, 22, 6, 27), fill=main, width=3)
        draw.rectangle((4, 26, 7, 29), fill=light)
        draw.line((26, 17, 29, 20), fill=main)
    elif name == 'haste':
        draw.polygon([(9, 26), (8, 18), (16, 5), (28, 5), (22, 13), (24, 13), (17, 21), (18, 22)], fill=dark)
        draw.polygon([(11, 23), (11, 18), (18, 7), (25, 7), (18, 16)], fill=main)
        draw.line((12, 22, 23, 9), fill=light, width=2)
        draw.line((15, 21, 21, 16), fill=shade, width=2)
        draw.line((3, 13, 9, 13), fill=shade, width=2)
        draw.line((2, 18, 7, 18), fill=main, width=2)
        draw.line((3, 23, 6, 23), fill=light)
    stem = 'scroll_' + name
    image.save(OUT / (stem + '.png'))
    palette = sorted({image.getpixel((x, y)) for y in range(32) for x in range(32) if image.getpixel((x, y))[3]})
    keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    mapping = {color: keys[i] for i, color in enumerate(palette)}
    color_lines = [mapping[color] + ': #' + ''.join(f'{v:02x}' for v in color[:3]) for color in palette]
    rows = [''.join(mapping.get(image.getpixel((x, y)), '.') for x in range(32)) for y in range(32)]
    (OUT / (stem + '.pxg')).write_text('\n'.join(['name: '+stem, 'size: 32', 'kind: item', *color_lines, '---', *rows])+'\n', encoding='utf-8')
    assert image.getchannel('A').getextrema() == (0, 255)
    assert len(palette) <= 4
    return image


if __name__ == '__main__':
    for name in COLORS:
        build(name)
    print('Built seven 32x32 icons and editable .pxg sources.')
