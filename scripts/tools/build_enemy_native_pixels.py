"""Source-based Picxel production of the approved 96/192px enemy canvases.

References are restored byte-for-byte from Git, never from production sprites.
Run prepare, build <group>, then (after visual review) finish <group>.
"""
from pathlib import Path
from types import SimpleNamespace
import argparse
import hashlib
import io
import json
import re
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / 'artifacts/previews/enemies_native_96_192/20261021-r01'
SKILL = ROOT / '.agents/skills/picxel-external-images'
sys.path.insert(0, str(SKILL / 'scripts'))
import external_pixel as ep


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def board(images, dest, cell=210, columns=5):
    out = Image.new('RGB', (columns*cell, ((len(images)+columns-1)//columns)*(cell+28)), '#303945')
    draw = ImageDraw.Draw(out)
    for i,(name,img) in enumerate(images):
        x,y = i%columns*cell, i//columns*(cell+28)
        img = img.copy().convert('RGBA')
        img.thumbnail((cell-12,cell-12),Image.Resampling.NEAREST)
        out.paste(img,(x+(cell-img.width)//2,y+(cell-img.height)//2),img)
        draw.text((x+6,y+cell+3),name,fill='white')
    out.save(dest)


def prepare():
    names = subprocess.check_output(['git','ls-tree','-r','--name-only','02b3ef4','artifacts/sources/enemies'],cwd=ROOT).decode().splitlines()
    records=[]
    for p in names:
        if not p.endswith('.png'): continue
        parts=p.split('/')
        enemy=parts[3]
        if enemy=='xiaoguai_move': group='mite'; name=Path(p).stem
        elif enemy=='iron_knight': group='knight'; name=Path(p).stem
        elif enemy=='echo_bat': group='bat'; name=parts[-2]+'-'+Path(p).stem
        elif enemy=='underworld_wolf': group='wolf'; name=parts[-2]+'-'+Path(p).stem
        else: continue
        data=subprocess.check_output(['git','show','02b3ef4:'+p],cwd=ROOT)
        dest=TASK/'sources'/group/(name+'.png')
        dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists(): assert dest.read_bytes()==data
        else: dest.write_bytes(data)
        img=Image.open(dest).convert('RGBA')
        records.append(dict(group=group,name=name,git_source=p,revision='02b3ef4',sha256=hashlib.sha256(data).hexdigest(),size=list(img.size),bbox=img.getbbox(),alpha=sorted(set(img.getchannel('A').tobytes()))))
    write(TASK/'source_manifest.json',records)
    for group in ('mite','bat','knight','wolf'):
        subset=[r for r in records if r['group']==group]
        board([(r['name'],Image.open(TASK/'sources'/group/(r['name']+'.png'))) for r in subset],TASK/(group+'-sources.png'))
    for group,folder in [('mite','combat'),('bat','echo_bat'),('knight','iron_knight'),('wolf','underworld_wolf')]:
        src=ROOT/'assets/sprites/enemies'/folder
        for p in src.rglob('*'):
            if p.is_file() and p.suffix in ('.png','.json','.tres'):
                dest=TASK/'previous'/group/p.relative_to(src)
                dest.parent.mkdir(parents=True,exist_ok=True)
                if not dest.exists(): dest.write_bytes(p.read_bytes())
    print('Recovered',len(records),'original frames; source boards at',TASK)


def mask_sources():
    records=ep.read(TASK/'source_manifest.json')
    for r in records:
        group,name=r['group'],r['name']
        image=Image.open(TASK/'sources'/group/(name+'.png')).convert('RGBA')
        a=np.array(image); rgb=a[:,:,:3].astype(int)
        lo=rgb.min(axis=2); hi=rgb.max(axis=2)
        if group=='bat':
            # Black backdrop; dark blue outlines remain distinguishable from it.
            mask=(hi>10)&((hi-lo)>3)
            mask[:100]=False; mask[590:]=False
        else:
            # Warm light backdrop and neutral ground shadows are not body art.
            mask=((hi<208)|((hi-lo)>30))&(((hi-lo)>12)|(hi<70))
            if group=='knight':
                mask[610:]&=~((hi[610:]>70)&((hi-lo)[610:]<27))
        if group=='bat' and name=='attack-09':
            # Source breath trail is a separate runtime effect; keep the lips.
            mask[:,475:]=False
        labels,n=ndimage.label(mask,np.ones((3,3)))
        counts=np.bincount(labels.ravel()); counts[0]=0
        mask=(counts[labels]>100)&(labels>0) if group=='bat' else labels==counts.argmax()
        # Fill tiny internal matte defects only; keep leg/tail/wing gaps open.
        holes=ndimage.binary_fill_holes(mask)&~mask
        labels,n=ndimage.label(holes)
        counts=np.bincount(labels.ravel())
        mask|=holes&(counts[labels]<35)
        a[:,:,3]=mask.astype('uint8')*255; a[~mask,:3]=0
        clean=Image.fromarray(a)
        dest=TASK/'masked'/group/(name+'.png'); dest.parent.mkdir(parents=True,exist_ok=True)
        clean.save(dest); r['masked_bbox']=clean.getbbox()
    write(TASK/'source_manifest.json',records)
    for group in ('mite','bat','knight','wolf'):
        subset=[r for r in records if r['group']==group]
        board([(r['name'],Image.open(TASK/'masked'/group/(r['name']+'.png'))) for r in subset],TASK/(group+'-masked.png'))
        print(group,[(r['name'],r['masked_bbox']) for r in subset])
    for group,folder in [('bat','echo_bat'),('wolf','underworld_wolf'),('knight','iron_knight')]:
        manifest=ep.read(ROOT/'assets/sprites/enemies'/folder/('art_source_manifest.json' if group=='knight' else 'manifest.json'))
        original={r['sha256'] for r in records if r['group']==group}
        expected={r.get('source_sha256',r.get('sha256')) for r in manifest.get('frames',manifest.get('sources',[]))}
        assert original==expected,(group,'source hash mismatch',original^expected)
    print('All 53 bat/knight/wolf source hashes match current production provenance; mite originals restored from original source folder.')


CONFIG={
    'mite':dict(size=96,scale=.1,origin=[12,12],offset=[0,2],folder='combat'),
    'bat':dict(size=96,scale=.12,origin=[4.8,9.48],offset=[0,-10],folder='echo_bat'),
    'knight':dict(size=192,scale=.25,origin=[6,3.5],offset=[0,-70],folder='iron_knight'),
    'wolf':dict(size=192,scale=.3072,origin=[96-360*.3072,187-650*.3072],offset=[0,-91],folder='underworld_wolf'),
}


def build(group):
    base='wolf' if group.startswith('wolf') else group
    conf=CONFIG[base]; size=conf['size']
    records=[r for r in ep.read(TASK/'source_manifest.json') if r['group']==base]
    if base=='wolf': records=[r for r in records if (r['name'].startswith('jump'))==(group=='wolf_jump')]
    old=TASK/'previous'/base
    if base=='knight':
        colors=set()
        for p in old.glob('knight_*.png'):
            colors|={rgb[:3] for _,rgb in Image.open(p).convert('RGBA').getcolors(2000000) if rgb[3]}
        palette=['#%02x%02x%02x'%c for c in sorted(colors)]
    else: palette=ep.read(old/('art_source_manifest.json' if base=='mite' else 'manifest.json'))['palette']
    assert len(palette)<=16
    work=TASK/group
    for r in records:
        name=r['name']; refs=work/'refs'; prepared=work/'prepared'
        refs.mkdir(parents=True,exist_ok=True); prepared.mkdir(exist_ok=True)
        (refs/(name+'.png')).write_bytes((TASK/'sources'/base/(name+'.png')).read_bytes())
        notes={
            'mite':['Continuous antennae and jaw rim','Single dark mouth opening; preserve teeth as a connected rim','Low creeping silhouette and side fins'],
            'bat':['Connected wing bones and wing membrane','Two red eyes gaze right; small closed smile except open release mouth','Keep both ears, feet and pose-specific folded wings'],
            'knight':['Connected hammer handle and shield silhouette','Blue steel plates; helmet visor slit without inventing eyes','Feet and proportions share source registration'],
            'wolf':['Blue rib markings connected and readable','Eyes look right/up following source head pose; preserve open or closed mouth per pose','Dark tail curls and legs with natural gaps'],
        }
        anchor=dict(size=size,kind='sprite',subject=base+' '+name,keep=notes[base],drop=['Watermark, backdrop, ground shadow','Hairline scratches and meaningless isolated texture flecks'],palette=palette)
        if base in ('bat','wolf'):
            anchor['faces']=[dict(box=[.37,.2,.85,.57],complex=True,gaze='Rightward, following the original head angle of '+name,expression='Original teeth and eye expression; '+('open mouth for attack-09' if base=='bat' else 'open howl for attack-04; other mouths follow individual source'),reason='Preserve eye direction and coherent mouth at native size')]
        write(refs/(name+'.anchor.json'),anchor)
        image=Image.open(TASK/'masked'/base/(name+'.png')).convert('RGBA')
        # A shared transform, evaluated from the high-resolution original at 4x
        # target density. Picxel then quantizes and votes on the final grid.
        s=conf['scale']*4; ox,oy=[v*4 for v in conf['origin']]
        image=image.transform((size*4,size*4),Image.Transform.AFFINE,(1/s,0,-ox/s,0,1/s,-oy/s),Image.Resampling.BICUBIC)
        image.save(prepared/(name+'.png'))
    write(work/'registration.json',dict(**conf,palette=palette,source='720px originals',sample_density=4,method='shared affine source registration, Picxel palette quantization and majority vote'))
    result=ep.build(SimpleNamespace(refs=work/'refs',out=work/'work',sizes=[size],prepared_dir=work/'prepared',background='none',preserve_canvas=True))
    assert result==0
    board([(r['name'],Image.open(work/'work'/f"{r['name']}-{size}.png").resize((size*2,size*2),Image.Resampling.NEAREST)) for r in records],TASK/(group+'-pixels.png'),cell=size*2+12,columns=5)


def finish(group):
    base='wolf' if group.startswith('wolf') else group
    work=TASK/group/'work'; size=CONFIG[base]['size']
    report=ep.read(work/'batch-report.json')
    for r in report['jobs']:
        selected=work/f"{r['name']}-{size}-clean.pxg"
        if not selected.exists(): selected=work/f"{r['name']}-{size}.pxg"
        ep.select(SimpleNamespace(out=work,name=r['name'],size=size,sheet=selected,note='Compared all poses against original contact sheet: shared scale and registration, preserved pose silhouette and face direction; simplified subpixel texture via palette voting. Bat: filled accidental internal matte holes and restored continuous dark contour; no model generation.' if base=='bat' else 'Compared all poses against originals: preserved pose and face direction, shared scale and registration, palette voting simplifies subpixel texture; no model generation.'))
    ep.finish(SimpleNamespace(out=work))


def repair_bat():
    out=TASK/'bat/work'; changes=[]; images=[]
    for r in ep.read(out/'batch-report.json')['jobs']:
        name=r['name']; sheet=ep.px.load(out/f'{name}-96.pxg')
        a=np.array(sheet.image().convert('RGBA')); mask=a[:,:,3]>0
        solid=ndimage.binary_fill_holes(mask)
        outline=ndimage.binary_dilation(solid,iterations=1)&~mask
        # All repairs use the bat's existing darkest contour color.
        a[outline]=(16,18,27,255)
        image=Image.fromarray(a)
        repaired=ep.px._import_image(image,96,f'{name}-96-clean','sprite',sheet.palette,ep.read(TASK/'bat/registration.json')['palette'])
        repaired.path=out/f'{name}-96-clean.pxg'
        repaired.path.write_text(repaired.dump(),encoding='utf-8'); ep.px.render(repaired,out)
        changes.append(dict(name=name,contour_pixels=int(outline.sum())))
        images.append((name,image.resize((384,384),Image.Resampling.NEAREST)))
    write(TASK/'bat/contour_repairs.json',changes)
    board(images,TASK/'bat-clean.png',cell=396,columns=5)


def repair_knight():
    out=TASK/'knight/work'; images=[]; changes=[]
    for r in ep.read(out/'batch-report.json')['jobs']:
        name=r['name']; sheet=ep.px.load(out/f'{name}-192.pxg')
        a=np.array(sheet.image().convert('RGBA')); before=a.copy(); mask=a[:,:,3]>0
        interior=ndimage.binary_erosion(mask,iterations=2)
        # The thin shield engraving became dotted marks. Remove those small
        # dark fragments inside steel plates; retain the continuous outer rim.
        region=np.zeros((192,192),bool); region[55:154,110:169]=True
        for _ in range(1):
            labels,count=ndimage.label((np.max(a[:,:,:3],axis=2)<=95)&mask,np.ones((3,3)))
            sizes=np.bincount(labels.ravel())
            points=np.argwhere((labels>0)&(sizes[labels]<=6)&interior&region)
            for y,x in points:
                patch=a[y-2:y+3,x-2:x+3,:3].reshape(-1,3)
                candidates=patch[np.max(patch,axis=1)>95]
                if len(candidates):
                    colors,counts=np.unique(candidates,axis=0,return_counts=True)
                    a[y,x,:3]=colors[counts.argmax()]
        if name.startswith('move'):
            for y in range(163,168):
                if y>=192: break
                shadow=(a[y,:,3]>0)&(np.max(a[y,:,:3],axis=1)<40)&(before[y-3,:,3]==0)
                a[y,shadow]=0
        image=Image.fromarray(a)
        repaired=ep.px._import_image(image,192,f'{name}-192-clean','sprite',sheet.palette,ep.read(TASK/'knight/registration.json')['palette'])
        repaired.path=out/f'{name}-192-clean.pxg'; repaired.path.write_text(repaired.dump(),encoding='utf-8'); ep.px.render(repaired,out)
        changes.append(dict(name=name,changed_pixels=int(np.any(a!=before,axis=2).sum())))
        images.append((name,image.resize((384,384),Image.Resampling.NEAREST)))
    write(TASK/'knight/local_repairs.json',changes)
    board(images,TASK/'knight-clean.png',cell=396,columns=5)


def install():
    groups={}; sources=ep.read(TASK/'source_manifest.json'); records=[]
    for group in ('mite','bat','knight','wolf_main','wolf_jump'):
        report,selected=ep.reviewed_sheets(TASK/group/'work')
        base='wolf' if group.startswith('wolf') else group
        groups.setdefault(base,{})
        for r in report['jobs']:
            image=Image.open(TASK/group/'work'/f"{r['name']}-{CONFIG[base]['size']}.png").convert('RGBA')
            groups[base][r['name']]=image
    assert sum(map(len,groups.values()))==60
    for base,frames in groups.items():
        conf=CONFIG[base]; size=conf['size']; dest=ROOT/'assets/sprites/enemies'/conf['folder']
        def atlas(filename,names):
            image=Image.new('RGBA',(size*len(names),size))
            for i,name in enumerate(names): image.paste(frames[name],(i*size,0))
            path=dest/filename; path.parent.mkdir(parents=True,exist_ok=True); image.save(path)
            records.append(dict(path=path.relative_to(ROOT).as_posix(),size=list(image.size),frame_size=size,frames=len(names),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        provenance=dict(revision='native96_192_20261021',task=TASK.relative_to(ROOT).as_posix(),originals_revision='02b3ef4',source='720px originals restored from Git; hashes verified',method='Project Picxel source conversion, shared palette and fixed source registration; local contour/engraving repair; no image model',**conf)
        frame_records=[]
        for name,img in frames.items():
            buffer=io.BytesIO(); img.save(buffer,format='PNG')
            original=next(r for r in sources if r['group']==base and r['name']==name)
            frame_records.append(dict(name=name,source_sha256=original['sha256'],source_path=original['git_source'],frame_sha256=hashlib.sha256(buffer.getvalue()).hexdigest(),visible_bbox=list(img.getbbox())))
        if base=='mite':
            atlas('enemy_gloom_mite_idle.png',['move-01'])
            atlas('enemy_gloom_mite_move.png',[f'move-{i:02}' for i in range(1,8)])
            m=ep.read(dest/'art_source_manifest.json')
            m.update(frame_size=size,idle_source='move-01',atlas_sources={'enemy_gloom_mite_idle.png':['move-01'],'enemy_gloom_mite_move.png':list(frames)},editable={n:(TASK/'mite/work'/f'{n}-96.pxg').relative_to(ROOT).as_posix() for n in frames},frame_rects=[[size*i,0,size,size] for i in range(7)],baseline_exclusive=65,game_display=dict(canvas_world_size=[96,96],sprite_scale=[1,1],sprite_offset=conf['offset'],baseline_world_y=19,frame_duration=1/14),frames=frame_records,processing=provenance,source=(TASK/'sources/mite').relative_to(ROOT).as_posix())
            write(dest/'art_source_manifest.json',m)
        elif base=='bat':
            atlas('idle.png',['move-01'])
            for action,count in [('move',6),('attack',9)]: atlas(action+'.png',[f'{action}-{i:02}' for i in range(1,count+1)])
            m=ep.read(dest/'manifest.json')
            for r in frame_records:
                action,num=r.pop('name').split('-'); r['atlas']=(dest/(action+'.png')).relative_to(ROOT).as_posix(); r['atlas_frame']=int(num)-1
            m.update(canvas=[96,96],provenance=provenance,anchor='Source scale .12; source (360,321) maps to frame center (48,48); fixed for every pose',sprite_scale=[1,1],sprite_position=conf['offset'],release_mouth_pixel=[60,46],frames=frame_records)
            write(dest/'manifest.json',m)
        elif base=='knight':
            m=ep.read(dest/'art_source_manifest.json')
            for filename,names in m['atlas_sources'].items(): atlas(filename,names)
            m.update(frame_size=192,processing=provenance,source=(TASK/'sources/knight').relative_to(ROOT).as_posix(),editable={n:(TASK/'knight/work'/f'{n}-192-clean.pxg').relative_to(ROOT).as_posix() for n in frames},frames=frame_records)
            write(dest/'art_source_manifest.json',m)
            m=ep.read(dest/'manifest.json'); m.update(frame_size=[192,192],movement_foot_anchor=[96,166],sprite_scale=1,sprite_offset=conf['offset'],collision_capsule={'radius':24,'height':102,'position':[0,-61.5]}); m.pop('collision_radius',None)
            write(dest/'manifest.json',m)
            from install_combat_picxel_assets import boss_resource
            (dest/'iron_knight_sprite_frames.tres').write_text(boss_resource(),encoding='utf-8')
        else:
            for action,count in [('move',7),('attack',4),('jump',10)]: atlas('atlases/'+action+'.png',[f'{action}-{i:02}' for i in range(1,count+1)])
            frames['attack-01'].save(dest/'frames/attack_01.png')
            m=ep.read(dest/'manifest.json')
            for r in m['frames']:
                name=f"{r['action']}-{r['number']:02}"; new=next(v for v in frame_records if v['name']==name)
                for key in ('source_pixels_per_cell','source_origin','approved_sample_reused'): r.pop(key,None)
                r.update(sha256=new['frame_sha256'],source_sha256=new['source_sha256'],source=new['source_path'],sprite_scale=1.0,sprite_offset=conf['offset'],colors=len({p[:3] for p in frames[name].getdata() if p[3]}),visible_bbox=new['visible_bbox'])
            m.update(revision='production-192',canvas=[192,192],runtime_base_body_scale=1.5,runtime_sprite_scale=1,source_pixels_per_output_pixel=1/.3072,world_units_per_source_pixel=.3072,source_foot_anchor=[360,650],frame_foot_anchor=[96,187],registration='All frames share one source-to-world transform baked into the 192px canvas; scale 1, offset (0,-91), subtract gameplay air height',processing=provenance)
            write(dest/'manifest.json',m)
            path=dest/'wolf_sprite_frames.tres'; text=path.read_text(encoding='utf-8')
            text=re.sub(r'region = Rect2\((\d+), 0, 128, 128\)',lambda m:f'region = Rect2({int(m[1])//128*192}, 0, 192, 192)',text)
            transforms={f"{r['action']}:{r['number']-1}":dict(sprite_scale=1.0,sprite_offset=conf['offset']) for r in m['frames']}
            text=re.sub(r'^metadata/frame_transforms = .*$', 'metadata/frame_transforms = '+json.dumps(transforms),text,flags=re.M)
            path.write_text(text,encoding='utf-8')
        write(dest/'native_pixel_provenance.json',dict(**provenance,frames=frame_records))
    write(TASK/'installed_atlases.json',records)
    print('INSTALLED 13 atlases, 60 unique source frames / 63 atlas cells, plus wolf idle alias')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('command',choices=['prepare','mask','build','finish','repair-bat','repair-knight','install'])
    parser.add_argument('group',nargs='?',choices=['mite','bat','knight','wolf_main','wolf_jump'])
    args=parser.parse_args()
    if args.command in ('build','finish'): {'build':build,'finish':finish}[args.command](args.group)
    else: {'prepare':prepare,'mask':mask_sources,'repair-bat':repair_bat,'repair-knight':repair_knight,'install':install}[args.command]()
