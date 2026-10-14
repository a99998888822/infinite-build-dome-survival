"""Package the open-pit lighting review from genuine engine captures."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/analysis/cavern_open_pit_review_20261013'
FRAMES = OUT / 'frames'
BEFORE = ROOT / 'artifacts/analysis/cavern_population_refine_20261013/frames/overview.png'


def main():
    data = json.loads((FRAMES / 'verification.json').read_text(encoding='utf-8'))
    capture = json.loads((OUT / 'capture.json').read_text(encoding='utf-8'))
    assert not data['failures']
    assert capture['exit_code'] == 0 and capture['foreground_samples'] == 0
    assert capture['private_desktop'] == capture['verified_desktop']
    baseline = json.loads((OUT / 'production_before.json').read_text(encoding='utf-8'))
    changed = [p for p, digest in baseline.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != digest]
    assert not changed, changed
    old = Image.open(BEFORE).convert('RGB')
    new = Image.open(FRAMES / 'overview.png').convert('RGB')
    a, b = np.array(old, dtype=float), np.array(new, dtype=float)
    regions = {'left_top_shadow': (0, 210, 150, 270), 'lit_floor': (420, 430, 820, 550),
               'bottom_arc': (280, 660, 480, 700)}
    measurements = {}
    for name, (x0, y0, x1, y1) in regions.items():
        measurements[name] = {'before': float(a[y0:y1,x0:x1].mean()), 'after': float(b[y0:y1,x0:x1].mean())}
    assert measurements['left_top_shadow']['after'] < measurements['left_top_shadow']['before']
    assert measurements['bottom_arc']['after'] < measurements['bottom_arc']['before']
    assert measurements['lit_floor']['after'] > measurements['lit_floor']['before']
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 23)
    comparison = Image.new('RGB', (1280, 802), '#111017')
    draw = ImageDraw.Draw(comparison)
    draw.text((18, 8), '上一版：水平暗带', font=font, fill='#dedccc')
    comparison.paste(old.resize((640, 360), Image.Resampling.NEAREST), (0, 44))
    draw.text((658, 8), '本版：露天坑底的椭圆光区', font=font, fill='#dedccc')
    comparison.paste(new.resize((640, 360), Image.Resampling.NEAREST), (640, 44))
    draw.text((18, 414), '顶部弧形暗边与远景遗迹（原尺寸局部）', font=font, fill='#dedccc')
    comparison.paste(new.crop((0, 35, 1280, 350)), (0, 456))
    comparison.save(OUT / 'comparison.png')
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg
    for filename, extra in [('pit_walkthrough.mp4', ['-c:v', 'libx264', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart']),
                            ('pit_walkthrough.gif', ['-filter_complex', '[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none', '-loop', '0'])]:
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '10',
                        '-i', str(FRAMES / 'tour_%03d.png'), *extra, str(OUT / filename)], check=True)
    gif = Image.open(OUT / 'pit_walkthrough.gif')
    assert gif.n_frames == len(data['samples']) == 160 and gif.size == (1280, 720)
    summary = {'checks': data['checks'], 'failures': data['failures'], 'protected_files': len(baseline),
               'production_changed': changed, 'lighting': data['atmosphere'], 'pixel_comparison': measurements,
               'capture': capture, 'frames': gif.n_frames, 'seconds': 16, 'route': data['route'],
               'review_only': True, 'enemies_paused': True, 'original_art_unchanged': True}
    (OUT / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    (OUT / 'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>露天地穴 · 顶部光照审阅</title><style>
body{background:#101015;color:#eee9da;font:16px/1.7 system-ui,"Microsoft YaHei";margin:24px auto;max-width:1280px;padding:0 20px}
h1{font-size:25px}p{color:#c0c3b3}img,video{display:block;width:100%;height:auto;margin:18px 0}a{color:#c6d8ae}
button{background:#262c28;color:#e3e8d3;padding:8px 14px;border:1px solid #576153;margin-right:8px;cursor:pointer}
</style><h1>巨大露天地穴 · 椭圆形受光区域</h1>
<p>顶部两侧阴影加深、中央退远；底部保留浅弧，坑底中央轻微提亮。遗迹放大约 28%，稍向远处移动，视差减慢，顶部光照略有提升。</p>
<img src="frames/overview.png">
<video id="tour" controls loop muted playsinline preload="metadata" poster="frames/overview.png" src="pit_walkthrough.mp4"></video>
<button onclick="seek(0)">右移</button><button onclick="seek(4)">下移</button><button onclick="seek(8)">左移</button><button onclick="seek(12)">上移</button>
<p>16 秒连续实机移动；录制中没有传送。暂停刷怪以便观察场景，正式资源和正式配置未替换。</p>
<p><a href="pit_walkthrough.gif">原尺寸动图</a> · <a href="summary.json">验证记录</a></p>
<img src="comparison.png"><script>function seek(t){const v=document.getElementById('tour');v.currentTime=t;v.play()}</script>
''', encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
