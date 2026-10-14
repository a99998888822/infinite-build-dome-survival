"""Package the continuous GPU rock walkthrough and validate its control shot."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/analysis/cavern_population_refine_20261013'
FRAMES = OUT / 'frames'


def main():
    data = json.loads((FRAMES / 'verification.json').read_text(encoding='utf-8'))
    capture = json.loads((OUT / 'capture.json').read_text(encoding='utf-8'))
    assert not data['failures']
    assert capture['exit_code'] == 0 and capture['foreground_samples'] == 0
    assert capture['private_desktop'] == capture['verified_desktop']
    baseline = json.loads((OUT / 'production_before.json').read_text(encoding='utf-8'))
    changed = [p for p, digest in baseline.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != digest]
    assert not changed, changed
    shadow = np.array(Image.open(FRAMES / 'blocked_shadow.png').convert('RGB'))
    control = np.array(Image.open(FRAMES / 'blocked_control.png').convert('RGB'))
    difference = np.max(np.abs(shadow.astype(int)-control.astype(int)), axis=2)>3
    difference[:250, :] = False
    difference[460:, :] = False
    difference[:, :500] = False
    difference[:, 780:] = False
    yy, xx = np.where(difference)
    assert 350 < len(xx) < 2500
    bounds = [int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1)]
    assert bounds[0] >= 600 and bounds[1] >= 300 and bounds[2] <= 680 and bounds[3] <= 410, bounds
    assert shadow[difference].mean() < control[difference].mean()
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg
    for filename, extra in [('rock_walkthrough.mp4', ['-c:v', 'libx264', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart']),
                            ('rock_walkthrough.gif', ['-filter_complex', '[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none', '-loop', '0'])]:
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '10',
                        '-i', str(FRAMES / 'occlusion_%03d.png'), *extra, str(OUT / filename)], check=True)
    gif = Image.open(OUT / 'rock_walkthrough.gif')
    assert gif.n_frames == len(data['occlusion_samples']) == 118
    assert gif.size == (1280, 720)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    sheet = Image.new('RGB', (960, 338), '#111017')
    draw = ImageDraw.Draw(sheet)
    for i, (name, title) in enumerate([('blocked_control', '石后：完全被遮住'), ('blocked_shadow', '石后：显示人形暗影'), ('front_normal', '绕至正面：恢复人物')]):
        shot = Image.open(FRAMES / f'{name}.png').convert('RGB')
        shot = shot.crop((480, 150, 800, 450))
        sheet.paste(shot, (i*320, 38))
        draw.text((i*320+10, 5), title, font=font, fill='#e6e9d7')
    sheet.save(OUT / 'occlusion_comparison.png')
    summary = {'checks': data['checks'], 'failures': data['failures'], 'protected_files': len(baseline),
               'production_changed': changed, 'small_props': data['small_prop_spacing'],
               'silhouette_changed_pixels': len(xx), 'silhouette_pixel_bounds': bounds,
               'capture': capture, 'frames': gif.n_frames, 'seconds': 11.8,
               'movement': 'continuous real input: rear block, right, down, left, front block, right, up, left, rear block',
               'review_only': True, 'enemies_paused': True}
    (OUT / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    (OUT / 'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>石后暗影与 B/Q 间距微调</title><style>
body{background:#101015;color:#eee9da;font:16px/1.7 system-ui,"Microsoft YaHei";margin:24px auto;max-width:1280px;padding:0 20px}
h1{font-size:25px}p{color:#c0c3b3}img,video{display:block;width:100%;height:auto;margin:18px 0}a{color:#c6d8ae}
</style><h1>石后人形暗影 · B/Q 避免相邻重复</h1>
<p>人物被石头挡住时显示随动作变化的人形暗影，绕到正面或离开遮挡后自动消失。小物件按跨区块规则错开同形状，保留原有中密度。</p>
<video controls loop muted playsinline preload="metadata" poster="frames/blocked_shadow.png" src="rock_walkthrough.mp4"></video>
<p>11.8 秒连续实机行走；录制中没有传送。暂停刷怪以便观察场景，正式资源和正式配置未替换。</p>
<p><a href="rock_walkthrough.gif">原尺寸动图</a> · <a href="summary.json">验证记录</a></p>
<img src="occlusion_comparison.png"><h2>B/Q 摆放全景</h2><img src="frames/overview.png">
''', encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
