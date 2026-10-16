"""Author hard-edged weapon VFX from layered shapes on a 2px grid.

These are deterministic local drawings, not image-model output. Weapon bodies
and the approved dagger/dash art are inputs for style only and never rewritten.
"""
from pathlib import Path
from math import sin, cos, pi
from PIL import Image, ImageDraw
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/sprites/weapons/effects/block_vfx'
OUT.mkdir(parents=True, exist_ok=True)
SCALE = 2
CREAM = '#fff3cb'
WARM = ['#74403c', '#c66740', '#f5b85b', CREAM]
COOL = ['#35596b', '#569aa9', '#a4e0dc', '#efffea']
PURPLE = ['#503154', '#8d537c', '#d398b1', '#ffe0d6']


def poly(im, points, color):
    ImageDraw.Draw(im).polygon([(round(x / SCALE), round(y / SCALE)) for x, y in points], fill=color)


def rect(im, box, color):
    ImageDraw.Draw(im).rectangle(tuple(round(v / SCALE) for v in box), fill=color)


def arc(im, center, radius, width, start, end, color):
    count = max(6, round(abs(end - start) * radius / 7))
    angles = [start + (end - start) * i / count for i in range(count + 1)]
    points = [(center[0] + cos(a) * radius, center[1] + sin(a) * radius) for a in angles]
    points += [(center[0] + cos(a) * (radius - width * min(1, (a-start)/(end-start)*3)),
                center[1] + sin(a) * (radius - width * min(1, (a-start)/(end-start)*3))) for a in reversed(angles)]
    poly(im, points, color)


def blob(im, center, radius, phase, color, sides=14):
    points = []
    for i in range(sides * 2):
        angle = 2 * pi * i / (sides * 2)
        r = radius * (1 + (0.11 if i % 2 else -0.09) + 0.07 * sin(i * 2.1 + phase))
        points.append((center[0] + cos(angle) * r, center[1] + sin(angle) * r))
    poly(im, points, color)


def grenade(im, i, n):
    t = i / (n - 1)
    radius = 18 + 38 * min(t / 0.34, 1)
    if t < 0.36:
        # Joined flame lobes open into a few large separated embers.
        blob(im, (64, 64), radius, 0.8, WARM[0], 7)
        blob(im, (61, 60), radius * 0.90, 1.4, WARM[1], 7)
        blob(im, (60, 57), radius * (0.76 - t * 0.5), 0.3, WARM[2], 6)
        blob(im, (60, 57), radius * max(0, 0.48 - t * 0.7), 1.5, WARM[3], 5)
    elif t < 0.76:
        for j in range(5):
            a = j*2*pi/5 + 0.24
            r = 25 + t*24
            x,y = 64+cos(a)*r,64+sin(a)*r
            size = 21*(1-t)
            blob(im,(x,y),size,j,WARM[0],4)
            blob(im,(x-2,y-3),size*0.8,j,WARM[1],4)
            if t<0.58: blob(im,(x-3,y-4),size*0.46,j,WARM[2],4)
    for j in range(5):
        a = j * 2 * pi / 5 + 0.24
        r = 29 + t * 27
        x, y = 64 + cos(a) * r, 64 + sin(a) * r
        size = (6 + (j % 2) * 3) * max(0, 1 - max(t - 0.4, 0) / 0.6)
        if size >= 2:
            poly(im, [(x-size,y), (x,y-size*0.6), (x+size,y+size), (x-size*0.6,y+size)], WARM[2 if t < 0.5 else 1])


def tome(im, i, n):
    t = i / (n - 1)
    radius = 18 + min(t / 0.25, 1) * 13
    center = (48, 61)
    if t < 0.7:
        # Four broad separated seal brackets leave the target readable inside.
        for j in range(4):
            a = j * pi / 2
            base = [(radius, -5), (radius, 8), (8, radius), (-5, radius), (radius-7, 6), (radius-7, -5)]
            pts = [(center[0]+cos(a)*x-sin(a)*y,center[1]+sin(a)*x+cos(a)*y) for x,y in base]
            poly(im, pts, COOL[1])
            base = [(radius, -5), (radius, 4), (4, radius), (-5, radius), (radius-4, 0), (radius-4, -5)]
            poly(im, [(center[0]+cos(a)*x-sin(a)*y,center[1]+sin(a)*x+cos(a)*y) for x,y in base], COOL[2 if t > 0.2 else 3])
        if t < 0.32:
            poly(im, [(44,28),(54,28),(52,66),(46,82),(46,64)], COOL[3])
    for j in range(4):
        a = j * pi / 2 + pi / 4
        r = 27 + t * 17
        x, y = 48 + cos(a)*r, 61 + sin(a)*r
        s = max(0, (1-t)*6)
        if s >= 2: poly(im, [(x-s,y),(x,y-s),(x+s,y),(x,y+s)], COOL[1 if t > 0.65 else 2])


