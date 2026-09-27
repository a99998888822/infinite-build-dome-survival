"""Original pixel art and approval-only animation; no production game mutations."""
from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/previews/iron_knight"
SIZE = 160
ANCHOR = (80, 122)
P = {
    "ink": "#090f19", "joint": "#131d2a", "deep": "#1b2a39",
    "shadow": "#25384b", "low": "#354d62", "steel": "#526d80",
    "light": "#7f99a8", "shine": "#b9c9ce", "glint": "#e0e6dc",
    "blue": "#123440", "blue_dark": "#0e2430", "blue_light": "#1b4b56",
    "brass_dark": "#4b4c37", "brass": "#8a8b5c", "brass_light": "#b8b681",
    "rune_dark": "#1c515f", "rune": "#327889", "rune_light": "#71b4b6",
    "leather": "#17262d", "leather_light": "#516367",
}
SPECS = {
    "idle": ([230] * 4, True),
    "move": ([120, 100, 100, 100, 120, 100, 100, 100], True),
    "windup": ([160, 180, 200, 260], False),
    "dash": ([20, 20, 40, 40, 20, 20], False),
    "recover": ([100, 100, 140, 160], False),
    "death": ([100, 100, 140, 180, 220, 380], False),
}
LABELS = {"idle": "待机", "move": "重甲行走", "windup": "举盾蓄力",
          "dash": "冲刺挥锤", "recover": "刹停收招", "death": "倒地"}
DASH_SECONDS = sum(SPECS["dash"][0]) / 1000
DASH_DISTANCE = 240
PREVIEW_FPS = 50
PREVIEW_SECONDS = 1.6 + .8 + DASH_SECONDS + .5 + 1.1


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def lerp(a, b, t):
    return a + (b - a) * t


def pose(action, i):
    p = dict(bob=0, lean=0, stride=0, lift=0, hand=(38, 80), tip=(35, 100),
             shield_dx=0, shield_dy=0, shield_angle=0, collapse=0, dim=False,
             body_shift=(0, 0), gait=None)
    if action == "idle":
        p.update(bob=[0, -1, 0, 1][i], hand=(38, 80 + [0, 0, 1, 0][i]))
    elif action == "move":
        swing = [-2, -1, 1, 2, 2, 1, -1, -2][i]
        p.update(body_shift=([-1,-1,0,1,1,1,0,-1][i], [0,2,-1,-3,0,2,-1,-3][i]),
                 gait=i, shield_dx=2, shield_dy=-2,
                 hand=(38+swing,80), tip=(35+swing,100))
    elif action == "windup":
        p.update(bob=i, lean=2 + i, shield_dx=i, shield_dy=-i,
                 hand=[(38, 70), (36, 50), (45, 36), (56, 27)][i],
                 tip=[(30, 48), (23, 26), (29, 12), (55, 3)][i], stride=-3)
    elif action == "dash":
        p.update(bob=[3, 2, 1, 2, 3, 4][i], lean=7, shield_dx=6, shield_dy=-2,
                 stride=[-10, -5, 5, 11, 7, 2][i], lift=4,
                 hand=[(58, 28), (78, 35), (93, 48), (98, 65), (92, 80), (83, 91)][i],
                 tip=[(65, 5), (96, 12), (112, 31), (123, 61), (114, 92), (102, 112)][i])
    elif action == "recover":
        p.update(bob=[5, 3, 1, 0][i], lean=[5, 2, 0, 0][i], shield_dx=[4, 2, 0, 0][i],
                 hand=[(80, 92), (66, 88), (44, 82), (38, 80)][i],
                 tip=[(100, 112), (79, 112), (39, 103), (35, 100)][i], stride=[9, 6, 2, 0][i])
    elif action == "death":
        t = (i + 1) / 6
        p.update(collapse=t * .58, lean=-t * 14, stride=-round(t * 8),
                 shield_angle=t * 1.20, shield_dx=-t * 30, shield_dy=t * 2,
                 hand=(lerp(38, 28, t), lerp(80, 105, t)),
                 tip=(lerp(35, 7, t), lerp(100, 118, t)), dim=i > 2)
    return p


