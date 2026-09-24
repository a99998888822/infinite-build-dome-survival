"""Original pixel assets, following the project's hand-authored icon workflow."""
from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/tome_purse_review"
ICONS = ROOT / "assets/ui/icons/weapons"
WORLD = ROOT / "assets/sprites/weapons"
INK = "#10191e"


def book(frame=0):
    im = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(im)
    # Lower board, heavy paper block and offset page edges.
    d.polygon([(12,19),(33,10),(55,20),(53,48),(31,60),(10,47)], fill=INK)
    d.polygon([(13,22),(33,13),(53,22),(51,46),(31,57),(12,45)], fill="#37464d")
    d.polygon([(15,22),(33,14),(51,23),(49,44),(31,54),(14,43)], fill="#a3a798")
    d.polygon([(31,28),(51,22),(49,44),(31,54)], fill="#717f7a")
    for y in [30,34,38,42]:
        d.line([(15,y),(31,y+10),(49,y)], fill="#c0c0a8")
        d.line([(16,y+1),(31,y+11),(48,y+1)], fill="#526769")
    d.line([(32,49),(48,40)], fill="#d9d6b7")
    # Slightly raised dark cover; the open wedge is visible along its right edge.
    lift = [0,1,3,1][frame]
    d.polygon([(8,15-lift),(29,5-lift),(51,16),(48,39),(28,52),(7,39-lift)], fill=INK)
    d.polygon([(10,16-lift),(29,7-lift),(48,17),(45,37),(28,48),(10,37-lift)], fill="#263740")
    d.polygon([(12,17-lift),(28,9-lift),(44,17),(41,34),(28,43),(12,34-lift)], fill="#354b53")
    d.polygon([(13,19-lift),(28,11-lift),(41,18),(38,33),(28,40),(13,33-lift)], fill="#273c44")
    d.line([(10,16-lift),(10,36-lift),(27,47)], fill="#52666b")
    d.line([(11,17-lift),(27,9-lift)], fill="#71878a")
    # Cartographic eye: broken orbital grid rather than a brightly glowing gem.
    d.line([(19,20),(29,15),(37,21),(34,31),(25,36),(18,30),(19,20)], fill="#62858c")
    d.line([(18,26),(36,22)], fill="#456e79")
    d.line([(21,32),(34,28)], fill="#456e79")
    d.line([(25,17),(23,27),(26,35)], fill="#456e79")
    d.line([(31,17),(32,24),(29,34)], fill="#7a9997")
    d.polygon([(20,27),(26,21),(34,25),(28,30)], fill="#a1b3a8")
    d.polygon([(23,26),(27,23),(31,25),(27,28)], fill="#577f88")
    d.line([(27,23),(27,28)], fill=INK, width=2)
    for x,y in [(20,20),(34,22),(24,35)]: d.point((x,y), fill="#c7c9ae")
    # Tarnished silver corners and spine bands.
    for poly in [[(10,16-lift),(18,12-lift),(16,18-lift),(11,22-lift)],
                 [(39,13),(48,17),(47,24),(43,20)],
                 [(10,31-lift),(10,37-lift),(17,42-lift),(15,36-lift)],
                 [(38,39),(45,34),(44,39),(28,49),(28,45)]]:
        d.polygon(poly, fill="#657a7c")
        d.line(poly[:2], fill="#b4bfb1")
    for y in [22,30,37]:
        d.line([(8,y),(13,y+3)], fill="#8c956e", width=2)
        d.point((9,y), fill="#ccbd8a")
    # Open sheet lifts away briefly as the spell ticks.
    d.polygon([(47,20),(52,22),(49,38),(46,41)], fill="#d0cdb0")
    d.line([(48,24),(49,25),(47,34)], fill="#83918b")
    if frame in [1,2]:
        d.polygon([(43,18),(49,14-frame*2),(52,20),(48,35),(45,38)], fill="#d7d2b3")
        d.line([(47,19),(49,21),(47,31)], fill="#8a9c97")
    # Muted blue bookmark, no halo.
    d.polygon([(35,47),(39,45),(39,58),(36,56),(34,60)], fill=INK)
    d.line([(37,48),(37,55)], fill="#668d99", width=2)
    return im


