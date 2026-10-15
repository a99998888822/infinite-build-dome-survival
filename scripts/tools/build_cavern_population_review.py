"""Package genuine GPU frames for review without altering scenery assets."""
from pathlib import Path
import hashlib
import json
import shutil
import statistics
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'temp/artifacts/analysis/cavern_population_review_20261013'
FRAMES = OUT / 'frames'


def main():
    data = json.loads((FRAMES / 'verification.json').read_text(encoding='utf-8'))
    runtime = json.loads((OUT / 'capture.json').read_text(encoding='utf-8'))
    assert not data['failures']
    assert runtime['exit_code'] == 0 and runtime['foreground_samples'] == 0
    assert runtime['private_desktop'] == runtime['verified_desktop']
    baseline = json.loads((OUT / 'production_before.json').read_text(encoding='utf-8'))
    changed = [p for p, h in baseline.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h]
    assert not changed, changed
    sequence = sorted(FRAMES.glob('tour_*.png'))
    assert len(sequence) == len(data['samples']) == 320
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg
    # Unretouched, full-resolution GPU frames. No rescaling or added pixels.
    if '--reuse-media' not in sys.argv:
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '10',
                        '-i', str(FRAMES / 'tour_%03d.png'), '-c:v', 'libx264', '-crf', '17',
                        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(OUT / 'battle_tour.mp4')], check=True)
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '10',
                        '-i', str(FRAMES / 'tour_%03d.png'), '-filter_complex',
                        '[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none',
                        '-loop', '0', str(OUT / 'battle_tour.gif')], check=True)
    gif = Image.open(OUT / 'battle_tour.gif')
    assert gif.size == (1280, 720) and gif.n_frames == 320
    duration = 0
    for i in range(gif.n_frames):
        gif.seek(i)
        duration += gif.info['duration']
    assert duration == 32000
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 17)
    sheet = Image.new('RGB', (1280, 812), '#111017')
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 12), 'ABCDQ 场景审阅 · 四向实机移动截帧', font=font, fill='#eeeade')
    for index, (frame, label) in enumerate([(39, '右移'), (119, '下移'), (199, '左移'), (279, '上移')]):
        x, y = (index % 2) * 640, 50 + (index // 2) * 381
        shot = Image.open(sequence[frame]).convert('RGB').resize((640, 360), Image.Resampling.NEAREST)
        sheet.paste(shot, (x, y))
        draw.text((x+12, y+360), label, font=small, fill='#d4d8b7')
    sheet.save(OUT / 'tour_contact.png')
    ranges = {k: [min(s[k] for s in data['samples']), max(s[k] for s in data['samples'])]
              for k in ('cells', 'grass_loaded', 'grass_visible', 'small_visible', 'scenery_nodes', 'grass_batch_nodes')}
    summary = {'checks': data['checks'], 'failures': data['failures'], 'production_files_verified': len(baseline),
               'production_changed': changed, 'runtime': runtime, 'route': data['route'], 'population_ranges': ranges,
               'idle_draw_calls_median': statistics.median(x['draw_calls'] for x in data['idle_metrics']),
               'note': 'Scenery review with enemies paused; engine fixed timestep 30, PNG sequence and playback 10 fps. Not a combat FPS benchmark.'}
    profile = OUT / 'profile/verification.json'
    if profile.exists():
        run = json.loads(profile.read_text(encoding='utf-8'))
        assert not run['failures'] and run['profile_only']
        summary['scene_cpu_profile_without_capture'] = {}
        for name, rows in [('all', run['update_profile']),
                           ('streaming', [r for r in run['update_profile'] if r['streamed']]),
                           ('steady', [r for r in run['update_profile'] if not r['streamed']])]:
            times = sorted(r['microseconds']/1000 for r in rows)
            summary['scene_cpu_profile_without_capture'][name] = {
                'count': len(times), 'median_ms': statistics.median(times),
                'p95_ms': times[int((len(times)-1)*.95)], 'max_ms': max(times)}
    (OUT / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    (OUT / 'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>ABCDQ 主战斗场景审阅</title><style>
body{margin:0;background:#101015;color:#eee9da;font:16px/1.7 system-ui,"Microsoft YaHei"}
main{max-width:1280px;margin:24px auto;padding:0 20px}h1{font-size:25px;margin-bottom:4px}
p{color:#bebfb2}video,img{display:block;width:100%;height:auto;border:1px solid #363c36;margin:16px 0}
nav{display:flex;gap:12px;flex-wrap:wrap}a{color:#c6d3b1}button{background:#252d25;color:#ecebd7;border:1px solid #576150;padding:8px 18px;cursor:pointer}
.note{color:#a7af9d;font-size:14px}</style><main>
<h1>ABCDQ 主战斗场景 · 独立审阅版</h1>
<p>草簇随地表颜色聚集，B/Q 中密度，A 超低密度，C 保留在两侧暗区。D 近景、涵洞背景与黑暗过渡沿用已确认版本。</p>
<video id="tour" src="battle_tour.mp4" controls loop muted playsinline preload="metadata" poster="frames/overview.png"></video>
<nav><button onclick="seek(0)">右移 0–8秒</button><button onclick="seek(8)">下移 8–16秒</button>
<button onclick="seek(16)">左移 16–24秒</button><button onclick="seek(24)">上移 24–32秒</button>
<a href="battle_tour.gif">打开原尺寸动图</a><a href="summary.json">验证记录</a></nav>
<p class="note">实际人物输入驱动，无录制中传送。审阅时暂停刷怪，便于观察摆放；该录像不作为战斗帧率测试。正式场景配置和素材未替换。</p>
<h2>起始区域 / A01 圆石</h2><img src="frames/overview.png">
<h2>A05 倒木区域</h2><img src="frames/log_area.png">
<h2>四向移动截帧</h2><img src="tour_contact.png">
<script>function seek(t){const v=document.getElementById('tour');v.currentTime=t;v.play()}</script></main>''', encoding='utf-8')
    print(json.dumps(summary, indent=2))
    print('GIF_BYTES', (OUT / 'battle_tour.gif').stat().st_size)
    print('MP4_BYTES', (OUT / 'battle_tour.mp4').stat().st_size)


if __name__ == '__main__':
    main()
