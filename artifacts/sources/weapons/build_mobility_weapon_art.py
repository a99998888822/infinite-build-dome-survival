"""Draw original mobility-weapon pixel assets locally; no image API is used.

Outputs are review candidates. Existing weapon images and runtime data are untouched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/generated/mobility_weapons_20261007'
PREVIEWS = OUT / 'previews/r02'
REVIEW_FPS = 50
REVIEW_FRAMES = 100
INK = '#181d22'
METAL = ['#29323c', '#465763', '#71828a', '#abbdbf', '#e4ede0']
BRASS = ['#433426', '#735638', '#ab8650', '#d3b974', '#f4df9b']
LEATHER = ['#272725', '#493c32', '#75614b', '#a18a63']
ICE = ['#2b555d', '#408b96', '#69bdc3', '#a5e5da', '#efffee']
FIRE = ['#654132', '#a65b32', '#d88a3e', '#f2c36b', '#fff1bb']
STAR = ['#303653', '#554b79', '#7c70b1', '#a4afe1', '#d2e6f6', '#f2f7dc']
manifest: dict = {'version': 2, 'provenance': 'Original local pixel drawing; no image model or image API.',
                  'status': 'art_review_candidate_not_gameplay', 'icons': {}, 'bodies': {}, 'effects': {},
                  'world_weapon_display': False,
                  'display_names': {'dash_blade': '\u7a81\u8fdb\u77ed\u5203', 'recoil_gun': '\u5de8\u578b\u624b\u6301\u706b\u70ae', 'star_tome': '\u79fb\u661f\u79d8\u5178'},
                  'review': {'fps': REVIEW_FPS, 'frames_per_weapon': REVIEW_FRAMES,
                             'relative_velocity': [10,4,0], 'velocity_knot_time': 0.8,
                             'dash_seconds': 0.22, 'cannon_retreat_seconds': 0.28},
                  'range_rules': {'dash_and_star_movement': 'ellipse; attack-distance bonus only; pointer clamped radially',
                                  'dash_and_star_impact': 'circle; damage-area bonus only',
                                  'cannon_retreat': 'fixed distance; no stat bonuses'},
                  'indicators': {'source': 'res://scripts/battle/mobility_weapon_indicator.gd',
                                 'exports': ['previews/r02/godot/' + name + '_indicator_alpha.png' for name in
                                             ['dash_blade','recoil_gun','star_tome','star_tome_return']],
                                 'canvas': [640,480], 'player_origin': [260,240],
                                 'note': 'Parameterized Godot geometry. Distances shown are art-review values.'}}


def blank(size):
    return Image.new('RGBA', size, (0, 0, 0, 0))


def poly(draw, pts, fill, outline=INK, width=1):
    draw.polygon(pts, fill=fill)
    if outline:
        draw.line(pts + [pts[0]], fill=outline, width=width)


def star(draw, x, y, r, color, inner=0.24):
    pts = []
    for i in range(8):
        a = math.pi * i / 4 - math.pi / 2
        radius = r if i % 2 == 0 else r * inner
        pts.append((round(x + math.cos(a) * radius), round(y + math.sin(a) * radius)))
    draw.polygon(pts, fill=color)


def pixel_line(draw, pts, color, width=1):
    draw.line([(round(x), round(y)) for x, y in pts], fill=color, width=width)


def arc(draw, cx, cy, rx, ry, a, b, color, width=1):
    steps = max(4, int(abs(b-a) * max(rx, ry) * 1.6))
    pts = [(cx + math.cos(a+(b-a)*i/steps)*rx, cy + math.sin(a+(b-a)*i/steps)*ry) for i in range(steps+1)]
    pixel_line(draw, pts, color, width)


def save_asset(im, relative, section, key, **metadata):
    if section == 'bodies': metadata['usage'] = 'reference_only_not_displayed_in_world'
    path = OUT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    colors = {p[:3] for _,p in im.getcolors(im.width * im.height) if p[3]}
    manifest[section][key] = {'path': relative, 'size': list(im.size), 'bbox': list(im.getbbox() or (0,0,0,0)),
                              'colors': len(colors), 'alpha': sorted(value for _,value in im.getchannel('A').getcolors()),
                              'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), **metadata}


def dagger_icon():
    im=blank((64,64)); d=ImageDraw.Draw(im)
    # A short asymmetric blade, swept tip and split steel bevel.
    poly(d,[(22,39),(25,26),(38,17),(50,5),(49,19),(43,29),(31,42)],METAL[1])
    poly(d,[(26,35),(29,27),(39,21),(47,10),(44,24),(33,37)],METAL[3],None)
    poly(d,[(28,37),(44,24),(49,12),(47,25),(34,40)],METAL[2],None)
    pixel_line(d,[(27,34),(37,27),(46,13)],METAL[4])
    pixel_line(d,[(29,37),(41,27)],METAL[0],2)
    poly(d,[(18,35),(22,34),(35,44),(35,49),(30,48),(20,41),(16,41)],BRASS[1])
    pixel_line(d,[(20,36),(32,45),(34,45)],BRASS[3],2)
    poly(d,[(21,42),(28,47),(19,60),(12,57)],LEATHER[1])
    for j in range(4):
        pixel_line(d,[(20-j*2,44+j*3),(25-j*2,47+j*3)],LEATHER[3])
        pixel_line(d,[(19-j*2,46+j*3),(24-j*2,49+j*3)],LEATHER[0])
    poly(d,[(12,54),(20,59),(18,62),(10,58)],BRASS[1])
    pixel_line(d,[(12,55),(18,59)],BRASS[3])
    # Three small inset runes keep the accent inside the physical weapon.
    for x,y in [(35,28),(38,25),(41,22)]:
        d.rectangle((x,y,x+1,y+1),fill=ICE[3])
    poly(d,[(23,38),(26,38),(28,41),(25,43),(22,41)],ICE[1])
    d.point((25,40),fill=ICE[4])
    return im.resize((128,128),Image.Resampling.NEAREST)


def gun_icon():
    im=blank((64,64)); d=ImageDraw.Draw(im)
    # Wide muzzle and short receiver distinguish it from the existing long cannon.
    poly(d,[(9,37),(20,28),(29,27),(33,34),(25,41),(22,48),(14,58),(8,55),(11,46)],LEATHER[1])
    poly(d,[(13,38),(21,33),(25,34),(19,43),(13,52),(11,51)],LEATHER[2],None)
    pixel_line(d,[(14,39),(17,39),(14,47),(12,51)],LEATHER[3])
    poly(d,[(18,29),(34,19),(43,19),(47,28),(33,38),(24,39)],METAL[1])
    poly(d,[(23,29),(36,22),(40,25),(30,32)],METAL[3],None)
    pixel_line(d,[(25,34),(37,27)],METAL[0],2)
    poly(d,[(31,22),(44,9),(51,7),(60,22),(57,28),(40,31)],BRASS[1])
    poly(d,[(34,23),(45,13),(52,12),(53,19),(39,28)],BRASS[2],None)
    pixel_line(d,[(36,22),(47,12)],BRASS[4],2)
    poly(d,[(47,7),(53,6),(62,21),(60,27),(55,27),(45,12)],METAL[0])
    poly(d,[(51,10),(54,11),(59,20),(58,23),(55,21),(50,13)],'#131b22',BRASS[2])
    pixel_line(d,[(48,9),(57,25)],BRASS[3])
    poly(d,[(29,38),(34,36),(34,41),(29,46),(24,45),(24,42)],METAL[0])
    pixel_line(d,[(26,42),(28,44),(32,41),(32,38)],BRASS[2])
    pixel_line(d,[(28,38),(28,41)],METAL[3])
    poly(d,[(22,27),(20,23),(22,21),(24,25),(29,24),(28,28)],METAL[1])
    for x,y in [(25,34),(36,30),(16,42)]:
        d.rectangle((x,y,x+1,y+1),fill=BRASS[3])
    pixel_line(d,[(11,55),(14,57),(21,48)],LEATHER[0],2)
    return im.resize((128,128),Image.Resampling.NEAREST)


def tome_icon(returning=False):
    im=blank((64,64)); d=ImageDraw.Draw(im)
    poly(d,[(10,17),(43,9),(56,43),(51,53),(21,61),(10,54),(6,25)],'#242b3a')
    poly(d,[(14,43),(52,35),(55,46),(50,52),(22,59),(14,54)],'#b4a58a')
    pixel_line(d,[(19,49),(49,41)],'#e0d4b2')
    pixel_line(d,[(20,52),(50,44)],'#716858')
    pixel_line(d,[(21,55),(50,47)],'#e0d4b2')
    poly(d,[(9,15),(41,6),(55,40),(23,49),(12,45),(5,22)],STAR[0])
    poly(d,[(13,18),(40,11),(50,36),(24,43)],STAR[1])
    poly(d,[(17,20),(38,14),(46,33),(25,39)],'#3d4267',None)
    pixel_line(d,[(13,18),(40,11),(49,35)],STAR[2])
    pixel_line(d,[(9,17),(17,42),(24,46)],'#69727d')
    for pts in [[(12,18),(18,17),(17,22)],[(36,12),(40,11),(42,17)],[(44,34),(49,35),(47,38)],[(22,39),(24,44),(29,42)]]:
        poly(d,pts,BRASS[2])
    # Inlaid astrolabe, sparse orbit and a large clear star rather than tiny writing.
    arc(d,32,27,10,9,-2.9,2.5,BRASS[2])
    pixel_line(d,[(24,22),(40,30)],BRASS[1])
    star(d,32,27,8,BRASS[3],0.40)
    star(d,32,27,5,STAR[3],0.30)
    d.rectangle((31,26,33,28),fill=STAR[4])
    for x,y in [(25,20),(39,32),(28,35)]: d.point((x,y),fill=STAR[4])
    poly(d,[(11,30),(15,29),(17,36),(13,37)],BRASS[1])
    pixel_line(d,[(12,31),(14,35)],BRASS[3])
    if returning:
        # The alternate skill marker reuses the book with a distinct return sigil.
        d.ellipse((39,40,61,62),fill=INK,outline=BRASS[2],width=1)
        arc(d,50,51,8,7,-1.6,2.1,STAR[3],2)
        poly(d,[(42,51),(40,58),(47,57)],STAR[4],None)
        star(d,50,51,4,STAR[5])
    return im.resize((128,128),Image.Resampling.NEAREST)


def bodies():
    im=blank((48,24)); d=ImageDraw.Draw(im)
    poly(d,[(4,11),(17,10),(17,14),(4,15)],LEATHER[1])
    for x in range(6,17,3): d.line((x,11,x+1,14),fill=BRASS[2])
    poly(d,[(17,6),(20,7),(21,18),(18,18)],BRASS[2])
    poly(d,[(20,10),(34,7),(44,3),(40,11),(29,15),(21,14)],METAL[2])
    poly(d,[(23,10),(35,8),(41,5),(36,10),(23,12)],METAL[4],None)
    pixel_line(d,[(25,13),(34,10)],ICE[2])
    save_asset(im.resize((96,48),Image.Resampling.NEAREST),'bodies/dash_blade.png','bodies','dash_blade',pivot=[34,24],facing='right')
    im=blank((48,28)); d=ImageDraw.Draw(im)
    poly(d,[(3,13),(16,9),(22,14),(18,19),(10,25),(5,24),(9,17)],LEATHER[1])
    pixel_line(d,[(6,15),(14,12),(16,14),(10,20)],LEATHER[2],2)
    poly(d,[(14,8),(30,7),(33,15),(18,17)],METAL[1])
    poly(d,[(24,7),(39,4),(45,6),(45,17),(40,19),(26,15)],BRASS[1])
    poly(d,[(27,8),(40,6),(40,10),(27,11)],BRASS[3],None)
    d.rectangle((40,6,44,17),fill=METAL[0]); d.line((42,7,42,16),fill=BRASS[2])
    arc(d,20,18,5,4,0,math.pi,BRASS[2])
    save_asset(im.resize((96,56),Image.Resampling.NEAREST),'bodies/recoil_gun.png','bodies','recoil_gun',pivot=[28,28],facing='right',muzzle=[88,22])
    book=tome_icon().resize((48,48),Image.Resampling.NEAREST)
    save_asset(book,'bodies/star_tome.png','bodies','star_tome',pivot=[24,36],facing='three_quarter')


def effect_frame(key, t, size, index):
    w,h=size; im=blank((w,h)); d=ImageDraw.Draw(im); cx=w/2; cy=h/2
    rng=random.Random(773)
    if key=='dash_trail':
        for j in range(5):
            y=cy+(j-2)*4; tip=w-5-t*9; length=(w-15)*(1-t*.6)*(1-abs(j-2)*.17)
            poly(d,[(tip,y),(tip-length,y-2),(tip-length*.7,y+1)],ICE[1+j%3],None)
        for j in range(7):
            x=6+j*7+t*9; y=cy+rng.randint(-11,11)
            if index%3!=j%3: d.rectangle((int(x),int(y),int(x)+1,int(y)+1),fill=ICE[2])
    elif key=='dash_circle':
        r=16+17*math.sin(t*math.pi/2); phase=t*math.tau
        for side in (0,math.pi):
            for layer in range(3):
                arc(d,cx,cy,r-layer, r-layer, phase+side,phase+side+2.5*(1-t*.25),ICE[layer+1],2)
            angle=phase+side+2.5*(1-t*.25)
            star(d,cx+math.cos(angle)*r,cy+math.sin(angle)*r,3,ICE[4])
        for j in range(12):
            a=j*math.tau/12+.25; rr=r+3+t*4
            if j%3!=index%3: d.point((round(cx+math.cos(a)*rr),round(cy+math.sin(a)*rr)),fill=ICE[2])
    elif key=='muzzle':
        reach=10+25*math.sin((t*.85+.1)*math.pi)*(1-t*.5)
        for j in range(5):
            a=(j-2)*.22
            x=7+reach*math.cos(a); y=cy+reach*math.sin(a)
            poly(d,[(3,cy),(x,y-2),(x-4,y),(x+3,y+1),(4,cy+3)],FIRE[1+j%3],None)
        poly(d,[(3,cy-3),(16,cy-2),(24,cy),(15,cy+2),(3,cy+3)],FIRE[4],None)
    elif key=='pellet':
        x=w-4-t*4
        poly(d,[(2,cy),(x-3,cy-1),(x,cy),(x-3,cy+1)],FIRE[2],None)
        d.rectangle((int(x)-3,int(cy)-1,int(x)-1,int(cy)+1),fill=FIRE[4])
    elif key=='pellet_hit':
        for j in range(7):
            a=j*math.tau/7+.3; r=2+t*10
            pixel_line(d,[(cx+math.cos(a)*r*.65,cy+math.sin(a)*r*.65),(cx+math.cos(a)*r,cy+math.sin(a)*r)],FIRE[2+j%3])
        if t<.5: star(d,cx,cy,4*(1-t),FIRE[4])
    elif key=='recoil_dust':
        for j in range(9):
            x=12+j*4+t*(4+j*.6); y=cy+5+math.sin(j*2)*4-t*(2+j%3)
            r=max(1,round((3+j%3)*(1-t*.6)))
            poly(d,[(x-r,y),(x-r/2,y-r),(x+r/2,y-r),(x+r,y),(x+r/2,y+r),(x-r/2,y+r)],LEATHER[1+j%3],None)
        for j in range(5):
            pixel_line(d,[(3+j*5,cy+9+j%2),(8+j*5+t*8,cy+9+j%2)],BRASS[1])
    elif key in ('star_depart','star_arrive','star_return'):
        depart=key=='star_depart'; p=t if depart else 1-t
        collapse=1-p
        for j in range(8):
            a=j*math.tau/8+t*2; r=5+20*p
            x=cx+math.cos(a)*r*.7; y=cy+math.sin(a)*r-t*7
            star(d,x,y,2+(j%3==0)*2,STAR[2+j%4])
            pixel_line(d,[(cx+(x-cx)*.45,cy+(y-cy)*.45),(x,y)],STAR[1+j%3])
        if collapse>.1:
            poly(d,[(cx,cy-25*collapse),(cx+3*collapse,cy),(cx,cy+18*collapse),(cx-3*collapse,cy)],STAR[4],None)
            star(d,cx,cy,8*collapse,STAR[5])
        if key=='star_return': arc(d,cx,cy+15,14+4*t,5,-math.pi,math.pi,BRASS[3])
    elif key=='star_shockwave':
        r=4+30*t
        for j in range(8):
            a=j*math.tau/8+.08; b=a+.57
            arc(d,cx,cy,r,r,a,b,STAR[3],2)
            arc(d,cx,cy,r-2,r-2,a,b,STAR[2])
            mid=(a+b)/2
            x=cx+math.cos(mid)*(r+2); y=cy+math.sin(mid)*(r+2)
            if t<.8: star(d,x,y,2,STAR[4])
        if t<.25: star(d,cx,cy,8*(1-t*3),STAR[5])
    elif key=='star_anchor':
        phase=t*math.tau
        arc(d,cx,cy,19,19,0,math.tau,STAR[1])
        for j in range(4):
            a=j*math.pi/2+.12
            arc(d,cx,cy,21,21,a,a+.65,STAR[3])
            x=cx+math.cos(a+phase*.1)*23; y=cy+math.sin(a+phase*.1)*23
            star(d,x,y,2,BRASS[3])
        star(d,cx,cy,12,BRASS[2],.4)
        star(d,cx,cy,9,STAR[2+(index//2)%2],.3)
        star(d,cx,cy,4,STAR[5],.3)
        for j in range(3):
            a=phase+j*math.tau/3
            d.rectangle((round(cx+math.cos(a)*16),round(cy+math.sin(a)*16),round(cx+math.cos(a)*16)+1,round(cy+math.sin(a)*16)+1),fill=STAR[4])
    return im.resize((w*2,h*2),Image.Resampling.NEAREST)


def effects():
    definitions=[('dash_trail',(64,32),8,24,False),('dash_circle',(80,80),10,48,False),
                 ('muzzle',(48,32),6,30,False),('pellet',(24,8),4,20,True),('pellet_hit',(32,32),6,24,False),
                 ('recoil_dust',(64,32),8,20,False),('star_depart',(48,64),8,24,False),
                 ('star_arrive',(48,64),8,24,False),('star_shockwave',(80,80),10,24,False),
                 ('star_anchor',(64,64),12,12,True),('star_return',(48,64),8,24,False)]
    for key,size,count,fps,loop in definitions:
        frames=[effect_frame(key,i/count,size,i) for i in range(count)]
        atlas=blank((frames[0].width*count,frames[0].height))
        for i,frame in enumerate(frames):
            p=OUT/'effects'/key/f'{i:02d}.png'; p.parent.mkdir(parents=True,exist_ok=True); frame.save(p)
            atlas.paste(frame,(i*frame.width,0))
        pivot={'muzzle':[6,32],'dash_trail':[118,32],'pellet':[40,8]}.get(key,[frames[0].width//2,frames[0].height//2])
        save_asset(atlas,f'effects/{key}.png','effects',key,frame_size=list(frames[0].size),frames=count,fps=fps,loop=loop,
                   pivot=pivot,unique_frames=len({f.tobytes() for f in frames}))


def label_font(size):
    for path in ['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/arial.ttf']:
        if Path(path).exists(): return ImageFont.truetype(path,size)
    return ImageFont.load_default()


def boards():
    board=Image.new('RGB',(1200,780),'#141e20'); d=ImageDraw.Draw(board)
    d.text((32,22),'MOBILITY WEAPONS / PIXEL ART 01',font=label_font(25),fill='#e3e8db')
    names=['\u7a81\u8fdb\u77ed\u5203','\u5de8\u578b\u624b\u6301\u706b\u70ae','\u79fb\u661f\u79d8\u5178']
    ids=['dash_blade','recoil_gun','star_tome']
    samples=[['dash_trail','dash_circle'],['muzzle','pellet','recoil_dust'],['star_arrive','star_shockwave','star_anchor']]
    for i,key in enumerate(ids):
        x=24+i*394
        d.rounded_rectangle((x,80,x+380,749),radius=9,fill='#202d30',outline='#3a4b4b',width=1)
        d.text((x+20,98),names[i],font=label_font(25),fill=['#bce8df','#f1ce91','#c0c9ef'][i])
        icon=Image.open(OUT/'icons'/f'{key}.png').convert('RGBA')
        board.paste(icon.resize((256,256),Image.Resampling.NEAREST),(x+61,142),icon.resize((256,256),Image.Resampling.NEAREST))
        board.paste(icon.resize((48,48),Image.Resampling.NEAREST),(x+36,417),icon.resize((48,48),Image.Resampling.NEAREST))
        d.text((x+99,425),'128 px / HUD 48 px',font=label_font(16),fill='#afc0bb')
        for j,effect in enumerate(samples[i]):
            record=manifest['effects'][effect]; fw,fh=record['frame_size']; frame=Image.open(OUT/record['path']).crop((fw*2,0,fw*3,fh))
            scale=min(1.0,320/fw,95/fh); frame=frame.resize((round(fw*scale),round(fh*scale)),Image.Resampling.NEAREST)
            y=485+j*80
            board.paste(frame,(x+20,y),frame)
            d.text((x+190,y+23),effect.replace('_',' '),font=label_font(14),fill='#afc0bb')
    PREVIEWS.mkdir(parents=True,exist_ok=True)
    board.save(PREVIEWS/'art_board.png')
    icons=Image.new('RGB',(688,200),'#202b2b'); di=ImageDraw.Draw(icons)
    for i,key in enumerate(['dash_blade','recoil_gun','star_tome','star_tome_return']):
        im=Image.open(OUT/'icons'/f'{key}.png'); icons.paste(im,(16+i*168,12),im)
        di.text((16+i*168,151),['DASH BLADE','HAND CANNON','STAR TOME','RETURN READY'][i],font=label_font(14),fill='#d4ddcf')
    icons.save(PREVIEWS/'icons.png')


def assemble_captures(frames_dir):
    names=['\u7a81\u8fdb\u77ed\u5203','\u5de8\u578b\u624b\u6301\u706b\u70ae','\u79fb\u661f\u79d8\u5178']
    ids=['dash_blade','recoil_gun','star_tome']
    blurbs=['\u77ed\u51b2 / \u7ec8\u70b9\u5468\u8eab\u5706\u65a9','\u524d\u65b9\u6563\u5f39 / \u540c\u65f6\u5411\u540e\u6ed1\u9000','\u95ea\u73b0\u9707\u5f00 / \u7559\u5370\u8fd4\u56de']
    rendered=[]
    for frame in range(REVIEW_FRAMES):
        board=Image.new('RGB',(1232,660),'#131e21'); d=ImageDraw.Draw(board)
        d.text((24,16),'MOBILITY WEAPONS / ART MOTION REVIEW',font=label_font(24),fill='#e2e9dd')
        d.text((24,56),'\u539f\u521b\u50cf\u7d20\u7d20\u6750 \u00b7 Godot \u6218\u6597\u80cc\u666f\u4e2d\u7684\u53d7\u63a7\u7f8e\u672f\u9884\u6f14',font=label_font(16),fill='#a9bebc')
        for i,key in enumerate(ids):
            x=16+i*408
            d.rounded_rectangle((x,98,x+392,625),radius=8,fill='#233034',outline='#405154')
            icon_key='star_tome_return' if key=='star_tome' and 0.3<=frame/REVIEW_FPS<1.6 else key
            im=Image.open(OUT/'icons'/f'{icon_key}.png').convert('RGBA')
            board.paste(im,(x+14,116),im)
            d.text((x+151,139),names[i],font=label_font(26),fill=['#b8e5de','#e9c98c','#c2caed'][i])
            d.text((x+151,183),'HAND CANNON' if key=='recoil_gun' else key.replace('_',' ').upper(),font=label_font(14),fill='#94aba9')
            diagram=Image.open(PREVIEWS/'godot'/f'{key}_indicator_alpha.png').convert('RGBA')
            bounds=diagram.getbbox()
            diagram=diagram.crop((max(0,bounds[0]-12),max(0,bounds[1]-12),min(diagram.width,bounds[2]+12),min(diagram.height,bounds[3]+12)))
            factor=min(330/diagram.width,150/diagram.height)
            diagram=diagram.resize((round(diagram.width*factor),round(diagram.height*factor)),Image.Resampling.LANCZOS)
            board.paste(diagram,(x+(392-diagram.width)//2,247+(150-diagram.height)//2),diagram)
            shot=Image.open(Path(frames_dir)/key/f'{frame:03d}.png').convert('RGB')
            # Two-times reduction retains crisp engine pixels. Do not retouch the effect.
            shot=shot.crop((340,210,1140,590)).resize((400,190),Image.Resampling.NEAREST)
            board.paste(shot.crop((4,0,396,190)),(x,408))
            d.text((x+16,600),blurbs[i],font=label_font(15),fill='#ccd7ca')
        d.text((20,638),'\u7f8e\u672f\u9996\u7a3f\uff0c\u5c1a\u672a\u63a5\u5165\u6b63\u5f0f\u6b66\u5668\u903b\u8f91\u3002\u5f00\u5934\u4e0e\u8fd4\u56de\u72b6\u6001\u52a0\u505c\u7559\u4fbf\u4e8e\u67e5\u770b\u3002',font=label_font(13),fill='#92aaa5')
        rendered.append(board)
    durations=[1000//REVIEW_FPS]*REVIEW_FRAMES; durations[0]=800; durations[round(1.15*REVIEW_FPS)]=600; durations[-1]=500
    rendered[0].save(PREVIEWS/'motion.gif',save_all=True,append_images=rendered[1:],duration=durations,loop=0,optimize=False)
    overview=rendered[10].copy()
    for i,key in enumerate(ids):
        shot=Image.open(PREVIEWS/'godot'/f'{key}_effect.png').convert('RGB').crop((340,210,1140,590)).resize((400,190),Image.Resampling.NEAREST)
        overview.paste(shot.crop((4,0,396,190)),(16+i*408,408))
    overview.save(PREVIEWS/'review_overview.png')
    for key in ids:
        frames=[]
        for index in range(REVIEW_FRAMES):
            im=Image.open(Path(frames_dir)/key/f'{index:03d}.png').convert('RGB')
            frames.append(im.resize((960,540),Image.Resampling.NEAREST))
        frames[0].save(PREVIEWS/f'{key}.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False)
    print(f'CAPTURES_ASSEMBLED {REVIEW_FRAMES*3} engine frames; composite and 3 individual GIFs')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--boards-only',action='store_true')
    parser.add_argument('--assemble-captures',type=Path)
    args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    if args.assemble_captures:
        assemble_captures(args.assemble_captures); return
    if args.boards_only:
        manifest.update(json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))); boards(); return
    for key,im in [('dash_blade',dagger_icon()),('recoil_gun',gun_icon()),('star_tome',tome_icon()),('star_tome_return',tome_icon(True))]:
        save_asset(im,f'icons/{key}.png','icons',key,pixel_grid=2)
    bodies(); effects(); boards()
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for section in ('icons','bodies','effects'):
        for key,item in manifest[section].items():
            assert item['alpha']==[0,255], (key,'binary alpha')
            if section=='effects': assert item['unique_frames']==item['frames'],(key,'duplicate frames')
    print('MOBILITY_ART_READY icons=4 bodies=3 effect_atlases=11 frames=88 binary_alpha=true')
    print(OUT)


if __name__=='__main__':
    main()
