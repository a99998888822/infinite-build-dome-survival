"""Hand-authored pixel assets and animation storyboard; no gameplay registration."""
from __future__ import annotations

import json
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/meteor_flail_review"
ASSETS = ROOT / "assets/sprites/weapons/meteor_flail"
ICON = ROOT / "assets/ui/icons/weapons/weapon_meteor_flail.png"
INK = "#111c22"
STEEL = "#61787e"
LIGHT = "#b4c3b8"
GOLD = "#bfa575"
BLUE = "#83c5d3"


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def head():
    im = Image.new("RGBA", (40, 40))
    d = ImageDraw.Draw(im)
    # A cast-iron meteor, eight blunt angular points, a brass equator and
    # one small engraved eye. Discrete shades; no blur or gradient.
    spikes = [[(16, 10), (18, 2), (22, 2), (24, 10)],
              [(27, 11), (33, 6), (35, 9), (32, 16)],
              [(30, 17), (38, 18), (38, 22), (30, 25)],
              [(29, 27), (35, 33), (32, 35), (25, 31)],
              [(23, 30), (22, 38), (18, 38), (16, 30)],
              [(12, 29), (7, 34), (4, 31), (8, 24)],
              [(10, 24), (2, 22), (2, 18), (10, 15)],
              [(12, 12), (6, 7), (9, 4), (16, 9)]]
    for poly in spikes:
        d.polygon(poly, fill="#455962", outline=INK)
        d.line(poly[:2], fill=LIGHT, width=1)
    d.polygon([(12, 8), (24, 7), (31, 12), (34, 23), (28, 31), (16, 34), (8, 28), (6, 17)], fill="#273940", outline=INK)
    d.polygon([(12, 10), (23, 9), (30, 14), (30, 20), (19, 24), (9, 20), (8, 16)], fill=STEEL)
    d.polygon([(12, 11), (22, 10), (27, 13), (20, 15), (10, 17)], fill="#91a4a4")
    d.polygon([(9, 23), (18, 27), (30, 22), (27, 29), (16, 32), (10, 27)], fill="#344a54")
    d.line([(9, 19), (17, 22), (26, 20), (32, 16)], fill=INK, width=4)
    d.line([(9, 18), (17, 21), (26, 19), (31, 16)], fill="#746240", width=3)
    d.line([(10, 18), (17, 20), (25, 18), (30, 15)], fill=GOLD)
    d.line([(20, 10), (18, 13), (21, 16)], fill="#3c7788")
    d.line([(19, 11), (18, 13), (20, 15)], fill=BLUE)
    d.line([(25, 24), (21, 26), (23, 28), (19, 30)], fill="#4f899a")
    d.polygon([(12, 25), (15, 23), (19, 25), (15, 27)], fill="#273c44", outline="#8cb4ad")
    d.line([(15, 24), (15, 26)], fill=INK)
    d.point((11, 12), LIGHT)
    d.point((27, 14), LIGHT)
    return im


def link():
    im = Image.new("RGBA", (9, 7))
    d = ImageDraw.Draw(im)
    d.polygon([(2, 0), (6, 0), (8, 2), (8, 4), (6, 6), (2, 6), (0, 4), (0, 2)], fill=INK)
    d.line([(2, 1), (6, 1), (7, 2)], fill=LIGHT)
    d.line([(1, 2), (1, 4), (3, 5), (6, 5), (7, 4)], fill=STEEL)
    d.rectangle((3, 2, 5, 4), fill=(0, 0, 0, 0))
    return im


def grip():
    im = Image.new("RGBA", (12, 32))
    d = ImageDraw.Draw(im)
    d.polygon([(3, 2), (8, 2), (9, 27), (7, 30), (3, 29), (2, 26)], fill="#273e45", outline=INK)
    for y in [7, 12, 17, 22]:
        d.line([(3, y), (8, y + 2)], fill="#577577", width=2)
    for y in [3, 25]:
        d.rectangle((2, y, 9, y + 3), fill="#756348", outline=INK)
        d.line([(3, y), (7, y)], fill=GOLD)
    return im


def paste_center(canvas, sprite, center, angle=0):
    if angle:
        sprite = sprite.rotate(angle, Image.Resampling.NEAREST, expand=True)
    canvas.alpha_composite(sprite, (round(center[0] - sprite.width / 2), round(center[1] - sprite.height / 2)))


