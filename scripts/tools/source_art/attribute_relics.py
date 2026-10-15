"""Hand-authored pixel icons; no image model or external-image conversion.

Draw at 64px, export nearest-neighbor 128px RGBA production sources and one
review sheet. Names and rarity labels come from the existing UTF-8 catalog.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "temp/artifacts/reviews/attribute_relics_20261015"
INK = "#252b30"
BROWN_D, BROWN, BROWN_L = "#493a37", "#77533f", "#aa7e55"
BONE_D, BONE, BONE_L = "#a89573", "#d3c39c", "#ede0b5"
GOLD_D, GOLD, GOLD_L = "#755537", "#b78a4b", "#e3b869"
TEAL_D, TEAL, TEAL_L = "#294d49", "#4a8070", "#87b39b"
RED_D, RED, RED_L = "#572e3c", "#9d4654", "#d07a77"
PURPLE_D, PURPLE, PURPLE_L = "#3e354e", "#775c8d", "#b59bbc"
CLEAR = (0, 0, 0, 0)


def canvas():
    im = Image.new("RGBA", (64, 64), CLEAR)
    return im, ImageDraw.Draw(im)


def coagulation_vial():
    im, d = canvas()
    d.polygon([(24, 7), (39, 7), (41, 19), (47, 24), (53, 33),
               (54, 44), (49, 54), (40, 59), (23, 59), (14, 54),
               (9, 44), (10, 33), (16, 24), (22, 20)], fill=INK)
    d.polygon([(24, 18), (38, 18), (39, 23), (46, 27), (50, 35),
               (50, 44), (46, 51), (39, 55), (24, 55), (17, 51),
               (13, 43), (14, 34), (19, 27), (24, 24)], fill=PURPLE_D)
    d.polygon([(24, 22), (29, 22), (24, 29), (19, 34), (17, 43),
               (20, 49), (16, 46), (15, 36), (19, 29)], fill=PURPLE)
    d.polygon([(17, 35), (24, 32), (34, 35), (46, 32), (48, 37),
               (47, 45), (42, 51), (25, 53), (19, 48), (16, 42)], fill=RED)
    d.polygon([(33, 37), (46, 35), (47, 44), (41, 50), (27, 51),
               (26, 46), (34, 44)], fill=RED_D)
    d.line([(20, 35), (24, 34), (32, 37)], fill=RED_L, width=2)
    d.line([(19, 28), (16, 33), (15, 39)], fill=PURPLE_L, width=2)
    d.line([(20, 49), (24, 52)], fill=PURPLE_L, width=2)
    d.polygon([(28, 36), (23, 44), (25, 47), (30, 47), (33, 44)], fill=RED_L)
    d.rectangle((21, 9, 42, 19), fill=INK)
    d.rectangle((23, 11, 40, 16), fill=GOLD)
    d.rectangle((24, 6, 38, 10), fill=INK)
    d.rectangle((26, 7, 36, 9), fill=GOLD_L)
    d.line([(24, 12), (38, 12)], fill=GOLD_L, width=2)
    d.polygon([(36, 16), (41, 16), (44, 25), (42, 30), (37, 28)], fill=INK)
    d.polygon([(37, 17), (39, 17), (42, 25), (41, 27), (39, 25)], fill=RED)
    return im


def trade_charter():
    im, d = canvas()
    d.polygon([(9, 7), (47, 7), (53, 13), (49, 21), (49, 46),
               (54, 48), (53, 55), (47, 58), (13, 58), (9, 53),
               (11, 18), (6, 16), (6, 11)], fill=INK)
    d.polygon([(14, 13), (45, 13), (45, 48), (49, 51), (46, 54),
               (14, 54), (12, 51)], fill=BONE)
    d.polygon([(38, 14), (45, 14), (45, 48), (49, 51), (45, 54), (39, 53)], fill=BONE_D)
    d.rectangle((15, 15, 17, 48), fill=BONE_L)
    d.rectangle((10, 9, 45, 16), fill=GOLD_D)
    d.line([(11, 10), (45, 10), (49, 13)], fill=GOLD_L, width=2)
    d.ellipse((41, 8, 51, 18), fill=INK)
    d.ellipse((44, 10, 48, 15), fill=GOLD)
    d.line([(13, 52), (43, 52)], fill=GOLD_D, width=2)
    d.line([(14, 55), (43, 55)], fill=GOLD_L, width=2)
    # A merchant crest and sparse rules; no fake readable lettering.
    d.polygon([(22, 19), (28, 16), (34, 19), (34, 27), (28, 31), (22, 27)], fill=TEAL_D)
    d.polygon([(25, 20), (31, 20), (31, 26), (28, 28), (25, 26)], fill=TEAL)
    d.line([(26, 21), (29, 21)], fill=TEAL_L, width=2)
    d.rectangle((21, 34, 34, 35), fill=GOLD_D)
    d.rectangle((21, 39, 31, 40), fill=GOLD_D)
    d.polygon([(37, 35), (44, 35), (49, 58), (43, 55), (39, 59), (35, 45)], fill=INK)
    d.polygon([(39, 39), (42, 39), (46, 55), (42, 52), (40, 55), (38, 44)], fill=TEAL)
    d.line([(39, 42), (42, 52)], fill=TEAL_L, width=2)
    d.polygon([(38, 29), (46, 29), (51, 34), (51, 40), (46, 45),
               (39, 45), (34, 40), (34, 34)], fill=INK)
    d.polygon([(39, 32), (45, 32), (48, 35), (48, 39), (45, 42),
               (39, 42), (37, 39), (37, 35)], fill=RED)
    d.line([(39, 33), (44, 33)], fill=RED_L, width=2)
    d.polygon([(41, 35), (45, 37), (41, 40), (39, 38)], fill=RED_D)
    return im


def market_key():
    im, d = canvas()
    # Diagonal shaft and two stepped teeth remain recognizable when reduced.
    d.line([(39, 25), (11, 53)], fill=INK, width=12)
    d.line([(37, 27), (11, 53)], fill=GOLD_D, width=7)
    d.line([(36, 27), (10, 52)], fill=GOLD, width=4)
    d.line([(35, 27), (11, 51)], fill=GOLD_L, width=2)
    d.polygon([(13, 43), (23, 51), (19, 56), (14, 52), (10, 57),
               (5, 53), (10, 46)], fill=INK)
    d.polygon([(14, 46), (20, 51), (18, 53), (14, 49), (9, 54), (8, 52)], fill=GOLD)
    d.line([(14, 46), (19, 50)], fill=GOLD_L, width=2)
    d.line([(24, 34), (31, 41)], fill=INK, width=6)
    d.line([(25, 33), (32, 40)], fill=GOLD, width=4)
    d.line([(25, 33), (31, 39)], fill=GOLD_L, width=2)
    d.polygon([(40, 4), (50, 5), (58, 13), (58, 24), (51, 32),
               (39, 33), (31, 26), (28, 15), (32, 8)], fill=INK)
    d.polygon([(40, 7), (49, 8), (55, 15), (55, 23), (49, 29),
               (40, 30), (34, 25), (31, 16), (35, 10)], fill=GOLD_D)
    d.line([(33, 17), (36, 11), (41, 8), (48, 9)], fill=GOLD_L, width=3)
    d.line([(40, 29), (48, 28), (53, 23)], fill=GOLD, width=2)
    d.polygon([(41, 11), (48, 12), (52, 17), (51, 23), (46, 27),
               (39, 25), (35, 20), (36, 15)], fill=INK)
    d.polygon([(42, 13), (47, 14), (49, 18), (48, 22), (44, 24),
               (39, 22), (38, 17)], fill=PURPLE)
    d.polygon([(43, 16), (48, 18), (47, 22), (44, 23), (41, 20)], fill=PURPLE_D)
    d.line([(42, 14), (39, 17), (39, 20)], fill=PURPLE_L, width=2)
    d.rectangle((42, 17, 44, 20), fill=INK)
    return im


def bone_whistle():
    im, d = canvas()
    # Cord forms a visible loop behind the tapered carved bone.
    d.line([(32, 29), (46, 36), (51, 47), (47, 56), (39, 58),
            (31, 52), (28, 41), (33, 30)], fill=INK, width=6)
    d.line([(32, 29), (46, 37), (49, 47), (45, 54), (39, 56),
            (33, 51), (30, 41), (34, 31)], fill=TEAL, width=3)
    d.line([(46, 39), (47, 47), (44, 51)], fill=TEAL_L, width=2)
    d.polygon([(6, 41), (9, 29), (18, 18), (29, 11), (43, 7),
               (53, 6), (58, 12), (57, 18), (45, 20), (33, 24),
               (24, 32), (17, 43), (10, 47)], fill=INK)
    d.polygon([(9, 40), (12, 30), (20, 21), (31, 14), (44, 10),
               (53, 9), (55, 12), (54, 16), (44, 17), (31, 22),
               (21, 31), (15, 41), (11, 43)], fill=BONE)
    d.polygon([(9, 40), (15, 32), (24, 23), (36, 16), (52, 12),
               (54, 16), (44, 17), (31, 22), (21, 31), (15, 41), (11, 43)], fill=BONE_D)
    d.line([(13, 29), (21, 20), (31, 14), (44, 10), (50, 10)], fill=BONE_L, width=2)
    d.line([(45, 8), (47, 18)], fill=INK, width=4)
    d.line([(46, 9), (48, 17)], fill=TEAL, width=3)
    d.line([(47, 10), (48, 14)], fill=TEAL_L, width=2)
    for x, y in [(20, 27), (29, 20), (38, 16)]:
        d.ellipse((x-2, y-2, x+3, y+3), fill=INK)
        d.line([(x, y+2), (x+2, y+2)], fill=BROWN, width=1)
    d.polygon([(8, 40), (12, 36), (15, 39), (12, 44), (9, 44)], fill=INK)
    d.line([(9, 41), (12, 38)], fill=BROWN, width=2)
    return im


def tide_bell():
    im, d = canvas()
    # Purple tied loop and hanging clapper distinguish this from the cracked bell.
    d.line([(26, 18), (22, 10), (26, 5), (31, 9), (33, 16),
            (36, 7), (41, 7), (43, 12), (37, 18)], fill=INK, width=6)
    d.line([(26, 16), (25, 10), (27, 8), (31, 13), (33, 17),
            (37, 9), (40, 10), (38, 14)], fill=PURPLE, width=3)
    d.line([(25, 10), (27, 8), (30, 11)], fill=PURPLE_L, width=2)
    d.polygon([(28, 47), (38, 47), (40, 54), (36, 60), (29, 60),
               (25, 56)], fill=INK)
    d.polygon([(29, 51), (35, 51), (37, 55), (34, 58), (29, 57)], fill=GOLD_D)
    d.line([(29, 52), (28, 55), (30, 57)], fill=GOLD_L, width=2)
    d.polygon([(24, 16), (39, 16), (45, 22), (46, 34), (52, 42),
               (58, 47), (58, 52), (6, 52), (6, 47), (12, 42),
               (17, 34), (18, 23)], fill=INK)
    d.polygon([(25, 19), (37, 19), (42, 24), (43, 35), (50, 44),
               (14, 44), (20, 34), (21, 24)], fill=GOLD)
    d.polygon([(35, 21), (41, 25), (42, 35), (48, 43), (38, 43)], fill=GOLD_D)
    d.polygon([(25, 21), (29, 20), (28, 33), (23, 43), (16, 43),
               (22, 33), (23, 25)], fill=GOLD_L)
    d.rectangle((9, 46, 55, 49), fill=GOLD_D)
    d.line([(11, 46), (51, 46)], fill=GOLD_L, width=2)
    # Single dark-red eye, broad enough to survive the 32px shop display.
    d.polygon([(23, 31), (29, 26), (36, 26), (43, 31), (36, 37),
               (29, 37)], fill=INK)
    d.polygon([(26, 31), (30, 29), (35, 29), (40, 31), (35, 34),
               (30, 34)], fill=RED)
    d.rectangle((31, 28, 34, 35), fill=INK)
    d.rectangle((31, 29, 32, 31), fill=RED_L)
    d.line([(19, 39), (25, 39)], fill=GOLD_D, width=2)
    return im


FACTORIES = {
    "relic_crimson_coagulation_vial": coagulation_vial,
    "relic_goblin_trade_charter": trade_charter,
    "relic_void_market_key": market_key,
    "relic_hunting_bone_whistle": bone_whistle,
    "relic_hungry_tide_bell": tide_bell,
}


def build():
    records = {r["id"]: r for r in json.loads((ROOT / "data_config/relics.json").read_text(encoding="utf-8"))}
    board = Image.new("RGB", (1200, 760), "#131e20")
    d = ImageDraw.Draw(board)
    title_font = ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc", 25)
    small_font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18)
    d.text((25, 17), "新增遗物 · 三种属性补充", font=title_font, fill=BONE_L)
    d.text((25, 57), "本地原创像素绘制 · 128px 透明 PNG · 每格右侧为 40px 缩略效果", font=small_font, fill="#a3b7ad")
    rarity_labels = {"common": ("普通 · 白", "#c6c9c0"), "rare": ("稀有 · 蓝", "#84adcf"),
                     "mythic": ("神话 · 橙", "#dfa15c"), "legendary": ("传说 · 红", "#df7b75")}
    entries = list(FACTORIES.items())
    for slot, (key, factory) in enumerate(entries):
        im = factory()
        assert im.size == (64, 64) and im.mode == "RGBA"
        assert set(im.getchannel("A").tobytes()) == {0, 255}
        assert im.getcolors(24) is not None
        bbox = im.getchannel("A").getbbox()
        assert bbox and min(bbox[:2]) >= 2 and max(bbox[2:]) <= 62
        source = im.resize((128, 128), Image.Resampling.NEAREST)
        source.save(ROOT / "assets/ui/icons/relics" / (key + ".png"))
        record = records[key]
        label, color = rarity_labels[record["rarity"]]
        x, y = 20 + (slot % 3)*393, 100 + (slot // 3)*322
        d.rectangle((x, y, x+373, y+303), fill="#1c292a", outline="#3b4b46", width=1)
        d.rectangle((x, y, x+373, y+2), fill=color)
        d.text((x+17, y+15), record["display_name"], font=title_font, fill=BONE_L)
        limit = "无上限" if record["max_stack"] == 0 else "上限 " + str(record["max_stack"])
        d.text((x+17, y+53), label + " · " + limit, font=small_font, fill=color)
        board.paste(source, (x+55, y+87), source)
        thumb = source.resize((40, 40), Image.Resampling.NEAREST)
        board.paste(thumb, (x+261, y+132), thumb)
        for row, effect in enumerate(record["description"].split("；")):
            d.text((x+17, y+227+row*23), effect, font=small_font, fill="#d1cdb9")
        print(key, "128x128 RGBA", "palette", len(im.getcolors()), "bounds", bbox)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    board.save(OUTPUT / "icons.png")


if __name__ == "__main__":
    build()
