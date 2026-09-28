"""Package the reviewed 3838180 Picxel frames; never install runtime textures."""
from pathlib import Path
from argparse import Namespace
import hashlib
import json
import shutil
from PIL import Image,ImageDraw,ImageFont
import build_combat_picxel_review as t

TASK=t.TASK
DELIVERY=TASK/'delivery'
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',23)
SMALL=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
LABELS={'beginner':'初心者','boss_walk':'小 Boss · 移动','boss_attack':'小 Boss · 攻击','enemy_walk':'小怪 · 移动'}


def sheet(frames,path):
    width,height=frames[0].size
    result=Image.new('RGBA',(width*len(frames),height))
    for index,frame in enumerate(frames):result.paste(frame,(index*width,0))
    path.parent.mkdir(parents=True,exist_ok=True);result.save(path)


def pack():
    records=t.external.read(TASK/'source-map.json')['records']
    all_frames={};transforms=[]
    for group in t.GROUPS:
        selected=[r for r in records if r['group']==group]
        frames=[]
        for record in selected:
            size=64 if group in ('beginner','enemy_walk') else 128
            path=TASK/group/'work'/f"{record['name']}-{size}.png"
            native=Image.open(path).convert('RGBA')
            if group=='beginner':
                result=native.crop((5,5,59,59));dx,dy=-5,-5
                assert result.getbbox()[3]==52
            elif group=='enemy_walk':
                result=Image.new('RGBA',(86,86));dx,dy=11,60-native.getbbox()[3]
                result.alpha_composite(native,(dx,dy))
            else:
                result=Image.new('RGBA',(160,160))
                dx=16;dy=128-native.getbbox()[3] if group=='boss_walk' else 2
                result.alpha_composite(native,(dx,dy))
            assert sum(native.getchannel('A').tobytes())==sum(result.getchannel('A').tobytes()),record['name']
            out=DELIVERY/group/'frames';out.mkdir(parents=True,exist_ok=True)
            result.save(out/f"{record['name']}.png")
            if group=='beginner':
                directory=DELIVERY/group/'frames_128';directory.mkdir(exist_ok=True)
                shutil.copyfile(TASK/group/'work'/f"{record['name']}-128.png",directory/f"{record['name']}.png")
            frames.append(result)
            transforms.append({'name':record['name'],'native_grid':size,'canvas':result.size,'translation':[dx,dy],'opaque_pixels':sum(1 for value in result.getchannel('A').tobytes() if value)})
        all_frames[group]=frames
    beginner=DELIVERY/'beginner/combat'
    sheet([all_frames['beginner'][0]],beginner/'void_hunter_idle_right.png')
    sheet([all_frames['beginner'][i-1] for i in (1,3,5,7)],beginner/'void_hunter_walk_right_spritesheet.png')
    sheet(all_frames['beginner'],beginner/'void_hunter_walk_right_all_frames.png')
    ui=DELIVERY/'beginner/ui';ui.mkdir(parents=True,exist_ok=True)
    Image.open(TASK/'beginner/work/beginner_01-128.png').resize((256,256),Image.Resampling.NEAREST).save(ui/'void_hunter_idle_right.png')
    shutil.copyfile(TASK/'portrait/work/beginner_portrait-128.png',ui/'icon_void_hunter.png')
    boss=DELIVERY/'boss/combat'
    sheet(all_frames['boss_walk'],boss/'knight_move.png')
    sheet([all_frames['boss_walk'][0]],boss/'knight_idle.png')
    attack=all_frames['boss_attack']
    sheet(attack,boss/'knight_attack.png')
    sheet(attack[:7],boss/'knight_windup.png')
    sheet(attack[7:9],boss/'knight_dash.png')
    sheet(attack[9:],boss/'knight_recover.png')
    enemy=DELIVERY/'enemy/combat'
    sheet([all_frames['enemy_walk'][0]],enemy/'enemy_gloom_mite_idle.png')
    sheet([all_frames['enemy_walk'][i-1] for i in (1,3,6)],enemy/'enemy_gloom_mite_move.png')
    sheet(all_frames['enemy_walk'],enemy/'enemy_gloom_mite_move_all_frames.png')
    layout={
        'status':'awaiting_user_review','runtime_assets_modified':False,'image_model_used':False,'remote_commit':'3838180',
        'method':'Source background masks, Picxel palette voting, original light/ink recovery and localized face patches',
        'maximum_colors_per_subject':16,'alpha':[0,255],
        'beginner':{'frame_size':[54,54],'compatible_frames':[1,3,5,7],'compatible_fps':3.5,'all_frames':8,'all_frames_fps':7,'idle_source_frame':1,'display':[256,256],'portrait':[128,128]},
        'boss':{'frame_size':[160,160],'native_grid':[128,128],'move_frames':11,'move_fps':11,'attack_frames':11,
                'windup':{'source_frames':[1,2,3,4,5,6,7],'duration_seconds':.8},
                'dash':{'source_frames':[8,9],'duration_seconds':.16},
                'recover':{'source_frames':[10,11],'duration_seconds':.5},
                'notes':['Frame counts must be updated in SpriteFrames on installation.','No death or return-to-idle source frames were supplied.','Frame 8 arc and frames 9-11 impact light are baked into the artwork.']},
        'enemy':{'frame_size':[86,86],'native_grid':[64,64],'compatible_frames':[1,3,6],'compatible_frame_duration_seconds':.14,'all_frames':7,'all_frames_preview_fps':8,'idle_source_frame':1},
        'frame_transforms':transforms,'files':[]}
    for path in sorted(DELIVERY.rglob('*.png')):
        image=Image.open(path).convert('RGBA');colors=image.getcolors(image.width*image.height)
        visible={pixel for _,pixel in colors if pixel[3]}
        assert len(visible)<=16,path
        assert set(image.getchannel('A').tobytes())=={0,255},path
        layout['files'].append({'path':path.relative_to(TASK).as_posix(),'size':image.size,'opaque_colors':len(visible),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    for record in records:
        assert hashlib.sha256((t.ROOT/record['source']).read_bytes()).hexdigest()==record['sha256']
    t.write(TASK/'manifest.json',layout)
    previews(all_frames)
    print(json.dumps({'delivery_pngs':len(layout['files']),'source_frames':len(records),'runtime_assets_modified':False}))


def stamp(canvas,sprite,position,scale=1):
    sprite=sprite.resize((sprite.width*scale,sprite.height*scale),Image.Resampling.NEAREST)
    canvas.paste(sprite,position,sprite)


def previews(frames):
    overview=Image.new('RGB',(1120,790),'#172b2b');draw=ImageDraw.Draw(overview)
    draw.text((24,16),'新版初心者与怪物 · Picxel 审阅稿',font=FONT,fill='#f1e7cf')
    draw.text((24,51),'37 帧原图像素化 · 真透明 · 每主体最多 16 色 · 当前仅供审阅',font=SMALL,fill='#aec4b7')
    for index,group in enumerate(t.GROUPS):
        x=20+(index%2)*550;y=88+(index//2)*345
        draw.rounded_rectangle((x,y,x+530,y+326),radius=8,fill='#46645e')
        draw.text((x+18,y+12),LABELS[group],font=FONT,fill='#f1e7cf')
        if group=='beginner':
            im=Image.open(DELIVERY/'beginner/ui/void_hunter_idle_right.png').convert('RGBA')
            stamp(overview,im,(x+3,y+37))
            portrait=Image.open(DELIVERY/'beginner/ui/icon_void_hunter.png').convert('RGBA')
            stamp(overview,portrait,(x+270,y+65))
            stamp(overview,frames[group][2],(x+415,y+137),1)
            text='8 帧 · 战斗 54×54 · 展示 256 · 头像 128'
        elif group=='enemy_walk':
            stamp(overview,frames[group][0],(x+50,y+49),2)
            stamp(overview,frames[group][3],(x+283,y+78),2)
            text='7 帧 · 64 像素稿 → 86×86 透明画布'
        else:
            native=Image.open(TASK/group/'work'/f'{group}_{1 if group=="boss_walk" else 9:02d}-128.png').convert('RGBA')
            stamp(overview,native,(x+5,y+42),2)
            other=frames[group][6 if group=='boss_walk' else 7]
            stamp(overview,other,(x+303,y+103),1)
            text='11 帧 · 128 像素稿 → 160×160 透明画布'
        draw.text((x+16,y+292),text,font=SMALL,fill='#e3e3cc')
    overview.save(TASK/'review.png')
    # Each contact sheet displays every actual delivery frame at integer scale.
    for group,sequence in frames.items():
        side=sequence[0].width;scale=2 if side>=128 else 3
        cell=side*scale+12;cols=4;rows=(len(sequence)+cols-1)//cols
        board=Image.new('RGB',(cols*cell,rows*(side*scale+38)+50),'#46645e');d=ImageDraw.Draw(board)
        d.text((12,8),LABELS[group]+' · 全部原始帧顺序',font=FONT,fill='#f1e7cf')
        for i,frame in enumerate(sequence):
            x=i%cols*cell;y=50+i//cols*(side*scale+38)
            stamp(board,frame,(x,y),scale);d.text((x+12,y+side*scale+3),f'{i+1:02d}',font=SMALL,fill='#f1e7cf')
        board.save(TASK/f'{group}-frames.png')
        if group=='boss_attack':durations=[110,110,120,110,110,120,120,80,80,250,250]
        else:durations=[round(1000/({'beginner':7,'boss_walk':11,'enemy_walk':8}[group])/10)*10]*len(sequence)
        movie=[]
        for i,frame in enumerate(sequence):
            canvas=Image.new('RGB',(side*scale+80,side*scale+94),'#46645e');d=ImageDraw.Draw(canvas)
            d.text((16,10),LABELS[group]+' · 素材预览',font=SMALL,fill='#f1e7cf')
            stamp(canvas,frame,(40,40),scale)
            d.text((16,side*scale+53),f'{i+1:02d} / {len(sequence):02d}',font=SMALL,fill='#f1e7cf');movie.append(canvas)
        movie[0].save(TASK/f'{group}.gif',save_all=True,append_images=movie[1:],duration=durations,loop=0,disposal=2)
    # Four animations together; supplied PNGs, never a claimed game recording.
    movie=[]
    for tick in range(40):
        now=tick*.05
        canvas=Image.new('RGB',(900,690),'#172b2b');d=ImageDraw.Draw(canvas)
        for index,group in enumerate(t.GROUPS):
            x=(index%2)*450;y=(index//2)*345
            d.rectangle((x+8,y+8,x+442,y+337),fill='#46645e')
            d.text((x+20,y+15),LABELS[group],font=FONT,fill='#f1e7cf')
            if group=='boss_attack':
                if now<.8:frame=frames[group][min(6,int(now/.8*7))]
                elif now<.96:frame=frames[group][7+min(1,int((now-.8)/.16*2))]
                elif now<1.46:frame=frames[group][9+min(1,int((now-.96)/.5*2))]
                else:frame=frames['boss_walk'][0]
            else:
                fps={'beginner':7,'boss_walk':11,'enemy_walk':8}[group]
                frame=frames[group][int(now*fps)%len(frames[group])]
            scale=3 if group=='beginner' else 2 if group=='enemy_walk' else 1
            if group.startswith('boss'):
                # Integer crop removes only the preview canvas; full PNG stays 160.
                frame=frame.crop((16,0,144,140));scale=2
            stamp(canvas,frame,(x+(450-frame.width*scale)//2,y+49),scale)
            d.text((x+20,y+308),'像素素材预览 · 非实机录像',font=SMALL,fill='#d0dccc')
        movie.append(canvas)
    movie[0].save(TASK/'animations.gif',save_all=True,append_images=movie[1:],duration=50,loop=0,disposal=2)


if __name__=='__main__':pack()
