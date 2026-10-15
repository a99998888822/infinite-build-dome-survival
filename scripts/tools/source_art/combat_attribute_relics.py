"""Original local pixel drawings for the six confirmed combat-attribute relics.

No image model or external-image conversion. Draw on a 64px grid, export
128px transparent RGBA with nearest sampling; reuse the shipped palette.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from attribute_relics import (
    INK, BROWN_D, BROWN, BROWN_L, BONE_D, BONE, BONE_L,
    GOLD_D, GOLD, GOLD_L, TEAL_D, TEAL, TEAL_L,
    RED_D, RED, RED_L, PURPLE_D, PURPLE, PURPLE_L, canvas,
)

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "temp/artifacts/reviews/combat_attribute_relics_20261015"


def falcon_pin():
    im, d = canvas()
    d.polygon([(11, 48), (13, 24), (24, 7), (31, 5), (31, 20), (24, 38)], fill=INK)
    d.polygon([(14, 41), (16, 24), (26, 10), (28, 10), (28, 21), (22, 35)], fill=BONE)
    d.line([(14, 44), (26, 13)], fill=BROWN, width=3)
    d.line([(19, 28), (25, 24)], fill=BONE_L, width=3)
    d.line([(16, 36), (23, 32)], fill=BONE_D, width=3)
    d.line([(14, 51), (45, 20)], fill=INK, width=10)
    d.line([(14, 51), (44, 21)], fill=GOLD_D, width=6)
    d.line([(14, 49), (43, 20)], fill=GOLD_L, width=2)
    d.ellipse((28, 7, 58, 37), fill=INK)
    d.ellipse((31, 10, 55, 34), fill=GOLD)
    d.ellipse((35, 14, 51, 30), fill=INK)
    d.ellipse((38, 17, 48, 27), fill=TEAL_D)
    d.line([(43, 13), (43, 30)], fill=TEAL_L, width=2)
    d.line([(35, 22), (51, 22)], fill=TEAL_L, width=2)
    d.rectangle((41, 20, 44, 23), fill=BONE_L)
    d.polygon([(12, 46), (19, 52), (9, 58)], fill=INK)
    d.polygon([(13, 49), (16, 52), (12, 54)], fill=GOLD_L)
    return im


def whetstone():
    im, d = canvas()
    d.polygon([(6, 36), (37, 9), (54, 16), (58, 26), (27, 56), (9, 51)], fill=INK)
    d.polygon([(10, 36), (38, 13), (52, 19), (25, 45)], fill=TEAL)
    d.polygon([(28, 47), (54, 22), (54, 26), (27, 52)], fill=TEAL_D)
    d.polygon([(10, 40), (24, 48), (24, 51), (12, 48)], fill=BROWN_D)
    d.line([(13, 35), (38, 15), (48, 19)], fill=TEAL_L, width=2)
    d.polygon([(20, 34), (38, 19), (44, 21), (27, 38)], fill=RED_D)
    d.line([(23, 35), (37, 23)], fill=RED, width=3)
    d.polygon([(12, 29), (18, 24), (35, 33), (35, 42), (29, 48), (27, 38)], fill=INK)
    d.polygon([(15, 29), (18, 27), (32, 35), (32, 41), (30, 43), (30, 36)], fill=BROWN)
    d.line([(16, 28), (30, 35)], fill=BROWN_L, width=2)
    d.rectangle((22, 31, 28, 37), fill=GOLD_D)
    d.rectangle((23, 32, 27, 33), fill=GOLD_L)
    return im


def execution_seal():
    im, d = canvas()
    d.polygon([(15, 36), (25, 40), (18, 59), (13, 54), (8, 56)], fill=INK)
    d.polygon([(17, 40), (21, 41), (17, 54), (14, 51), (12, 53)], fill=RED)
    d.polygon([(41, 35), (50, 38), (58, 54), (51, 53), (48, 59)], fill=INK)
    d.polygon([(44, 39), (47, 40), (53, 51), (49, 50), (48, 54)], fill=RED_D)
    d.polygon([(26, 7), (38, 7), (42, 13), (36, 24), (44, 30),
               (20, 30), (28, 23), (22, 14)], fill=INK)
    d.polygon([(28, 10), (35, 10), (38, 14), (32, 22), (26, 14)], fill=PURPLE_D)
    d.line([(27, 12), (34, 12)], fill=PURPLE_L, width=2)
    d.rectangle((23, 23, 40, 27), fill=GOLD)
    d.rectangle((12, 28, 52, 52), fill=INK)
    d.rectangle((15, 31, 49, 49), fill=GOLD_D)
    d.rectangle((17, 32, 47, 46), fill=RED_D)
    d.line([(18, 32), (46, 32)], fill=RED_L, width=2)
    d.polygon([(25, 36), (42, 36), (35, 43), (25, 43)], fill=GOLD_L)
    d.rectangle((22, 35, 24, 44), fill=GOLD)
    d.line([(16, 49), (48, 49)], fill=GOLD, width=2)
    return im


def ward_talisman():
    im, d = canvas()
    d.line([(22, 23), (16, 11), (21, 5), (42, 6), (47, 12), (40, 24)], fill=INK, width=6)
    d.line([(22, 23), (19, 11), (22, 8), (41, 9), (44, 12), (39, 23)], fill=BROWN_L, width=2)
    d.polygon([(17, 20), (43, 20), (50, 28), (47, 53), (30, 59), (13, 51), (12, 29)], fill=INK)
    d.polygon([(19, 24), (41, 24), (46, 29), (43, 50), (30, 54), (17, 49), (16, 30)], fill=TEAL)
    d.polygon([(34, 26), (42, 26), (46, 29), (43, 50), (31, 54), (33, 47)], fill=TEAL_D)
    d.line([(20, 25), (18, 32), (19, 45)], fill=TEAL_L, width=2)
    d.polygon([(22, 32), (30, 29), (39, 32), (37, 42), (30, 48), (23, 42)], fill=INK)
    d.polygon([(25, 34), (30, 32), (36, 34), (34, 40), (30, 44), (26, 40)], fill=BONE)
    d.line([(26, 34), (30, 33), (30, 42)], fill=BONE_L, width=2)
    d.line([(22, 25), (39, 25)], fill=BROWN, width=3)
    return im


def twin_magazine():
    im, d = canvas()
    for x, y in [(12, 11), (34, 7)]:
        d.polygon([(x, y+16), (x+2, y+6), (x+9, y), (x+16, y+6),
                   (x+18, y+16), (x+18, y+34), (x, y+34)], fill=INK)
        d.polygon([(x+3, y+16), (x+5, y+7), (x+9, y+4), (x+13, y+7),
                   (x+15, y+16)], fill=GOLD)
        d.line([(x+5, y+14), (x+7, y+8)], fill=GOLD_L, width=3)
        d.rectangle((x+3, y+18, x+15, y+34), fill=BROWN_D)
        d.rectangle((x+4, y+18, x+6, y+30), fill=BROWN_L)
    d.polygon([(8, 31), (54, 27), (54, 49), (48, 58), (14, 60), (8, 53)], fill=INK)
    d.polygon([(12, 35), (50, 31), (50, 48), (45, 54), (16, 56), (12, 51)], fill=TEAL_D)
    d.polygon([(13, 35), (28, 34), (28, 54), (16, 55), (13, 51)], fill=TEAL)
    d.line([(31, 33), (31, 55)], fill=INK, width=3)
    d.polygon([(9, 40), (53, 36), (54, 42), (10, 47)], fill=INK)
    d.line([(12, 43), (51, 39)], fill=GOLD, width=4)
    d.line([(13, 42), (49, 38)], fill=GOLD_L, width=2)
    return im


def stilltime_amber():
    im, d = canvas()
    d.polygon([(22, 6), (42, 9), (54, 27), (51, 46), (40, 57),
               (20, 57), (8, 39), (12, 20)], fill=INK)
    d.polygon([(23, 10), (39, 12), (50, 28), (47, 44), (38, 52),
               (22, 53), (12, 38), (16, 22)], fill=GOLD)
    d.polygon([(23, 10), (29, 18), (19, 35), (13, 36), (17, 22)], fill=GOLD_L)
    d.polygon([(40, 16), (49, 29), (46, 43), (37, 51), (31, 43), (41, 33)], fill=GOLD_D)
    d.polygon([(26, 18), (37, 20), (42, 30), (35, 41), (24, 42), (18, 33)], fill=BROWN_L)
    # A trapped dragonfly silhouette, deliberately sparse at UI size.
    d.polygon([(29, 29), (19, 24), (18, 29), (27, 34)], fill=BROWN_D)
    d.polygon([(32, 29), (42, 24), (44, 29), (34, 34)], fill=BROWN_D)
    d.line([(30, 25), (31, 43)], fill=INK, width=3)
    d.rectangle((28, 24, 32, 27), fill=INK)
    d.line([(20, 27), (26, 30)], fill=GOLD, width=2)
    d.line([(39, 27), (35, 30)], fill=GOLD, width=2)
    d.polygon([(14, 45), (22, 51), (38, 51), (46, 45), (48, 51),
               (41, 58), (21, 59), (13, 51)], fill=INK)
    d.line([(17, 48), (23, 54), (38, 54), (44, 49)], fill=GOLD_D, width=4)
    d.line([(23, 54), (36, 54)], fill=GOLD_L, width=2)
    return im


FACTORIES = {
    "relic_falcon_sighting_pin": falcon_pin,
    "relic_executioner_whetstone": whetstone,
    "relic_crimson_execution_seal": execution_seal,
    "relic_faded_ward_talisman": ward_talisman,
    "relic_twin_chamber_magazine": twin_magazine,
    "relic_stilltime_amber": stilltime_amber,
}


def build():
    records = {r["id"]: r for r in json.loads((ROOT / "data_config/relics.json").read_text(encoding="utf-8"))}
    board = Image.new("RGB", (980, 880), "#131e20")
    d = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc", 24)
    small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 17)
    d.text((25, 17), "战斗属性遗物 · 正式采用六件", font=font, fill=BONE_L)
    d.text((25, 57), "本地原创像素绘制 · 128px 透明 PNG · 右侧为 40px 缩略图 · 均无持有上限", font=small, fill=TEAL_L)
    rarities = {"common": ("白", "#c6c9c0"), "uncommon": ("绿", "#99c18d"),
                "rare": ("蓝", "#84adcf"), "epic": ("紫", "#b59bbc"),
                "mythic": ("橙", "#dfa15c"), "legendary": ("红", "#df7b75")}
    for slot, (key, factory) in enumerate(FACTORIES.items()):
        im = factory()
        assert im.size == (64, 64) and im.mode == "RGBA"
        assert set(im.getchannel("A").tobytes()) == {0, 255}
        assert im.getcolors(24) is not None
        bbox = im.getchannel("A").getbbox()
        assert bbox and min(bbox[:2]) >= 2 and max(bbox[2:]) <= 62
        source = im.resize((128, 128), Image.Resampling.NEAREST)
        source.save(ROOT / "assets/ui/icons/relics" / (key + ".png"))
        record = records[key]
        rarity, color = rarities[record["rarity"]]
        x, y = 20 + (slot % 3)*316, 100 + (slot // 3)*385
        d.rectangle((x, y, x+295, y+367), fill="#1c292a", outline="#3b4b46")
        d.rectangle((x, y, x+295, y+2), fill=color)
        d.text((x+15, y+16), record["display_name"], font=font, fill=BONE_L)
        d.text((x+15, y+51), rarity + "色 · 无上限", font=small, fill=color)
        board.paste(source, (x+34, y+88), source)
        thumb = source.resize((40, 40), Image.Resampling.NEAREST)
        board.paste(thumb, (x+221, y+133), thumb)
        lines = []
        for effect in record["description"].split("；"):
            if effect.startswith("仅影响"):
                lines.extend(["仅作用于适配攻击；", "部分攻击无法重复命中同一目标"])
            else:
                lines.append(effect)
        for row, effect in enumerate(lines):
            d.text((x+15, y+235+row*24), effect, font=small, fill=BONE)
        print(key, "128x128 RGBA", "palette", len(im.getcolors()), "bounds", bbox)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    board.save(OUTPUT / "icons.png")


if __name__ == "__main__":
    build()
