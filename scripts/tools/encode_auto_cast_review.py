"""Encode real Godot screenshots at their recorded physics timestamps."""
from pathlib import Path
import argparse
import hashlib
import html
import json
import subprocess

import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--return-capture', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    runs = []
    for root in [args.capture] + ([args.return_capture] if args.return_capture else []):
        report = json.loads((root / 'capture.json').read_text(encoding='utf-8'))
        desktop = json.loads((root / 'runtime.json').read_text(encoding='utf-8'))
        assert report['failures'] == 0
        assert desktop['exit_code'] == 0 and desktop['foreground_samples'] == 0
        assert desktop['verified_desktop'] == desktop['private_desktop']
        runs.append((root, report, desktop))
    clean_log = (runs[-1][0] / 'runtime.log').read_text(encoding='utf-8', errors='replace')
    assert not any(x in clean_log for x in ['ERROR:', 'SCRIPT ERROR', 'FAIL '])
    clips = []
    for key in runs[0][1]['samples']:
        root, report, desktop = runs[1] if len(runs) > 1 and key == '08_manual_return' else runs[0]
        samples = report['samples'][key]
        assert len(samples) > 1
        stride = samples[-1]['tick'] - samples[-2]['tick']
        assert stride > 0
        duration_ms = round((samples[-1]['tick'] + stride - samples[0]['tick']) / report['physics_fps'] * 1000)
        atlas = Image.new('RGB', (320 * 8, 180 * 4))
        for i in range(32):
            with Image.open(root / samples[min(len(samples)-1, i * len(samples) // 32)]['file']) as source:
                atlas.paste(source.convert('RGB').resize((320, 180)), ((i % 8) * 320, (i // 8) * 180))
        background = atlas.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
        accents = []
        for sample in samples:
            with Image.open(root / sample['file']) as source:
                pixels = np.asarray(source.convert('RGB'))[::3, ::3].astype(np.int16)
            red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
            mask = ((blue-red > 8) & (blue >= green)) | ((red-green > 25) & (red > 130)) | (pixels.min(axis=2) > 140)
            colors = pixels[mask].astype(np.uint8)
            if len(colors): accents.append(colors[::max(1, len(colors)//1200)])
        foreground = Image.fromarray(np.concatenate(accents).reshape(1, -1, 3)).quantize(colors=128)
        palette = Image.new('P', (1, 1))
        palette.putpalette(background.getpalette()[:384] + foreground.getpalette()[:384])
        frames, durations = [], []
        encoded = 0
        for i, sample in enumerate(samples):
            with Image.open(root / sample['file']) as source:
                image = source.convert('RGB')
                frames.append(image.quantize(palette=palette, dither=Image.Dither.NONE))
            next_tick = samples[i+1]['tick'] if i+1 < len(samples) else sample['tick'] + stride
            cumulative = round((next_tick - samples[0]['tick']) / report['physics_fps'] * 100) * 10
            durations.append(max(10, cumulative-encoded))
            encoded = cumulative
        gif = args.output / (key + '.gif')
        frames[0].save(gif, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True, disposal=1)
        with Image.open(gif) as verify:
            assert verify.is_animated and abs(sum(verify.seek(i) or verify.info.get('duration', 0) for i in range(verify.n_frames)) - duration_ms) <= 20
            verify.seek(verify.n_frames // 2)
            verify.convert('RGB').save(args.output / (key + '_poster.png'))
        del frames
        # Full resolution MP4 uses the same real screenshot sequence and timeline.
        concat = root / (key + '_concat.txt')
        rows = []
        for i, sample in enumerate(samples):
            path = (root / sample['file']).resolve().as_posix()
            assert "'" not in path
            next_tick = samples[i+1]['tick'] if i+1 < len(samples) else sample['tick'] + stride
            rows += ["file '" + path + "'", 'duration %.9f' % ((next_tick-sample['tick']) / report['physics_fps'])]
        rows.append(rows[-2])
        concat.write_text('\n'.join(rows) + '\n', encoding='utf-8')
        mp4 = args.output / (key + '.mp4')
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(concat), '-t', str(duration_ms/1000), '-fps_mode', 'vfr', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(mp4)], check=True)
        clips.append({'id': key, **report['descriptions'][key], 'frames': len(samples), 'duration_ms': duration_ms,
                      'gif': gif.name, 'mp4': mp4.name, 'gif_bytes': gif.stat().st_size,
                      'source': str(root), 'desktop': desktop['private_desktop'],
                      'sha256': hashlib.sha256(gif.read_bytes()).hexdigest(),
                      'events': [item for item in report['launches'] if item['clip'] == key]})
        print(key, len(samples), duration_ms, gif.stat().st_size, flush=True)
    manifest = {'real_gameplay': True, 'retimed': False, 'gif_size': [1280, 720], 'video_size': [1280, 720],
                'fixtures': runs[0][1]['fixtures'], 'desktop_reports': [r[2] for r in runs], 'clips': clips,
                'review_scope': 'Esc per-weapon mode icons, battle status icons and the two-page Settings panel. Optional movement chapters demonstrate the current production UI.'}
    (args.output / 'verification.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for i, (_, _, desktop) in enumerate(runs):
        (args.output / ('desktop_%d.json' % (i+1))).write_text(json.dumps(desktop, indent=2) + '\n', encoding='utf-8')
    build_page(args.output, clips)


def build_page(output, clips):
    note = '正式 GameRoot 实机录制。已暂停额外刷怪并固定测试遭遇；部分场景使用静止、高血量目标，撤退场景保留敌人追击。字幕与鼠标标记仅用于审阅，攻击、移动、输入及冷却均为正式实现。按实际游戏时间编码，未补画或加速。逐帧保存图片会降低录制时的显示 FPS，画面中的 FPS 不作为游戏性能结果。'
    cards, navigation, markdown = [], [], ['# 自动释放与位移：实机动图审阅', '', note, '', f'{len(clips)} 段录制均在私有桌面完成，foreground_samples=0。视频可暂停、拖动进度、全屏或切换 0.5 倍速；GIF 按正常游戏速度循环。', '']
    for n, clip in enumerate(clips, 1):
        title, description = html.escape(clip['title']), html.escape(clip['description'])
        navigation.append(f'<a href="#{clip["id"]}">{n:02d} {title.split("：")[0]}</a>')
        cards.append(f'''<section id="{clip['id']}"><div class="heading"><span>{n:02d}</span><div><h2>{title}</h2><p>{description}</p></div><small>{clip['duration_ms']/1000:.1f}s</small></div>
<video controls muted loop playsinline preload="metadata" poster="{clip['id']}_poster.png"><source src="{clip['mp4']}" type="video/mp4"></video>
<div class="actions"><button onclick="const v=this.closest('section').querySelector('video');v.currentTime=0;v.play()">从头播放</button><button onclick="const v=this.closest('section').querySelector('video');v.playbackRate=v.playbackRate===1?0.5:1;this.textContent=v.playbackRate===1?'切换 0.5×':'恢复 1×'">切换 0.5×</button><a href="{clip['gif']}" target="_blank">打开 GIF</a><a href="{clip['mp4']}" download>下载原分辨率视频</a></div></section>''')
        markdown += [f'## {n}. {clip["title"]}', '', f'![{clip["title"]}]({(output / clip["gif"]).resolve().as_posix()})', '', f'[原分辨率视频]({(output / clip["mp4"]).resolve().as_posix()}) · {clip["duration_ms"]/1000:.1f} 秒', '']
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>自动释放与位移 · 实机审阅</title><style>
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#0c1512;color:#e3eadf;font:15px/1.7 "Microsoft YaHei",sans-serif}main{max-width:1180px;margin:0 auto;padding:40px 24px}h1{font-size:32px;line-height:1.35;margin:8px 0 18px}h2{font-size:19px;line-height:1.45;margin:0;color:#e9d492}p{margin:5px 0;color:#aabdb2}.tag{color:#b8e9c7;font-size:13px}nav{display:flex;gap:8px;flex-wrap:wrap;margin:24px 0 36px}a,button{color:#cae9e1;text-decoration:none}nav a,.actions>*{border:1px solid #3b5245;padding:7px 12px;border-radius:6px;background:#17281f}section{scroll-margin-top:16px;margin-bottom:28px;border:1px solid #345041;border-radius:12px;overflow:hidden;background:#111e17}.heading{display:flex;align-items:center;gap:15px;padding:20px}.heading>span{font-size:28px;color:#6f9785}.heading>div{flex:1}.heading small{color:#8ca294}video{width:100%;display:block;background:#000;aspect-ratio:16/9}.actions{display:flex;gap:10px;flex-wrap:wrap;padding:14px 20px}button{cursor:pointer;font:inherit}.note{padding:16px 20px;border-left:3px solid #c8b471;background:#14231b}footer{color:#8ca294;margin:24px 0}
</style><main><div class="tag">GODOT 实机 · ''' + str(len(clips)) + ''' 段动图 · 未抢占桌面焦点</div><h1>自动释放与位移<br>逐项审阅</h1><p>先看设置，再看实际战斗。每段都可独立重播、暂停和慢放。</p><nav>''' + ''.join(navigation) + '</nav><div class="note">' + html.escape(note) + '</div><br>' + ''.join(cards) + '<footer><a href="verification.json">查看帧数、时长与私有桌面验证</a></footer></main></html>'
    (output / 'index.html').write_text(page, encoding='utf-8')
    (output / 'review.md').write_text('\n'.join(markdown), encoding='utf-8')


if __name__ == '__main__':
    main()
