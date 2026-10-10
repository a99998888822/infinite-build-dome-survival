"""Package actual GPU captures; no simulated artwork is used in the GIFs."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
DEFS = [
    ('dagger', '营地短刀 · 单次轻击', 36, '短促亮刃接触点、两像素内的快速回弹；观察接触瞬间与回正速度。'),
    ('hammer', '裂地战锤 · 重击', 54, '触地碎块、裂缝起点短亮、较厚命中爆点和较慢回弹；伤害节点时序保持一致。'),
    ('tome', '坤舆秘仪书 · 逐次点名', 48, '每次点名同步强调目标和下方真实武器栏图标；小段角标、压缩回弹与短音组成一个节拍。'),
    ('lamp', '赤铜炉灯 · 持续接触', 66, '首次接触有小爆点；连续受击每 280 毫秒最多强调一次，无反复摆动，全部伤害照常结算。'),
    ('combo', '营地短刀 · 三次连击', 42, '真实三次攻击分别接触两个目标，检查轻击反馈能否回正、连续命中是否清楚。'),
    ('dense', '四种武器 · 密集叠加', 72, '24 个固定高血量目标；短刀、战锤、秘仪书与炉灯同时施放，观察轻击和火流是否抢走重击反馈。'),
]


def main():
    capture = json.loads((OUT/'validation/gpu_capture.json').read_text(encoding='utf-8'))
    assert not capture['failures'], capture['failures']
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 19)
    small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 15)
    entries = []
    overview = Image.new('RGB', (1240, 3 * 270), '#17221f')
    for number, (key, title, count, note) in enumerate(DEFS):
        variants = {}
        for variant in ['before', 'r02']:
            frames = [Image.open(OUT/'frames'/f'{key}_{variant}_{i:03}.png').convert('RGB') for i in range(count)]
            assert all(im.size == (620, 440) for im in frames)
            variants[variant] = frames
            for part in range((count + 23)//24):
                chunk = frames[part*24:(part+1)*24]
                sheet = Image.new('RGB', (620*len(chunk), 440))
                for j, im in enumerate(chunk): sheet.paste(im, (620*j, 0))
                sheet.save(OUT/'renders'/f'{key}_{variant}_{part}.webp', lossless=True, method=0)
        pairs = []
        for i, (before, after) in enumerate(zip(variants['before'], variants['r02'])):
            pair = Image.new('RGB', (1240, 482), '#17221f')
            pair.paste(before, (0, 42)); pair.paste(after, (620, 42))
            draw = ImageDraw.Draw(pair)
            draw.text((16, 9), '现行版本 · ' + title, fill='#bdccc6', font=font)
            draw.text((636, 9), 'R02 审阅 · 同一攻击进度', fill='#e4d6a5', font=font)
            draw.text((380, 415), f'{i/30:.2f} s', fill='#bdccc6', font=small)
            draw.text((1000, 415), f'{i/30:.2f} s', fill='#bdccc6', font=small)
            pairs.append(pair)
        # One palette for the full clip avoids per-frame color shimmer.
        sample = Image.new('RGB', (620*4, 241))
        for j, at in enumerate([0, count//4, count//2, count*3//4]):
            sample.paste(pairs[at].resize((620, 241)), (620*j, 0))
        palette = sample.quantize(colors=256)
        indexed = [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in pairs]
        durations = [30 if i % 3 != 2 else 40 for i in range(count)]
        durations[-1] += 500
        indexed[0].save(OUT/'renders'/f'{key}_comparison.gif', save_all=True,
                        append_images=indexed[1:], duration=durations, loop=0, optimize=False, disposal=1)
        peak = 19 if key == 'hammer' else 7 if key == 'tome' else 4 if key in ['dagger','combo'] else 18
        pairs[peak].save(OUT/'renders'/f'{key}_keyframe.png')
        tile = pairs[peak].resize((620,241),Image.Resampling.NEAREST)
        overview.paste(tile,((number%2)*620,(number//2)*270))
        entries.append({'id':key,'title':title,'frames':count,'fps':30,'note':note,'chunks':(count+23)//24})
        print('PACKAGED', key, count, flush=True)
    overview.save(OUT/'overview.png')
    (OUT/'review-data.js').write_text('window.REVIEW_DATA = '+json.dumps(entries,ensure_ascii=False,indent=2)+';\n',encoding='utf-8')
    (OUT/'validation/package.json').write_text(json.dumps({'clips':6,'frames':sum(x[2]*2 for x in DEFS),'source':'Actual private-desktop GPU captures','gif_palette':'One 256-color palette per clip; browser sheets are lossless'},indent=2),encoding='utf-8')


if __name__ == '__main__':
    main()
