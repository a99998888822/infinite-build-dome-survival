"""Package actual Godot frame captures as a portable browser review."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
NAMES={
    'dash_circle':('突进短刃 · 落地斩击','粗细错落的三段刀光，亮刃与深色厚度分层，接触帧加入短促爆点。','保留椭圆投影与原有时长。'),
    'star_depart':('移星 · 离开','五组成面晶片向中心收拢，最后压缩为一束亮核。','观察收缩是否清楚，角色是否仍可辨认。'),
    'star_arrive':('移星 · 抵达','亮核先出现，再向外打开为大小错落的紫蓝晶片。','与离开的运动方向相反。'),
    'star_return':('移星 · 返回','晶片逆向聚拢，以少量金色定位点区别首次闪现。','返回不增加额外伤害表现。'),
    'star_anchor':('移星 · 原位星印','加粗中心四角星、阶梯断环和深色底影，亮点分段流转。','放在角色旁检视；正式标记仍留在原位置。'),
    'star_shockwave':('移星 · 冲击环','五段宽窄不同的冲击带向外推进，中央迅速留空。','保留圆形语义，让角色与目标保持可见。'),
    'dash_trail':('突进短刃 · 残影','三组长短与厚薄不同的色块，头部聚拢、尾部碎裂。','定点检视图集，未模拟实际位移。'),
    'wind_blade':('风刃','硬边分段弧片、厚刃与碎片尾迹，替代平滑细线和透明曲面。','定点检视，原速时长保持 0.46 秒。'),
    'flail_trail':('流星摆锤 · 拖影','锤头后方的短弧改成断续钢蓝色块，靠锤头更亮。','保留正式锤头、铁链、姿态与 0.6 秒挥动。'),
}

def main():
    manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    render_check=json.loads((OUT/'gpu_capture.json').read_text(encoding='utf-8'))
    assert not render_check['failures']
    entries=[]; diffs={}
    for key,definition in manifest['effects'].items():
        n=definition['frames']; all_frames={}
        for variant in ['baseline','candidate']:
            frames=[Image.open(OUT/'godot_frames'/f'{key}_{variant}_{i:02d}.png').convert('RGB') for i in range(n)]
            assert all(frame.size==(440,320) for frame in frames)
            sheet=Image.new('RGB',(440*n,320))
            for i,frame in enumerate(frames): sheet.paste(frame,(440*i,0))
            sheet.save(OUT/'renders'/f'{key}_{variant}.webp',lossless=True,method=6)
            all_frames[variant]=frames
        diffs[key]=sum(ImageChops.difference(a,b).getbbox() is not None for a,b in zip(all_frames['baseline'],all_frames['candidate']))
        assert diffs[key]>0,(key,'candidate not visible')
        title,description,note=NAMES[key]
        entries.append({'id':key,'title':title,'description':description,'note':note,'frames':n,'fps':definition['fps'],
                        'priority':'中' if key in ['dash_trail','wind_blade','flail_trail'] else '高',
                        'loop':key=='star_anchor','cell':[440,320]})
        if key=='dash_circle':
            pairs=[]
            for a,b in zip(all_frames['baseline'],all_frames['candidate']):
                pair=Image.new('RGB',(880,350),'#16231f'); pair.paste(a,(0,30)); pair.paste(b,(440,30))
                d=ImageDraw.Draw(pair); font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
                d.text((12,3),'当前版本',fill='#ccd6cc',font=font); d.text((452,3),'候选 R01 · 0.5 倍速',fill='#e5c783',font=font)
                pairs.append(pair)
            pairs[0].save(OUT/'dash_comparison.gif',save_all=True,append_images=pairs[1:],duration=42,loop=0)
    lamp_frames=[Image.open(OUT/'godot_frames'/f'lamp_reference_{i:02d}.png').convert('RGB') for i in range(18)]
    sheet=Image.new('RGB',(440*18,320))
    for i,frame in enumerate(lamp_frames): sheet.paste(frame,(440*i,0))
    sheet.save(OUT/'renders/lamp_reference.webp',lossless=True,method=6)
    entries.append({'id':'lamp_reference','title':'风格参考 · 赤铜炉灯','description':'正式版本的像素火流：硬边色阶、成组块面、分帧变化。','note':'参考项，未改造。','frames':18,'fps':18,'priority':'参考','loop':True,'cell':[440,320]})
    (OUT/'review-data.js').write_text('window.REVIEW_DATA = '+json.dumps(entries,ensure_ascii=False,indent=2)+';\n',encoding='utf-8')
    board=Image.new('RGB',(990,834),'#15221e'); d=ImageDraw.Draw(board); font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',19)
    for j,(key,definition) in enumerate(manifest['effects'].items()):
        i=min(definition['frames']-1,3 if key!='flail_trail' else 10)
        frame=Image.open(OUT/'godot_frames'/f'{key}_candidate_{i:02d}.png').convert('RGB')
        x,y=j%3*330,j//3*278
        d.text((x+12,y+9),NAMES[key][0],fill='#e2d5ae',font=font)
        board.paste(frame.resize((330,240),Image.Resampling.NEAREST),(x,y+38))
    board.save(OUT/'overview.png')
    unchanged={path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in manifest['protected_sha256'].items()}
    assert all(unchanged.values()),unchanged
    report={'candidate_pixels_visible':diffs,'production_files_unchanged':unchanged,'captures':render_check['captured'],
            'authored_grid_px':2,'candidate_alpha':[0,255],'model_used':None,
            'note':'Controlled Godot frame sampling. Browser playback uses the captured frame order and declared FPS. No combat integration or balance test claimed.'}
    (OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('PACKAGED',len(entries),'CAPTURES',render_check['captured'],'UNCHANGED',len(unchanged))

if __name__=='__main__':main()
