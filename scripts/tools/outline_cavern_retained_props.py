"""One-pixel exterior-only repairs; preserve every interior RGBA byte.

Picxel stores the one-colour repair overlay on a padded 128px canvas. The
production derivative keeps the existing non-square size and interior palette.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT=Path(__file__).resolve().parents[2]
TASK=ROOT/'artifacts/analysis/obstacle_revision_20261013'
SKILL=ROOT/'.agents/skills/picxel-external-images'
sys.path.insert(0,str(SKILL/'vendor/picxel/scripts'))
import picxel as px

def prepare():
    for directory in ['before','refs','work','after']:(TASK/directory).mkdir(parents=True,exist_ok=True)
    records=[]
    for code,name in [('A01','rock'),('A05','log')]:
        path=ROOT/f'assets/sprites/background/cavern/prop_{name}.png'
        before=TASK/'before'/path.name
        if not before.exists():shutil.copy2(path,before)
        a=np.array(Image.open(before).convert('RGBA'))
        opaque=a[:,:,3]>0
        pad=np.pad(~opaque,1,constant_values=True)
        seed=np.zeros_like(pad);seed[0,:]=seed[-1,:]=True;seed[:,0]=seed[:,-1]=True
        outside=ndi.binary_propagation(seed,mask=pad)
        edge=ndi.binary_dilation(outside,structure=ndi.generate_binary_structure(2,1))[1:-1,1:-1]&opaque
        # Dark purple sampled from the existing retained art; no new palette ramp.
        colour=(19,16,27)
        overlay=np.zeros((128,128,4),dtype=np.uint8)
        ox,oy=(128-a.shape[1])//2,(128-a.shape[0])//2
        section=overlay[oy:oy+a.shape[0],ox:ox+a.shape[1]]
        section[edge]=(*colour,255)
        Image.fromarray(overlay).save(TASK/'refs'/f'{name}_outline.png')
        anchor={'subject':f'Exterior-only repair overlay for {code}; exact padded native pixels',
                'kind':'sprite','size':128,'keep':['Every marked exterior pixel at its exact coordinate'],
                'drop':[],'colors':['#13101b'],'palette':['#13101b'],'regions':[],'faces':[]}
        (TASK/'refs'/f'{name}_outline.anchor.json').write_text(json.dumps(anchor,indent=2),encoding='utf-8')
        b=a.copy();b[edge,:3]=colour
        assert np.array_equal(a[:,:,3],b[:,:,3]) and np.array_equal(a[~edge],b[~edge])
        Image.fromarray(b).save(TASK/'after'/path.name)
        records.append({'code':code,'name':name,'path':str(path),'size':[a.shape[1],a.shape[0]],
            'offset':[ox,oy],'edge_pixels':int(edge.sum()),'changed_pixels':int(np.any(a!=b,axis=2).sum()),
            'interior_changed_pixels':0,'alpha_changed_pixels':0,
            'before_sha256':hashlib.sha256(before.read_bytes()).hexdigest(),
            'after_sha256':hashlib.sha256((TASK/'after'/path.name).read_bytes()).hexdigest()})
    (TASK/'edge_report.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    board=Image.new('RGB',(960,600),'#454b48');draw=ImageDraw.Draw(board)
    for i,r in enumerate(records):
        draw.text((20,i*290+15),r['code']+'  '+r['name']+'   before / after',font=font,fill='white')
        for j,folder in enumerate(['before','after']):
            im=Image.open(TASK/folder/f'prop_{r["name"]}.png').convert('RGBA').resize((r['size'][0]*3,r['size'][1]*3),Image.Resampling.NEAREST)
            board.paste(im,(50+j*470,i*290+70),im)
    board.save(TASK/'edge_before_after.png')
    print(json.dumps(records))

def exact_grids():
    for r in json.loads((TASK/'edge_report.json').read_text(encoding='utf-8')):
        name=r['name']+'_outline'
        im=np.array(Image.open(TASK/'refs'/f'{name}.png'))
        rows=[''.join('A' if p[3] else '.' for p in line) for line in im]
        path=TASK/'work'/f'{name}-128-exact.pxg'
        sheet=px.Sheet(path.stem,128,'sprite',f'{name}.pal',{'A':'#13101b'},rows,path)
        path.write_text(sheet.dump(),encoding='utf-8')
        assert not px.check(sheet)[0]
        px.render(sheet,TASK/'work')

def install():
    for r in json.loads((TASK/'edge_report.json').read_text(encoding='utf-8')):
        name=r['name'];native=Image.open(TASK/'before'/f'prop_{name}.png').convert('RGBA')
        sheet=px.load(TASK/'work'/f'{name}_outline-128-exact.pxg')
        x,y=r['offset'];w,h=r['size']
        native.alpha_composite(sheet.image().crop((x,y,x+w,y+h)))
        target=TASK/'after'/f'prop_{name}.png'
        assert native.tobytes()==Image.open(target).convert('RGBA').tobytes()
        shutil.copy2(target,r['path'])
    print('INSTALLED_EXTERIOR_ONLY')

if __name__=='__main__':
    {'prepare':prepare,'grids':exact_grids,'install':install}[sys.argv[1]]()
