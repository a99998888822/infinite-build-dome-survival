"""Reference-led, separately authored 64px and 32px goblin pixel drawings.

Draw directly at native resolution. No source-image sampling, filters,
quantization, antialiasing, or downsampling is used to produce either sprite.
The source photograph is opened only when composing the labelled review board.
This is code-authored pixel artwork, not an image-model output.
"""

from pathlib import Path
import argparse
import hashlib
import json

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/previews/goblin_reprint"
OUT = SOURCE / "native_pixel_review"
COLORS = {
    "I": "#151e22",  # silhouette / deepest cloth
    "D": "#242e35",  # cloth shadow
    "C": "#38454b",  # blue-black cloth
    "L": "#5b6868",  # selective cloth highlight
    "F": "#364637",  # dark hair / green occlusion
    "S": "#536d43",  # green shadow
    "M": "#809951",  # olive skin
    "G": "#acbd69",  # skin light
    "H": "#d0cf8a",  # skin accent
    "B": "#785c36",  # brass shadow
    "O": "#b8944d",  # brass
    "Y": "#ebce85",  # brass highlight
    "V": "#9ca99a",  # shirt shadow
    "W": "#e8e4c9",  # shirt / eye highlight
}


class Pixel:
    def __init__(self, size):
        self.image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def p(self, color, points):
        self.draw.polygon(points, fill=COLORS[color])

    def r(self, color, box):
        self.draw.rectangle(box, fill=COLORS[color])

    def l(self, color, points, width=1):
        self.draw.line(points, fill=COLORS[color], width=width)

    def dot(self, color, *points):
        self.draw.point(points, fill=COLORS[color])