def leg_joints(p):
    if p["gait"] is None:
        s=p["stride"]
        return (((53,78),(47+s*.45,96),(41+s,114-(p["lift"] if s>0 else 0))),
                ((69,78),(75-s*.45,96),(81-s,114-(p["lift"] if s<0 else 0))))
    # Alternate contact, weight transfer, knee lift, and reaching for the next step.
    # Each planted ankle stays on the floor; the pelvis moves over it.
    i=p["gait"]
    dx,dy=p["body_shift"]
    far_ankles=[(67,114),(59,114),(51,114),(43,114),(37,114),(40,110),(56,103),(66,107)]
    near_ankles=[(51,114),(47,110),(63,103),(83,107),(89,114),(81,114),(73,114),(65,114)]
    joints=[]
    for hip,ankle in [((53+dx,78+dy),far_ankles[i]),((69+dx,78+dy),near_ankles[i])]:
        vx,vy=ankle[0]-hip[0],ankle[1]-hip[1]
        distance=math.hypot(vx,vy)
        upper=lower=21.0
        assert distance<=upper+lower,(i,hip,ankle)
        direction=math.atan2(vx,vy)
        bend=math.acos(max(-1,min(1,(upper**2+distance**2-lower**2)/(2*upper*distance))))
        knee=(hip[0]+upper*math.sin(direction+bend),hip[1]+upper*math.cos(direction+bend))
        joints.append((hip,knee,ankle))
    return tuple(joints)


class Painter:
    def __init__(self, p):
        self.p = p
        self.image = Image.new("RGBA", (SIZE, SIZE))
        self.d = ImageDraw.Draw(self.image)
        self.limb_space = False

    def pt(self, xy, shield=False):
        x, y = xy
        p = self.p
        if shield:
            a = p["shield_angle"]
            x, y = (94 + (x - 94) * math.cos(a) - (y - 107) * math.sin(a),
                    107 + (x - 94) * math.sin(a) + (y - 107) * math.cos(a))
            x += p["shield_dx"]
            y += p["shield_dy"]
        else:
            x += p["lean"] * max(0, 112 - y) / 80
            y += max(0, 112 - y) * p["collapse"]
            y += p["bob"] * max(0, 112 - y) / 80
        if not self.limb_space:
            x+=p["body_shift"][0]
            y+=p["body_shift"][1]
        return round(x + 16), round(y + 10)

    def poly(self, pts, color, outline=None, shield=False):
        self.d.polygon([self.pt(p, shield) for p in pts], fill=P[color], outline=P[outline] if outline else None)

    def line(self, pts, color, width=1, shield=False):
        self.d.line([self.pt(p, shield) for p in pts], fill=P[color], width=width)

    def dot(self, x, y, color, size=1, shield=False):
        x, y = self.pt((x, y), shield)
        self.d.rectangle((x, y, x + size - 1, y + size - 1), fill=P[color])

    def leg(self, hip, knee, foot, far=False):
        hx, hy = hip
        kx, ky = knee
        fx, fy = foot
        self.line([hip, knee, foot], "ink", 13)
        self.line([hip, knee, foot], "shadow", 9)
        self.poly([(hx-5,hy-3),(hx+5,hy-2),(kx+5,ky-5),(kx-5,ky-3)], "deep", "ink")
        self.line([(hx-3,hy),(kx-3,ky-5)],"low" if far else "steel",2)
        self.poly([(kx,ky-7),(kx+6,ky-1),(kx+3,ky+5),(kx-1,ky+7),(kx-6,ky+1)],"shadow","ink")
        self.poly([(kx,ky-5),(kx+1,ky),(kx-1,ky+4),(kx-4,ky)],"low" if far else "steel")
        self.line([(kx-4,ky-1),(kx,ky-5),(kx+4,ky-1)],"steel" if far else "shine",1)
        self.poly([(kx-4,ky+6),(kx+4,ky+5),(fx+4,fy-4),(fx,fy),(fx-5,fy-4)],"deep","ink")
        self.line([(kx-3,ky+7),(fx-3,fy-5),(fx,fy-2)],"low" if far else "light",1)
        self.line([(kx+1,ky+8),(fx+1,fy-8),(fx-1,fy-6)],"rune_dark" if far else "rune",1)
        self.poly([(fx-5,fy-4),(fx+3,fy-5),(fx+8,fy),(fx+7,fy+3),(fx-5,fy+3)],"shadow","ink")
        self.line([(fx-3,fy-3),(fx+2,fy-4),(fx+6,fy)],"steel" if far else "light",1)
        for y in [fy,fy+2]: self.line([(fx-4,y),(fx+5,y-1)],"joint",1)


def thigh_plates(r, hip, knee, far):
    # Plates follow the upper leg instead of remaining a rigid skirt over the knee.
    hx,hy=hip
    dx,dy=knee[0]-hx,knee[1]-hy
    length=math.hypot(dx,dy)
    ux,uy=dx/length,dy/length
    vx,vy=uy,-ux
    def at(side,along): return (hx+vx*side+ux*along,hy+vy*side+uy*along)
    for i in range(3):
        a=i*4
        r.poly([at(-6,a),at(6,a),at(7,a+4),at(0,a+7),at(-7,a+5)],"shadow" if far else "deep","ink")
        r.line([at(-5,a+1),at(4,a+1),at(5,a+3)],"steel" if far else "low",1)
        r.dot(*at(-3,a+3),"rune")


