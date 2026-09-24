"""Draw the original grenade-cannon review icon locally with Pillow.

No model/API calls. The 64px master uses hand-authored pixel geometry,
an opaque palette, and a transparent canvas. Does not edit gameplay data.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/iron_grenade_cannon_review"
ASSET = ROOT / "assets/ui/icons/weapons/weapon_iron_grenade_cannon.png"
INK = "#111b1c"
P = {
    "iron_dark": "#293539", "iron_low": "#3c4a4b", "iron": "#596768",
    "iron_light": "#83908a", "iron_high": "#bdc5ae", "brass_dark": "#594932",
    "brass": "#967947", "brass_light": "#c6aa6b", "brass_high": "#ebd296",
    "wood_dark": "#3c2c25", "wood": "#77523a", "wood_light": "#aa7950",
    "wood_high": "#c99a68", "rune_dark": "#365f51", "rune": "#79a280",
}


def draw_icon() -> Image.Image:
    icon = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(icon)
    angle = math.radians(-31)
    co, si = math.cos(angle), math.sin(angle)

    def xy(u, v):
        return (round(29 + u * co - v * si), round(33 + u * si + v * co))

    def polygon(points, color, outline=None):
        d.polygon([xy(u, v) for u, v in points], fill=color, outline=outline)

    def line(points, color, width=1):
        d.line([xy(u, v) for u, v in points], fill=color, width=width)

    def oval(u, v, a, b, color, outline=None):
        polygon([(u + a * math.cos(i * math.tau / 36), v + b * math.sin(i * math.tau / 36)) for i in range(36)], color, outline)

    # The stock, grip and trigger sit behind the heavy barrel assembly.
    polygon([(-28, -4), (-25, -7), (-19, -4), (-13, -3), (-9, 1), (-12, 8), (-20, 6), (-25, 11), (-29, 10)], P["wood"], INK)
    polygon([(-27, -3), (-25, -4), (-18, 0), (-13, 0), (-15, 3), (-21, 2), (-25, 5)], P["wood_light"])
    line([(-27, -2), (-25, -2), (-19, 1)], P["wood_high"])
    line([(-24, 7), (-20, 4), (-16, 5)], P["wood_dark"])
    polygon([(-29, -3), (-27, -4), (-26, 9), (-28, 11), (-30, 10)], P["iron_dark"], INK)
    line([(-28, -2), (-27, 8)], P["iron_light"])
    polygon([(-10, 6), (-3, 6), (-6, 19), (-12, 20), (-15, 16)], P["wood"], INK)
    polygon([(-10, 8), (-7, 9), (-10, 17), (-13, 17)], P["wood_light"])
    for height in [11, 14, 17]:
        line([(-12, height), (-8, height)], P["wood_dark"])
    line([(-3, 6), (4, 7), (4, 13), (1, 16), (-7, 16)], INK, 3)
    line([(-2, 7), (3, 8), (3, 12), (0, 14), (-6, 14)], P["brass"])
    line([(-1, 7), (-1, 11), (-3, 12)], P["iron_light"])

    # Cast-iron tube: discrete cylindrical shade bands, no blur or gradients.
    polygon([(-13, -7), (-8, -11), (20, -11), (25, -7), (25, 7), (19, 11), (-7, 11), (-13, 7)], P["iron_dark"], INK)
    polygon([(-10, -6), (-6, -10), (20, -10), (23, -6), (23, 4), (-10, 4)], P["iron"])
    polygon([(-8, -7), (-5, -9), (20, -9), (22, -6), (-7, -4)], P["iron_light"])
    polygon([(-10, 2), (22, 2), (23, 6), (19, 9), (-7, 9), (-11, 6)], P["iron_low"])
    line([(-6, -9), (7, -9)], P["iron_high"])
    line([(12, -9), (19, -9)], P["iron_high"])
    line([(-6, 9), (19, 9)], INK)

    # Brass barrel hoop follows the same curved cross section as the muzzle.
    polygon([(8, -11), (12, -11), (15, -7), (15, 7), (11, 11), (7, 11), (11, 6), (11, -6)], P["brass_dark"], INK)
    polygon([(9, -10), (11, -10), (14, -6), (14, 4), (12, 7), (11, 6), (12, 3), (12, -5)], P["brass"])
    line([(9, -10), (11, -9), (13, -6), (13, -2)], P["brass_light"])
    line([(9, -10), (11, -9)], P["brass_high"])

    # Breech plate with bolts and a restrained, non-emissive eldritch engraving.
    polygon([(-12, -4), (-6, -7), (3, -6), (5, -3), (5, 5), (-2, 8), (-10, 6)], P["iron_dark"], INK)
    line([(-10, -3), (-6, -5), (2, -5), (3, -3)], P["iron_light"])
    line([(-9, 5), (-2, 6), (3, 4)], P["iron_low"])
    for u, v in [(-8, -3), (2, -3), (-8, 4), (2, 4)]:
        oval(u, v, 1, 1, P["brass"])
        d.point(xy(u, v - 1), P["brass_light"])
    line([(-5, -2), (-2, -2), (0, 0), (-2, 2), (-5, 2), (-6, 0), (-5, -2)], P["rune_dark"])
    line([(-5, 0), (-3, -1), (-1, 0), (-3, 1), (-5, 0)], P["rune"])
    d.point(xy(-3, 0), INK)
    line([(-3, 3), (-4, 4), (-3, 5)], P["rune_dark"])

    # Wide, dark bore is the defining silhouette; no energy core or muzzle fire.
    oval(23, 0, 5.5, 11, P["iron_light"], INK)
    oval(23.8, 0.3, 3.8, 8.2, INK)
    polygon([(22, -8), (24, -7), (25, -3), (25, 4), (23, 7), (21, 7), (23, 4), (23, -4)], "#1d282a")
    line([(20, -8), (22, -10), (24, -10), (26, -7)], P["iron_high"])
    line([(24, 9), (21, 10), (20, 8)], P["iron_dark"])

    # A few isolated chips, never random noise at inventory scale.
    line([(16, -4), (18, -4)], P["iron_high"])
    line([(17, 4), (19, 4)], P["iron_dark"])
    d.point(xy(4, -8), P["brass_dark"])
    return icon


def font(size=16):
    # The project's 16px OTF is a subset; use a full CJK font on review sheets.
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def preview(icon):
    canvas = Image.new("RGB", (1120, 720), "#0c1312")
    d = ImageDraw.Draw(canvas)
    gold, text, muted = "#e7ce90", "#d2d8c9", "#8b9a90"
    d.text((36, 24), "铸铁榴弹炮 / ICON 与属性审阅稿", font=font(24), fill=gold)
    d.text((36, 61), "V1 · 本地原创像素绘制 · 尚未接入战斗", font=font(), fill=muted)
    d.rectangle((36, 103, 434, 501), fill="#17201c", outline="#485447", width=2)
    canvas.paste(icon.resize((384, 384), Image.Resampling.NEAREST), (44, 111), icon.resize((384, 384), Image.Resampling.NEAREST))
    d.text((54, 514), "64 × 64 原图 · 6 倍最近邻放大", font=font(), fill=text)
    for x, size in [(57, 32), (150, 48), (264, 64)]:
        d.rectangle((x - 8, 550, x + size + 8, 631), fill="#243026", outline="#59624a")
        scaled = icon.resize((size, size), Image.Resampling.NEAREST)
        canvas.paste(scaled, (x, 560), scaled)
        d.text((x - 2, 642), str(size) + " px", font=font(), fill=muted)
    d.text((482, 111), "远程 / 重型 / 群体爆炸", font=font(24), fill=gold)
    rows = [
        ("一级基础伤害", "16 + 远程伤害 × 1.2"),
        ("攻击间隔", "1.80 秒"),
        ("攻击距离 / 爆炸半径", "420 / 64"),
        ("飞行时间 / 基础弹数", "0.45 秒 / 1 枚"),
        ("暴击率 / 暴击伤害", "5% / 150%"),
        ("负载 / 附魔槽", "26 / 2"),
        ("最高等级", "5 级：伤害 32 / 半径 80"),
    ]
    for index, (label, value) in enumerate(rows):
        y = 171 + index * 45
        d.text((482, y), label, font=font(), fill=muted)
        d.text((768, y), value, font=font(), fill=text)
        d.line((482, y + 32, 1078, y + 32), fill="#26342d")
    d.text((482, 516), "自动瞄准密集怪群，抛射后在固定落点爆炸。", font=font(), fill=text)
    d.text((482, 548), "越过沿途敌人；每枚榴弹对每个敌人伤害一次。", font=font(), fill=text)
    d.text((482, 580), "范围伤害，无距离衰减；不自带燃烧。", font=font(), fill=text)
    d.text((482, 628), "铸铁灰绿 / 黄铜箍 / 木柄 / 少量蚀纹", font=font(), fill=gold)
    d.text((36, 687), "图标为透明 PNG；本页底色与边框仅用于审阅。详细规则见同目录武器设计文档。", font=font(), fill=muted)
    canvas.save(OUT / "iron_grenade_cannon_review.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ASSET.parent.mkdir(parents=True, exist_ok=True)
    icon = draw_icon()
    assert icon.getbbox() and icon.getbbox()[0] > 0 and icon.getbbox()[2] < 64
    assert icon.getbbox()[1] > 0 and icon.getbbox()[3] < 64
    assert set(icon.getchannel("A").tobytes()) == {0, 255}
    icon.save(ASSET)
    icon.resize((384, 384), Image.Resampling.NEAREST).save(OUT / "icon_6x.png")
    preview(icon)
    report = {"source": "local original pixel drawing; no model/API", "asset": str(ASSET.relative_to(ROOT)), "size": list(icon.size), "mode": icon.mode, "alpha_values": [0, 255], "bounds": list(icon.getbbox()), "opaque_colors": len(icon.getcolors()) - 1, "gameplay_integrated": False}
    (OUT / "asset_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
