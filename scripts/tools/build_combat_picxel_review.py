"""Review-only Picxel conversion of the 37 source frames from commit 3838180.

Uses the project's external-image skill; never writes runtime assets. Each
animation has a fixed source canvas. See source-map.json for pixel transforms.
"""
from argparse import ArgumentParser, Namespace
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys
import tempfile

import numpy as np
from scipy import ndimage as nd
from PIL import Image, ImageDraw, ImageFont
import picxel_combat_source_masks as masks

ROOT=Path(__file__).resolve().parents[2]
TASK=ROOT/'artifacts/previews/combat_picxel_3838180'
TEMP=Path(tempfile.gettempdir())/'picxel-3838180'
SKILL=ROOT/'.agents/skills/picxel-external-images'
sys.path.insert(0,str(SKILL/'scripts'))
import external_pixel as external

GROUPS=('beginner','boss_walk','boss_attack','enemy_walk')
SIZES={'beginner':[64,128],'boss_walk':[128],'boss_attack':[128],'enemy_walk':[64]}
PALETTES={
    'beginner':['#252e2d','#9b9987','#b8b3a0','#d4c9b3','#be9e88','#ead1b9','#f4e6d0','#304e4b','#4e6d66','#71928a','#453a32','#695544','#8a7258','#78908d','#c2cdca','#53b7a4'],
    'boss':['#0c1420','#162335','#24364a','#354960','#4b5d77','#64758c','#8c99aa','#c6d1dc','#313143','#575269','#183e53','#205f7b','#287fa5','#38b6e0','#77ddf5','#e0f8ff'],
    'enemy':['#142028','#293840','#39484b','#4b5e57','#61715f','#798571','#97a18b','#bac0a9','#424855','#626576','#8b8da2','#b7b9ca','#5e604a','#858464','#ada784','#dde0c8'],
}

