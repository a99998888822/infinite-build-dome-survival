"""Repair existing pixel art and bake display frames at their authored world size.

No image model, invented animation or source replacement. Build is non-mutating;
--install copies validated candidates only. The immutable before/ archive makes
the review reproducible even after installation. Non-Picxel frame sizes are
explicit integration derivatives, not new high-resolution source artwork.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / 'temp/artifacts/previews/edge_repair_20261013'
BEFORE = TASK / 'before'
AFTER = TASK / 'after'
DISPLAY = 'assets/sprites/display_clarity'
STATES = ['neutral', 'downcast', 'displeased', 'smile', 'delighted']
# Retired stone, portrait and old player sources were removed on 2026-10-15.
APPROVED_CATEGORIES = {'finance'}
SKILL = ROOT / '.agents/skills/picxel-external-images'
sys.path.insert(0, str(SKILL / 'vendor/picxel/scripts'))
import picxel as px


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def snapshot():
    if (TASK/'before_manifest.json').exists():
        for entry in read(TASK/'before_manifest.json'):
            if not (BEFORE/entry['path']).is_file(): continue
            assert sha(BEFORE/entry['path']) == entry['sha256'], entry['path']
        return
    patterns = ['assets/sprites/background/wetland/ruin_*.png',
                'assets/sprites/player/combat/*', 'assets/sprites/enemies/combat/*',
                'assets/sprites/enemies/iron_knight/*', 'assets/sprites/enemies/echo_bat/*',
                'assets/sprites/enemies/underworld_wolf/*', 'assets/ui/finance/portraits/*',
                'assets/ui/finance/goblin*', 'assets/ui/finance/bank_counter_desk_picxel.png',
                'assets/ui/finance/finance_background.png', 'assets/ui/settlement/goblin_reactions.png',
                'artifacts/editable/finance_background/*', 'data_config/characters.json',
                'data_config/cavern_meadow_battlefield.json','scenes/player/player_root.tscn',
                'scenes/enemy/*.tscn','scripts/player/player_controller.gd',
                'scripts/enemies/echo_bat.gd','scripts/enemies/elite_rusher.gd',
                'scripts/enemies/underworld_wolf.gd','scripts/ui/bank_counter_portrait.gd',
                'scripts/ui/finance_scene_layout.gd']
    paths = set()
    for pattern in patterns:
        for p in ROOT.glob(pattern):
            paths.update(q for q in p.rglob('*') if q.is_file()) if p.is_dir() else paths.add(p)
    entries = []
    for path in sorted(paths):
        if path.suffix in ['.import','.uid']: continue
        rel = path.relative_to(ROOT)
        dest = BEFORE/rel
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,dest)
        entries.append({'path':rel.as_posix(),'sha256':sha(path)})
    write(TASK/'before_manifest.json',entries)


def palette(im):
    a = np.array(im.convert('RGBA'))
    colors = np.unique(a[a[:,:,3]>0,:3],axis=0)
    return colors[np.argsort(colors @ np.array([.2126,.7152,.0722]))]


def save_grid(im, path, kind='sprite'):
    colors = palette(im)
    assert len(colors)<=16, (path,len(colors))
    a = np.array(im.convert('RGBA'))
    template=BEFORE/path.relative_to(AFTER) if path.is_relative_to(AFTER) else None
    if template is not None and template.exists():
        previous=px.load(template)
        if previous.image().tobytes()==im.convert('RGBA').tobytes():
            path.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(template,path)
            return previous
    else: previous=None
    lookup = {tuple(c):chr(65+i) for i,c in enumerate(colors)}
    rows = [''.join(lookup[tuple(p[:3])] if p[3] else '.' for p in row) for row in a]
    symbols = {chr(65+i):'#%02x%02x%02x'%tuple(c) for i,c in enumerate(colors)}
    sheet = px.Sheet(path.stem,im.width,kind,'custom',symbols,rows,path)
    if previous is not None and set(symbols.values())<=set(previous.colors.values()):
        reverse={value:key for key,value in previous.colors.items()}
        remap={key:reverse[value] for key,value in symbols.items()}
        sheet.colors=previous.colors
        sheet.palette=previous.palette
        sheet.name=previous.name
        sheet.rows=[''.join(remap.get(c,c) for c in row) for row in rows]
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(sheet.dump(),encoding='utf-8')
    assert sheet.image().tobytes()==im.convert('RGBA').tobytes()
    return sheet


def repair_contour(im, kind):
    a=np.array(im.convert('RGBA')); mask=a[:,:,3]>0
    colors=palette(im); ink=colors[1] if kind in ['stone','portrait'] else colors[0]
    # Exterior only: internal holes, eyes, mouth and stone cracks are protected.
    outside=~ndi.binary_fill_holes(mask)
    edge=mask & ndi.binary_dilation(outside,structure=ndi.generate_binary_structure(2,1))
    ys,xs=np.where(mask)
    if kind=='stone':
        # Ground-contact moss keeps its old palette and outline instead of a ring.
        edge &= np.indices(mask.shape)[0] < int(ys.min()+(ys.max()-ys.min())*.90)
    elif kind=='portrait':
        # Hands have intentionally narrow skin-colored tips. Only strengthen
        # their already-dark outline; do not turn the fingers into black rods.
        y=np.indices(mask.shape)[0]
        luminance=a[:,:,:3]@np.array([.2126,.7152,.0722])
        edge &= (y<210)|(luminance<65)
    a[edge,:3]=ink
    a[~mask]=0
    return Image.fromarray(a)


def display_frame(im, factor, size, kind):
    """Nearest-neighbor player display frame with a one-pixel contour.

    A single uniform transform about the original frame center preserves pose
    registration. There is no per-frame trim/refit or animation normalization.
    """
    assert kind=='player'
    im=im.convert('RGBA'); colors=palette(im)
    # Preserve the finished 64px face's one-pixel eyes.
    offset=(im.width/2-size/2/factor,im.height/2-size/2/factor)
    small=im.transform((size,size),Image.Transform.AFFINE,
        (1/factor,0,offset[0],0,1/factor,offset[1]),Image.Resampling.NEAREST)
    a=np.array(small); mask=a[:,:,3]>=96
    rgb=a[:,:,:3].astype(float)
    distance=((rgb[:,:,None,:]-colors[None,None,:,:])**2*np.array([.25,.55,.20])).sum(axis=3)
    a[:,:,:3]=colors[np.argmin(distance,axis=2)]
    a[:,:,3]=mask*255; a[~mask]=0
    # Resolve the contour on the final display pixel grid.
    outside=~ndi.binary_fill_holes(mask)
    edge=mask & ndi.binary_dilation(outside,structure=ndi.generate_binary_structure(2,1))
    a[edge,:3]=colors[0]
    return Image.fromarray(a)


def put(im, rel):
    path=AFTER/rel;path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
    return path


def atlas(frames, rel):
    w,h=frames[0].size
    image=Image.new('RGBA',(w*len(frames),h))
    for i,frame in enumerate(frames):image.paste(frame,(i*w,0))
    put(image,rel)


def original(rel):
    return Image.open(BEFORE/rel).convert('RGBA')


def build():
    snapshot(); records=[]
    rel='assets/ui/finance/bank_counter_desk_picxel.png'
    put(repair_contour(original(rel),'desk'),rel)
    records.append({'id':'small_desk','category':'finance','before':rel,'after':rel,'frames':1})
    # Repair selected structural lines on the existing 688x384 editable scene.
    base_rel='artifacts/editable/finance_background/pixel_background.png'
    bank=original(base_rel);d=ImageDraw.Draw(bank)
    ink='#292a2f'; wood='#aa8357';shade='#45352d'
    paths=[[(1,270),(205,270),(229,222)],[(1,274),(203,274)],
           [(6,279),(6,335),(56,338)],[(63,281),(63,337)],
           [(73,282),(73,337),(122,338),(122,284)],[(133,283),(133,337),(186,337),(186,282)],
           [(232,218),(499,218),(559,311)],[(207,315),(551,315)],
           [(195,329),(562,329)],[(211,345),(211,373)],[(549,345),(549,373)]]
    for line in paths:d.line(line,fill=ink,width=1)
    for line in [[(1,258),(201,258),(220,226)],[(209,319),(549,319)],[(200,325),(559,325)]]:
        d.line(line,fill=wood,width=1)
    put(bank,base_rel)
    source=Image.open(ROOT/'artifacts/sources/finance/finance_table_ui_scroll_short.png').convert('RGBA')
    mask=Image.open(ROOT/'artifacts/editable/finance_background/scroll_mask.png').convert('L')
    composite=Image.composite(source,bank.resize(source.size,Image.Resampling.NEAREST),mask)
    rel='assets/ui/finance/finance_background.png';put(composite,rel)
    records.append({'id':'wide_desk','category':'finance','before':rel,'after':rel,'frames':1})
    # Editable tiles remain synchronized with the composited scene.
    for row in range(3):
        for col in range(6):
            dest=AFTER/f'artifacts/editable/finance_background/tiles/bank-r{row+1}-c{col+1}-128.pxg'
            tile=px.load(BEFORE/dest.relative_to(AFTER)).image()
            visible=bank.crop((col*128,row*128,min(bank.width,(col+1)*128),(row+1)*128))
            tile.paste(visible,(0,0))
            save_grid(tile,dest,'tile')
    factors={}
    for rec in records:
        rec['before_sha256']=sha(BEFORE/rec['before']);rec['after_sha256']=sha(AFTER/rec['after'])
    write(TASK/'repair_manifest.json',{'method':'Local contour repair and palette-constrained coverage resampling; no image generation','records':records,'wolf_source_scales':factors})
    validate_frames(records,factors)
    contact_sheets(records)
    print('BUILT',len(records),'resource groups',TASK)


def contact_sheets(records):
    for category in sorted(APPROVED_CATEGORIES):
        rows=[r for r in records if r['category']==category]
        canvas=Image.new('RGB',(1024,len(rows)*310),(37,42,48));draw=ImageDraw.Draw(canvas)
        for i,r in enumerate(rows):
            for col,base,field in [(0,BEFORE,'before'),(1,AFTER,'after')]:
                im=Image.open(base/r[field]).convert('RGBA')
                fs=r.get('before_frame_size',r.get('frame_size',im.height)) if col==0 else r.get('frame_size',im.height)
                if r.get('frames',1)>1:im=im.crop((0,0,fs,fs))
                if category!='finance':im=im.crop(im.getbbox())
                else:im.thumbnail((490,250),Image.Resampling.NEAREST)
                scale=max(1,min(490//im.width,250//im.height));im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
                canvas.paste(im,(col*512+(512-im.width)//2,i*310+40),im)
                draw.text((col*512+14,i*310+12),r['id']+(' | BEFORE' if col==0 else ' | AFTER')+' x'+str(scale),fill='white')
        canvas.save(TASK/(category+'_comparison.png'))


def validate_frames(records, wolf_scales):
    checks=[]
    for rec in records:
        if rec['category']=='finance':continue  # HD scroll is intentionally composited.
        old=original(rec['before']);new=Image.open(AFTER/rec['after']).convert('RGBA')
        count=rec.get('frames',1);size=rec['frame_size'];old_size=rec.get('before_frame_size',size)
        assert new.size==(size*count,size),rec['id']
        for index in range(count):
            frame=new.crop((index*size,0,(index+1)*size,size));a=np.array(frame)
            assert len(palette(frame))<=16 and set(np.unique(a[:,:,3]))<={0,255},rec['id']
            assert frame.getbbox() is not None,rec['id']
            deviation=0.0
            if rec['category'] in ['player','enemy']:
                assert not a[0,:,3].any() and not a[-1,:,3].any() and not a[:,0,3].any() and not a[:,-1,3].any(),(rec['id'],index,'clipped')
                source=old.crop((index*old_size,0,(index+1)*old_size,old_size))
                factor=rec.get('factor',1)
                if rec.get('per_pose_scale'):factor=wolf_scales[rec['id'][5:]+':'+str(index)]
                expected=(np.array(source.getbbox(),dtype=float)-old_size/2)*factor+size/2
                deviation=float(np.abs(np.array(frame.getbbox())-expected).max())
                assert deviation<=1.6,(rec['id'],index,deviation)
            else:
                assert np.array_equal(np.array(old)[:,:,3],a[:,:,3]),rec['id']
            checks.append({'asset':rec['id'],'frame':index,'colors':len(palette(frame)),'bbox_error_world_px':round(deviation,4)})
    write(TASK/'pixel_validation.json',{'checks':len(checks),'failures':0,'frames':checks})


def approved_output(path):
    rel=Path(path).as_posix()
    return not rel.startswith(DISPLAY+'/') or rel.startswith(DISPLAY+'/player/')


def install():
    report=read(TASK/'repair_manifest.json')
    report['records']=[r for r in report['records'] if r['category'] in APPROVED_CATEGORIES]
    validate_frames(report['records'],report['wolf_source_scales'])
    for r in report['records']:
        assert sha(AFTER/r['after'])==r['after_sha256']
    installed=[]
    for p in sorted(AFTER.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(AFTER);dest=ROOT/rel
        if rel.as_posix() not in {r['after'] for r in report['records']} and not rel.as_posix().startswith('artifacts/editable/finance_background/'):continue
        dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
        installed.append({'path':rel.as_posix(),'sha256':sha(dest)})
    write(TASK/'installed_files.json',installed)
    refresh_metadata(report)
    print('INSTALLED',len(installed),'files')


def refresh_metadata(report):
    rel='artifacts/editable/finance_background/source-map.json';data=read(BEFORE/rel)
    data['asset_sha256']=sha(ROOT/data['asset']);data['edge_repair_revision']='20261013-local-wood-structure-lines'
    for row in data['tiles']:row['sha256']=sha(ROOT/row['grid'])
    write(ROOT/rel,data)



if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    install() if args.install else build()
