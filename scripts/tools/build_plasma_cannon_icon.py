"""Original local pixel art for the plasma-cannon icon review.

Writes a sibling v2 PNG, preserving the live icon and weapon configuration.
Reads the approved grenade icon unchanged for a same-scale comparison board.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/plasma_cannon_icon_review"
PLASMA = ROOT / "assets/ui/icons/weapons/weapon_plasma_cannon_v2.png"
GRENADE = ROOT / "assets/ui/icons/weapons/weapon_iron_grenade_cannon.png"
INK = "#101924"
P = {
    "shadow": "#20283b", "navy": "#2c4053", "steel": "#486378",
    "light": "#7597a6", "edge": "#b0c9ce", "edge_hi": "#d3e0d9",
    "violet": "#595072", "violet_hi": "#8b799c", "deep": "#163a4a",
    "cyan_low": "#247a93", "cyan": "#35bad3", "cyan_hi": "#76e9ee",
    "core": "#d0ffff", "black": "#101d2a",
}


def draw_icon():
    icon = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(icon)
    co, si = math.cos(math.radians(-31)), math.sin(math.radians(-31))

    def xy(u, v):
        return round(30 + u * co - v * si), round(33 + u * si + v * co)

    def poly(points, fill, outline=None):
        d.polygon([xy(u, v) for u, v in points], fill=fill, outline=outline)

    def line(points, fill, width=1):
        d.line([xy(u, v) for u, v in points], fill=fill, width=width)

    def dot(u, v, color):
        d.point(xy(u, v), color)

    # Compact rear power pack: metal fins rather than a wooden butt stock.
    poly([(-27, -5), (-23, -8), (-16, -7), (-12, -3), (-13, 5), (-21, 8), (-27, 4)], P["shadow"], INK)
    poly([(-26, -3), (-23, -6), (-18, -5), (-18, 3), (-24, 5), (-26, 3)], P["steel"])
    line([(-25, -4), (-23, -6), (-19, -5)], P["edge"])
    for u in [-23, -20, -17]:
        line([(u, -5), (u, 5)], INK, 2)
        line([(u + 1, -5), (u + 1, 3)], P["light"])

    # Underslung grip, power-cell heel and a curved insulated cable.
    poly([(-12, 6), (-5, 6), (-6, 20), (-13, 22), (-16, 18)], P["navy"], INK)
    poly([(-12, 8), (-8, 8), (-10, 18), (-13, 19)], P["steel"])
    for v in [11, 14, 17]:
        line([(-12, v), (-8, v)], P["shadow"])
    poly([(-14, 18), (-6, 17), (-5, 21), (-13, 24), (-16, 21)], P["shadow"], INK)
    line([(-14, 20), (-7, 19)], P["cyan_low"])
    line([(-4, 8), (2, 12), (0, 17), (-6, 18)], INK, 3)
    line([(-3, 9), (0, 12), (-1, 15), (-5, 16)], P["violet_hi"])

    # Angular reactor housing; a wide silhouette at the rear and open front.
    poly([(-17, -7), (-11, -12), (0, -12), (8, -7), (10, -1), (7, 8), (-1, 12), (-12, 9), (-17, 3)], P["navy"], INK)
    poly([(-15, -6), (-10, -10), (0, -10), (6, -6), (4, -2), (-13, -1)], P["steel"])
    line([(-14, -6), (-9, -10), (-1, -10), (4, -7)], P["light"])
    line([(-10, -11), (-4, -11)], P["edge"])
    poly([(-14, 3), (4, 3), (7, 6), (-1, 10), (-11, 7)], P["shadow"])

    # Hexagonal containment window with a luminous suspended plasma seed.
    poly([(-10, -6), (-3, -8), (3, -4), (3, 3), (-3, 7), (-10, 5), (-13, 0)], P["light"], INK)
    poly([(-9, -5), (-3, -6), (1, -3), (1, 2), (-3, 5), (-9, 3), (-11, 0)], P["deep"])
    line([(-9, -5), (-3, -6), (0, -4)], P["edge"])
    poly([(-7, -4), (-3, -4), (0, -1), (-1, 2), (-4, 4), (-8, 2), (-9, -1)], P["cyan_low"])
    poly([(-6, -3), (-3, -3), (-1, -1), (-2, 2), (-5, 3), (-7, 1), (-7, -1)], P["cyan"])
    poly([(-5, -2), (-3, -2), (-2, 0), (-4, 2), (-6, 0)], P["cyan_hi"])
    line([(-5, -2), (-4, 0), (-3, 0)], P["core"])
    dot(-4, 1, P["core"])
    # Clamps interrupt the window boundary to retain a mechanical feel.
    line([(-11, -5), (-9, -2)], P["shadow"], 2)
    line([(-1, 4), (-2, 6)], P["steel"], 2)

    # Two long, separated electromagnetic rails; no round barrel opening.
    poly([(3, -9), (22, -9), (29, -6), (30, -3), (24, -3), (20, -5), (6, -5)], P["steel"], INK)
    poly([(5, -8), (22, -8), (27, -6), (25, -5), (20, -6), (6, -6)], P["light"])
    line([(6, -8), (21, -8), (27, -6)], P["edge"])
    line([(9, -5), (21, -5), (26, -3)], P["cyan_hi"])
    poly([(5, 4), (20, 4), (25, 2), (30, 3), (28, 7), (22, 10), (3, 9)], P["navy"], INK)
    poly([(6, 6), (20, 6), (26, 4), (27, 6), (21, 8), (6, 8)], P["steel"])
    line([(7, 5), (20, 5), (25, 3)], P["cyan"])
    line([(8, 8), (21, 8), (27, 6)], P["light"])
    # Rail braces and dark separators prevent a generic solid gun silhouette.
    for u in [9, 16]:
        line([(u, -9), (u + 1, -6)], P["shadow"], 2)
        line([(u, 6), (u + 1, 9)], P["shadow"], 2)
        dot(u, -8, P["edge"])
    # Discrete electric arc in the open channel, contained inside the weapon.
    line([(7, 0), (11, -1), (13, 1), (17, -1), (20, 0), (24, -1)], P["cyan_low"])
    line([(14, 0), (17, -1), (19, 0)], P["cyan_hi"])
    dot(23, -1, P["core"])

    # Muted violet ceramic vents and sparse fasteners are the only accents.
    for u in [-9, -5, -1]:
        line([(u, -11), (u + 1, -9)], P["violet_hi"])
    for u, v in [(-14, 0), (-10, 7), (2, 8), (24, -6), (24, 6)]:
        dot(u, v, P["edge"])
    return icon


def font(size=18):
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def comparison(plasma, grenade):
    board = Image.new("RGB", (1080, 842), "#0e1516")
    d = ImageDraw.Draw(board)
    d.text((34, 23), "武器 ICON 对比审阅", font=font(28), fill="#e4d5b2")
    d.text((34, 67), "统一 64 × 64 透明原图 · 下方包含实际小尺寸显示", font=font(17), fill="#9baba5")
    for x, icon, title, subtitle, detail, accent in [
        (34, plasma, "电浆炮 · 重绘版", "冷色能量武器", "开放双导轨 / 蓝青电浆核心 / 金属握柄", "#86e4ed"),
        (558, grenade, "铸铁榴弹炮 · 已认可版", "暖色实体火炮", "粗短空心炮管 / 黄铜箍 / 木柄", "#d8b47c"),
    ]:
        d.rectangle((x, 114, x + 487, 589), fill="#182321", outline="#3d5049", width=2)
        d.text((x + 22, 132), title, font=font(24), fill=accent)
        scaled = icon.resize((384, 384), Image.Resampling.NEAREST)
        board.paste(scaled, (x + 52, 187), scaled)
        d.text((x + 22, 604), subtitle, font=font(20), fill=accent)
        d.text((x + 22, 638), detail, font=font(17), fill="#bac7bd")
        for dx, size in [(31, 32), (160, 48), (301, 64)]:
            sx, sy = x + dx, 682
            d.rectangle((sx, sy, sx + 97, sy + 83), fill="#23312c", outline="#516052")
            small = icon.resize((size, size), Image.Resampling.NEAREST)
            board.paste(small, (sx + (98 - size) // 2, sy + (84 - size) // 2), small)
            d.text((sx + 23, sy + 92), str(size) + " px", font=font(16), fill="#9baba5")
    board.save(OUT / "plasma_vs_grenade.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    original_hash = hashlib.sha256(GRENADE.read_bytes()).hexdigest()
    grenade = Image.open(GRENADE).convert("RGBA")
    plasma = draw_icon()
    bounds = plasma.getbbox()
    assert 0 < bounds[0] < bounds[2] < 64 and 0 < bounds[1] < bounds[3] < 64
    assert set(plasma.getchannel("A").tobytes()) == {0, 255}
    plasma.save(PLASMA)
    plasma.resize((384, 384), Image.Resampling.NEAREST).save(OUT / "plasma_icon_6x.png")
    comparison(plasma, grenade)
    assert hashlib.sha256(GRENADE.read_bytes()).hexdigest() == original_hash
    report = {"mode": "original local pixel drawing; no model/API", "plasma": str(PLASMA.relative_to(ROOT)), "size": [64, 64], "rgba": True, "alpha_values": [0, 255], "bounds": bounds, "palette_colors": len(plasma.getcolors()) - 1, "grenade_sha256": original_hash, "live_icon_replaced": False}
    (OUT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
