"""Hand-authored pixel icons, following the project's local drawing workflow.

The art is original pixel geometry without model/API calls. Integration metadata
is checked against the live relic catalog.
Native 32px geometry and an opaque palette preserve crisp nearest-neighbor scaling.
"""

from PIL import Image, ImageDraw, ImageFont

INK = '#29283b'
GOLD_DARK, GOLD, GOLD_LIGHT, GOLD_HIGH = '#865b3a', '#c18a4d', '#ebbc70', '#ffe4a0'
SILVER_DARK, SILVER, SILVER_LIGHT = '#52677b', '#8cabb5', '#d5e8dd'


def canvas():
    im = Image.new('RGBA', (32, 32))
    return im, ImageDraw.Draw(im)


def trigger():
    im, d = canvas()
    # Short iron mount and visible pivot; a broad hooked brass trigger hangs below.
    d.polygon([(8, 4), (21, 4), (24, 7), (24, 11), (20, 14), (8, 14), (6, 11), (6, 7)], fill=INK)
    d.rectangle((8, 6, 21, 11), fill=SILVER_DARK)
    d.line([(9, 6), (20, 6), (22, 8)], fill=SILVER)
    d.rectangle((8, 9, 11, 11), fill='#394255')
    d.polygon([(14, 9), (22, 10), (24, 14), (24, 19), (22, 24), (18, 28), (10, 28), (7, 25), (7, 22), (9, 21), (11, 24), (15, 23), (17, 20), (18, 15), (14, 14)], fill=INK)
    d.polygon([(16, 11), (21, 12), (22, 15), (22, 19), (20, 23), (17, 26), (11, 26), (9, 24), (9, 23), (11, 25), (16, 24), (19, 20), (20, 15), (16, 14)], fill=GOLD)
    d.line([(16, 11), (20, 12), (21, 15), (21, 19), (19, 23), (16, 25), (11, 25)], fill=GOLD_LIGHT)
    d.line([(17, 12), (20, 13), (20, 17)], fill=GOLD_HIGH)
    d.point((10, 24), fill=GOLD_HIGH)
    d.polygon([(14, 7), (18, 7), (20, 9), (20, 12), (18, 14), (14, 14), (12, 12), (12, 9)], fill=INK)
    d.rectangle((14, 9, 18, 12), fill='#795780')
    d.line([(14, 9), (17, 9)], fill='#c5a1bd')
    d.rectangle((16, 10, 17, 11), fill='#382e4c')
    d.point((9, 8), fill=SILVER_LIGHT)
    return im


def ledger():
    im, d = canvas()
    # Open blue boards and asymmetric page stacks.
    d.polygon([(3, 6), (12, 5), (16, 8), (21, 5), (29, 7), (29, 25), (21, 25), (16, 28), (11, 25), (3, 25), (2, 23), (2, 8)], fill=INK)
    d.polygon([(4, 8), (12, 7), (16, 10), (21, 7), (27, 8), (27, 23), (20, 23), (16, 26), (11, 23), (4, 23)], fill='#46557c')
    d.line([(4, 23), (11, 23), (16, 26), (20, 23), (27, 23)], fill='#7887a4')
    d.polygon([(5, 7), (11, 7), (15, 10), (15, 23), (11, 21), (5, 21)], fill='#d9c59b')
    d.polygon([(17, 10), (21, 7), (26, 8), (26, 21), (21, 21), (17, 23)], fill='#b39979')
    d.line([(5, 7), (11, 7), (14, 9)], fill='#fff0c5')
    d.line([(18, 10), (21, 8), (25, 9)], fill='#f1deb0')
    d.line([(6, 21), (11, 21), (14, 23)], fill='#8f735f')
    d.line([(18, 22), (21, 20), (25, 20)], fill='#e5cfa5')
    d.line([(16, 10), (16, 23)], fill='#66505d')
    for x, y in [(7, 10), (7, 19), (21, 10), (21, 18)]:
        d.line([(x, y), (x + 2, y)], fill='#a08067')
    # One wakeful eye bridging the gutter, without text or a realistic face.
    d.polygon([(10, 15), (13, 12), (18, 12), (22, 15), (18, 18), (13, 18)], fill=INK)
    d.polygon([(12, 15), (14, 13), (18, 13), (20, 15), (18, 16), (14, 16)], fill='#efdeaf')
    d.rectangle((15, 13, 17, 16), fill='#91aca0')
    d.line([(16, 13), (16, 16)], fill=INK)
    d.point((15, 13), fill='#fff4d9')
    d.polygon([(20, 22), (24, 22), (24, 29), (22, 27), (20, 29)], fill=INK)
    d.line([(21, 23), (21, 27)], fill='#a4505c')
    d.line([(22, 23), (22, 26)], fill='#d27b78')
    return im