def hammer(r, hand, tip):
    # A single gauntlet grips a short haft. Head is always drawn from the same rig.
    hx, hy = hand
    tx, ty = tip
    dx, dy = tx-hx, ty-hy
    length = math.hypot(dx, dy)
    ux, uy = dx/length, dy/length
    vx, vy = -uy, ux
    butt = hx-ux*7, hy-uy*7
    r.line([butt, tip], "ink", 7)
    r.line([butt, tip], "leather", 5)
    r.line([(butt[0]-1,butt[1]-1), (tx-1,ty-1)], "leather_light", 1)
    for along in [-5, 0, 5, 10]:
        cx, cy = hx+ux*along, hy+uy*along
        r.line([(cx-vx*2,cy-vy*2), (cx+vx*2,cy+vy*2)], "brass_dark", 1)

    def box(a, b, c, d):
        return [(tx+vx*x+ux*y,ty+vy*x+uy*y) for x,y in [(a,c),(b,c),(b,d),(a,d)]]

    r.poly(box(-13,13,-7,7), "shadow", "ink")
    r.poly(box(-11,10,-6,2), "steel")
    r.poly(box(-10,9,2,5), "low")
    r.poly(box(-12,-7,-6,6), "light", "ink")
    r.poly(box(8,13,-6,6), "deep", "ink")
    r.line([box(-10,8,-6,-6)[0], box(-10,8,-6,-6)[1]], "shine", 2)
    r.poly(box(-2,3,-7,7), "brass_dark", "ink")
    r.line([box(-1,-1,-5,5)[0], box(-1,-1,-5,5)[2]], "brass", 1)
    r.dot(tx-2, ty-2, "rune", 2)
    # Closed steel fingers, not a bare human hand.
    r.poly([(hx-5,hy-5),(hx+4,hy-5),(hx+6,hy),(hx+3,hy+5),(hx-5,hy+4)], "steel", "ink")
    r.line([(hx-4,hy-3),(hx+3,hy-3)], "shine", 1)
    for y in [hy,hy+2]: r.line([(hx-4,y),(hx+3,y)], "shadow", 1)


