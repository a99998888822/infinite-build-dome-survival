"""Compose real Godot frames side by side. Only crop/resize/annotate combat."""
import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT_PATH = 'C:/Windows/Fonts/msyh.ttc'
FONT = ImageFont.truetype(FONT_PATH, 22)
SMALL = ImageFont.truetype(FONT_PATH, 17)
TITLE = ImageFont.truetype(FONT_PATH, 27)
PANEL_WIDTH = 640
WORLD_TOP = 142
WORLD_HEIGHT = 257
HEIGHT = 446
WIDTH = 1280
INK = '#101b1a'
PAPER = '#e2ebe5'
MUTED = '#aabbb4'
COLORS = ['#e8ba82', '#89d5af']
NAMES = {
    'range': ('攻击距离对比 · 守夜长枪', '只改变攻击距离属性；伤害范围属性固定为 0'),
    'area': ('伤害范围对比 · 榴弹炮', '只改变伤害范围属性；攻击距离属性固定为 0，落点固定'),
    'combined': ('双属性叠加 · 赤铜炉灯', '攻击距离与伤害范围同时取相同数值；喷射时间与单次伤害保持一致'),
}


def load(family, mode):
    folder = HERE / 'captures' / f'{family}_{mode}'
    report = json.loads((folder / 'report.json').read_text(encoding='utf-8'))
    assert report['failures'] == 0
    assert [case['score'] for case in report['cases']] == [0, 50, 100, 200]
    return folder, report


def compose(family, reports, folders, case_index, frame_index):
    canvas = Image.new('RGB', (WIDTH, HEIGHT), INK)
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 8), NAMES[family][0], font=TITLE, fill=PAPER)
    draw.text((19, 46), NAMES[family][1], font=SMALL, fill=MUTED)
    for n, score in enumerate([0, 50, 100, 200]):
        x = 935 + n * 82
        fill = '#294b3e' if n == case_index else '#1a2925'
        draw.rounded_rectangle((x, 12, x + 70, 48), radius=6, fill=fill)
        draw.text((x + 10, 15), f'+{score}', font=SMALL, fill=PAPER if n == case_index else MUTED)
    for column, report in enumerate(reports):
        case = report['cases'][case_index]
        entry = case['frames'][frame_index]
        x = column * PANEL_WIDTH
        color = COLORS[column]
        title = '当前规则 · 每点加成 100% 生效' if column == 0 else '审阅方案 · 每点加成 50% 生效'
        draw.text((x + 17, 76), title, font=FONT, fill=color)
        if family == 'area':
            value = f"伤害范围 +{case['area_attribute']:.0f} → 爆炸半径 {case['blast_radius']:.0f} px"
        elif family == 'range':
            value = f"攻击距离 +{case['range_attribute']:.0f} → 实际距离 {case['actual_range']:.0f} px"
        else:
            value = f"距离 +{case['range_attribute']:.0f} / 范围 +{case['area_attribute']:.0f} → 喷射 {case['actual_range']:.0f} px"
        draw.text((x + 17, 109), value, font=FONT, fill=PAPER)
        with Image.open(folders[column] / entry['file']) as im:
            # All variants use the same crop and camera per weapon family.
            crop = im.convert('RGB').crop((0, 140, 960, 525))
            crop = crop.resize((PANEL_WIDTH, WORLD_HEIGHT), Image.Resampling.LANCZOS)
        canvas.paste(crop, (x, WORLD_TOP))
        draw.text((x + 17, 405), f"实际命中 {entry['hit_targets']} 个目标", font=FONT, fill=color)
    draw.line((639, 72, 639, HEIGHT - 7), fill='#607268', width=2)
    return canvas


def make(family):
    folders, reports = zip(*(load(family, mode) for mode in ['current', 'half']))
    frames = []
    comparisons = []
    for case_index in range(4):
        left, right = [report['cases'][case_index] for report in reports]
        assert left['range_attribute'] == right['range_attribute']
        assert left['area_attribute'] == right['area_attribute']
        assert left['single_damage'] == right['single_damage']
        assert len(left['frames']) == len(right['frames']) == 60
        assert left['cast_tick'] == right['cast_tick']
        if case_index == 0:
            assert left['actual_range'] == right['actual_range']
            assert left['blast_radius'] == right['blast_radius']
            assert left['hits'] == right['hits']
        assert set(right['hits']).issubset(set(left['hits']))
        for i in range(60):
            assert left['frames'][i]['physics_tick'] == right['frames'][i]['physics_tick']
            frames.append(compose(family, reports, folders, case_index, i))
        comparisons.append({'score': left['score'], 'range': [left['actual_range'], right['actual_range']],
                            'blast_radius': [left['blast_radius'], right['blast_radius']],
                            'hit_targets': [len(left['hits']), len(right['hits'])], 'single_damage': left['single_damage']})
    atlas = Image.new('RGB', (WIDTH, HEIGHT * 16))
    for row, index in enumerate([c * 60 + f for c in range(4) for f in [0, 18, 24, 37]]):
        atlas.paste(frames[index], (0, row * HEIGHT))
    palette = atlas.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    quantized = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    destination = HERE / f'{family}_comparison.gif'
    quantized[0].save(destination, save_all=True, append_images=quantized[1:], duration=50,
                      loop=0, optimize=False, disposal=1)
    # Preserve an actual RGB contact sheet at the visible impact/spray phase.
    moment = 19 if family == 'range' else 25 if family == 'area' else 32
    sheet = Image.new('RGB', (WIDTH, HEIGHT * 4), INK)
    for row in range(4):
        sheet.paste(frames[row * 60 + moment], (0, row * HEIGHT))
    sheet.save(HERE / f'{family}_contact_sheet.png')
    frames[120 + moment].save(HERE / f'{family}_poster.png')
    with Image.open(destination) as gif:
        total_ms = 0
        for i in range(gif.n_frames):
            gif.seek(i)
            total_ms += gif.info['duration']
        assert total_ms == 12000
    optimized = HERE / f'{family}_review.gif'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-i', str(destination),
                    '-filter_complex', '[0:v]split[a][b];[a]palettegen=stats_mode=diff:max_colors=128[p];[b][p]paletteuse=dither=none:diff_mode=rectangle',
                    '-gifflags', '+transdiff+offsetting', '-loop', '0', '-y', str(optimized)], check=True)
    with Image.open(optimized) as gif:
        optimized_ms = 0
        assert gif.n_frames == 240
        for i in range(gif.n_frames):
            gif.seek(i)
            optimized_ms += gif.info['duration']
        assert optimized_ms == 12000
    result = {'family': family, 'artifact': str(destination), 'duration_ms': total_ms,
              'size': [WIDTH, HEIGHT], 'bytes': destination.stat().st_size, 'cases': comparisons,
              'review_artifact': str(optimized), 'review_bytes': optimized.stat().st_size,
              'source': 'Actual Godot GPU frames, 60 Hz fixed simulation, sampled at 20 fps, original timing.'}
    (HERE / f'{family}_comparison.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('families', nargs='*', default=['range', 'area', 'combined'])
    args = parser.parse_args()
    for family in args.families:
        make(family)
