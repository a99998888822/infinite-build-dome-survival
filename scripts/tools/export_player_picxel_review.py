"""Export reviewed Picxel player frames as review-only Godot asset packages."""
from argparse import ArgumentParser, Namespace
from pathlib import Path
import hashlib
import json
import shutil

from PIL import Image, ImageDraw, ImageFont
import prepare_player_picxel_review as task

ROOT, TASK, external = task.ROOT, task.TASK, task.external
NAMES = {'beginner': '初心者', 'capitalist': '资本家'}
PREFIX = {'beginner':'void_hunter', 'capitalist':'capitalist'}
IDLE = {'beginner':3, 'capitalist':7}
FOUR = {'beginner':[2,4,5,6], 'capitalist':[1,3,5,7]}


def select_frames():
    report=external.read(TASK/'work/batch-report.json')
    for entry in report['jobs']:
        for size in (64,128):
            external.select(Namespace(out=TASK/'work',name=entry['name'],size=size,
                sheet=task.final_path(TASK,entry['name'],size),
                note='Compared all source poses, face crops and native/enlarged results. Complete hands, feet and held props; source gaze retained; one-pixel contour precedes local eye repairs.'))
    external.finish(Namespace(out=TASK/'work'))


def portraits():
    base=TASK/'portraits'
    for folder in ('refs','prepared'): (base/folder).mkdir(parents=True,exist_ok=True)
    source_map={r['name']:r for r in external.read(TASK/'source-map.json')['records']}
    for character in NAMES:
        name=f'{character}_walk{IDLE[character]:02d}'
        source=ROOT/source_map[name]['source']
        original=Image.open(source).convert('RGBA')
        cut=task.extract(original,character,IDLE[character])
        crop=(190,35,565,480) if character=='beginner' else (180,35,550,495)
        cut.crop(crop).save(base/'prepared'/f'{character}_portrait.png')
        shutil.copyfile(source,base/'refs'/f'{character}_portrait.png')
        anchor={'subject':f'{character} head and shoulders from the supplied standing pose',
                'kind':'sprite','size':128,'palette':task.PALETTES[character],
                'keep':['Original head silhouette and three-quarter view','Original gaze and expression',
                        'Blond fringe and teal eyes' if character=='beginner' else 'Tall hat, monocle and bow tie'],
                'drop':['Background and lower body outside portrait crop'],
                'regions':[], 'faces':[{'box':[0.1,0.25,0.92,0.83],'complex':True,
                    'expression':'Neutral focused expression' if character=='beginner' else 'Calm half-lidded expression',
                    'gaze':'Iris toward image-right, light sclera on image-left' if character=='beginner' else 'Head faces right; pupils left/central under lids with sclera toward image-right',
                    'reason':'Check original iris and monocle after palette reduction'}], 'source_crop':crop}
        task.write(base/'refs'/f'{character}_portrait.anchor.json',anchor)
    external.build(Namespace(refs=base/'refs',out=base/'work',prepared_dir=base/'prepared',sizes=[128],background='none'))


def sheet(frames):
    side=frames[0].width
    result=Image.new('RGBA',(side*len(frames),side))
    for i,frame in enumerate(frames): result.paste(frame,(side*i,0))
    return result