def draw_frame(action, index):
    p = pose(action, index)
    r = Painter(p)
    far_leg,near_leg=leg_joints(p)
    # Split cloth behind the armored legs; the outline is tall, not broad/chibi.
    r.poly([(44,72),(76,72),(82,99),(76,106),(71,100),(66,107),(62,100),(54,106),(49,100),(41,106)],"blue_dark","ink")
    r.line([(48,78),(45,93),(46,99)],"blue_light",1)
    r.line([(72,80),(77,97),(75,101)],"rune_dark",1)
    r.limb_space=True
    r.leg(*far_leg,True)
    r.leg(*near_leg,False)
    r.limb_space=False
    # Fitted cuirass with navy plate sides and a dark, engraved turquoise center.
    r.poly([(45,40),(57,36),(72,36),(82,43),(77,61),(72,73),(51,75),(45,61)],"deep","ink")
    r.poly([(48,43),(58,40),(71,40),(77,44),(72,65),(65,72),(53,68)],"blue_dark","ink")
    r.poly([(48,44),(53,45),(51,58),(55,69),(50,66),(46,54)],"shadow")
    r.line([(47,44),(49,51),(48,58),(52,66)],"steel",1)
    r.line([(75,45),(73,54),(74,61),(70,67)],"low",1)
    # Separate angular glyphs with negative space, using the same teal palette.
    for path in [[(60,44),(60,50)],[(60,44),(65,46),(60,48)],
                 [(54,54),(54,62)],[(54,56),(59,54)],[(54,59),(58,58)],
                 [(65,54),(69,56),(65,58),(69,61)],[(65,58),(64,62)],
                 [(55,65),(58,65)],[(68,64),(70,64)]]:
        r.line(path,"rune",1)
    for x,y in [(60,45),(54,56),(65,58)]: r.dot(x,y,"rune_light")
    for y in [68,72,76]:
        r.poly([(50,y-1),(60,y+1),(71,y-1),(73,y+3),(62,y+5),(49,y+3)],"deep","ink")
        r.line([(51,y),(60,y+2),(69,y)],"low",1)
    r.poly([(59,72),(63,70),(67,73),(64,77),(60,77),(57,74)],"shadow","ink")
    r.line([(59,73),(63,71),(66,73)],"light",1)
    r.dot(62,73,"rune",2)
    # Front tabard, surrounded by descending pointed tassets.
    r.poly([(56,78),(68,78),(68,94),(63,104),(58,99),(54,101)],"blue_dark","ink")
    r.line([(59,81),(64,81),(61,84),(61,87)],"rune",1)
    r.line([(58,89),(63,89),(63,93),(60,93)],"rune_dark",1)
    r.line([(60,96),(62,98),(64,96)],"rune",1)
    r.limb_space=True
    thigh_plates(r,far_leg[0],far_leg[1],True)
    thigh_plates(r,near_leg[0],near_leg[1],False)
    r.limb_space=False
    # Shield arm under the shield, then a long pointed steel kite shield.
    r.line([(78,47),(84,60),(88,72)],"ink",11)
    r.line([(78,47),(84,60),(88,72)],"shadow",7)
    r.poly([(78,49),(89,43),(98,35),(102,45),(110,51),(108,88),(95,118),(84,102),(77,73)],"deep","ink",True)
    r.line([(79,50),(89,45),(97,38),(101,47),(108,52)],"light",1,True)
    r.line([(79,53),(79,73),(86,101),(95,115)],"steel",1,True)
    r.line([(109,54),(106,89),(95,115)],"low",1,True)
    r.poly([(83,53),(92,48),(97,43),(99,49),(105,54),(103,86),(95,107),(87,97),(82,72)],"blue_dark","ink",True)
    r.line([(84,54),(91,50),(96,46)],"blue_light",1,True)
    r.line([(83,58),(84,76),(89,94),(95,107)],"rune_dark",1,True)
    r.line([(102,54),(101,80),(96,98)],"rune_dark",1,True)
    # Staggered rows of abstract inscriptions, no head/eye/tentacle emblem.
    for path in [[(95,48),(92,52),(98,52),(95,55)],
                 [(87,59),(87,67),(92,63),(87,61)],
                 [(96,59),(100,59),(97,62),(97,67)],
                 [(88,73),(93,73),(93,77),(89,80)],
                 [(97,71),(100,74),(97,77)],
                 [(92,84),(97,84),(94,87),(94,92)],
                 [(91,89),(97,89)],
                 [(93,97),(95,99),(97,96)]]:
        r.line(path,"rune_dark",3,True)
        r.line(path,"rune",1,True)
    if not p["dim"]:
        for x,y in [(95,48),(87,60),(98,59),(91,73),(94,87)]:
            r.dot(x,y,"rune_light",1,True)
    for x,y in [(81,52),(88,48),(105,54),(81,72),(87,98),(105,84),(95,112)]:
        r.dot(x,y,"ink",2,True)
        r.dot(x,y,"steel",1,True)
    # Near articulated arm; pointed couter and thin silver vambrace ridge.
    hx,hy=p["hand"]
    elbow=((43+hx)*.5-4,(48+hy)*.5+5)
    if action in ("idle", "move") or (action=="recover" and index==3):
        elbow=((43+hx)*.5,(48+hy)*.5)
    r.line([(43,48),elbow,(hx,hy)],"ink",11)
    r.line([(43,48),elbow,(hx,hy)],"shadow",7)
    ex,ey=elbow
    r.poly([(ex-6,ey-6),(ex+4,ey-4),(ex+5,ey+1),(ex,ey+5),(ex-7,ey+2)],"deep","ink")
    r.line([(ex-5,ey-4),(ex,ey-2),(ex+3,ey-3)],"steel",1)
    r.line([(ex-2,ey+3),(hx-3,hy-2)],"steel",2)
    r.line([(ex-3,ey+3),(hx-4,hy-3)],"light",1)
    # Tiered pauldrons echo the reference without increasing native resolution.
    for i in reversed(range(4)):
        y=38+i*5
        r.poly([(40-i,y),(48,y-2),(55-i,y+3),(51-i,y+7),(34-i,y+8),(36-i,y+3)],"shadow","ink")
        r.line([(36-i,y+4),(42-i,y+1),(48,y),(52-i,y+3)],"steel",1)
        r.line([(36-i,y+6),(47-i,y+5)],"low",1)
        r.dot(38-i,y+4,"light")
        r.dot(47-i,y+2,"rune")
    r.poly([(74,38),(79,35),(87,41),(88,48),(78,46)],"deep","ink")
    r.line([(76,39),(79,37),(85,41)],"steel",1)
    for y in [45,49]: r.line([(80,y),(86,y+2)],"low",1)
    # High gorget and a narrow, long-faced closed helmet with a pointed crown.
    r.poly([(53,34),(64,38),(76,33),(78,39),(64,45),(51,39)],"deep","ink")
    r.line([(53,36),(64,41),(75,36)],"steel",1)
    r.poly([(61,10),(68,6),(75,12),(78,22),(77,32),(68,41),(57,35),(54,24),(56,16)],"deep","ink")
    r.poly([(61,12),(67,9),(71,12),(73,21),(64,21),(57,23),(57,17)],"shadow")
    r.poly([(61,13),(66,10),(69,12),(65,13),(62,18),(59,20),(58,18)],"low")
    r.line([(61,12),(66,8),(71,11),(74,17)],"steel",1)
    r.line([(65,10),(69,12),(71,17)],"light",1)
    r.line([(67,17),(70,20),(73,21),(72,15)],"rune_dark",1)
    r.poly([(56,24),(64,25),(69,29),(77,23),(75,33),(68,41),(58,35)],"joint","ink")
    r.line([(57,25),(63,27),(68,29),(75,25)],"steel",1)
    r.line([(69,30),(68,39)],"light",1)
    r.line([(59,29),(62,35),(66,38)],"low",1)
    r.line([(75,28),(73,33),(70,37)],"shadow",1)
    if not p["dim"]:
        r.line([(60,25),(64,26)],"rune",1)
        r.dot(73,24,"rune_light")
    # Small metal temple fin, no exposed face or bare ear.
    r.poly([(55,21),(49,17),(51,24),(56,28)],"brass_dark","ink")
    r.line([(50,19),(55,23)],"brass",1)
    hammer(r,p["hand"],p["tip"])
    return r.image