def purse(frame=0):
    im = Image.new("RGBA", (64,64))
    d = ImageDraw.Draw(im)
    # Ragged opening and visible stacks of old square-hole coins.
    d.polygon([(20,7),(26,9),(29,6),(35,8),(41,7),(45,14),(39,21),(22,20),(17,13)], fill=INK)
    d.polygon([(20,10),(27,12),(33,9),(41,10),(42,14),(37,17),(23,17)], fill="#573b2c")
    for x,y in [(24,8),(32,7),(38,10)]:
        d.polygon([(x-3,y),(x-1,y-2),(x+3,y-1),(x+4,y+3),(x+1,y+5),(x-3,y+3)], fill="#c29c4d", outline="#493822")
        d.line([(x-2,y),(x+1,y-1),(x+2,y)], fill="#ebd88e")
        d.rectangle((x,y+1,x+1,y+2),fill="#665037")
    # Rounded leather body made of hard pixel contours and broad shade clusters.
    bulge = [0,1,2,0][frame]
    d.polygon([(22,18),(39,18),(41,24),(48+bulge,31),(53,43),(51,52),(44,58),(20,59),(11,54),(9,44),(13-bulge,32),(20,24)],fill=INK)
    d.polygon([(23,20),(37,20),(39,26),(46,32),(50,44),(48,51),(42,55),(21,56),(14,51),(12,44),(16,33),(22,27)],fill="#765038")
    d.polygon([(24,23),(28,26),(24,34),(21,48),(25,55),(17,52),(14,45),(18,34)],fill="#ab7950")
    d.polygon([(30,24),(35,24),(40,32),(44,47),(41,53),(29,55),(25,49),(26,36)],fill="#94633e")
    d.polygon([(39,29),(46,35),(49,44),(47,51),(42,55),(33,56),(39,50),(41,44)],fill="#4d3428")
    d.line([(19,34),(16,44),(18,49)],fill="#d09a60")
    d.line([(23,28),(20,40),(23,46)],fill="#543b2d")
    d.line([(34,25),(35,34),(38,41)],fill="#60422e")
    d.line([(26,51),(31,53),(36,52)],fill="#b38350")
    # Stitched hem and creases.
    for x,y in [(18,52),(22,54),(27,55),(32,55),(37,54),(43,51),(46,46),(45,40)]:
        d.line([(x,y),(x+1,y-1)], fill="#be9262")
    for x,y in [(21,39),(29,31),(32,46),(40,38),(28,47)]:
        d.line([(x,y),(x+2,y+1)],fill="#b08050")
    # Tightened cord, knot, and brass clasp.
    d.polygon([(19,18),(40,17),(41,22),(20,23)],fill="#332b22",outline=INK)
    d.line([(21,19),(39,18)],fill="#d4b575")
    d.line([(21,21),(39,20)],fill="#9b7a46")
    d.rectangle((28,18,34,23),fill="#a98849",outline="#372f24")
    d.rectangle((30,19,32,21),fill="#e2c77c")
    d.line([(20,21),(14,24),(12,29),(17,31),(19,25),(19,36)],fill=INK,width=3)
    d.line([(20,21),(14,24),(13,28),(17,29),(18,25),(18,35)],fill="#b18a55")
    d.line([(39,20),(46,23),(48,29),(43,27),(42,24),(45,37)],fill=INK,width=3)
    d.line([(39,20),(45,23),(46,27),(43,26),(44,35)],fill="#b18a55")
    # Small lender's seal: a stamped coin, distinct from the tome's eye.
    d.polygon([(31,32),(38,34),(39,42),(33,46),(27,41),(27,35)],fill="#432f22",outline=INK)
    d.polygon([(31,33),(37,35),(37,41),(33,44),(29,40),(29,36)],fill="#b18a45")
    d.line([(30,35),(33,34),(36,36)],fill="#ebce81")
    d.rectangle((32,37,34,40),fill="#513924")
    return im


def coin(frame):
    im = Image.new("RGBA", (16,16))
    d = ImageDraw.Draw(im)
    half = [5,4,2,1,2,4,5,4][frame]
    d.polygon([(8-half,4),(7-half,6),(7-half,10),(8-half,12),(8+half,12),(9+half,10),(9+half,6),(8+half,4)],fill="#58412a",outline=INK)
    d.polygon([(8-half,5),(8+half,5),(8+half,11),(8-half,11),(7-half,9),(7-half,7)],fill="#c39343")
    d.line([(8-half,5),(8+half-1,5)],fill="#f4dfa0")
    d.line([(7-half,7),(7-half,9)],fill="#ecd082")
    if half>=3:
        d.rectangle((7,7,9,9),fill="#806036")
        d.rectangle((8,7,9,8),fill="#3c3526")
        d.point((10,10),fill="#e4b759")
    else: d.line([(8,5),(8,10)],fill="#eac976")
    return im


