"""Source-derived high resolution B/C, original-colour D, and simplified Q."""
from pathlib import Path
import hashlib
import io
import json
import shutil
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
import cavern_image_processing as art

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/analysis/obstacle_revision_v02_20261013'
SKILL=ROOT/'.agents/skills/picxel-external-images'
sys.path.insert(0,str(SKILL/'vendor/picxel/scripts'))
import picxel as px
art.SOURCES={p.name:p for p in (ROOT/'artifacts/analysis/battle_scene_20261012/sucai').rglob('*.png')}
Q=['decal_single_brick','decal_stacked_bricks','decal_brick_fragments','decal_scattered_stones','decal_high_rubble','decal_low_rubble','decal_flat_stones']

def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(im,name):im.save(OUT/'after'/name);return im
def backup(path):
    dest=OUT/'before'/path.name
    if not dest.exists():shutil.copy2(path,dest)
    return Image.open(dest).convert('RGBA')

def simplify_q(im,index):
    a=np.array(im.convert('RGBA'));mask=a[:,:,3]>0
    # Keep the existing silhouette and separate pebbles. Median lighting removes
    # speckled texture; the original dark connected seams retain stacked faces.
    lum=a[:,:,:3]@np.array([.2126,.7152,.0722])
    filled=lum[tuple(ndi.distance_transform_edt(~mask,return_distances=False,return_indices=True))]
    soft=ndi.median_filter(filled,size=3 if index<3 or index in [4,5] else 1)
    if index==2:
        palette=np.array([[26,30,29],[78,68,56],[105,90,70],[120,107,85],[136,135,124]],dtype=np.uint8)
        levels=np.digitize(soft,[39,80,104,125])
    elif index<2:
        palette=np.array([[26,30,29],[42,46,42],[68,66,59],[122,121,111],[136,135,124]],dtype=np.uint8)
        levels=np.digitize(soft,[36,59,91,130])
    else:
        palette=np.array([[20,26,26],[41,52,51],[61,73,70],[114,126,116],[135,145,134]],dtype=np.uint8)
        levels=np.digitize(soft,[33,62,92,132])
    # One local majority pass removes isolated colour sparks without dithering.
    for _ in range(2 if index in [0,1,4,5] else 1):
        votes=np.stack([ndi.uniform_filter((levels==i).astype(float),size=3,mode='nearest') for i in range(5)])
        mode=votes.argmax(0);strength=votes.max(0)
        levels=np.where(strength>=.56,mode,levels)
    labels,count=ndi.label(mask,structure=np.ones((3,3)))
    outside=~ndi.binary_fill_holes(mask)
    edge=mask&ndi.binary_dilation(outside,structure=ndi.generate_binary_structure(2,1))
    areas=np.bincount(labels.ravel())
    # A tiny pebble needs a lit centre more than a solid black silhouette.
    edge&=areas[labels]>=12
    levels[edge]=0
    result=a.copy();result[:,:,:3]=palette[levels];result[~mask]=0
    assert np.array_equal(result[:,:,3],a[:,:,3])
    return Image.fromarray(result)

