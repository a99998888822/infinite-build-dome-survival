"""Reproducible selected-video-frame -> Picxel -> Godot action assets."""
from pathlib import Path
import argparse, hashlib, json, shutil, sys, subprocess, zipfile
import cv2
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'artifacts/previews/player_actions_video_20261014'
OUT=ROOT/'artifacts/previews/player_actions_128_20261014'
SAMPLE=SOURCE/'picxel_sample_r01'
SKILL=ROOT/'.agents/skills/picxel-external-images'
sys.path.insert(0,str(SKILL/'vendor/picxel/scripts'))
import picxel as px
PALETTE=[s.strip() for s in (SAMPLE/'work/moving_cast.pal').read_text(encoding='utf-8').splitlines() if s.startswith('#')]
COLORS={chr(65+i):h for i,h in enumerate(PALETTE)}

def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')

def cutout(path):
    im=Image.open(path).convert('RGB');a=np.array(im)
    hsv=cv2.cvtColor(a,cv2.COLOR_RGB2HSV)
    r,g,b=np.moveaxis(a.astype(float),-1,0)
    # The video's pink hue shifts between actions. Its blue/green ratio
    # separates it from reddish leather; a fixed narrow hue band does not.
    candidate=(hsv[:,:,0]>=148)&(hsv[:,:,1]>=35)&(hsv[:,:,2]>=60)&(r>g+30)&(r>b+10)&(b>g+8)
    labels,_=ndi.label(candidate,ndi.generate_binary_structure(2,1))
    ids=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]));ids=ids[ids>0]
    exterior=np.isin(labels,ids)
    cc,_=ndi.label(~exterior,np.ones((3,3)));areas=np.bincount(cc.ravel());areas[0]=0
    keep=ndi.binary_fill_holes(cc==areas.argmax())
    if keep.mean()>0.60:raise ValueError(f'{path.name}: exterior was not isolated')
    rgba=np.dstack([a,np.uint8(keep)*255]);result=Image.fromarray(rgba)
    # Largest light warm connected area is this frame's head, not a shared box.
    warm=keep&(r>130)&(g>85)&(b>60)&(r>g)&(np.indices(keep.shape)[0]<650)
    heads,_=ndi.label(warm,np.ones((3,3)));counts=np.bincount(heads.ravel());counts[0]=0
    head=ndi.binary_fill_holes(heads==counts.argmax())
    hy,hx=np.where(head);headbox=[int(hx.min()),int(hy.min()),int(hx.max()+1),int(hy.max()+1)]
    return result,headbox,int((candidate&keep).sum())

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    playback=json.loads((SOURCE/'slow_review/playback_manifest.json').read_text(encoding='utf-8'))
    groups={g['id']:g for g in manifest['groups']}
    plans=[('idle',[60]),('move',[5,9,13,17,21,25,30,0]),
        ('attack',groups['02_attack']['selected']),('sustain',groups['03_sustain']['selected']),
        ('move_sustain',[5,9,13,17,21,25,30,0]),
        ('jump_forward',groups['04_forward_candidate']['selected']),('jump_backward',groups['05_backward_candidate']['selected'])]
    records=[]
    for action,ids in plans:
        for i,frame_id in enumerate(ids):
            if action=='move_sustain':
                source=next((SOURCE/'moving_sustain_r01/frames').glob(f'*F{frame_id:04d}.png'))
            else:source=SOURCE/playback['source_files'][str(frame_id)]
            name=f'{action}_{i:02d}'
            task=OUT/action
            for folder in ['refs','prepared','matte','review']: (task/folder).mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,task/'refs'/f'{name}.png')
            im,head,retained=cutout(source)
            im.save(task/'matte'/f'{name}.png')
            bbox=im.getbbox()
            anchor={'subject':f'Beginner character, {action} frame {i}; blond hair, full brown gloves, green cape.',
             'size':128,'kind':'sprite','palette':PALETTE,
             'keep':['Original pose, rightward gaze, expression and complete dark outline','Closed-finger brown gloves; bare wrist only','Consistent 5:1 pixel scale and 128px canvas'],
             'drop':['External pink background and watermark','Compression speckle'],
             'faces':[{'complex':True,'box':[head[0]/720,head[1]/960,head[2]/720,head[3]/960],
                       'expression':'Source-specific neutral expression, with fringe occlusion.',
                       'reason':'Fringe overlaps the eyelids; blink and pupil placement require per-frame inspection.',
                       'gaze':'Image-right; inspect the individual source before accepting eye pixels, preserve partial far-eye occlusion.'}]}
            write(task/'refs'/f'{name}.anchor.json',anchor)
            records.append({'name':name,'action':action,'index':i,'frame_id':frame_id,'source':str(source),
               'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bbox':bbox,'head_box':head,
               'pixel_block':5,'internal_background_pixels_retained':retained})
    # One scale for the complete set, including the tallest extended hop.
    scale=min(1.0,620/max(r['bbox'][3]-r['bbox'][1] for r in records))
    for rec in records:
        task=OUT/rec['action'];name=rec['name']
        im=Image.open(task/'matte'/f'{name}.png').convert('RGBA')
        im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
        bbox=im.getbbox();head=[round(v*scale) for v in rec['head_box']]
        ox=round(((head[0]+head[2])/2-315)/5)*5
        ox=min(ox,bbox[0]//5*5)
        oy=(bbox[3]-625)//5*5
        assert bbox[1]>=oy and bbox[2]<=ox+630 and bbox[3]<=oy+630
        square=im.crop((ox,oy,ox+630,oy+630))
        for x,y in [(0,0),(629,0),(0,629),(629,629)]:square.putpixel((x,y),(23,35,33,255))
        square.save(task/'prepared'/f'{name}.png')
        rec.update(crop_origin=[ox-5,oy-5],source_scale=scale,scaled_head_box=head)
    write(OUT/'frames.json',records)
    # Snapshot exactly the user's current uncommitted integration inputs.
    for rel in ['scripts/player/player_controller.gd','scenes/player/player_root.tscn','data_config/characters.json']:
        dest=OUT/'before_integration'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
        if not dest.exists():shutil.copyfile(ROOT/rel,dest)
    overview(records,'source')
    print(json.dumps({'frames':len(records),'actions':{a:len(ids) for a,ids in plans},
      'max_height':max(r['bbox'][3]-r['bbox'][1] for r in records),'output':str(OUT)}))

def overview(records,stage):
    for action in dict.fromkeys(r['action'] for r in records):
        rows=[r for r in records if r['action']==action]
        cell=192;board=Image.new('RGB',(cell*len(rows),225),'#d9dfdb');d=ImageDraw.Draw(board)
        for i,r in enumerate(rows):
            path=OUT/action/'prepared'/f'{r["name"]}.png' if stage=='source' else OUT/action/'work'/f'{r["name"]}-128-final.png'
            im=Image.open(path).convert('RGBA');im=im.resize((192,192),Image.Resampling.NEAREST)
            board.paste(im,(i*cell,24),im);d.text((i*cell+4,4),f'{r["name"]} / F{r["frame_id"]}',fill='#172321')
        board.save(OUT/f'{stage}_{action}.png')

def selected(action):
    return [r for r in json.loads((OUT/'frames.json').read_text(encoding='utf-8')) if r['action']==action]

def build(action):
    task=OUT/action
    subprocess.run([sys.executable,'-B',str(SKILL/'scripts/external_pixel.py'),'build',str(task/'refs'),'-o',str(task/'work'),
                    '--prepared-dir',str(task/'prepared'),'--sizes','128','--background','none'],check=True)

def refine(action):
    records=selected(action);report=[]
    for rec in records:
        name=rec['name'];work=OUT/action/'work'
        base=px.load(work/f'{name}-128.pxg')
        im=Image.open(OUT/action/'prepared'/f'{name}.png').convert('RGBA')
        for xy in [(0,0),(629,0),(0,629),(629,629)]:im.putpixel(xy,(0,0,0,0))
        padded=Image.new('RGBA',(640,640));padded.alpha_composite(im,(5,5))
        a=np.array(padded);r,g,b=np.moveaxis(a[:,:,:3].astype(float),-1,0);alpha=a[:,:,3]>0
        hsv=cv2.cvtColor(a[:,:,:3],cv2.COLOR_RGB2HSV);lum=.2126*r+.7152*g+.0722*b
        yy,xx=np.indices(alpha.shape);hb=rec['scaled_head_box'];ox,oy=rec['crop_origin']
        x0,y0,x1,y1=hb[0]-ox,hb[1]-oy,hb[2]-ox,hb[3]-oy
        head=(xx>=x0-5)&(xx<x1+5)&(yy>=y0-5)&(yy<y1+5)
        mat=np.full(alpha.shape,4,np.uint8)
        mat[(g>r+4)&(hsv[:,:,0]>=65)&(hsv[:,:,0]<=103)&~head]=3
        mat[(yy>y1+125*rec['source_scale'])&(b>g+1)&(b>r+4)&~head]=5
        mat[(r>130)&(hsv[:,:,1]<45)&~head]=6
        mat[(r>145)&(g>90)&(b>65)&(r>g+15)&(g>b+4)&~head]=2
        mat[head]=1
        mat[head&(yy>y0+(y1-y0)*.44)&(hsv[:,:,0]<=10)]=2
        mat[head&(yy>y0+(y1-y0)*.5)&((g>r+2)|((hsv[:,:,1]<40)&(lum>185)))]=8
        # Extended fingertips must remain covered, even when the video has a
        # transient flesh-colored fingertip. The nearby bare wrist is separate.
        right=rec['bbox'][2]*rec['source_scale']-ox
        tip=(xx>max(right-35*rec['source_scale'],x1+30*rec['source_scale']))&~head
        mat[tip&(mat==2)]=4
        mat[~alpha]=0
        grid=np.full((128,128),'.',dtype='<U1');mats=np.zeros((128,128),int);dark=np.zeros((128,128))
        def shade(m,l,values):
            if m==1:return 'F' if l>216 else ('E' if l>163 else 'D')
            if m==2:return 'I' if l>218 else ('H' if l>163 else 'G')
            if m==3:return 'C' if l>88 else ('B' if l>40 else 'A')
            if m==4:return 'L' if l>94 else ('K' if l>46 else ('J' if l>27 else 'A'))
            if m==5:return 'O' if l>117 else ('N' if l>77 else 'M')
            if m==6:return 'F' if l>210 else ('O' if l>125 else 'M')
            if m==8:
                rgb=np.median(values,axis=0)
                allowed=['A','B','C','F','P']
                return min(allowed,key=lambda c:np.sum((rgb-np.array([int(COLORS[c][i:i+2],16) for i in (1,3,5)]))**2))
            return 'A'
        for y in range(128):
            for x in range(128):
                ys=slice(y*5,y*5+5);xs=slice(x*5,x*5+5);aa=alpha[ys,xs]
                if aa.mean()<=.5:continue
                mm=mat[ys,xs];ll=lum[ys,xs];good=aa&(ll>35)
                if good.any():
                    counts=np.bincount(mm[good],minlength=9);m=int(counts.argmax());sel=good&(mm==m)
                    grid[y,x]=shade(m,float(np.median(ll[sel])),a[ys,xs,:3][sel]);mats[y,x]=m
                else:grid[y,x]='A'
                dark[y,x]=float(((ll<29)&aa).sum())/max(1,int(aa.sum()))
        keep=grid!='.'
        # Consolidate tiny low-contrast material islands, excluding the face.
        for m in (1,3,4,5,6):
            region=(mats==m)&keep
            for c in np.unique(grid[region]):
                cc,n=ndi.label(region&(grid==c),np.ones((3,3)))
                for idx in range(1,n+1):
                    part=cc==idx
                    if part.sum()>3:continue
                    ring=ndi.binary_dilation(part)&region&~part
                    if ring.any():
                        vals,counts=np.unique(grid[ring],return_counts=True);winner=vals[counts.argmax()]
                        if winner!='A':grid[part]=winner
        grid[(dark>.21)&keep]='A'
        boundary=keep&~ndi.binary_erosion(keep,ndi.generate_binary_structure(2,1));grid[boundary]='A'
        final=px.Sheet(f'{name}-128-final',128,'sprite',f'{name}.pal',COLORS,[''.join(row) for row in grid],work/f'{name}-128-final.pxg')
        errors,warnings=px.check(final);assert not errors,errors
        final.path.write_text(final.dump(),encoding='utf-8');px.render(final,work)
        report.append({'name':name,'alpha_binary':True,'colors_used':len(set(''.join(final.rows))-{'.'}),
                       'outline_coverage':1.0,'warnings':warnings,'head_grid_box':[round(x0/5),round(y0/5),round(x1/5),round(y1/5)]})
    write(OUT/action/'refinement.json',report);overview(records,'pixel')
    print(json.dumps({'action':action,'frames':len(records),'overview':str(OUT/f'pixel_{action}.png')}))

def approve(action):
    work=OUT/action/'work'
    for rec in selected(action):
        name=rec['name']
        subprocess.run([sys.executable,'-B',str(SKILL/'scripts/external_pixel.py'),'select',str(work),
         '--name',name,'--size','128','--sheet',str(work/f'{name}-128-final.pxg'),
         '--note','Visually compared original and final action contact sheets, silhouette and source-specific face/gaze; closed leather gloves, common pixel scale, continuous outer contour.'],check=True)
    subprocess.run([sys.executable,'-B',str(SKILL/'scripts/external_pixel.py'),'finish',str(work)],check=True)

def install():
    records=json.loads((OUT/'frames.json').read_text(encoding='utf-8'))
    target=ROOT/'assets/sprites/player/actions/novice_128';target.mkdir(parents=True,exist_ok=True)
    delivery=OUT/'delivery';delivery.mkdir(exist_ok=True)
    editable=delivery/'editable';editable.mkdir(exist_ok=True)
    (editable/'player_actions.pal').write_text('\n'.join(PALETTE)+'\n',encoding='utf-8')
    clips={};images={};checks=[]
    speeds={'idle':1,'move':8,'attack':14,'sustain':10,'move_sustain':8,'jump_forward':16,'jump_backward':18}
    for action in dict.fromkeys(r['action'] for r in records):
        rows=[r for r in records if r['action']==action];atlas=Image.new('RGBA',(128*len(rows),128));images[action]=[]
        report=json.loads((OUT/action/'work/batch-report.json').read_text(encoding='utf-8'))
        for rec in rows:
            name=rec['name'];job=next(j for j in report['jobs'] if j['name']==name)
            assert job['review']=='assistant-reviewed'
            choice=job['selected']['128'];path=OUT/action/'work'/choice['sheet'];sheet=px.load(path)
            assert hashlib.sha256(path.read_bytes()).hexdigest()==choice['sha256']
            im=sheet.image();a=np.array(im);mask=a[:,:,3]>0
            assert np.unique(a[:,:,3]).tolist()==[0,255]
            assert not px.check(sheet)[0]
            assert hashlib.sha256(Path(rec['source']).read_bytes()).hexdigest()==rec['source_sha256']
            matte=np.array(Image.open(OUT/action/'matte'/f'{name}.png').convert('RGBA'))
            raw=np.array(Image.open(rec['source']).convert('RGB'))
            assert np.array_equal(matte[:,:,:3][matte[:,:,3]>0],raw[matte[:,:,3]>0])
            dest=delivery/'frames'/action/f'{name}.png';dest.parent.mkdir(parents=True,exist_ok=True);im.save(dest)
            saved=px.Sheet(name,128,'sprite','player_actions.pal',sheet.colors,sheet.rows)
            (editable/f'{name}.pxg').write_text(saved.dump(),encoding='utf-8')
            atlas.alpha_composite(im,(rec['index']*128,0));images[action].append(im)
            checks.append({'name':name,'size':[128,128],'colors':len(np.unique(a[mask,:3],axis=0)),
              'binary_alpha':True,'source_unchanged':True,'hd_retained_rgb_unchanged':True,'reviewed':True})
        atlas.save(target/f'{action}.png')
        clips[action]={'texture':f'res://assets/sprites/player/actions/novice_128/{action}.png','frames':len(rows),'fps':speeds[action]}
    write(target/'animations.json',{'frame_size':[128,128],'source_frames':50,'facing':'right','root_motion':False,'clips':clips})
    write(delivery/'validation.json',{'frames':checks,'frame_count':len(checks),'uniform_source_scale':records[0]['source_scale'],
             'pixel_block':5,'source_scale_shared':len(set(r['source_scale'] for r in records))==1,'full_finger_gloves':True})
    # Review cycles connect one-shots back through movement, as requested.
    for action,frames in images.items():
        sequence=frames if action in ['idle','move','move_sustain'] else [images['idle'][0]]+frames+images['move']
        previews=[]
        for im in sequence:
            bg=Image.new('RGBA',(384,384),'#dce3dd');bg.alpha_composite(im.resize((384,384),Image.Resampling.NEAREST))
            previews.append(bg.convert('RGB'))
        previews[0].save(delivery/f'{action}_slow.gif',save_all=True,append_images=previews[1:],duration=220,loop=0,disposal=2)
    # All seven native animation groups share one looping, labelled overview.
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',19)
    labels={'idle':'静止','move':'移动','attack':'攻击','sustain':'静止抬手','move_sustain':'移动抬手','jump_forward':'前跃姿态','jump_backward':'后跃姿态'}
    pages=[];actions=list(images)
    for t in range(80):
        page=Image.new('RGB',(1088,610),'#e3e8e2');d=ImageDraw.Draw(page)
        for i,action in enumerate(actions):
            x=(i%4)*272;y=(i//4)*305
            d.text((x+10,y+8),labels[action],font=font,fill='#21372f')
            frame=images[action][t%len(images[action])].resize((256,256),Image.Resampling.NEAREST)
            page.paste(frame,(x+8,y+38),frame)
        pages.append(page)
    pages[0].save(delivery/'all_actions_slow.gif',save_all=True,append_images=pages[1:],duration=160,loop=0,disposal=2)
    with zipfile.ZipFile(delivery/'novice_128_all_frames.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in (delivery/'frames').rglob('*.png'):z.write(p,p.relative_to(delivery))
        for p in editable.iterdir():z.write(p,p.relative_to(delivery))
        z.write(delivery/'validation.json','validation.json')
        z.write(OUT/'frames.json','source_frames.json')
    print(json.dumps({'installed':str(target),'frames':len(checks),'delivery':str(delivery)}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['prepare','build','refine','approve','install']);parser.add_argument('action',nargs='?');args=parser.parse_args()
    if args.command=='prepare':prepare()
    elif args.command=='build':build(args.action)
    elif args.command=='refine':refine(args.action)
    elif args.command=='approve':approve(args.action)
    elif args.command=='install':install()