def rune():
    # Draw one mask then apply alpha once: intersections never exceed 20% opacity.
    mask=Image.new("L",(384,240))
    d=ImageDraw.Draw(mask)
    def point(a,r=1): return (round(192+math.cos(a)*174*r),round(120+math.sin(a)*108*r))
    for radius in [1,.88,.58]:
        points=[point(i*math.tau/120,radius) for i in range(121)]
        d.line(points,fill=255,width=2 if radius != .88 else 1)
    # Meridian lattice, broken astrolabe spokes and interlaced star diagram.
    for a in [0.28,1.0,1.9,2.7]:
        d.line([point(a,.87),point(a+math.pi,.87)],fill=255,width=1)
    star=[point(i*math.tau/7+.2,.77) for i in range(7)]
    d.line([star[(i*3)%7] for i in range(8)],fill=255,width=2)
    for index in range(28):
        a=index*math.tau/28
        center=point(a,.945)
        x,y=center
        d.line([(x-3,y-3),(x,y+3),(x+3,y-3)],fill=255)
        if index%2: d.line([(x-3,y),(x+3,y)],fill=255)
        else: d.rectangle((x-1,y-2,x+1,y),outline=255)
    for a in [.4,1.45,2.3,3.8,5.1]:
        x,y=point(a,.59)
        d.rectangle((x-2,y-2,x+2,y+2),outline=255)
        d.line([(x-5,y),(x+5,y)],fill=255)
    d.line([(155,120),(177,107),(207,108),(229,120),(207,132),(177,133),(155,120)],fill=255)
    d.line([(192,108),(192,132)],fill=255,width=2)
    im=Image.new("RGBA",mask.size,(172,220,245,0))
    im.putalpha(mask.point(lambda value: 51 if value else 0))
    return im


def font(size): return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",size)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    ICONS.mkdir(parents=True,exist_ok=True)
    WORLD.mkdir(parents=True,exist_ok=True)
    (OUT/".gdignore").touch()
    assets={}
    for name,draw in [("weapon_kunyu_ritual_tome",book),("weapon_rentier_purse",purse)]:
        im=draw()
        im.save(ICONS/f"{name}.png")
        im.save(WORLD/f"{name}.png")
        im.resize((384,384),Image.Resampling.NEAREST).save(OUT/f"{name}_6x.png")
        sheet=Image.new("RGBA",(256,64))
        for frame in range(4): sheet.paste(draw(frame),(frame*64,0))
        sheet.save(WORLD/f"{name}_animated.png")
        assert set(im.getchannel('A').tobytes())=={0,255}
        assert all(v>0 for v in im.getbbox()[:2]) and max(im.getbbox()[2:])<64
        assets[name]={"icon_size":list(im.size),"alpha":[0,255],"bounds":list(im.getbbox()),"animation_frames":4}
    coins=Image.new("RGBA",(128,16))
    for frame in range(8): coins.paste(coin(frame),(frame*16,0))
    coins.save(WORLD/"rentier_coin_spin.png")
    glyph=rune()
    glyph.save(WORLD/"kunyu_domain_rune.png")
    assert max(glyph.getchannel('A').getextrema())==51
    board=Image.new("RGB",(1080,714),"#10191e")
    d=ImageDraw.Draw(board)
    d.text((30,20),"坤舆秘仪书 / 食利者钱袋",font=font(27),fill="#d4dfd3")
    d.text((30,62),"V2 · 原创像素素材 · 64 × 64 透明图标",font=font(16),fill="#869c9f")
    entries=[("weapon_kunyu_ritual_tome","坤舆秘仪书","厚重藏蓝封皮 / 旧银包角 / 微启书页","常驻虚线领域 · 外沿方粒 · 呼吸符文", "#98c8d1"),
             ("weapon_rentier_purse","食利者钱袋","深棕皮革 / 黄铜束口 / 外露古金币","每轮三枚金币 · 战斗中隐藏钱袋本体", "#d9b36b")]
    for index,(name,title,detail,behavior,color) in enumerate(entries):
        x=30+index*530
        d.rectangle((x,106,x+490,531),fill="#1c2a30",outline="#3f565c",width=2)
        im=Image.open(ICONS/f"{name}.png").resize((384,384),Image.Resampling.NEAREST)
        board.paste(im,(x+54,124),im)
        d.text((x+14,546),title,font=font(25),fill=color)
        d.text((x+14,588),detail,font=font(17),fill="#b9cac5")
        d.text((x+14,618),behavior,font=font(17),fill="#8da4a5")
        for n,size in enumerate([24,32,48]):
            small=Image.open(ICONS/f"{name}.png").resize((size,size),Image.Resampling.NEAREST)
            board.paste(small,(x+16+n*65,656),small)
    board.save(OUT/"icons_review_v2.png")
    (OUT/"asset_validation.json").write_text(json.dumps({"source":"original local pixel geometry; no API", "gameplay_integrated":False,"assets":assets,"rune_alpha_max":51,"coin_frames":8},indent=2)+"\n",encoding="utf-8")
    print("TOME_PURSE_ASSETS_COMPLETE")


if __name__=="__main__": main()