def export():
    delivery=TASK/'delivery'
    source_map=external.read(TASK/'source-map.json')['records']
    manifest={'status':'awaiting_user_review','runtime_assets_modified':False,
              'image_model_used':False,'method':'Source extraction, Picxel palette majority vote, source ink recovery and local eye/accessory repairs',
              'combat_native_grid':[64,64],'combat_export':[54,54],'combat_crop':[5,5,59,59],
              'combat_baseline_bottom':52,'maximum_colors_per_character':16,
              'alpha':[0,255],'characters':{},'files':[]}
    all_frames={}
    for character in NAMES:
        out=delivery/character
        for folder in ('combat','frames_64','frames_128','ui'): (out/folder).mkdir(parents=True,exist_ok=True)
        frames=[]
        records=sorted((r for r in source_map if r['character']==character),key=lambda r:r['frame'])
        translations=[]
        for record in records:
            for size in (64,128):
                im=Image.open(TASK/'work'/f"{record['name']}-{size}.png").convert('RGBA')
                im.save(out/f'frames_{size}'/f"{record['name']}.png")
                if size==64:
                    cropped=im.crop((5,5,59,59))
                    assert sum(cropped.getchannel('A').tobytes())==sum(im.getchannel('A').tobytes())
                    dy=52-cropped.getbbox()[3]
                    fixed=Image.new('RGBA',(54,54));fixed.alpha_composite(cropped,(0,dy))
                    assert sum(fixed.getchannel('A').tobytes())==sum(cropped.getchannel('A').tobytes())
                    assert fixed.getbbox()[3]==52
                    frames.append(fixed);translations.append(dy)
            assert hashlib.sha256((ROOT/record['source']).read_bytes()).hexdigest()==record['sha256']
        prefix=PREFIX[character]
        frames[IDLE[character]-1].save(out/'combat'/f'{prefix}_idle_right.png')
        compatible=sheet([frames[i-1] for i in FOUR[character]])
        compatible.save(out/'combat'/f'{prefix}_walk_right_spritesheet.png')
        sheet(frames).save(out/'combat'/f'{prefix}_walk_right_all_frames.png')
        showcase=Image.open(out/'frames_128'/f'{character}_walk{IDLE[character]:02d}.png')
        showcase.resize((256,256),Image.Resampling.NEAREST).save(out/'ui'/f'{prefix}_idle_right.png')
        portrait=TASK/'portraits/work'/f'{character}_portrait-128.png'
        shutil.copyfile(portrait,out/'ui'/f'icon_{prefix}.png')
        manifest['characters'][character]={'display_name':NAMES[character],
            'source_frame_count':len(frames),'idle_source_frame':IDLE[character],
            'compatible_walk_source_frames':FOUR[character],'compatible_walk_frames':4,
            'compatible_walk_fps':3.5 if character=='beginner' else 6,
            'all_frames_sheet_size':[54*len(frames),54],
            'all_frames_fps_for_same_cycle_duration':len(frames)*(3.5 if character=='beginner' else 6)/4,
            'pixel_baseline_correction_y':translations,'display_size':[256,256],
            'display_method':'2x nearest-neighbour enlargement from genuine 128px source-derived grid',
            'icon_size':[128,128],'icon_method':'Independent 128px conversion from high-resolution head-and-shoulders crop',
            'left_facing':'Mirror the complete frame as existing PlayerController does',
            'palette':task.PALETTES[character]}
        all_frames[character]=frames
    for path in delivery.rglob('*.png'):
        im=Image.open(path).convert('RGBA')
        colors={tuple(p) for p in im.getdata() if p[3]}
        assert len(colors)<=16,path
        assert set(im.getchannel('A').tobytes())=={0,255},path
        assert all(im.getpixel(pt)[3]==0 for pt in ((0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1))),path
        manifest['files'].append({'path':path.relative_to(TASK).as_posix(),'size':im.size,'opaque_colors':len(colors),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    task.write(TASK/'manifest.json',manifest)
    review(all_frames,delivery)
    print(json.dumps({'files':len(manifest['files']),'review':str(TASK/'review.png'),'runtime_modified':False}))


def review(all_frames,delivery):
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
    board=Image.new('RGB',(1120,740),'#172b2b');d=ImageDraw.Draw(board)
    d.text((28,18),'角色像素素材 · 审阅稿',font=font,fill='#e5dcc0')
    d.text((28,53),'全身与头像独立处理 · 每角色 16 色 · 真透明 · 最近邻显示',font=small,fill='#a3bdb2')
    for i,character in enumerate(NAMES):
        y=90+i*312
        d.rounded_rectangle((20,y,1100,y+296),radius=8,fill='#46645e')
        d.text((36,y+10),NAMES[character],font=font,fill='#f1e7cf')
        display=Image.open(delivery/character/'ui'/f'{PREFIX[character]}_idle_right.png').convert('RGBA')
        board.paste(display,(20,y+36),display)
        portrait=Image.open(delivery/character/'ui'/f'icon_{PREFIX[character]}.png').convert('RGBA')
        board.paste(portrait,(286,y+56),portrait)
        d.text((292,y+204),'128×128 头像',font=small,fill='#e8e7d7')
        idle=all_frames[character][IDLE[character]-1]
        board.paste(idle,(325,y+232),idle)
        d.text((422,y+22),'战斗动作 · 54×54 / 帧（下列为 2 倍显示）',font=small,fill='#e8e7d7')
        for j,frame in enumerate(all_frames[character]):
            x=433+j*93
            large=frame.resize((108,108),Image.Resampling.NEAREST)
            board.paste(large,(x-16,y+78),large)
            d.text((x+20,y+192),str(j+1),font=small,fill='#e8e7d7')
        d.text((434,y+241),'现有配置四帧顺序：'+' → '.join(map(str,FOUR[character])),font=small,fill='#e0d2a7')
        d.text((434,y+265),'全部原始动作帧亦已保留；底色仅用于审阅。',font=small,fill='#c4d5cd')
    board.save(TASK/'review.png')
    # The movie is a sprite preview, never labelled as captured gameplay.
    frames=[]
    for tick in range(60):
        im=Image.new('RGB',(680,340),'#46645e');draw=ImageDraw.Draw(im)
        draw.text((22,12),'四帧兼容图集 · 动作预览',font=font,fill='#eee4cc')
        for i,character in enumerate(NAMES):
            fps=3.5 if character=='beginner' else 6
            index=int((tick/15)*fps)%4
            sprite=all_frames[character][FOUR[character][index]-1]
            sprite=sprite.resize((216,216),Image.Resampling.NEAREST)
            im.paste(sprite,(58+336*i,66),sprite)
            draw.text((85+336*i,294),NAMES[character]+f' · {fps:g} FPS',font=small,fill='#eee4cc')
        frames.append(im)
    frames[0].save(TASK/'walk-preview.gif',save_all=True,append_images=frames[1:],duration=[70,60,70]*20,loop=0,disposal=2)


if __name__=='__main__':
    parser=ArgumentParser();parser.add_argument('stage',choices=['select','portraits','export'])
    args=parser.parse_args()
    {'select':select_frames,'portraits':portraits,'export':export}[args.stage]()