def telegraph(progress=0.0):
    # Straight filled rectangle with two emphasized long edges. No arrowheads.
    im=Image.new("RGBA",(288,48))
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,287,47),fill=(255,59,48,31))
    pulse=(.5+.5*math.sin(progress*math.tau*2))
    for y in (0,47):
        d.line((0,y,287,y),fill=(255,80,65,round(255*(.42+.13*pulse))),width=1)
        inner=1 if y==0 else 46
        d.line((0,inner,287,inner),fill=(255,60,50,46),width=1)
        for i in range(15):
            x=round((i*21+progress*46)%284)
            if (i+int(progress*8))%3==0:
                d.rectangle((x,y-1 if y else 0,x+2,y if y else 1),fill=(255,125,99,round(255*(.48+.12*pulse))))
    return im


def frame_at(frames, action, elapsed):
    durations,loop=SPECS[action]
    ms=elapsed*1000+1e-7
    if loop: ms%=sum(durations)
    for i,dt in enumerate(durations):
        if ms<dt: return frames[action][i]
        ms-=dt
    return frames[action][-1]


def ground():
    im=Image.new("RGBA",(480,232),"#1b282e")
    d=ImageDraw.Draw(im)
    rng=random.Random(92626)
    for y in range(0,232,24):
        for x in range(-40,480,40):
            dx=20 if (y//24)%2 else 0
            shade=rng.choice(["#223239","#26363b","#233139","#29393d"])
            d.rectangle((x+dx+1,y+1,x+dx+38,y+22),fill=shade)
            d.line((x+dx+2,y+2,x+dx+35,y+2),fill="#304146")
    for _ in range(160):
        x,y=rng.randrange(480),rng.randrange(232)
        d.rectangle((x,y,x+1,y+1),fill=rng.choice(["#19282d","#354548"]))
    return im


def actor(canvas, frame, feet, scale=.7, flip=False):
    if flip: frame=ImageOps.mirror(frame)
    frame=frame.resize((round(SIZE*scale),round(SIZE*scale)),Image.Resampling.NEAREST)
    pos=round(feet[0]-ANCHOR[0]*scale),round(feet[1]-ANCHOR[1]*scale)
    canvas.alpha_composite(frame,pos)


def save_gif(frames, path, duration):
    atlas=Image.new("RGB",(frames[0].width,frames[0].height*8))
    for i in range(8): atlas.paste(frames[i*(len(frames)-1)//7].convert("RGB"),(0,i*frames[0].height))
    palette=atlas.quantize(colors=128)
    seq=[f.convert("RGB").quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    seq[0].save(path,save_all=True,append_images=seq[1:],duration=duration,loop=0,disposal=1,optimize=True)


def attack_review(frames):
    player=Image.open(ROOT/"assets/sprites/player/combat/void_hunter_idle_right.png").convert("RGBA")
    player=ImageOps.mirror(player.crop(player.getbbox()))
    result=[]
    dash_start=2.4
    dash_end=dash_start+DASH_SECONDS
    recover_end=dash_end+.5
    for i in range(round(PREVIEW_SECONDS*PREVIEW_FPS)):
        t=i/PREVIEW_FPS
        scene=ground()
        d=ImageDraw.Draw(scene)
        if t<1.6:
            x=lerp(26,150,t/1.6)
            action,elapsed="move",t
            label="距离过远：只追赶，进入 240 范围后才起手"
        elif t<2.4:
            x=150
            action,elapsed="windup",t-1.6
            label="举盾蓄力 0.8 秒 · 两侧边缘预警"
            scene.alpha_composite(telegraph((t-1.6)/.8),(126,128))
        elif t<dash_end:
            x=150+DASH_DISTANCE*(t-dash_start)/DASH_SECONDS
            action,elapsed="dash",t-dash_start
            label="冲刺 + 挥锤 0.16 秒 · 速度提升至原来的 2.5 倍"
        elif t<recover_end:
            x=390
            action,elapsed="recover",t-dash_end
            label="刹停收招 0.5 秒 · 盾牌回位"
        else:
            x=390
            action,elapsed="idle",t-recover_end
            label="恢复待机 · 预警锁定后可以侧移躲开"
        py=152-60*min(1,max(0,(t-2.10)/.55))
        d.ellipse((x-17,148,x+25,157),fill="#172329")
        d.ellipse((367,py-3,393,py+3),fill="#172329")
        scene.alpha_composite(player,(380-player.width//2,round(py-player.height)))
        actor(scene,frame_at(frames,action,elapsed),(x,152))
        # Sparse ground chips during braking, never a second damage telegraph.
        if dash_end-.04<t<dash_end+.25:
            for j in range(7):
                px=x-12-j*5
                yy=153-(j%3)*2
                d.rectangle((px,yy,px+2,yy+1),fill="#6b7772")
        panel=Image.new("RGB",(960,550),"#111d25")
        pd=ImageDraw.Draw(panel)
        pd.text((22,10),"钢甲骑士小 Boss · 攻击动作与预警审阅",font=font(23),fill="#d6e1da")
        panel.paste(scene.resize((960,464),Image.Resampling.NEAREST),(0,48))
        pd.text((22,521),label,font=font(17),fill="#acbfc3")
        pd.text((683,12),"美术模拟 · 尚未接入实战",font=font(15),fill="#94aeb3")
        result.append(panel)
    save_gif(result,OUT/"knight_attack.gif",1000//PREVIEW_FPS)
    # A dedicated enlarged strip makes the hammer motion easy to review.
    montage=Image.new("RGB",(1120,294),"#1b2930")
    md=ImageDraw.Draw(montage)
    for index,frame in enumerate(frames["dash"]):
        tile=frame.resize((208,208),Image.Resampling.NEAREST)
        montage.paste(tile,(index*182-12,32),tile)
        md.text((index*182+42,249),["高举","起挥","前压","击出","下砸","随势收锤"][index],font=font(16),fill="#c4d3d1")
    md.text((20,5),"冲刺中的连续挥锤 · 6 帧 / 0.16 秒 · 实际速度 2.5 倍",font=font(19),fill="#e0e7dc")
    montage.save(OUT/"hammer_keyframes.png")


def speed_comparison(frames):
    # Identical new artwork in both rows isolates timing from appearance.
    result=[]
    start=.8
    for i in range(150):
        t=i/PREVIEW_FPS
        panel=Image.new("RGB",(960,648),"#111d25")
        pd=ImageDraw.Draw(panel)
        pd.text((22,10),"冲刺与挥锤速度对比 · 同款新造型",font=font(23),fill="#d6e1da")
        pd.text((704,14),"美术模拟 · 正常速度播放",font=font(15),fill="#94aeb3")
        for row,(seconds,title) in enumerate([(.4,"原节奏：240 距离 / 0.40 秒"),
                                              (DASH_SECONDS,"新节奏：240 距离 / 0.16 秒 · 2.5 倍速度")]):
            scene=ground().crop((0,72,480,204))
            sd=ImageDraw.Draw(scene)
            x=100
            if t<start:
                action,elapsed="windup",t
                scene.alpha_composite(telegraph(t/start),(76,76))
            elif t<start+seconds:
                u=(t-start)/seconds
                x+=DASH_DISTANCE*u
                action,elapsed="dash",u*DASH_SECONDS
            else:
                x+=DASH_DISTANCE
                elapsed=t-start-seconds
                action="recover" if elapsed<.5 else "idle"
                if action=="idle": elapsed-=.5
            sd.line((100,100,340,100),fill="#3b5059",width=1)
            sd.line((340,94,340,110),fill="#667d83",width=1)
            sd.ellipse((x-17,96,x+25,105),fill="#172329")
            actor(scene,frame_at(frames,action,elapsed),(x,100))
            top=78+row*292
            pd.text((22,top-25),title,font=font(18),fill="#c0d7d7" if row else "#94aab1")
            panel.paste(scene.resize((960,264),Image.Resampling.NEAREST),(0,top))
        result.append(panel)
    save_gif(result,OUT/"knight_speed_comparison.gif",1000//PREVIEW_FPS)


def walk_review(frames):
    result=[]
    seconds=sum(SPECS["move"][0])*3/1000
    for i in range(round(seconds*PREVIEW_FPS)):
        t=i/PREVIEW_FPS
        panel=Image.new("RGBA",(1000,620),"#111d25")
        d=ImageDraw.Draw(panel)
        d.text((25,20),"骑士站姿与完整迈步 · 动作审阅",font=font(28),fill="#d9e4df")
        d.text((26,66),"160×160 原生像素 · 此处放大 3 倍 · 美术模拟，尚未接入战斗",font=font(17),fill="#9db8bd")
        for left in [15,515]:
            d.rectangle((left,110,left+470,530),fill="#22333b",outline="#3e525c")
            d.rectangle((left+1,476,left+469,529),fill="#1b2b33")
            d.line((left+20,506,left+450,506),fill="#435b64")
        d.text((122,120),"待机：双腿分开撑稳",font=font(21),fill="#c8dbda")
        d.text((606,120),"行走：大腿带动抬膝",font=font(21),fill="#c8dbda")
        d.ellipse((175,493,332,513),fill="#152129")
        d.ellipse((673,493,830,513),fill="#152129")
        actor(panel,frame_at(frames,"idle",t),(250,490),3)
        actor(panel,frame_at(frames,"move",t),(750,490),3)
        d.text((58,552),"双脚间距 40 像素 · 膝腿向外展开",font=font(19),fill="#b7ced0")
        d.text((548,552),"八帧循环 · 胯甲、身体随步伐运动",font=font(19),fill="#b7ced0")
        d.text((26,587),"右侧为原地行走动作检查；右手仍自然垂锤，青色符文沿用上一版。",font=font(16),fill="#91aab3")
        result.append(panel)
    save_gif(result,OUT/"knight_walk_review.gif",1000//PREVIEW_FPS)


def board(frames):
    im=Image.new("RGB",(1120,960),"#111d25")
    d=ImageDraw.Draw(im)
    d.text((30,23),"钢甲骑士 · 巨盾 / 单手锤",font=font(31),fill="#e0e7dc")
    d.text((31,70),"双腿展开撑稳 · 整条腿迈步 · 右手垂锤 · 青色几何符文 · 原生分辨率仍为 160×160",font=font(17),fill="#a2b9c0")
    for x in [24,398]:
        d.rectangle((x,116,x+355,535),fill="#22333b",outline="#3e525c")
    hero=frames["idle"][0].resize((480,480),Image.Resampling.NEAREST)
    im.paste(hero,(-23,117),hero)
    pose_image=frames["windup"][-1].resize((480,480),Image.Resampling.NEAREST)
    im.paste(pose_image,(354,117),pose_image)
    d.text((117,506),"双腿展开 · 垂锤",font=font(17),fill="#ccd8d6")
    d.text((503,506),"举盾 · 抬锤",font=font(17),fill="#ccd8d6")
    d.text((790,121),"轮廓与材质",font=font(22),fill="#d8ded0")
    for i,text in enumerate(["① 双脚间距 40 像素，撑稳重甲", "② 大腿带动膝踝完整迈步", "③ 胯甲随大腿摆动", "④ 身体随承重、抬腿上下起伏", "⑤ 右手垂锤，保留青色符文"]):
        d.text((776,171+i*39),text,font=font(16),fill="#b1c4c6")
    # Same in-game scale comparison, magnified 2x together.
    d.text((776,390),"同一倍率尺寸对比",font=font(18),fill="#d8ded0")
    player=Image.open(ROOT/"assets/sprites/player/combat/void_hunter_idle_right.png").convert("RGBA")
    normal=Image.open(ROOT/"assets/sprites/enemies/combat/enemy_gloom_mite_idle.png").convert("RGBA")
    samples=[player.crop(player.getbbox()),normal.crop(normal.getbbox()),frames["idle"][0].resize((112,112),Image.Resampling.NEAREST)]
    for i,(item,title) in enumerate(zip(samples,["玩家","普通怪","骑士"])):
        item=item.crop(item.getbbox())
        item=item.resize((item.width*2,item.height*2),Image.Resampling.NEAREST)
        im.paste(item,(790+i*105-item.width//2,562-item.height),item)
        d.text((772+i*105,576),title,font=font(14),fill="#b1c4c6")
    d.text((29,581),"冲刺提示 · 无箭头直角矩形",font=font(22),fill="#d8ded0")
    d.text((30,617),"内部 12% 不透明度；两侧长边 42%～55%，少量亮红方粒脉动",font=font(16),fill="#a2b9c0")
    path=telegraph(.22).resize((720,120),Image.Resampling.NEAREST)
    im.paste(path,(30,654),path)
    d.text((31,790),"进入 240 距离才起手 · 预警 0.8 秒 · 冲刺与挥锤 0.16 秒（原为 0.4 秒）",font=font(18),fill="#beced0")
    d.line((30,838,1090,838),fill="#3c515b")
    d.text((30,863),"6 组动画 / 32 帧 · 160×160 透明 PNG · 固定脚底锚点 · 最近邻像素显示",font=font(20),fill="#d1dfdc")
    d.text((30,904),"美术资源审阅阶段：造型、挥锤动作与预警样式；尚未替换正式怪物或技能逻辑。",font=font(17),fill="#91aab3")
    im.save(OUT/"knight_review.png")


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    frames={action:[draw_frame(action,i) for i in range(len(spec[0]))] for action,spec in SPECS.items()}
    manifest={"preview_only":True,"direct_pixel_drawing":True,"frame_size":[SIZE,SIZE],"anchor":ANCHOR,
              "suggested_runtime_scale":.7,"palette":P,"actions":{},
              "reference_style":"pointed closed helm, tiered dark steel, separate teal angular runes, kite shield",
              "neutral_pose":{"legs":"wide straight stance with outward thigh alignment","foot_spacing":40,"hammer_arm":"relaxed at side","hand":[38,80],"hammer_head":[35,100]},
              "gait":{"frames":8,"cycle_ms":sum(SPECS["move"][0]),"upper_leg_length":21,"lower_leg_length":21,"thigh_plates_follow_leg":True,"pelvis_and_body_shift":True},
              "dash":{"duration_ms":round(DASH_SECONDS*1000),"previous_duration_ms":400,"speed_multiplier":.4/DASH_SECONDS,"distance":DASH_DISTANCE,"speed":DASH_DISTANCE/DASH_SECONDS,"windup_ms":800,"hammer_synchronized":True},
              "telegraph":{"fill_alpha":31,"edge_alpha_range":[107,140],"edge_particle_alpha_range":[122,153],"radius_gate":240,"shape":"straight rectangle without arrows or rounded corners"}}
    for action,seq in frames.items():
        sheet=Image.new("RGBA",(SIZE*len(seq),SIZE))
        hashes=[]
        for i,frame in enumerate(seq):
            bbox=frame.getbbox()
            assert bbox and bbox[0]>=3 and bbox[1]>=3 and bbox[2]<=SIZE-3 and bbox[3]<=SIZE-3,(action,i,bbox)
            assert set(frame.getchannel("A").tobytes()) <= {0,255}
            hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
            sheet.alpha_composite(frame,(SIZE*i,0))
        assert len(set(hashes))==len(hashes),(action,"duplicate animation frames")
        sheet.save(OUT/f"knight_{action}.png")
        manifest["actions"][action]={"count":len(seq),"durations_ms":SPECS[action][0],"loop":SPECS[action][1],"unique_frames":len(set(hashes)),"sheet_size":sheet.size}
    frames["idle"][0].save(OUT/"knight_reference.png")
    telegraph(.22).save(OUT/"dash_telegraph.png")
    # Full transparent animation strip is reviewable separately from the action mockup.
    board(frames)
    attack_review(frames)
    speed_comparison(frames)
    walk_review(frames)
    contact=Image.new("RGB",(125+max(len(seq) for seq in frames.values())*166,1014),"#1b2930")
    dc=ImageDraw.Draw(contact)
    for row,(action,seq) in enumerate(frames.items()):
        dc.text((13,row*168+62),LABELS[action],font=font(17),fill="#b7c9c9")
        for i,frame in enumerate(seq):
            contact.paste(frame,(125+i*166,row*168),frame)
    contact.save(OUT/"animation_contact_sheet.png")
    with Image.open(OUT/"knight_attack.gif") as gif:
        duration=0
        for i in range(gif.n_frames): gif.seek(i); duration+=gif.info["duration"]
        assert duration==round(PREVIEW_SECONDS*1000)
        manifest["attack_gif"]={"frames":gif.n_frames,"duration_ms":duration,"size":gif.size,"sample_fps":PREVIEW_FPS}
    with Image.open(OUT/"knight_speed_comparison.gif") as gif:
        duration=0
        for i in range(gif.n_frames): gif.seek(i); duration+=gif.info["duration"]
        assert duration==3000
        manifest["speed_comparison_gif"]={"frames":gif.n_frames,"duration_ms":duration,"size":gif.size,"sample_fps":PREVIEW_FPS}
    with Image.open(OUT/"knight_walk_review.gif") as gif:
        duration=0
        for i in range(gif.n_frames): gif.seek(i); duration+=gif.info["duration"]
        assert duration==sum(SPECS["move"][0])*3
        manifest["walk_review_gif"]={"frames":gif.n_frames,"duration_ms":duration,"size":gif.size,"sample_fps":PREVIEW_FPS}
    (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"output":str(OUT),"animations":len(frames),"frames":sum(len(s) for s in frames.values()),"alpha":"binary transparent","attack_ms":round(PREVIEW_SECONDS*1000)}))


if __name__=="__main__": main()