def draw_chain(canvas, start, end, sag=0):
    dx, dy = end[0] - start[0], end[1] - start[1]
    n = max(2, round(math.hypot(dx, dy) / 7))
    for i in range(n):
        t = (i + 0.5) / n
        pos = (start[0] + dx * t, start[1] + dy * t + math.sin(t * math.pi) * sag)
        paste_center(canvas, LINK, pos, -math.degrees(math.atan2(dy, dx)) + (25 if i % 2 else 0))


def icon():
    im = Image.new("RGBA", (64, 64))
    paste_center(im, GRIP.resize((10, 28), Image.Resampling.NEAREST), (15, 21), -28)
    draw_chain(im, (11, 10), (46, 33), -6)
    paste_center(im, HEAD, (43, 43), -12)
    return im


def board(ic):
    im = Image.new("RGB", (1060, 670), "#111c21")
    d = ImageDraw.Draw(im)
    d.text((30, 22), "流星摆锤 · 素材与动作审阅", font=font(26), fill="#dce5d4")
    d.text((30, 64), "铸铁陨星 / 短链 / 旧铜箍 / 少量浅蓝刻纹", font=font(16), fill="#95abad")
    d.rectangle((30, 112, 441, 523), fill="#25353b", outline="#657b7d", width=2)
    big = ic.resize((384, 384), Image.Resampling.NEAREST)
    im.paste(big, (44, 125), big)
    for x, s in [(48, 32), (144, 48), (266, 64)]:
        small = ic.resize((s, s), Image.Resampling.NEAREST)
        im.paste(small, (x, 557), small)
        d.text((x, 633), f"{s}px", font=font(13), fill="#96abaa")
    d.text((484, 123), "靠距离与节奏，打出外侧重击", font=font(24), fill="#b7d4d5")
    rows = [("挥击方式", "左扫、右扫交替"), ("攻击朝向", "起手时锁定最近敌人方向"),
            ("武器显示", "只在攻击时出现，待机隐藏"), ("伤害位置", "锤头触碰；链条仅作连接"),
            ("距离变化", "短距离起手 → 伸展重击 → 收回"), ("命中反馈", "白蓝方形碎屑，短促残影")]
    for i, (k, v) in enumerate(rows):
        y = 191 + i * 48
        d.text((484, y), k, font=font(16), fill="#94a8a7")
        d.text((609, y), v, font=font(16), fill="#d5dfd1")
        d.line((484, y + 34, 1028, y + 34), fill="#35474b")
    d.text((484, 513), "原始透明素材", font=font(16), fill=GOLD)
    for sprite, p in [(HEAD, (512, 580)), (LINK, (655, 577)), (GRIP, (753, 575))]:
        s = sprite.resize((sprite.width * 2, sprite.height * 2), Image.Resampling.NEAREST)
        im.paste(s, (p[0] - s.width // 2, p[1] - s.height // 2), s)
    d.text((831, 560), "动作概念稿\n尚未接入正式战斗", font=font(16), fill="#92a6a6", spacing=8)
    im.save(OUT / "meteor_flail_review.png")


def animation():
    rng = random.Random(250925)
    ground = Image.new("RGBA", (350, 230), "#26322f")
    d = ImageDraw.Draw(ground)
    for _ in range(530):
        x, y = rng.randrange(350), rng.randrange(230)
        d.rectangle((x, y, x + rng.randrange(1, 4), y + 1), fill=rng.choice(["#2e3935", "#303e36", "#202d2a"]))
    player = Image.open(ROOT / "assets/sprites/player/combat/void_hunter_idle_right.png").convert("RGBA")
    enemy = Image.open(ROOT / "assets/sprites/enemies/combat/enemy_gloom_mite_idle.png").convert("RGBA")
    player = player.crop(player.getbbox()).resize((27, 40), Image.Resampling.NEAREST)
    enemy = enemy.crop(enemy.getbbox()).resize((37, 33), Image.Resampling.NEAREST)
    pivot = (101, 113)
    targets = [(171, 76), (242, 105), (190, 172)]
    frames = []
    head_positions = []
    for index in range(144):
        time = index / 24
        cycle = int(time / 1.5)
        phase = (time % 1.5)
        sign = 1 if cycle % 2 == 0 else -1
        u = max(0, min(1, (phase - 0.18) / 0.55))
        visible = 0.08 <= phase < 0.88
        swing = -70 + 140 * (u * u * (3 - 2 * u))
        radius = 65 + 79 * math.sin(u * math.pi)
        theta = math.radians(swing * sign)
        point = (pivot[0] + radius * math.cos(theta), pivot[1] + radius * math.sin(theta) * 0.77)
        if phase < 0.18:
            radius = 65
            point = (pivot[0] + radius * math.cos(theta), pivot[1] + radius * math.sin(theta) * .77)
        scene = ground.copy()
        sd = ImageDraw.Draw(scene)
        for target in targets:
            sd.ellipse((target[0]-17,target[1]+10,target[0]+17,target[1]+17), fill="#18251e")
            paste_center(scene, enemy, (target[0], target[1]-4))
        sd.ellipse((75,130,102,137), fill="#17251e")
        paste_center(scene, player, (87,113))
        if visible:
            # Only short square debris follows the head, never an opaque sector.
            if 0.23 < phase < .68:
                for age in [1, 2, 3]:
                    if len(head_positions) >= age:
                        hx, hy = head_positions[-age]
                        sd.rectangle((hx-1,hy-1,hx+1,hy+1), fill=["#8daeb8", "#627e8a", "#425b66"][age-1])
            draw_chain(scene, pivot, point, 4 * (1-math.sin(u*math.pi)))
            paste_center(scene, GRIP.resize((7,19),Image.Resampling.NEAREST), (103,112), 40*sign)
            hammer = HEAD.resize((33,33),Image.Resampling.NEAREST)
            paste_center(scene, hammer, point, -swing*sign)
            for target in targets:
                distance = math.hypot(point[0]-target[0],point[1]-target[1])
                if distance < 30 and .18 < phase < .73:
                    sd = ImageDraw.Draw(scene)
                    outer = radius >= 125
                    for p in range(8 if outer else 4):
                        a = p * math.tau / 8 + time
                        r = 13 + (index*3+p*5)%13
                        x, y = target[0]+math.cos(a)*r, target[1]+math.sin(a)*r*.7
                        sd.rectangle((x,y,x+2,y+2),fill="#dce9d9" if p%2 else BLUE)
        head_positions.append(point)
        output = Image.new("RGB", (700, 570), "#111c21")
        output.paste(scene.resize((700,460),Image.Resampling.NEAREST),(0,66))
        od = ImageDraw.Draw(output)
        od.text((18, 8), "流星摆锤 · 左右交替挥击", font=font(23), fill="#d3e2d3")
        od.text((18, 40), "动作概念预览 · 待机隐藏 · 链条无伤害 · 外侧锤头重击",font=font(14),fill="#8ea9ae")
        stage = "等待下一次挥击 · 武器隐藏" if not visible else ("收回" if phase>.73 else ("起手锁定方向" if phase<.18 else "外侧重击" if radius>=125 else "近侧挥击"))
        od.text((18, 536), stage, font=font(17), fill=GOLD if radius>=125 and visible else "#b5cbc8")
        frames.append(output)
    palette = frames[0].quantize(colors=192).getpalette()
    pal = Image.new("P", (1,1)); pal.putpalette(palette)
    converted = [im.quantize(palette=pal,dither=Image.Dither.NONE) for im in frames]
    converted[0].save(OUT / "meteor_flail_swing.gif",save_all=True,append_images=converted[1:],duration=[40,40,40,40,40,50]*24,loop=0,optimize=False)
    for index in [0,11,15,21,47]:
        frames[index].save(OUT / f"swing_{index:03d}.png")


HEAD, LINK, GRIP = head(), link(), grip()
if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").write_text("",encoding="utf-8")
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name, sprite in [("head",HEAD),("chain_link",LINK),("grip",GRIP)]:
        sprite.save(ASSETS / f"meteor_flail_{name}.png")
    ic = icon()
    ic.save(ICON)
    ic.resize((384,384),Image.Resampling.NEAREST).save(OUT / "icon_6x.png")
    board(ic)
    animation()
    report = {"source":"hand-authored pixel geometry", "status":"art and storyboard only; no gameplay registration",
              "icon_size":list(ic.size),"alpha":sorted(set(ic.getchannel('A').tobytes())),"bounds":list(ic.getbbox())}
    assert report["alpha"] == [0,255]
    assert ic.getbbox()[0] > 0 and ic.getbbox()[2] < 64 and ic.getbbox()[3] < 64
    (OUT / "asset_validation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report))