def tentacle(im, i, n):
    t = i / (n - 1)
    tail = max(0, (t - 0.5) * 2)
    # A convex whip ribbon rolls down into the existing flattened contact pose.
    y = 25 + min(t / 0.55, 1) * 66
    x0 = 24 + tail * 80
    outer = [(x0,67),(54,31+tail*40),(84,21+tail*48),(112,35+tail*43),(140,y-6),(144,y+8),(118,y+1),(90,49+tail*35),(58,52+tail*35)]
    if t < 0.88:
        poly(im, outer, PURPLE[0])
        poly(im, [(x0+8,64),(58,35+tail*40),(84,28+tail*48),(112,40+tail*43),(142,y),(125,y+3),(93,46+tail*36),(60,46+tail*38)], PURPLE[1])
        poly(im, [(46+tail*52,48+tail*38),(76,26+tail*48),(100,30+tail*44),(130,y-12),(143,y),(129,y-3),(99,37+tail*40),(77,33+tail*46)], PURPLE[2])
        poly(im, [(79,27+tail*47),(97,28+tail*47),(121,y-20),(140,y-3),(125,y-13),(98,34+tail*42)], PURPLE[3])
    if t > 0.4:
        for j in range(3):
            x = 104 + j*15 + t*5
            y = 103 - (j%2)*10 - (t-0.4)*19
            s = max(2, 8*(1-t))
            poly(im, [(x-s,y),(x,y-s*2),(x+s,y),(x,y+s)], PURPLE[2])


def hammer(im, i, n):
    # Frames 0..4 match authored hammer poses 4..8 around grip (10, 0).
    # Remaining frames break the settled contact into chunky stone splinters.
    if i < 6:
        head_angle = [-2.2, -1.95, -0.85, -0.2, 0.35, 0.35][i]
        span = [0.35,0.7,1.1,1.3,1.35,0.6][i]
        start = head_angle-span
        arc(im, (42,100), 35, 20, start, head_angle, WARM[0])
        arc(im, (42,100), 35, 14, start+span*0.12, head_angle, WARM[2])
        arc(im, (42,100), 34, 6, start+span*0.3, head_angle, WARM[3])
    if i >= 4:
        f = (i-4)/3
        for j in range(4):
            x, y = 64+(j-1.5)*(8+f*10), 107-(j%2)*8-f*7
            s = 10*(1-f)
            if s >= 2:
                poly(im, [(x-s,y),(x-s*0.3,y-s*2),(x+s,y-s),(x+s,y+s)], WARM[1])
                poly(im, [(x-s,y),(x-s*0.3,y-s*2),(x+s,y-s),(x,y-s*0.3)], WARM[3])


def spear(im, i, n):
    t = i / (n - 1)
    width = 13 * (1 - max(t - 0.55, 0)*1.6)
    start = 30 + max(t-0.5,0)*150
    poly(im, [(start,34),(96,32-width),(148,30-width),(188,32),(151,34+width),(86,33+width)], COOL[0])
    poly(im, [(start+8,32),(106,32-width),(158,32-width*0.55),(190,32),(148,32+width*0.65),(83,35)], COOL[1])
    poly(im, [(63+max(t-0.5,0)*130,31),(139,32-width*0.65),(190,32),(146,35),(87,34)], COOL[2])
    poly(im, [(104,31),(156,32-width*0.3),(190,32),(149,33)], COOL[3])
    if t < 0.65:
        poly(im, [(54,32-width-4),(103,32-width-8),(81,32-width-3)], COOL[2])
        poly(im, [(71,38+width),(124,38+width),(100,42+width)], COOL[1])


