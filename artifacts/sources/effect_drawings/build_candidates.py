"""Locally authored, deterministic pixel animation study. No image model/API.

Only writes into this review directory. Production assets/scripts are read-only.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
TAU = math.tau
ICE = ['#24414a', '#417d89', '#83c8cc', '#defff0']
STAR = ['#292c47', '#565783', '#969bdd', '#ddedff']
GOLD = '#e5c783'
STEEL = ['#293b45', '#526c78', '#8caab7', '#cbdccf']
DEFS = {
    'dash_circle': (160, 160, 10, 48, [80, 80]),
    'star_depart': (96, 128, 8, 24, [48, 64]),
    'star_arrive': (96, 128, 8, 24, [48, 64]),
    'star_return': (96, 128, 8, 24, [48, 64]),
    'star_anchor': (128, 128, 12, 12, [64, 64]),
    'star_shockwave': (160, 160, 10, 24, [80, 80]),
    'dash_trail': (128, 64, 8, 24, [118, 32]),
    'wind_blade': (128, 96, 12, 12 / .46, [64, 48]),
    'flail_trail': (320, 320, 18, 30, [160, 160]),
}


def rgba(hex_color):
    return tuple(bytes.fromhex(hex_color.lstrip('#'))) + (255,)


def diamond(d, x, y, rx, ry, palette=STAR, lean=0):
    x, y, rx, ry = round(x), round(y), max(1, round(rx)), max(2, round(ry))
    points = [(x + lean, y - ry), (x + rx, y), (x - lean, y + ry), (x - rx, y)]
    d.polygon(points, fill=palette[0])
    d.polygon([(x + lean, y - ry + 1), (x, y), (x - rx + 1, y)], fill=palette[3])
    d.polygon([(x + lean, y - ry + 1), (x + rx - 1, y), (x, y)], fill=palette[2])
    d.polygon([(x, y), (x + rx - 1, y), (x - lean, y + ry - 1)], fill=palette[1])


def burst(d, x, y, radius, palette=ICE):
    x, y, radius = round(x), round(y), max(2, round(radius))
    p = [(x, y-radius), (x+2,y-2), (x+radius,y), (x+2,y+2),
         (x,y+radius), (x-2,y+2), (x-radius,y), (x-2,y-2)]
    d.polygon(p, fill=palette[2])
    d.rectangle((x-1,y-1,x+1,y+1),fill=palette[3])


def ribbon(im, center, radius, start, span, thickness, palette, seed=0, y_ratio=1, peak=.68):
    """A filled blade with a dark back, broad body, and a hard cutting edge.

    All samples live on the authored 2px grid. No antialiased paths/resampling.
    """
    px = im.load()
    cx, cy = center
    for y in range(im.height):
        for x in range(im.width):
            dx, dy = x + .5 - cx, (y + .5 - cy) / y_ratio
            angle = (math.atan2(dy, dx) - start) % TAU
            if angle > span:
                continue
            u = angle / span
            taper = max(0.0, 1-abs(u-peak)/max(peak,1-peak)) ** .5
            wave = .65 * math.sin(u * 11 + seed) + .35 * math.sin(u * 23 + seed)
            outer = radius + wave
            width = max(.7, thickness * taper)
            depth = outer - math.hypot(dx, dy)
            if 0 <= depth <= width:
                color = 3 if depth < 1.05 and u > .30 else 2 if depth < width * .52 else 1
                if depth > width - 1.15:
                    color = 0
                px[x,y] = rgba(palette[color])


def dash(i, n):
    im = Image.new('RGBA', (80,80)); d=ImageDraw.Draw(im)
    t=i/(n-1)
    radius=[25,32,35,36,36,36,37,37,37,37][i]
    phase=-2.55 + t * 3.5
    fade=[1,1,1,1,.93,.8,.66,.5,.32,.18][i]
    for j, (shift,span,width) in enumerate([(0,2.28,8.5),(2.7,1.36,5.8),(4.6,.65,3.2)]):
        if i >= 8 and j==2: continue
        ribbon(im,(40,40),radius-j*.8,phase+shift,span*(.65+.35*fade),max(1.2,width*fade),ICE,j+3)
    d=ImageDraw.Draw(im)
    if i <= 2:
        a=phase+1.55
        burst(d,40+math.cos(a)*radius,40+math.sin(a)*radius,[5,4,2][i])
    for j in range(5):
        if i < 2 or (i+j)%4==0: continue
        a=phase*.45+j*1.19
        r=min(38, radius+1+(i-2)*.25)
        x,y=round(40+math.cos(a)*r),round(40+math.sin(a)*r)
        d.rectangle((x,y,x+(1 if i<7 else 0),y),fill=ICE[2 if i<6 else 1])
    return im


def teleport(key,i,n):
    im=Image.new('RGBA',(48,64)); d=ImageDraw.Draw(im)
    t=i/(n-1)
    departure=key=='star_depart'; returning=key=='star_return'
    spread=(1-t)**.72 if departure or returning else min(1,t/.72)
    phase=-.25 if returning else .20
    for j,(a,r,rx,ry) in enumerate([(-2.2,19,3,6),(-.85,23,4,8),(.2,17,3,6),(1.2,20,4,7),(2.55,21,3,5)]):
        a += phase + (-.24*t if returning else .22*t)
        x=24+math.cos(a)*r*spread*.72
        y=32+math.sin(a)*r*spread*1.15
        size=(.72+.3*(1-spread)) if departure or returning else max(.20,1-t*.72)
        if i==7 and not departure and not returning and j%2: continue
        diamond(d,x,y,rx*size,ry*size,STAR,lean=1 if j%2 else -1)
        if 2 <= i <= 6:
            tail=3 if departure or returning else -3
            tx=x+math.cos(a)*tail; ty=y+math.sin(a)*tail
            d.rectangle((round(tx),round(ty),round(tx)+1,round(ty)+1),fill=STAR[1])
    if departure:
        core=[2,3,4,5,5,4,3,1][i]
    elif returning:
        core=[1,2,3,4,6,5,3,1][i]
    else:
        core=[6,9,7,5,4,3,2,1][i]
    diamond(d,24,32,core,max(3,core*1.6),STAR)
    if returning:
        # Gold corners signal returning to the original mark, not another cast.
        for s in [-1,1]:
            x=24+s*(core+3)
            d.rectangle((x,30,x+1,32),fill=GOLD)
    if key=='star_arrive' and i<=1:
        d.rectangle((22,27,25,35),fill=STAR[3])
    if departure and i==7:
        im=Image.new('RGBA',(48,64)); d=ImageDraw.Draw(im)
        d.rectangle((23,30,24,33),fill=STAR[3])
    return im


def anchor(i,n):
    im=Image.new('RGBA',(64,64)); d=ImageDraw.Draw(im)
    # A grounded, broken, stepped seal; center identity is stable across frames.
    points=[(-23,-5),(-18,-12),(-9,-16),(9,-16),(18,-12),(23,-5),
            (23,5),(18,12),(9,16),(-9,16),(-18,12),(-23,5)]
    for j in range(0,12,3):
        p=[(32+x,34+y) for x,y in points[j:j+3]]
        d.line(p,fill=STAR[0],width=5)
        p=[(32+x,32+y) for x,y in points[j:j+3]]
        d.line(p,fill=STAR[1],width=3)
        d.line(p,fill=STAR[2] if (i//3)==j//3 else '#727caf',width=1)
    silhouette=[(32,19),(36,27),(43,32),(36,36),(32,44),(28,36),(21,32),(28,27)]
    d.polygon([(x,y+2) for x,y in silhouette],fill=STAR[0])
    d.polygon(silhouette,fill=STAR[1])
    d.polygon([(32,21),(32,32),(23,32),(29,28)],fill=STAR[2])
    d.polygon([(32,21),(35,28),(41,32),(32,32)],fill=STAR[3])
    d.polygon([(32,32),(41,32),(35,35),(32,42)],fill=STAR[2])
    d.rectangle((31,29,33,34),fill=STAR[3])
    for j,(x,y) in enumerate([(11,32),(32,17),(53,32),(32,47)]):
        diamond(d,x,y,2,3,STAR)
        if j==i//3: d.rectangle((x,y-1,x+1,y),fill=GOLD)
    return im


def shock(i,n):
    im=Image.new('RGBA',(80,80)); t=i/(n-1)
    radius=12+25*(1-(1-t)**1.6)
    width=[5,7,7,6,5,4,3,2,1.5,1][i]
    for j,(a,span) in enumerate([(-2.95,.92),(-1.70,.68),(-.63,1.03),(.72,.70),(1.8,.83)]):
        ribbon(im,(40,40),radius-(j%2)*1.5,a+.10*t,span,width*(1-.10*j),STAR,j+11)
    d=ImageDraw.Draw(im)
    if i<2: burst(d,40,40,4-i,STAR)
    for j in range(5):
        if i<2 or i>=8 and j%2: continue
        a=-2.6+j*1.21
        r=min(37.5,radius+2)
        x,y=40+math.cos(a)*r,40+math.sin(a)*r
        diamond(d,x,y,1,2 if i<6 else 1,STAR)
    return im


def trail(i,n):
    im=Image.new('RGBA',(64,32)); d=ImageDraw.Draw(im)
    for j,(tip,y,length,width) in enumerate([(60,15,51,5),(55,8,34,3),(54,23,41,3)]):
        length*=1-i*.065
        tip-=i*.65
        width=max(1,width-i*.35)
        points=[(tip,y),(tip-8,y-width),(tip-length*.64,y-width*.5),
                (tip-length,y-1),(tip-length*.86,y+1),(tip-13,y+width)]
        d.polygon(points,fill=ICE[0])
        d.polygon([(tip-1,y),(tip-10,y-width+1),(tip-length*.72,y),(tip-12,y+width-1)],fill=ICE[1])
        if i<6:
            d.polygon([(tip-1,y),(tip-11,y-width+1),(tip-length*.48,y-1),(tip-13,y+1)],fill=ICE[2])
        if i<3 and j==0: d.line([(round(tip-9),y-2),(round(tip-2),y)],fill=ICE[3],width=1)
        if i>1:
            x=round(tip-length-3)
            d.rectangle((x,y,x+2,y+1),fill=ICE[1])
    return im


def wind(i,n):
    im=Image.new('RGBA',(64,48)); t=i/n
    r=14*(1+t*.32)
    width=max(1,5.5*(1-t*.72))
    ribbon(im,(32,24),r,-1.55,1.06,width*.73,ICE,3,.62,peak=.80)
    ribbon(im,(32,24),r,-.31,1.82,width,ICE,5,.62,peak=.32)
    d=ImageDraw.Draw(im)
    for j in range(3):
        if i>8 and j==1: continue
        x=29-i*.65-j*4
        y=21+j*3
        d.polygon([(x,y),(x+3,y-1),(x+6,y),(x+2,y+1)],fill=ICE[1 if i>5 else 2])
    return im


def flail(i,n):
    im=Image.new('RGBA',(160,160))
    age=(i+.5)/30
    if age<.13 or age>.50: return im
    u=max(0,min(1,(age-.13)/.37)); eased=u*u*(3-2*u)
    current=math.radians(-65+130*eased)
    start=max(math.radians(-65),current-math.radians(25))
    span=current-start
    if span<.01: return im
    # Three separated, increasingly thick steel-blue blocks near the head.
    for j,(a,b,width) in enumerate([(0,.25,1.7),(.36,.66,2.8),(.74,1,4.4)]):
        ribbon(im,(80,80),71-j*.2,start+span*a,span*(b-a),width,STEEL,j+2,peak=.66)
    return im


def main():
    for folder in ['candidate','baseline','renders','godot_frames']:
        (OUT/folder).mkdir(exist_ok=True)
    manifest={'version':'r01','status':'review_only_not_installed','provenance':'Original deterministic local pixel drawing; no image model or API.',
              'pixel_grid':2,'ellipse_ratio':145/220,'effects':{},'protected_sha256':{}}
    protected=[ROOT/'scripts/effects/wind_blade_effect.gd',ROOT/'scripts/weapons/meteor_flail.gd',
               ROOT/'scripts/effects/mobility_atlas_effect.gd',ROOT/'scripts/weapons/mobility_weapon_runtime.gd',
               ROOT/'data_config/weapons.json']
    for key,(w,h,n,fps,pivot) in DEFS.items():
        frames=[]
        for i in range(n):
            if key=='dash_circle': im=dash(i,n)
            elif key in ['star_depart','star_arrive','star_return']: im=teleport(key,i,n)
            elif key=='star_anchor': im=anchor(i,n)
            elif key=='star_shockwave': im=shock(i,n)
            elif key=='dash_trail': im=trail(i,n)
            elif key=='wind_blade': im=wind(i,n)
            else: im=flail(i,n)
            frames.append(im.resize((w,h),Image.Resampling.NEAREST))
        sheet=Image.new('RGBA',(w*n,h))
        for i,im in enumerate(frames): sheet.paste(im,(w*i,0))
        path=OUT/'candidate'/f'{key}.png'; sheet.save(path)
        original=ROOT/'assets/sprites/weapons/mobility'/f'{key}.png'
        if original.exists():
            shutil.copy2(original,OUT/'baseline'/original.name); protected.append(original)
            assert Image.open(original).size==sheet.size
        colors={p[:3] for p in sheet.getdata() if p[3]}
        alpha=sorted(set(sheet.getchannel('A').getdata()))
        assert alpha==[0,255]
        assert len(colors)<=6,(key,len(colors))
        manifest['effects'][key]={'cell':[w,h],'frames':n,'fps':fps,'pivot':pivot,'colors':len(colors),'alpha':alpha,
            'candidate':f'candidate/{key}.png','frame_bounds':[list(im.getbbox()) if im.getbbox() else None for im in frames],
            'unique_frames':len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames}),
            'display_scale':[1.1,1.1*145/220] if key=='dash_circle' else [1,1],
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    for path in protected: manifest['protected_sha256'][path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    # A preview-only draw override. It inherits the real head path and retains
    # the original chain/head rendering; only the old fan/trailing arc is replaced.
    source=(ROOT/'scripts/weapons/meteor_flail.gd').read_text(encoding='utf-8')
    draw=source[source.index('func _draw() -> void:'):]
    start=draw.index('\t\tif local_time >= float(swing.windup)')
    end=draw.index('\t\tvar radial :=',start)
    replacement='\t\tvar frame := clampi(int(age * 30.0), 0, 17)\n\t\tdraw_texture_rect_region(review_trail, Rect2(-160, -160, 320, 320), Rect2(frame * 320, 0, 320, 320))\n'
    draw=draw[:start]+replacement+draw[end:]
    header='extends MeteorFlail\nvar review_trail: ImageTexture\n\nfunc _init() -> void:\n\treview_trail = ImageTexture.create_from_image(Image.load_from_file("'+(OUT/'candidate/flail_trail.png').as_posix()+'"))\n\n'
    (OUT/'candidate_flail.gd').write_text(header+draw,encoding='utf-8')
    print('CANDIDATES',len(DEFS),'PROTECTED',len(protected))


if __name__=='__main__': main()
