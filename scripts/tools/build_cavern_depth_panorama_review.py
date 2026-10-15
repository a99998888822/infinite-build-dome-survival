"""Package base-sorted grass and the five-cave scrolling bank from GPU captures."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'temp/artifacts/analysis/cavern_horizontal_parallax_review_20261013'
FRAMES = OUT / 'frames'


def main():
    global OUT, FRAMES
    parser = argparse.ArgumentParser()
    parser.add_argument('--reuse-media', action='store_true')
    parser.add_argument('--production-install', action='store_true')
    args = parser.parse_args()
    if args.production_install:
        OUT = ROOT / 'temp/artifacts/analysis/cavern_production_install_20261014'
        FRAMES = OUT / 'frames'
    data = json.loads((FRAMES / 'verification.json').read_text(encoding='utf-8'))
    runtime = json.loads((OUT / 'capture.json').read_text(encoding='utf-8'))
    assert not data['failures']
    assert runtime['exit_code'] == runtime['foreground_samples'] == 0
    assert runtime['private_desktop'] == runtime['verified_desktop']
    baseline = json.loads((OUT / 'production_before.json').read_text(encoding='utf-8'))
    changed = [p for p, h in baseline.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest()!=h]
    expected_changes = {'scenes/battle/battle_root.tscn','data_config/cavern_meadow_battlefield.json'} if args.production_install else set()
    assert set(changed) == expected_changes, changed
    if args.production_install:
        assert data['production_scene'] and not data['art_overrides']
    depth = data['depth_and_panorama']
    x, y, w, h = map(round, depth['rock_screen_rect'])
    with_grass = Image.open(FRAMES / 'base_grass.png').convert('RGB')
    control = Image.open(FRAMES / 'base_control.png').convert('RGB')
    a = np.array(with_grass)[y:y+h,x:x+w].astype(int)
    b = np.array(control)[y:y+h,x:x+w].astype(int)
    mask = np.array(Image.open(ROOT/'assets/sprites/background/cavern/prop_rock.png').getchannel('A').resize((w,h),Image.Resampling.NEAREST))>250
    difference = np.max(np.abs(a-b),axis=2)>3
    upper_changes = int((difference[:-36] & mask[:-36]).sum())
    contact_changes = int((difference[-36:] & mask[-36:]).sum())
    assert upper_changes == 0, ('grass improperly covers upper stone', upper_changes)
    assert contact_changes > 5, ('foreground grass must cover part of the base', contact_changes)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
    detail = Image.new('RGB',(640,286),'#111017')
    draw = ImageDraw.Draw(detail)
    for i,(shot,title) in enumerate([(control,'检查对照：隐藏草簇'),(with_grass,'当前效果：底座前后遮挡')]):
        draw.text((i*320+12,8),title,font=small,fill='#e2e6ce')
        detail.paste(shot.crop((x-85,y-40,x+235,y+206)),(i*320,40))
    detail.save(OUT/'base_detail.png')
    config = json.loads((ROOT/'data_config/cavern_battlefield.json').read_text(encoding='utf-8'))
    panorama = Image.open(ROOT/config['panorama'][6:]).convert('RGB')
    bank = Image.new('RGB',(1280,500),'#111017')
    draw = ImageDraw.Draw(bank)
    draw.text((18,10),'已接入的五张洞窟素材（处理后）',font=font,fill='#e2e6ce')
    cursor = 0
    for i,row in enumerate(config['panorama_modules']):
        left = (cursor+row['wall_gap']//2)*2
        tile = panorama.crop((left,0,left+row['width']*2,206))
        tile.thumbnail((402,170),Image.Resampling.NEAREST)
        col,row_i = i%3,i//3
        ox,oy = col*426+12,50+row_i*220
        bank.paste(tile,(ox+(402-tile.width)//2,oy))
        draw.text((ox+8,oy+178),row['source'],font=small,fill='#b7c3aa')
        cursor += row['width']+row['wall_gap']
    bank.save(OUT/'cave_bank.png')
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg
    for filename,extra in [('walkthrough.mp4',['-c:v','libx264','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart']),
                           ('walkthrough.gif',['-filter_complex','[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none','-loop','0'])]:
        if args.reuse_media and (OUT/filename).is_file():
            continue
        subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','10','-i',str(FRAMES/'tour_%03d.png'),*extra,str(OUT/filename)],check=True)
    gif = Image.open(OUT/'walkthrough.gif')
    assert gif.n_frames == len(data['samples']) == 180
    assert gif.size == (1280,720)
    profile_path = OUT/'profile/verification.json'
    profile = json.loads(profile_path.read_text(encoding='utf-8')) if profile_path.exists() else data
    profile_runtime = json.loads((OUT/'profile.json').read_text(encoding='utf-8')) if profile_path.exists() else runtime
    assert not profile['failures']
    assert profile_runtime['exit_code'] == profile_runtime['foreground_samples'] == 0
    assert profile_runtime['private_desktop'] == profile_runtime['verified_desktop']
    times = sorted(row['microseconds']/1000 for row in profile['update_profile'])
    summary = {'checks':data['checks'],'failures':data['failures'],'depth_and_panorama':depth,
               'production_installed':args.production_install,'art_overrides':data.get('art_overrides',True),
               'pixel_validation':{'upper_stone_covered_by_grass_pixels':upper_changes,'foreground_grass_over_base_pixels':contact_changes},
               'population_ranges':{key:[min(row[key] for row in data['samples']),max(row[key] for row in data['samples'])]
                                    for key in ['cells','grass_loaded','grass_batch_nodes','companion_grass']},
               'scene_update_cpu_ms':{'median':times[len(times)//2],'p95':times[int((len(times)-1)*.95)],'max':max(times)},
               'profile_validation':{'checks':profile['checks'],'failures':profile['failures'],'without_capture':profile.get('profile_only',False),'runtime':profile_runtime},
               'note':'CPU measures scenery update only, not total combat or GPU frame time; enemies paused for review.',
               'protected_files':len(baseline),'production_changed':changed,'runtime':runtime,'frames':180,'seconds':18,'route':data['route']}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>仅随横向移动的分层视差</title><style>
body{background:#101015;color:#eee9da;font:16px/1.7 system-ui,"Microsoft YaHei";margin:24px auto;max-width:1280px;padding:0 20px}
h1{font-size:25px}p{color:#c0c3b3}img,video{display:block;max-width:100%;height:auto;margin:18px auto}video{width:100%}a{color:#c6d8ae}
button{background:#262c28;color:#e3e8d3;padding:8px 14px;border:1px solid #576153;margin-right:8px;cursor:pointer}
</style><h1>停下即静止 · 横向移动时产生分层视差</h1>
<p>已取消超远景自动缓移。玩家左右移动时，远景遗迹按横向位移的 18%、超远景涵洞按 8% 移动；静止或上下移动时，两层背景保持不动。五张洞窟沿横向场景逐步展示，草簇底座遮挡与遗迹避让洞口的设计保留。</p>
<video id="tour" controls loop muted playsinline preload="metadata" poster="frames/base_grass.png" src="walkthrough.mp4"></video>
<button onclick="seek(0)">静止观察</button><button onclick="seek(2)">右移</button><button onclick="seek(6)">下移</button><button onclick="seek(10)">左移</button><button onclick="seek(14)">上移</button>
<p>18 秒连续实机录像：静止 2 秒，再右、下、左、上各 4 秒，录制中没有传送。可重点观察下移、上移时背景已完全停止。审阅时暂停刷怪，正式资源未替换。</p>
<p><a href="walkthrough.gif">原尺寸动图</a> · <a href="summary.json">验证记录</a></p>
<h2>物体底座附近</h2><img src="base_detail.png"><img src="frames/base_grass.png">
<h2>超远景素材</h2><img src="cave_bank.png">
<script>function seek(t){const v=document.getElementById('tour');v.currentTime=t;v.play()}</script>
'''
    if args.production_install:
        page = page.replace('停下即静止 · 横向移动时产生分层视差','正式战斗场景 · 已采用确认版本')
        page = page.replace('审阅时暂停刷怪，正式资源未替换。','录制时暂停刷怪；正常选人进入战斗即使用此版本。')
    (OUT/'index.html').write_text(page,encoding='utf-8')
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    main()