def draw_64(*, revised=False):
    """Author a broad hat, angular face, tailored bust and resting hands."""
    a = Pixel(64)
    # Seated coat: deliberately large, uninterrupted clusters.
    a.p("I", [(23, 40), (39, 40), (42, 42), (48, 43), (49, 47),
              (53, 51), (56, 56), (54, 59), (47, 59), (43, 57),
              (22, 57), (18, 59), (9, 59), (7, 56), (11, 50),
              (14, 47), (15, 44), (22, 43)])
    a.p("C", [(23, 42), (38, 42), (46, 44), (46, 48), (51, 52),
              (53, 56), (48, 58), (41, 55), (23, 55), (17, 57),
              (10, 57), (13, 51), (16, 47), (17, 45)])
    a.p("D", [(37, 43), (46, 45), (47, 50), (53, 56), (47, 56),
              (41, 53), (40, 57), (23, 57), (21, 51), (25, 47)])
    a.p("L", [(17, 45), (22, 44), (18, 47), (16, 51), (12, 54),
              (14, 50), (16, 48)])
    a.l("I", [(20, 47), (18, 52), (12, 55)])
    a.l("I", [(44, 48), (46, 53), (52, 55)])
    if revised:
        # Open the arm/torso gaps and taper the jacket into a narrow waist.
        # These are native pixel edits, not a horizontal image transform.
        a.draw.polygon([(21, 48), (23, 51), (25, 54), (25, 58),
                        (21, 58), (18, 56), (19, 53)], fill=(0, 0, 0, 0))
        a.draw.polygon([(43, 48), (41, 51), (39, 54), (39, 58),
                        (44, 58), (46, 55), (45, 52)], fill=(0, 0, 0, 0))
        a.p("I", [(26, 53), (38, 53), (38, 58), (26, 58)])
        a.p("D", [(27, 53), (37, 53), (37, 57), (27, 57)])
        a.l("I", [(22, 48), (24, 51), (26, 55), (26, 58)])
        a.l("I", [(42, 48), (40, 51), (38, 55), (38, 58)])
        a.l("C", [(25, 50), (27, 54), (28, 56)])
    # Neck, shirt and lapels occupy distinct clusters even at thumbnail size.
    a.p("S", [(26, 38), (38, 38), (36, 44), (31, 46), (26, 43)])
    a.p("V", [(25, 42), (31, 45), (38, 42), (36, 49), (31, 54), (27, 49)])
    a.p("W", [(25, 42), (30, 45), (28, 47), (26, 45)])
    a.p("W", [(38, 42), (34, 47), (32, 45)])
    a.p("W", [(30, 48), (33, 48), (33, 51), (31, 53), (29, 49)])
    a.p("I", [(25, 41), (22, 43), (23, 48), (25, 48), (24, 50),
              (30, 56), (27, 48)])
    a.p("C", [(24, 43), (26, 47), (27, 51), (25, 49), (26, 47)])
    a.p("I", [(39, 42), (41, 46), (38, 48), (39, 50), (33, 56),
              (34, 51), (37, 46)])
    a.l("L", [(39, 43), (40, 46), (37, 48)])
    # Black bow tie, no attempt to carry over fabric texture.
    a.p("I", [(27, 45), (30, 46), (32, 46), (35, 45), (35, 48),
              (32, 47), (30, 48), (27, 48)])
    a.dot("C", (28, 46), (34, 46))
    # A single broken-brass chain and square pin replace tiny jewelry detail.
    a.l("B", [(27, 49), (28, 53), (31, 55), (35, 55), (39, 51), (41, 48)])
    a.l("O", [(27, 49), (28, 52), (31, 54), (35, 54), (39, 50)])
    a.dot("Y", (28, 51), (32, 54), (37, 52))
    a.r("B", (40, 46, 42, 48))
    a.r("O", (40, 46, 41, 47))
    a.dot("Y", (40, 46))
    a.dot("O", (31, 56))
    # Cuffs and hands. Finger groups are authored as discrete two-pixel strips.
    a.p("V", [(11, 54), (15, 52), (20, 54), (19, 57), (13, 58), (10, 56)])
    a.l("W", [(11, 54), (15, 53), (18, 54)])
    a.p("I", [(15, 54), (20, 54), (22, 56), (26, 58), (26, 60),
              (23, 60), (22, 59), (22, 61), (19, 61), (18, 60),
              (18, 62), (15, 62), (14, 60), (12, 60), (12, 56)])
    a.p("M", [(15, 55), (19, 55), (22, 57), (25, 58), (25, 59),
              (22, 58), (20, 57), (21, 60), (19, 60), (17, 57),
              (17, 61), (15, 61), (14, 58), (13, 59), (13, 56)])
    a.p("G", [(15, 55), (18, 55), (21, 57), (18, 57), (16, 56),
              (15, 58), (14, 57)])
    a.l("G", [(19, 58), (20, 60)])
    a.l("G", [(16, 58), (16, 60)])
    a.dot("H", (15, 55), (18, 56))
    a.p("V", [(46, 53), (50, 53), (54, 55), (52, 58), (46, 57)])
    a.l("W", [(46, 54), (49, 54), (52, 55)])
    a.p("I", [(46, 55), (50, 55), (53, 57), (53, 61), (51, 61),
              (50, 62), (47, 62), (47, 60), (46, 62), (43, 62),
              (43, 60), (40, 61), (39, 59), (43, 57)])
    a.p("M", [(46, 56), (49, 56), (52, 58), (52, 60), (50, 59),
              (49, 61), (48, 61), (48, 58), (46, 58), (45, 61),
              (44, 61), (45, 58), (42, 60), (41, 59), (44, 57)])
    a.p("G", [(46, 56), (48, 56), (49, 57), (46, 58), (44, 58)])
    a.l("G", [(47, 58), (45, 60)])
    a.l("G", [(50, 58), (49, 60)])
    a.l("O", [(48, 58), (49, 58)])
    a.dot("Y", (48, 58))
    # Stepped ears. V2 brings each tip inward five native pixels.
    if revised:
        a.p("I", [(13, 26), (19, 27), (22, 29), (25, 32),
                  (22, 35), (18, 33), (16, 30)])
        a.p("M", [(15, 27), (20, 29), (23, 32), (21, 34), (18, 31)])
        a.l("G", [(14, 27), (18, 28), (20, 29)])
        a.p("S", [(17, 29), (20, 30), (22, 33), (20, 32)])
        a.p("I", [(42, 28), (48, 26), (52, 25), (51, 29),
                  (48, 32), (43, 35), (40, 32)])
        a.p("M", [(43, 29), (47, 27), (50, 27), (49, 30),
                  (45, 33), (42, 33)])
        a.l("G", [(45, 28), (48, 27), (51, 26)])
        a.p("S", [(45, 30), (49, 28), (47, 31), (43, 33)])
    else:
        a.p("I", [(8, 24), (16, 25), (21, 27), (25, 32), (22, 37),
                  (17, 35), (13, 32), (11, 28)])
        a.p("M", [(10, 25), (17, 27), (20, 28), (23, 32), (21, 35),
                  (17, 33), (14, 30)])
        a.l("G", [(10, 25), (16, 26), (20, 28)])
        a.p("S", [(13, 28), (17, 29), (21, 32), (20, 34), (17, 31)])
        a.p("I", [(42, 27), (48, 25), (57, 23), (54, 27), (53, 31),
                  (49, 35), (43, 37), (39, 32)])
        a.p("M", [(43, 28), (49, 26), (54, 25), (52, 30), (48, 33),
                  (43, 35), (41, 32)])
        a.l("G", [(45, 27), (50, 25), (55, 24)])
        a.p("S", [(45, 29), (50, 27), (49, 30), (46, 33), (42, 34)])
    # The face is proportionally enlarged so expression survives at 64px.
    a.p("I", [(22, 23), (39, 22), (45, 26), (44, 34), (40, 40),
              (34, 44), (30, 44), (24, 40), (20, 34), (19, 28)])
    a.p("S", [(23, 24), (38, 24), (43, 27), (43, 33), (39, 39),
              (33, 43), (30, 42), (25, 39), (21, 33), (21, 28)])
    a.p("M", [(24, 25), (36, 25), (40, 28), (40, 34), (36, 39),
              (32, 42), (29, 40), (24, 36), (22, 31)])
    a.p("G", [(24, 26), (28, 26), (30, 28), (29, 31), (25, 32),
              (23, 31), (23, 28)])
    if not revised:
        a.p("G", [(32, 29), (34, 31), (34, 34), (32, 36), (30, 34)])
    a.p("G", [(24, 34), (28, 36), (28, 38), (26, 37)])
    a.p("G", [(31, 40), (33, 40), (32, 41)])
    if revised:
        # Slanted lids, a cocked outer brow and matched sideways pupils.
        a.p("F", [(23, 27), (25, 27), (29, 29), (29, 30), (25, 29), (23, 29)])
        a.p("F", [(35, 29), (39, 27), (42, 27), (40, 29), (35, 30)])
        a.l("I", [(23, 30), (26, 30), (28, 31)])
        a.l("W", [(24, 31), (27, 31)])
        a.dot("O", (25, 31))
        a.dot("I", (26, 31))
        a.l("I", [(35, 31), (38, 29), (41, 29)])
        a.l("W", [(35, 32), (38, 30), (39, 30)])
        a.dot("O", (37, 31))
        a.dot("I", (38, 30))
        a.l("S", [(37, 33), (40, 31)])
        # Narrow bridge and a single-pixel, off-centre pointed tip.
        a.p("S", [(31, 30), (33, 31), (34, 33), (38, 35),
                  (34, 37), (31, 36), (30, 34)])
        a.p("G", [(31, 31), (32, 31), (33, 33), (37, 35),
                  (33, 35), (31, 34)])
        a.l("H", [(32, 32), (33, 33), (36, 35)])
        a.l("F", [(32, 36), (34, 37), (38, 35)])
        a.dot("G", (37, 35))
        # A raised mouth corner supports the calculating, amused expression.
        a.l("S", [(28, 38), (30, 39), (35, 39), (38, 37)])
        a.l("F", [(29, 39), (32, 39), (36, 38), (38, 36)])
        a.l("G", [(31, 40), (33, 40), (35, 39)])
    else:
        a.p("F", [(22, 28), (25, 27), (28, 28), (29, 30), (25, 29)])
        a.p("F", [(35, 29), (39, 27), (41, 27), (39, 29), (35, 30)])
        a.l("I", [(23, 30), (28, 31)])
        a.l("W", [(24, 31), (27, 31)])
        a.dot("O", (26, 31))
        a.dot("I", (27, 31))
        a.l("I", [(35, 31), (40, 30)])
        a.l("W", [(35, 32), (38, 31)])
        a.dot("O", (37, 31))
        a.dot("I", (38, 31))
        a.l("F", [(30, 34), (32, 36), (34, 35), (35, 33)])
        a.dot("H", (31, 33), (32, 34))
        a.l("S", [(28, 37), (31, 38), (35, 38), (38, 36)])
        a.l("F", [(29, 38), (34, 38), (36, 37)])
        a.l("G", [(31, 39), (34, 39)])
    # Octagonal monocle: eight-pixel aperture and explicit bright upper rim.
    a.l("B", [(22, 28), (24, 27), (27, 27), (29, 29), (29, 33),
              (27, 35), (24, 35), (21, 32), (21, 29), (22, 28)])
    a.l("O", [(22, 29), (23, 28), (27, 28), (28, 29), (28, 33),
              (26, 34), (23, 34), (22, 32), (22, 29)])
    a.l("Y", [(22, 29), (23, 28), (25, 28)])
    a.l("O", [(29, 30), (31, 29), (33, 30)])
    # Hair is three deliberate clumps, rather than individual strands.
    a.p("F", [(18, 21), (43, 21), (44, 25), (46, 28), (42, 27),
              (42, 30), (38, 27), (37, 25), (34, 25), (35, 28),
              (31, 26), (30, 24), (26, 27), (22, 27), (24, 25),
              (19, 27), (20, 24), (17, 24)])
    a.p("S", [(19, 22), (25, 23), (22, 25), (20, 25), (21, 24)])
    a.p("M", [(25, 23), (29, 23), (26, 25), (23, 26)])
    a.p("S", [(32, 23), (34, 23), (33, 25), (34, 26), (31, 24)])
    a.p("S", [(37, 23), (40, 23), (40, 25), (43, 27), (39, 26)])
    # Tall top hat. All forms are flat pixel clusters with a restrained rim.
    a.p("I", [(23, 2), (40, 2), (45, 4), (44, 9), (43, 16),
              (48, 15), (50, 16), (49, 20), (45, 22), (37, 23),
              (24, 23), (17, 21), (14, 17), (15, 15), (21, 17), (20, 5)])
    a.p("C", [(23, 3), (39, 3), (43, 5), (42, 15), (37, 18),
              (25, 18), (22, 16), (21, 5)])
    a.p("D", [(33, 4), (40, 4), (43, 5), (42, 16), (36, 18), (31, 17)])
    a.p("L", [(23, 4), (27, 4), (26, 6), (26, 13), (25, 15),
              (23, 13), (23, 7), (22, 5)])
    a.r("C", (25, 5, 27, 13))
    a.p("I", [(22, 15), (27, 17), (36, 17), (42, 15), (42, 18),
              (37, 20), (26, 20), (22, 18)])
    a.l("C", [(23, 17), (27, 18), (35, 18), (40, 17)])
    a.p("C", [(16, 16), (20, 18), (23, 20), (29, 21), (38, 21),
              (44, 19), (48, 16), (48, 19), (44, 21), (37, 22),
              (25, 22), (19, 20)])
    a.l("L", [(16, 16), (18, 18), (22, 20)])
    return a.image