def amplifier():
    im, d = canvas()
    # An unmistakable triangular brass frame, with a separate crystal inside.
    d.line([(15, 3), (2, 27), (29, 27), (16, 3), (15, 3)], fill=INK, width=4)
    d.line([(15, 5), (4, 25), (27, 25), (16, 5)], fill=GOLD, width=2)
    d.line([(15, 5), (5, 24)], fill=GOLD_LIGHT)
    d.line([(6, 26), (26, 26)], fill=GOLD_DARK)
    d.polygon([(15, 9), (21, 14), (20, 21), (15, 25), (10, 20), (10, 14)], fill=INK)
    d.polygon([(15, 11), (19, 15), (18, 20), (15, 23), (12, 19), (12, 15)], fill='#8062a4')
    d.polygon([(15, 11), (15, 17), (12, 19), (12, 15)], fill='#c29bce')
    d.polygon([(15, 17), (19, 15), (18, 20), (15, 23)], fill='#584374')
    d.line([(17, 12), (16, 15), (18, 17), (15, 19), (16, 22)], fill='#ece1ed')
    # Side electrodes have silver caps; no glow outside the pixel silhouette.
    for x in [3, 25]:
        d.rectangle((x, 15, x + 3, 21), fill=INK)
        d.rectangle((x + 1, 16, x + 2, 19), fill=SILVER)
        d.line([(x + 1, 16), (x + 2, 16)], fill=SILVER_LIGHT)
    for x, y in [(15, 4), (3, 26), (27, 26)]:
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=INK)
        d.point((x, y), fill=GOLD_HIGH)
    return im


def dividend():
    im, d = canvas()
    # Two coins above a sealed envelope, distinct from the existing flat check.
    for x, y in [(8, 6), (19, 4)]:
        d.polygon([(x + 2, y), (x + 6, y), (x + 8, y + 2), (x + 8, y + 7), (x + 6, y + 9), (x + 2, y + 9), (x, y + 7), (x, y + 2)], fill=INK)
        d.ellipse((x + 1, y + 1, x + 7, y + 8), fill=GOLD)
        d.line([(x + 2, y + 2), (x + 5, y + 2), (x + 6, y + 3)], fill=GOLD_HIGH)
        d.rectangle((x + 3, y + 4, x + 4, y + 5), fill=GOLD_DARK)
    d.polygon([(3, 11), (27, 11), (29, 13), (29, 26), (27, 28), (3, 28), (2, 26), (2, 13)], fill=INK)
    d.rectangle((4, 13, 27, 25), fill='#c1a279')
    d.polygon([(4, 14), (13, 21), (18, 21), (27, 14), (27, 25), (4, 25)], fill='#e5cea0')
    d.line([(4, 24), (11, 19)], fill='#a58063')
    d.line([(20, 19), (27, 24)], fill='#a58063')
    d.polygon([(4, 13), (27, 13), (17, 21), (14, 21)], fill='#92735d')
    d.polygon([(5, 13), (26, 13), (17, 19), (14, 19)], fill='#fff0c6')
    d.line([(5, 13), (25, 13)], fill='#fff7dd')
    d.polygon([(13, 18), (18, 18), (20, 20), (20, 23), (17, 25), (13, 24), (11, 22), (11, 20)], fill=INK)
    d.polygon([(13, 19), (17, 19), (19, 21), (17, 23), (13, 23), (12, 21)], fill='#a84654')
    d.line([(13, 20), (16, 20)], fill='#e79585')
    d.point((17, 22), fill='#752b45')
    return im


def vow():
    im, d = canvas()
    d.rectangle((13, 2, 18, 8), fill=INK)
    d.rectangle((14, 3, 17, 6), fill=SILVER)
    d.rectangle((15, 4, 16, 5), fill=(0, 0, 0, 0))
    d.point((14, 3), fill=SILVER_LIGHT)
    d.polygon([(14, 7), (17, 7), (22, 14), (25, 20), (25, 24), (21, 28), (17, 30), (12, 29), (7, 25), (6, 21), (8, 16)], fill=INK)
    d.polygon([(15, 8), (17, 10), (21, 16), (23, 21), (23, 24), (19, 28), (14, 28), (9, 24), (8, 21), (10, 16)], fill=SILVER_DARK)
    d.line([(15, 8), (10, 16), (8, 21), (10, 24), (14, 27)], fill=SILVER_LIGHT)
    d.line([(17, 10), (21, 16), (23, 21)], fill=SILVER)
    d.polygon([(15, 12), (18, 16), (20, 21), (19, 24), (16, 26), (12, 23), (11, 20)], fill=INK)
    d.polygon([(15, 14), (18, 18), (19, 21), (17, 24), (14, 24), (12, 20)], fill='#66a6b8')
    d.polygon([(15, 14), (15, 21), (12, 20)], fill='#c8eeee')
    d.polygon([(15, 21), (19, 21), (17, 24), (14, 24)], fill='#43839b')
    d.point((15, 16), fill='#f0fff0')
    # Small integrated silver wing on the lower right rim.
    d.polygon([(20, 21), (28, 17), (27, 22), (23, 27), (19, 27)], fill=INK)
    d.polygon([(21, 22), (26, 19), (25, 22), (21, 25), (20, 25)], fill=SILVER_LIGHT)
    d.line([(22, 24), (25, 21)], fill=SILVER)
    return im
