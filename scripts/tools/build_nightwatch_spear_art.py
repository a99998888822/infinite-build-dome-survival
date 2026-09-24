"""Hand-authored pixel geometry for the nightwatch spear review (no API)."""
from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/nightwatch_spear_review"
ICON = ROOT / "assets/ui/icons/weapons/weapon_nightwatch_spear.png"
WORLD = ROOT / "assets/sprites/weapons/weapon_nightwatch_spear.png"
P = {"ink": "#10191d", "wood": "#3d4546", "wood_hi": "#7a8176",
     "steel_lo": "#304a55", "steel": "#637f86", "silver": "#a9bfba", "edge": "#e1e8d3",
     "brass_lo": "#554834", "brass": "#9c8652", "brass_hi": "#c8b677",
     "cloth": "#243e43", "cloth_hi": "#47716b", "rune": "#729587"}


def draw_spear(canvas, transform):
    d = ImageDraw.Draw(canvas)
    def poly(points, color, outline=None):
        d.polygon([transform(u, v) for u, v in points], fill=color, outline=outline)
    def line(points, color, width=1):
        d.line([transform(u, v) for u, v in points], fill=color, width=width)

    # Ash-black pole and steel butt spike.
    poly([(-37,-2),(19,-2),(19,2),(-37,2)], P["ink"])
    line([(-35,-1),(18,-1)], P["wood_hi"])
    line([(-35,0),(18,0)], P["wood"])
    line([(-35,1),(18,1)], "#242e32")
    poly([(-40,0),(-36,-3),(-32,-2),(-32,2),(-36,3)], P["steel_lo"], P["ink"])
    line([(-38,0),(-35,-2),(-33,-1)], P["silver"])
    # Worn blue-green cloth grip.
    poly([(-28,-3),(-10,-3),(-9,3),(-28,3)], P["cloth"], P["ink"])
    for u in range(-26,-9,4):
        line([(u,-2),(u+2,2)], P["cloth_hi"])
    for u in [-29,-10,9]:
        poly([(u,-3),(u+2,-3),(u+2,3),(u,3)], P["brass_lo"], P["ink"])
        line([(u,-2),(u+1,-2)], P["brass_hi"])
        line([(u+1,-1),(u+1,2)], P["brass"])
    # Short ceremonial binding; silhouette remains a spear, not a flag.
    poly([(12,2),(11,6),(4,9),(6,5),(2,6),(7,2)], P["cloth"], P["ink"])
    line([(12,3),(9,6),(5,8)], P["cloth_hi"])
    # Small backward-facing wings and a long leaf-shaped blade.
    poly([(15,-2),(12,-7),(16,-5),(20,-2),(20,2),(16,5),(12,7),(15,2)], P["steel_lo"], P["ink"])
    line([(13,-6),(16,-4),(19,-2)], P["silver"])
    poly([(16,0),(21,-6),(28,-5),(39,0),(28,5),(21,6)], P["steel"], P["ink"])
    poly([(18,0),(22,-4),(28,-4),(37,0),(24,0)], P["silver"])
    poly([(19,1),(27,1),(36,0),(28,4),(22,4)], P["steel_lo"])
    line([(21,-5),(28,-4),(37,-1),(39,0)], P["edge"])
    line([(19,0),(37,0)], P["edge"])
    line([(23,4),(28,4),(34,2)], P["steel"])
    # Restrained eldritch eye engraved in the collar, no glow halo.
    poly([(18,-1),(20,-3),(23,-1),(20,1)], P["brass_lo"])
    line([(19,-1),(20,-2),(22,-1),(20,0),(19,-1)], P["rune"])
    d.point(transform(20,-1), fill=P["ink"])


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ICON.parent.mkdir(parents=True, exist_ok=True)
    WORLD.parent.mkdir(parents=True, exist_ok=True)
    icon = Image.new("RGBA", (64,64))
    angle=math.radians(-45)
    draw_spear(icon, lambda u,v: (round(32+u*math.cos(angle)-v*math.sin(angle)), round(32+u*math.sin(angle)+v*math.cos(angle))))
    world=Image.new("RGBA", (248,28))
    draw_spear(world, lambda u,v: (round(4+(u+40)*3.0), round(13+v)))
    icon.save(ICON)
    world.save(WORLD)
    icon.resize((384,384), Image.Resampling.NEAREST).save(OUT/"icon_6x.png")
    board=Image.new("RGB", (1080,680), "#0d171b")
    d=ImageDraw.Draw(board)
    d.text((32,22), "守夜长枪 / 图标与动作审阅", font=font(25), fill="#d6e2cb")
    d.text((32,62), "V1 · 原创本地像素绘制 · 近战直线贯穿", font=font(16), fill="#829a98")
    d.rectangle((32,108,431,507), fill="#1b2a2d", outline="#526260", width=2)
    big=icon.resize((384,384), Image.Resampling.NEAREST)
    board.paste(big,(40,116),big)
    d.text((48,524), "64 × 64 透明 PNG · 6 倍放大", font=font(16), fill="#b9c9bd")
    for x,size in [(55,32),(153,48),(281,64)]:
        small=icon.resize((size,size),Image.Resampling.NEAREST)
        d.rectangle((x-7,565,x+size+7,640),fill="#263637")
        board.paste(small,(x,574),small)
        d.text((x,646),f"{size}px",font=font(12),fill="#829a98")
    d.text((478,115), "保持距离，把怪物引成一条线", font=font(23), fill="#c7d6b4")
    rows=[("一级伤害提案","14 + 近战伤害 × 1.0"),("攻击间隔","1.10 秒"),("前方长度 / 全宽","220 / 28"),("前摇 / 刺出 / 收枪","0.10 / 0.12 / 0.16 秒"),("暴击率 / 暴击伤害","5% / 150%"),("负载 / 附魔槽提案","18 / 2")]
    for i,(label,value) in enumerate(rows):
        y=178+i*45
        d.text((478,y),label,font=font(16),fill="#829a98")
        d.text((750,y),value,font=font(16),fill="#d9e0cd")
        d.line((478,y+32,1030,y+32),fill="#304044")
    for i,text in enumerate(["自动瞄准最近敌人，前摇开始时锁定方向。","刺击沿直线穿过怪群，每次每目标只伤害一次。","枪尖冷银，长柄深色；无圆形爆炸、无发光大圈。","本次提供动作原型，尚未加入商店和奖励池。"]):
        d.text((478,472+i*37),text,font=font(16),fill="#bdcec3")
    board.save(OUT/"nightwatch_spear_review.png")
    report={"source":"local authored pixel art; no model/API", "icon":str(ICON.relative_to(ROOT)),"world":str(WORLD.relative_to(ROOT)),"icon_size":list(icon.size),"alpha":sorted(set(icon.getchannel('A').tobytes())),"bounds":list(icon.getbbox()),"status":"review prototype"}
    assert report["alpha"]==[0,255]
    assert icon.getbbox()[0]>0 and icon.getbbox()[2]<64
    (OUT/"asset_validation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