def draw_32():
    """Independent tiny composition: larger head, fewer fingers and no chain."""
    a = Pixel(32)
    a.p("I", [(11, 20), (21, 20), (25, 23), (26, 25), (29, 28),
              (28, 30), (22, 30), (20, 29), (11, 29), (9, 30),
              (3, 30), (2, 28), (5, 24), (7, 22)])
    a.p("C", [(9, 23), (12, 22), (20, 22), (24, 24), (25, 27),
              (27, 28), (23, 29), (21, 27), (11, 27), (8, 29),
              (4, 28), (7, 24)])
    a.p("D", [(20, 23), (23, 24), (25, 28), (21, 28), (20, 29), (12, 29), (13, 26)])
    a.p("W", [(12, 22), (16, 24), (20, 22), (17, 27), (15, 27)])
    a.l("I", [(11, 22), (12, 25), (15, 29)])
    a.l("I", [(21, 22), (20, 25), (17, 29)])
    a.l("I", [(14, 24), (17, 24)])
    a.dot("C", (13, 24), (18, 24))
    a.dot("O", (23, 24), (16, 28))
    a.dot("W", (5, 27), (25, 27))
    a.p("I", [(6, 27), (9, 27), (12, 29), (11, 30), (9, 30),
              (7, 30), (6, 30), (4, 30), (4, 28)])
    a.p("M", [(6, 28), (8, 28), (11, 29), (9, 29), (8, 30), (7, 29), (5, 29)])
    a.dot("G", (6, 28), (7, 28), (8, 30), (10, 29))
    a.p("I", [(23, 27), (26, 27), (28, 28), (28, 30), (26, 30),
              (23, 30), (22, 30), (20, 30), (20, 29)])
    a.p("M", [(23, 28), (25, 28), (27, 29), (25, 29), (24, 30),
              (23, 29), (21, 29)])
    a.dot("G", (23, 28), (24, 28), (24, 30))
    # Ears and a larger face receive most of the available pixels.
    a.p("I", [(2, 11), (8, 12), (11, 15), (10, 18), (6, 17), (4, 15)])
    a.p("M", [(3, 12), (7, 13), (10, 15), (9, 17), (6, 16)])
    a.l("G", [(3, 12), (6, 13)])
    a.dot("S", (6, 14), (7, 15), (8, 16))
    a.p("I", [(22, 13), (29, 10), (28, 14), (25, 17), (22, 18), (20, 15)])
    a.p("M", [(23, 13), (28, 11), (26, 15), (22, 17)])
    a.l("G", [(24, 13), (27, 12)])
    a.p("I", [(10, 11), (20, 10), (23, 12), (23, 17), (20, 21),
              (17, 23), (14, 23), (10, 20), (8, 16), (8, 13)])
    a.p("S", [(11, 12), (20, 11), (22, 13), (22, 17), (19, 20),
              (16, 22), (14, 21), (11, 19), (9, 16), (9, 14)])
    a.p("M", [(12, 12), (18, 12), (20, 14), (20, 18), (16, 21),
              (14, 20), (10, 17), (10, 14)])
    a.r("G", (10, 14, 13, 15))
    a.l("I", [(10, 15), (13, 15)])
    a.dot("W", (12, 16))
    a.l("I", [(18, 15), (21, 14)])
    a.dot("W", (19, 15))
    a.l("G", [(16, 15), (15, 17), (16, 18)])
    a.dot("S", (17, 17))
    a.l("F", [(14, 19), (17, 19), (18, 18)])
    a.dot("G", (15, 20), (16, 20))
    a.l("O", [(10, 14), (12, 13), (14, 14), (14, 16), (12, 18),
              (10, 17), (9, 15), (10, 14)])
    a.dot("Y", (10, 14), (11, 13))
    a.dot("O", (15, 14))
    a.p("F", [(9, 10), (21, 10), (22, 12), (23, 14), (20, 12),
              (18, 12), (18, 14), (16, 12), (14, 12), (11, 13), (8, 12)])
    a.dot("M", (11, 11), (12, 11))
    a.l("S", [(18, 11), (20, 12)])
    # Hat is a new 16px-wide design; highlights are contiguous 2px groups.
    a.p("I", [(10, 1), (21, 1), (23, 2), (22, 7), (25, 6),
              (26, 7), (25, 10), (20, 11), (11, 11), (7, 9),
              (6, 7), (7, 6), (10, 7), (9, 2)])
    a.p("C", [(11, 2), (20, 2), (22, 3), (21, 7), (12, 8), (10, 3)])
    a.p("D", [(17, 2), (21, 3), (21, 7), (16, 8)])
    a.l("L", [(11, 3), (12, 3), (12, 5)])
    a.l("I", [(11, 7), (14, 8), (19, 8), (22, 7)])
    a.l("C", [(7, 7), (9, 9), (12, 10), (20, 10), (24, 8)])
    return a.image