def hammer_crack(im, i, n):
    # A continuous dark cleft between large lifted stone plates, authored on
    # the same 2px grid. Six phases: snap open, lift, settle, leave the fissure.
    lift = [8,14,11,5,1,0][i]
    edge = ['#fff0bc','#eec57a','#bca878','#93876a','#716c59','#575847'][i]
    mid = ['#b99b62','#b09a70','#8b8064','#736e58','#5c604f','#454d43'][i]
    poly(im,[(0,42),(18,36),(34,42),(53,35),(68,42),(82,36),(96,41),
             (96,59),(77,65),(61,56),(43,64),(27,57),(12,63),(0,56)],'#272b2c')
    poly(im,[(0,44),(18,41),(34,47),(52,40),(70,46),(84,40),(96,45),
             (96,55),(77,59),(62,51),(44,58),(28,51),(11,57),(0,51)],'#131e23')
    if i < 5:
        # Opposite banks break in different directions; avoid repeated circles.
        poly(im,[(0,39),(8,27-lift),(25,23-lift),(40,31-lift),(34,44),(17,39)],mid)
        poly(im,[(0,39),(8,27-lift),(25,23-lift),(40,31-lift),(28,33-lift),(12,32-lift)],edge)
        poly(im,[(48,37),(55,25-lift),(73,21-lift),(91,29-lift),(96,43),(75,39),(65,43)],mid)
        poly(im,[(48,37),(55,25-lift),(73,21-lift),(91,29-lift),(75,31-lift),(59,31-lift)],edge)
        poly(im,[(6,59),(25,55),(42,63),(35,77+lift*0.35),(18,81+lift*0.35),(3,71)],mid)
        poly(im,[(6,59),(25,55),(42,63),(28,66),(12,65)],edge)
        poly(im,[(56,59),(68,57),(90,63),(96,77),(79,82+lift*0.35),(60,75)],mid)
        poly(im,[(56,59),(68,57),(90,63),(84,69),(65,65)],edge)
    if i < 3:
        for x,y,s in [(14,13-lift*0.3,5),(48,20-lift*0.6,7),(79,14-lift*0.3,5)]:
            poly(im,[(x-s,y),(x,y-s),(x+s,y+2),(x,y+s)],edge)


def flail(im, i, n):
    elapsed = (i+0.5)/30 - 0.13
    if elapsed < 0 or elapsed > 0.37: return
    p = min(1, max(0, elapsed/0.37))
    angle = (-65 + 130*(p*p*(3-2*p))) * pi/180
    span = (48 + 30*sin(p*pi)) * pi/180
    start = max(-65*pi/180, angle-span)
    span = angle-start
    arc(im, (160,160), 144, 30, start, angle, COOL[0])
    arc(im, (160,160), 144, 22, start+span*0.05, angle, COOL[1])
    arc(im, (160,160), 143, 12, start+span*0.19, angle, COOL[2])
    arc(im, (160,160), 143, 5, start+span*0.40, angle, COOL[3])
    if span>0.4: arc(im, (160,160), 121, 6, start+span*0.2, angle-0.30, COOL[1])


def muzzle(im, i, n):
    t = i/(n-1)
    length = [64,94,106,88,65,30][i]
    width = [16,29,25,18,12,5][i]
    if i < n-1:
        poly(im, [(6,44),(32,48-width),(53,40-width),(49,48-width*0.5),(length,48-width*0.7),(length-16,48),(length,48+width*0.55),(55,49+width*0.5),(63,48+width),(30,48+width),(6,52)], WARM[1])
        poly(im, [(6,43),(34,48-width*0.65),(length-4,47),(49,48+width*0.58),(7,54)], WARM[2])
        poly(im, [(6,44),(27,42),(length-18,48),(33,54),(7,52)], WARM[3])
    for j in range(2):
        x, y = length+6-j*12, 30 if j==0 else 61
        if i in [1,2,3,4]: poly(im, [(x,y),(x+12,y-3),(x+18,y+2),(x+4,y+4)], WARM[2])


def pellet(im, i, n):
    t = i/(n-1)
    r = 11+14*t
    if i < 4:
        blob(im,(32,32),r,0.8,WARM[1],5)
        blob(im,(31,30),r*0.67,1.5,WARM[2],5)
        if i<2: blob(im,(31,30),r*0.43,1,WARM[3],4)
    for j in range(3):
        a = j*2*pi/3+0.35
        x,y = 32+cos(a)*(14+t*14),32+sin(a)*(14+t*14)
        s = 5*(1-t)
        if s>=2: poly(im,[(x-s,y),(x,y-s),(x+s,y),(x,y+s)],WARM[2])


DEFINITIONS = [
    ('grenade',128,128,12,grenade), ('tome',96,128,10,tome),
    ('tentacle',160,128,8,tentacle), ('hammer',128,128,8,hammer),
    ('spear',192,64,7,spear), ('flail',320,320,18,flail),
    ('muzzle',128,96,6,muzzle), ('pellet_hit',64,64,6,pellet),
    ('hammer_crack',96,96,6,hammer_crack),
]
manifest = {'method':'local deterministic pixel geometry; no image model', 'pixel_grid':SCALE, 'clips':{}}
for name,w,h,count,draw in DEFINITIONS:
    sheet = Image.new('RGBA',(w*count,h))
    for index in range(count):
        frame = Image.new('RGBA',(w//SCALE,h//SCALE))
        draw(frame,index,count)
        sheet.paste(frame.resize((w,h),Image.Resampling.NEAREST),(index*w,0))
    sheet.save(OUT/(name+'.png'))
    assert set(sheet.getchannel('A').tobytes()) <= {0,255}
    manifest['clips'][name] = {'frame_size':[w,h],'frames':count,'colors':len(sheet.getcolors(w*count*h))-1}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(manifest,indent=2))