def build():
    for d in ['before','after','q_refs','q_work','sources']:(OUT/d).mkdir(parents=True,exist_ok=True)
    config=read(ROOT/'data_config/cavern_battlefield.json');records=[]
    for i,box in enumerate([(.613,.894,.69,.95),(.691,.905,.741,.951)]):
        path=ROOT/config['rubble'][i]['texture'][6:];old=backup(path)
        native=art.scene_material(art.loose_stone_source(i),'stone')
        im=native.resize((old.width*4,old.height*4),Image.Resampling.NEAREST)
        save(im,path.name);config['rubble'][i]['texture_density']=4.0
        records.append({'code':f'B{i+1:02}','path':str(path),'old_size':list(old.size),'size':list(im.size),'source_crop_size':list(native.size),'method':'4x sampling from original source, not old PNG enlargement'})
    for i,(box,brightness) in enumerate([((.52,.52,.96,.97),.58),((.60,.03,.89,.47),.46),((.12,.04,.38,.46),.46),((.12,.53,.38,.94),.60)]):
        path=ROOT/config['ruins'][i]['texture'][6:];old=backup(path)
        native=art.grade(art.crop_prop('ground_view1 (6).png',box),brightness,.7)
        im=native.resize((old.width*4,old.height*4),Image.Resampling.NEAREST)
        a=np.array(im);a[:,:,3]=(a[:,:,3]*np.clip((im.height-1-np.arange(im.height))[:,None]/24,0,1)).astype('uint8')
        save(Image.fromarray(a),path.name);config['ruins'][i]['display_size']=list(old.size)
        records.append({'code':f'C{i+1:02}','path':str(path),'old_size':list(old.size),'size':list(im.size),'source_crop_size':list(native.size),'method':'4x sampling from original source; same authored far depth and display extent'})
    source=art.read('front_view1.png');front=art.remove_back(source,'checker')
    a=np.array(front);labels,_=ndi.label(a[:,:,3]>0);counts=np.bincount(labels.ravel());a[(labels>0)&(counts[labels]<256),3]=0
    front=Image.fromarray(a)
    for i,box in enumerate([(0,0,850,590),(2030,0,2752,590),(0,570,1170,1536),(1670,700,2752,1536)]):
        path=ROOT/config['foreground'][i]['texture'][6:];old=backup(path);im=front.crop(box)
        save(im,path.name);config['foreground'][i]['display_size']=list(old.size)
        raw=np.array(source.crop(box));candidate=np.array(im);opaque=candidate[:,:,3]>0
        assert np.array_equal(raw[opaque,:3],candidate[opaque,:3])
        records.append({'code':f'D{i+1:02}','path':str(path),'old_size':list(old.size),'size':list(im.size),'method':'Original-resolution crop; original RGB retained; exterior background only removed','opaque_rgb_changed':0})
    write(OUT/'depth_config.json',config)
    for i,name in enumerate(Q):
        path=ROOT/f'assets/sprites/background/wetland/{name}.png';old=backup(path)
        # Preserve a traceable historical pixel source, not a claimed HD input.
        blob=subprocess.check_output(['git','show','f1f746e:'+path.relative_to(ROOT).as_posix()],cwd=ROOT)
        original=OUT/'sources'/f'{name}_historical_128.png';original.write_bytes(blob)
        Image.open(io.BytesIO(blob)).verify()
        old.save(OUT/'q_refs'/f'{name}.png')
        im=simplify_q(old,i);save(im,path.name)
        colors=np.unique(np.array(im)[np.array(im)[:,:,3]>0,:3],axis=0)
        anchor={'subject':'Simplify existing rubble into large material planes, keeping outline, tilt and layout',
                'kind':'sprite','size':64,'keep':['silhouette','stone grouping','top/side lighting'],
                'drop':['single-pixel texture noise'],'colors':[],'palette':['#%02x%02x%02x'%tuple(c) for c in colors],'regions':[],'faces':[]}
        write(OUT/'q_refs'/f'{name}.anchor.json',anchor)
        records.append({'code':f'Q{i+1:02}','path':str(path),'old_size':list(old.size),'size':list(im.size),'colors':len(colors),'method':'Five-colour material planes and a connected exterior rim; alpha preserved'})
    write(OUT/'build_report.json',{'a_sha256':{p.name:sha(p) for p in (ROOT/'assets/sprites/background/cavern').glob('prop_*.png')},'records':records})
    previews()
    print('BUILT',len(records))

def grids():
    for name in Q:
        path=OUT/'q_work'/f'{name}-64-simplified.pxg';im=Image.open(OUT/'after'/f'{name}.png').convert('RGBA');a=np.array(im)
        colors=np.unique(a[a[:,:,3]>0,:3],axis=0);lookup={tuple(c):chr(65+i) for i,c in enumerate(colors)}
        rows=[''.join(lookup[tuple(p[:3])] if p[3] else '.' for p in row) for row in a]
        sheet=px.Sheet(path.stem,64,'sprite',f'{name}.pal',{chr(65+i):'#%02x%02x%02x'%tuple(c) for i,c in enumerate(colors)},rows,path)
        path.write_text(sheet.dump(),encoding='utf-8');assert not px.check(sheet)[0];px.render(sheet,OUT/'q_work')

def previews():
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',19)
    for group in ['B','C','D','Q']:
        records=[r for r in read(OUT/'build_report.json')['records'] if r['code'].startswith(group)]
        im=Image.new('RGB',(900,260*len(records)),'#424a46');draw=ImageDraw.Draw(im)
        for i,r in enumerate(records):
            draw.text((16,i*260+10),r['code']+'   before / after',font=font,fill='white')
            for j,folder in enumerate(['before','after']):
                a=Image.open(OUT/folder/Path(r['path']).name).convert('RGBA')
                ratio=min(400/a.width,205/a.height)
                a=a.resize((round(a.width*ratio),round(a.height*ratio)),Image.Resampling.NEAREST)
                im.paste(a,(j*450+(450-a.width)//2,i*260+44),a)
        im.save(OUT/f'{group}_before_after.png')

def install():
    report=read(OUT/'build_report.json')
    for name,digest in report['a_sha256'].items():assert sha(ROOT/'assets/sprites/background/cavern'/name)==digest
    for r in report['records']:shutil.copy2(OUT/'after'/Path(r['path']).name,r['path'])
    shutil.copy2(OUT/'depth_config.json',ROOT/'data_config/cavern_battlefield.json')
    for name in Q:
        a=Image.open(OUT/'after'/f'{name}.png').convert('RGBA')
        assert px.load(OUT/'q_work'/f'{name}-64-simplified.pxg').image().tobytes()==a.tobytes()
    print('INSTALLED_BCDQ; A_UNCHANGED')

if __name__=='__main__':{'build':build,'grids':grids,'install':install}[sys.argv[1]]()