def font(size, bold=False):
    path = "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"
    return ImageFont.truetype(path, size)


def review(source, sprites):
    board = Image.new("RGBA", (1440, 960), "#202925")
    d = ImageDraw.Draw(board)
    d.text((40, 26), "哥布林 · 原生像素重绘", font=font(34, True), fill="#eee6cc")
    d.text((42, 80), "参考造型重新设计色块与轮廓  /  两档独立绘制  /  透明 PNG", font=font(20), fill="#a7b599")
    columns = [(24, "造型参考", "保留礼帽、尖耳、单片眼镜与西装"),
               (496, "64 × 64", "原生像素绘制 · 6 倍最近邻放大"),
               (968, "32 × 32", "独立简化构图 · 12 倍最近邻放大")]
    for x, title, note in columns:
        d.rectangle((x, 128, x + 448, 678), fill="#354139")
        d.text((x + 22, 148), title, font=font(25, True), fill="#e7dcba")
        d.text((x + 22, 629), note, font=font(17), fill="#b6c2a6")
    ref = Image.open(source).convert("RGBA")
    ref.thumbnail((400, 400), Image.Resampling.LANCZOS)
    board.alpha_composite(ref, (48, 209))
    for x, sprite in zip((528, 1000), sprites):
        board.alpha_composite(sprite.resize((384, 384), Image.Resampling.NEAREST), (x, 212))

    d.text((40, 708), "同等显示面积对比", font=font(23, True), fill="#e7dcba")
    d.text((40, 747), "两版均显示为 128 × 128", font=font(18), fill="#b6c2a6")
    d.text((40, 781), "64 版保留表情与手指；", font=font(18), fill="#b6c2a6")
    d.text((40, 813), "32 版更粗颗粒、符号化。", font=font(18), fill="#b6c2a6")
    for x, sprite, label in zip((384, 576), sprites, ("64 × 64 · 2 倍", "32 × 32 · 4 倍")):
        d.rectangle((x, 709, x + 159, 860), fill="#161f1c")
        board.alpha_composite(sprite.resize((128, 128), Image.Resampling.NEAREST), (x + 16, 722))
        d.text((x + 7, 870), label, font=font(17), fill="#b6c2a6")
    d.text((812, 715), "64 版 14 色 / 32 版 11 色", font=font(20), fill="#e7dcba")
    for i, color in enumerate(COLORS.values()):
        x = 814 + (i % 7) * 42
        y = 760 + (i // 7) * 34
        d.rectangle((x, y, x + 32, y + 26), fill=color)
    d.text((812, 854), "程序逐格绘制审阅稿，尚未接入游戏", font=font(18), fill="#b6c2a6")
    board.convert("RGB").save(OUT / "comparison.png")


def revision_02():
    """Non-destructive export of the requested 64px silhouette/face revision."""
    folder = OUT / "revision_02"
    folder.mkdir(parents=True, exist_ok=True)
    before = draw_64()
    after = draw_64(revised=True)
    # Confirm the comparison uses the exact previously delivered pixels.
    delivered = Image.open(OUT / "goblin_idle_64x64.png").convert("RGBA")
    assert before.tobytes() == delivered.tobytes()
    colors = after.getcolors(maxcolors=256)
    assert colors is not None
    alpha = sorted({rgba[3] for _, rgba in colors})
    count = sum(rgba[3] != 0 for _, rgba in colors)
    bounds = after.getbbox()
    assert after.size == (64, 64) and alpha == [0, 255] and count <= 14
    assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 64 and bounds[3] < 64
    after.save(folder / "goblin_idle_64x64.png")
    after.resize((512, 512), Image.Resampling.NEAREST).save(folder / "goblin_64_enlarged.png")

    board = Image.new("RGBA", (1200, 900), "#202925")
    d = ImageDraw.Draw(board)
    d.text((36, 25), "64×64 哥布林 · 形态调整", font=font(32, True), fill="#eee6cc")
    d.text((38, 78), "收窄腰部  /  尖鼻  /  狡黠眉眼  /  缩小耳朵", font=font(21), fill="#a7b599")
    for x, sprite, label in [(28, before, "上一版"), (620, after, "本次调整")]:
        d.rectangle((x, 124, x + 552, 687), fill="#354139")
        d.text((x + 24, 142), label, font=font(25, True), fill="#e7dcba")
        board.alpha_composite(sprite.resize((448, 448), Image.Resampling.NEAREST), (x + 52, 192))
        d.text((x + 24, 650), "原生 64×64 · 7 倍最近邻放大", font=font(17), fill="#b6c2a6")
    d.text((36, 716), "新版 · 2 倍显示", font=font(23, True), fill="#e7dcba")
    d.text((36, 758), "14 色 / 透明 PNG", font=font(19), fill="#b6c2a6")
    d.text((36, 798), "程序逐格绘制审阅稿", font=font(18), fill="#b6c2a6")
    for x, bg in [(300, "#161f1c"), (480, "#d9dcc8")]:
        d.rectangle((x, 714, x + 155, 869), fill=bg)
        board.alpha_composite(after.resize((128, 128), Image.Resampling.NEAREST), (x + 14, 728))
    d.text((692, 721), "腰线内收，手臂间留出空隙", font=font(20), fill="#e7dcba")
    d.text((692, 762), "鼻尖突出，斜挑眉眼与上扬嘴角", font=font(20), fill="#e7dcba")
    d.text((692, 803), "两侧耳尖各向内收 5 个原生像素", font=font(20), fill="#e7dcba")
    d.text((692, 850), "素材审阅图，尚未接入游戏", font=font(17), fill="#a7b599")
    board.convert("RGB").save(folder / "comparison.png")
    report = {"revision": 2, "method": "native pixel-coordinate edits to the 64px drawing",
              "size": list(after.size), "opaque_colors": count, "alpha": alpha,
              "bbox": list(bounds), "palette": COLORS,
              "previous_sprite_sha256": hashlib.sha256((OUT / "goblin_idle_64x64.png").read_bytes()).hexdigest(),
              "changes": ["narrow waist and open arm gaps", "pointed nose",
                          "slanted sly eyes and asymmetric smile", "ear tips moved inward five pixels"],
              "source_image_resampled": False, "image_model_used": False, "production_replaced": False}
    (folder / "manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", type=int, choices=(1, 2), default=1)
    args = parser.parse_args()
    if args.revision == 2:
        revision_02()
        return
    OUT.mkdir(parents=True, exist_ok=True)
    source = min(SOURCE.glob("*.png"), key=lambda p: len(p.name))
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    sprites = [draw_64(), draw_32()]
    report = {"method": "independently code-authored native pixel drawings from visual reference",
              "reference": source.relative_to(ROOT).as_posix(), "reference_sha256": source_hash,
              "source_pixels_used_for_sprites": False, "image_model_used": False,
              "antialiasing": False, "dithering": False, "production_replaced": False,
              "palette": COLORS, "outputs": {}}
    for sprite in sprites:
        size = sprite.width
        path = OUT / f"goblin_idle_{size}x{size}.png"
        sprite.save(path)
        colors = sprite.getcolors(maxcolors=256)
        assert colors is not None
        alpha = sorted({rgba[3] for _, rgba in colors})
        count = sum(rgba[3] != 0 for _, rgba in colors)
        assert alpha == [0, 255] and count <= len(COLORS)
        bounds = sprite.getbbox()
        assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < size and bounds[3] < size
        report["outputs"][path.name] = {"size": list(sprite.size), "opaque_colors": count,
                                       "alpha": alpha, "bbox": sprite.getbbox()}
        # Useful standalone magnified preview, preserving every native pixel.
        sprite.resize((512, 512), Image.Resampling.NEAREST).save(OUT / f"goblin_{size}_enlarged.png")
    review(source, sprites)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True))


if __name__ == "__main__":
    main()