def write(path,data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def palette(group):
    return PALETTES['boss' if group.startswith('boss') else 'enemy' if group=='enemy_walk' else group]

def prepare():
    if (TASK/'source-map.json').exists():raise ValueError('Prepared revision already exists')
    records=[]
    for group in GROUPS:
        base=TASK/group
        for directory in ('refs','prepared'):(base/directory).mkdir(parents=True,exist_ok=True)
        folder=masks.SRC/('\u521d\u5fc3\u8005' if group=='beginner' else group)
        paths=sorted(folder.glob('*.png'),key=lambda p:int(re.search(r'(\d+)$',p.stem)[1]))
        for index,path in enumerate(paths,1):
            name=f'{group}_{index:02d}'
            original=Image.open(path).convert('RGBA')
            if group=='beginner':
                cut=masks.beginner(original)
                head=cut.crop((0,20,720,320)).getbbox()
                offset=(round(576-(head[0]+head[2])/2),1008-cut.getbbox()[3])
                side=1152
            elif group.startswith('boss'):
                cut,_=masks.boss(original,group,index)
                offset=(24,40);side=768
            else:
                cut=masks.enemy(original);offset=(24,36);side=768
            prepared=Image.new('RGBA',(side,side));prepared.alpha_composite(cut,offset)
            assert sum(cut.getchannel('A').tobytes())==sum(prepared.getchannel('A').tobytes()),name
            prepared.save(base/'prepared'/f'{name}.png')
            shutil.copyfile(path,base/'refs'/f'{name}.png')
            if group=='beginner':
                desc='Blond young adventurer in green cape, brown leather and complete steel sword'
                face=[(280+offset[0])/side,(160+offset[1])/side,(535+offset[0])/side,(350+offset[1])/side]
                faces=[{'box':face,'complex':True,'expression':'Neutral focused face, closed small mouth','gaze':'Three-quarter image-right; near iris sits under the upper eyelid toward image-right; far eye partly occluded by bangs','reason':'Small source irises and bangs need comparison at both pixel sizes'}]
            elif group.startswith('boss'):
                desc='Dark steel knight with closed helmet, pointed tower shield and axe-headed hammer; original action pose'
                faces=[]
            else:
                desc='Green squid-like creature, elongated head, black almond eyes, circular mouth and purple back crystals'
                faces=[{'box':[0.40,0.36,0.67,0.58],'complex':False,'expression':'Two black hollow eyes and round open mouth','gaze':'Three-quarter front view; dark eyes have no human sclera','reason':'Preserve original hollow eyes and mouth ring'}]
            anchor={'subject':desc,'kind':'sprite','size':max(SIZES[group]),'palette':palette(group),
                    'keep':['Complete source silhouette, limbs and held equipment','Fixed animation source scale and origin','Blue swing arc and impact sparks' if group=='boss_attack' else 'Original pose and identifying details'],
                    'drop':['Backdrop, floor cast shadow and detached footer','Subpixel texture and soft glow fringe'],
                    'regions':[],'faces':faces}
            write(base/'refs'/f'{name}.anchor.json',anchor)
            records.append({'group':group,'name':name,'frame':index,'source':path.relative_to(ROOT).as_posix(),
                            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_bbox':cut.getbbox(),
                            'prepared_canvas':[side,side],'translation':offset,'sizes':SIZES[group]})
    write(TASK/'source-map.json',{'remote_commit':'3838180','image_model_used':False,'records':records})
    print(f'Prepared {len(records)} source frames')

def build(group,sample=False):
    source=TASK/group
    if sample:
        base=TEMP/f'sample-{group}'
        for directory in ('refs','prepared'):(base/directory).mkdir(parents=True,exist_ok=True)
        index=8 if group=='boss_attack' else 1
        name=f'{group}_{index:02d}'
        for ending in ('.png','.anchor.json'):shutil.copyfile(source/'refs'/(name+ending),base/'refs'/(name+ending))
        shutil.copyfile(source/'prepared'/(name+'.png'),base/'prepared'/(name+'.png'))
    else:base=source
    original_square=external.px._square
    def fixed_canvas(image,size):
        assert image.width==image.height and image.width%size==0
        return image
    external.px._square=fixed_canvas
    try:
        result=external.build(Namespace(refs=base/'refs',out=base/'work',prepared_dir=base/'prepared',sizes=SIZES[group],background='none'))
        if result:raise ValueError(f'Picxel build failed: {group}')
    finally:external.px._square=original_square
    refine(base,group)

def refine(base,group):
    report=external.read(base/'work/batch-report.json')
    repairs=[]
    for entry in report['jobs']:
        source=np.asarray(Image.open(base/'prepared'/f"{entry['name']}.png").convert('RGBA'))
        opaque=source[:,:,3]>127
        lum=source[:,:,:3].astype(float)@np.array([.2126,.7152,.0722]);lum[~opaque]=255
        ink=(nd.grey_closing(lum,size=(9,9))-lum>28)&(lum<110)&opaque
        for size in SIZES[group]:
            grid=external.px.load(base/'work'/f"{entry['name']}-{size}.pxg")
            image=np.asarray(grid.image().convert('RGBA')).copy()
            visible=image[:,:,3]>127;block=source.shape[0]//size
            fraction=ink.reshape(size,block,size,block).mean(axis=(1,3))
            recover=(fraction>=(.085 if size==64 else .12))&visible
            if group=='beginner':recover[:int(size*.39)]=False
            if group=='enemy_walk':recover[:int(size*.59)]=False
            if group.startswith('boss'):recover[:]=False
            colors=palette(group);rgb=[tuple(int(c[i:i+2],16) for i in (1,3,5)) for c in colors]
            image[recover,:3]=rgb[0]
            if group.startswith('boss'):
                # Lift dark steel one/two palette steps for the dark battlefield.
                # Keep the exact grid and existing hues; effect blues stay intact.
                before=image[:,:,:3].copy()
                for old,new in ((0,1),(1,3),(2,4),(3,5),(4,6),(5,6),(6,7)):
                    where=np.all(before==rgb[old],axis=2)&visible
                    image[where,:3]=rgb[new]
                patches=source.reshape(size,block,size,block,4).transpose(0,2,1,3,4).reshape(size,size,block*block,4)
                light=patches[:,:,:,:3]@np.array([.2126,.7152,.0722])
                light[patches[:,:,:,3]<128]=-1
                order=np.argsort(light,axis=2)
                counts=(patches[:,:,:,3]>=128).sum(axis=2)
                position=np.clip(block*block-1-(counts*.15).astype(int),0,block*block-1)
                chosen=np.take_along_axis(order,position[:,:,None],axis=2)
                highlight=np.take_along_axis(patches,chosen[:,:,:,None],axis=2)[:,:,0,:3].astype(float)
                value=highlight@np.array([.2126,.7152,.0722])
                median=np.take_along_axis(np.sort(light,axis=2),np.clip(block*block-1-counts//2,0,block*block-1)[:,:,None],axis=2)[:,:,0]
                lifted=(highlight/255)**.80*255
                candidates=np.asarray(rgb)
                nearest=((lifted[:,:,None,:]-candidates)**2).sum(3).argmin(2)
                recover_light=(value-median>15)&visible
                image[recover_light,:3]=candidates[nearest[recover_light]]
            # A one-cell contour strengthens the silhouette before local face QA.
            outline=nd.binary_dilation(visible)&~visible
            if group.startswith('boss'):
                # Do not draw black borders around blue light effects.
                blue=(image[:,:,2].astype(int)-image[:,:,0]>65)&visible
                outline &= ~nd.binary_dilation(blue,iterations=2)
            image[outline,:3]=rgb[0];image[outline,3]=255
            if group=='boss_attack' and int(entry['name'].rsplit('_',1)[1])>=8:
                # Source impact light joins both feet in threshold masks. Limit
                # opaque ground pixels to the observed shoe shapes and blue FX.
                left=[(213,627),(274,639),(261,663),(253,690),(242,709),(190,710),(184,690),(195,658)]
                right=[(406,627),(474,632),(485,655),(531,683),(533,701),(461,704),(402,687)]
                support=Image.new('L',(768,768))
                draw=ImageDraw.Draw(support)
                for polygon in (left,right):draw.polygon([(x+24,y+40) for x,y in polygon],fill=255)
                feet=np.asarray(support.resize((size,size),Image.Resampling.BOX))>=100
                effect=np.zeros((size,size),bool)
                for color in rgb[12:]:effect |= np.all(image[:,:,:3]==color,axis=2)
                y=np.indices(feet.shape)[0]
                erase=(y>=(642+40)//6)&~feet&~effect
                image[erase]=0
            symbols={c:chr(65+i) for i,c in enumerate(rgb)}
            rows=[''.join(symbols[tuple(p[:3])] if p[3] else '.' for p in row) for row in image]
            target=base/'work'/f"{entry['name']}-{size}-detail.pxg"
            result=external.px.Sheet(target.stem,size,'sprite',grid.palette,{chr(65+i):c for i,c in enumerate(colors)},rows,target)
            target.write_text(result.dump(),encoding='utf-8')
            assert not external.px.check(result)[0]
            external.px.render(result,base/'work')
            repairs.append({'name':entry['name'],'size':size,'source_ink_cells':int(recover.sum()),'outline_cells':int(outline.sum())})
    write(base/'work/local-repairs.json',{'method':'Source ink recovery and single-cell outline; no image model','records':repairs})

def select(group):
    base=TASK/group;report=external.read(base/'work/batch-report.json')
    notes={
        'beginner':'Compared every source pose, near/far iris placement, complete hands, feet and sword at native and enlarged sizes. Local eye patches follow the updated eight-frame references.',
        'boss_walk':'Compared all source silhouettes, shield, weapon, feet and armor. Fixed source scale, shared palette, local steel highlight recovery; no generated poses.',
        'boss_attack':'Compared all attack poses, raised weapon, shield, swing arc and impact sparks. Ground-mask repair preserves observed footwear and hard-alpha light pixels.',
        'enemy_walk':'Compared all tentacle gaps and back crystals. Original hollow eyes retained; localized mouth patches recover the circular rim at 64px.',
    }
    for entry in report['jobs']:
        for size in SIZES[group]:
            path=base/'work'/f"{entry['name']}-{size}-detail.pxg"
            face=base/'work'/f"{entry['name']}-{size}-detail-face.pxg"
            if face.exists():path=face
            external.select(Namespace(out=base/'work',name=entry['name'],size=size,sheet=path,
                note=notes[group]))
    external.finish(Namespace(out=base/'work'))


def portrait():
    base=TASK/'portrait'
    for folder in ('refs','prepared'):(base/folder).mkdir(parents=True,exist_ok=True)
    source=TASK/'beginner/refs/beginner_01.png'
    shutil.copyfile(source,base/'refs/beginner_portrait.png')
    masks.beginner(Image.open(source)).crop((190,35,565,480)).save(base/'prepared/beginner_portrait.png')
    write(base/'refs/beginner_portrait.anchor.json',{
        'subject':'Updated beginner head and shoulders from source frame 1','kind':'sprite','size':128,
        'palette':PALETTES['beginner'],'keep':['Blond fringe, original teal eyes and image-right gaze','Green cape and pale face'],
        'drop':['Backdrop and lower body outside the portrait crop'],'regions':[],
        'faces':[{'box':[.35,.35,.87,.71],'complex':True,'expression':'Neutral focused face with small closed mouth',
                  'gaze':'Near iris on image-right side of sclera, both pupils under upper lids, far eye partly covered by hair',
                  'reason':'Compare original iris and eyelids after conversion'}]})
    external.build(Namespace(refs=base/'refs',out=base/'work',prepared_dir=base/'prepared',sizes=[128],background='none'))

if __name__=='__main__':
    parser=ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=['prepare','build','sample','select','portrait'])
    parser.add_argument('--group',choices=GROUPS,default='beginner')
    args=parser.parse_args()
    if args.stage=='prepare':prepare()
    elif args.stage=='portrait':portrait()
    elif args.stage in ('build','sample'):build(args.group,args.stage=='sample')
    else:select(args.group)
