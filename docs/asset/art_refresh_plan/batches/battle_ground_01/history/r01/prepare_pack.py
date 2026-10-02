"""Build reference crops and a planning diagram; does not generate game art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json
import shutil
import tempfile
import zipfile

PACK = Path(__file__).resolve().parent
ROOT = PACK.parents[4]
FONT = Path('C:/Windows/Fonts/msyh.ttc')
BOLD = Path('C:/Windows/Fonts/msyhbd.ttc')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def crop_references():
    specs = [
        ('01_ground_planes_reference.png',
         'u=4143898148,827992823&fm=253&app=138&f=JPEG.jpg',
         (285, 283, 825, 429),
         '仅参考草地、岩面的大色块与硬边，不参考溪流和场景构图。'),
        ('02_vegetation_reference.png', 'b861aTower-Interior-1.webp',
         (1300, 925, 1870, 1080),
         '仅参考低植被成簇节奏与暗部层次；宽叶团块由文字定义，不复制针叶、树干或建筑。'),
    ]
    entries = []
    for out_name, source_name, box, usage in specs:
        source = ROOT / 'artifacts/reference/scene' / source_name
        target = PACK / out_name
        with Image.open(source) as original:
            original.convert('RGB').crop(box).save(target)
            source_size = list(original.size)
        entries.append({
            'file': out_name, 'source': source.relative_to(ROOT).as_posix(),
            'source_sha256': digest(source), 'source_size': source_size,
            'crop_xyxy': list(box), 'resized': False,
            'output_sha256': digest(target), 'usage': usage,
        })
    (PACK / 'reference_manifest.json').write_text(
        json.dumps({'status': 'style_reference_crops_only', 'references': entries},
                   ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def draw_layout():
    # Diagram only: flat symbols, no generated or repainted production textures.
    im = Image.new('RGB', (1440, 940), '#101c20')
    d = ImageDraw.Draw(im)

    def text(x, y, value, size=22, color='#dfdfca', bold=False):
        d.text((x, y), value, font=ImageFont.truetype(str(BOLD if bold else FONT), size), fill=color)

    text(42, 27, '暗绿遗址 · 战斗地面布局提案', 36, bold=True)
    text(44, 81, '色块拓扑示意｜不是重绘成品或游戏截图｜范围可向四周继续延伸', 21, '#a5b8ad')
    # Map space: 960 x 620, with clear margins and a separate legend.
    ox, oy = 44, 142
    d.rectangle((ox, oy, ox + 960, oy + 620), fill='#283d32', outline='#58715f', width=2)

    def poly(points, fill, outline=None, width=1):
        shifted = [(ox+x, oy+y) for x, y in points]
        d.polygon(shifted, fill=fill)
        if outline:
            d.line(shifted + [shifted[0]], fill=outline, width=width)

    # Dense grass forms quiet irregular masses rather than a grid.
    for points in [
        [(0,0),(385,0),(364,51),(241,71),(192,132),(76,159),(0,126)],
        [(600,0),(960,0),(960,244),(907,211),(856,132),(769,111),(696,72)],
        [(0,418),(75,450),(164,477),(231,546),(327,563),(352,620),(0,620)],
        [(638,620),(642,551),(721,533),(751,454),(820,436),(866,498),(960,515),(960,620)],
    ]:
        poly(points, '#34503a')
    # Dirt provides underlay at the ends and irregular edges of the stone route.
    west = [(0,330),(75,320),(132,283),(226,292),(329,252),(352,334),
            (255,367),(161,359),(89,398),(0,416)]
    east = [(589,314),(665,263),(688,190),(772,171),(794,111),(910,112),
            (960,80),(960,164),(858,206),(816,269),(751,276),(718,346),(624,383)]
    center = [(277,235),(331,162),(435,146),(493,173),(574,158),(657,222),
              (690,302),(655,390),(593,454),(479,470),(408,439),(313,438),(260,353)]
    for shape in (west, east, center):
        poly(shape, '#504b3a', '#62604a', 3)
    # Broken paving, shown with large geometric marks, not final textures.
    for x, y, w, h in [(50,354,49,25),(120,327,65,31),(200,323,50,25),
                       (247,291,59,28),(664,273,48,30),(702,216,52,27),
                       (772,194,42,24),(816,150,61,27),(901,116,45,26)]:
        poly([(x,y),(x+w,y-5),(x+w-3,y+h),(x+2,y+h+2)], '#687567', '#374b40', 2)
    paving = [(306,253),(353,190),(431,178),(486,208),(564,192),(625,239),
              (651,300),(618,373),(572,422),(487,435),(413,409),(337,406),(294,344)]
    poly(paving, '#667564', '#839078', 3)
    # Few paving lines only; deliberately abstract schematic representation.
    mask = Image.new('1', im.size)
    ImageDraw.Draw(mask).polygon([(ox+x, oy+y) for x, y in paving], fill=1)
    tile = Image.new('RGB', im.size, '#667564')
    td = ImageDraw.Draw(tile)
    for row, y in enumerate(range(160, 458, 36)):
        td.line((ox+275, oy+y, ox+670, oy+y), fill='#576856', width=2)
        for x in range(270 + (row % 2)*34, 700, 68):
            td.line((ox+x, oy+y, ox+x, oy+y+36), fill='#576856', width=2)
    im.paste(tile, mask=mask)
    d = ImageDraw.Draw(im)
    # Small water pockets; the rest of the map is dry land.
    for points in [
        [(26,184),(64,161),(117,181),(146,218),(115,243),(58,248),(22,222)],
        [(783,327),(834,305),(889,326),(918,363),(884,404),(825,401),(789,369)],
    ]:
        poly(points, '#263c42', '#6a8174', 3)
    # Stylized shrubs are symbols, not deliverable sprites.
    for x, y, w in [(158,180,60),(223,126,58),(346,112,51),(665,104,61),
                    (772,88,64),(120,451,65),(227,495,75),(376,520,60),
                    (587,503,78),(739,427,66),(868,455,60)]:
        poly([(x-w//2,y+10),(x-w//2+8,y-8),(x-10,y-19),(x+3,y-9),
              (x+19,y-17),(x+w//2,y),(x+w//2-9,y+17),(x-16,y+21)],
             '#49633c', '#172c22', 3)
    # Rubble close to the paving ends, not uniformly scattered.
    for x, y in [(290,259),(276,362),(338,429),(598,432),(652,344),(715,191),(190,365)]:
        poly([(x,y),(x+13,y-4),(x+19,y+7),(x+8,y+13)], '#7f8974')
    # Explicit callouts inside map; no implication of final perspective.
    text(ox+325, oy+285, '开阔战斗区', 30, '#f0efdb', True)
    text(ox+352, oy+330, '不规则旧铺砖', 21, '#dce1c9')
    text(ox+25, oy+276, '断续石路', 19, '#d2d9bd')
    text(ox+714, oy+222, '破砖 → 泥土 → 草', 18, '#d2d9bd')
    text(ox+414, oy+45, '连续草地', 24, '#b9c7a8')
    text(ox+375, oy+563, '外围也有完整地貌', 22, '#b9c7a8')
    text(ox+797, oy+347, '浅水', 20, '#b6cbd0')
    # Legend and implementation notes remain outside the map.
    text(1040, 150, '首批 8 项素材', 27, bold=True)
    items = [('#283d32','G01  稀疏草地'),('#34503a','G02  成片密草'),
             ('#504b3a','G03  湿润泥土'),('#667564','G04  磨损铺砖'),
             ('#687567','G05  严重破损铺砖'),('#49633c','G06–08  三种矮灌木')]
    for i, (color, label) in enumerate(items):
        y = 203+i*45
        d.rectangle((1042,y,1066,y+24), fill=color, outline='#7d8e78')
        text(1080, y-3, label, 21)
    text(1040, 495, '现有素材继续用', 25, bold=True)
    text(1040, 540, '石柱 / 残墙：远景视差层', 20, '#b6c3b4')
    text(1040, 577, '苔藓 / 碎石：地表交界处', 20, '#b6c3b4')
    text(1040, 614, '水纹：仅在实际水域出现', 20, '#b6c3b4')
    text(1040, 675, '示意图不上传豆包', 23, '#d7ba82', True)
    text(1040, 714, '仅上传指定画风参考裁图', 20, '#b6c3b4')
    d.line((44,796,1396,796), fill='#3e534b', width=2)
    text(44, 817, '分区尺度', 23, bold=True)
    text(190, 820, '连续草底＋大块不规则材质区域；128px 母纹理不等于 128px 方格交替铺地。', 21, '#b6c3b4')
    text(44, 870, '战斗优先', 23, bold=True)
    text(190, 873, '低矮植被避开密集战斗与预警；黄昏 / 夜晚共用素材，分别调整场景配色。', 21, '#b6c3b4')
    im.save(PACK / 'layout_proposal.png')


def archive_audit():
    source = Path(tempfile.gettempdir()) / 'battle-ground-analysis'
    audit = PACK / 'audit'
    audit.mkdir(exist_ok=True)
    for name in ['01_center.png', '02_wetland.png', '03_outskirts.png',
                 '04_return.png', '05_small_window.png', '06_live_combat.png', 'placements.json']:
        if (source / name).exists():
            shutil.copy2(source / name, audit / name)
    for suffix in ['.json', '.log']:
        src = source.with_suffix(suffix)
        if src.exists():
            shutil.copy2(src, audit / ('background_capture' + suffix))
    (audit / 'README.md').write_text(
        '# 旧场景分析基线\n\n'
        '2026-09-30通过既有battle_environment_test重新采集；此处均为修改前正式场景，'
        '不是候选地面。完整测试通过，failures=0。后台运行报告验证独立桌面，'
        'foreground_samples=0。截图仅用于分析，不打入豆包参考包。\n', encoding='utf-8')


def package():
    guide = (
        '# 地面高清生成包\n\n'
        '5张地表分别生成：上传01_ground_planes_reference.png，复制对应prompts/G01至G05全文。'
        '三种矮灌木同图生成：上传02_vegetation_reference.png，复制prompts/G06_G08_bushes.txt。\n\n'
        '只用画风参考，不上传旧游戏截图或旧石盘。草、土、砖必须满幅不透明，只有灌木用白底。'
        '各任务建议新对话；即使同一对话，也不要将上一张输出作为必须复刻的构图。\n\n'
        '保存原始高清文件至项目temp/battle_ground_01/，文件名与提示词文件名对应，后缀改为.png。'
        '先审高清稿，再处理128px母纹理、透明灌木、接缝与边界，组装候选场景。'
        '不要自行把整张地图缩成128px。\n'
    )
    files = [PACK / '01_ground_planes_reference.png', PACK / '02_vegetation_reference.png',
             PACK / 'reference_manifest.json', *sorted((PACK / 'prompts').glob('*.txt'))]
    with zipfile.ZipFile(PACK / 'battle_ground_01_doubao.zip', 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('START_HERE.md', guide.encode('utf-8'))
        for path in files:
            z.write(path, path.relative_to(PACK).as_posix())
    print(json.dumps({'reference_count': 2, 'prompt_count': len(files)-3,
                      'diagram': str(PACK / 'layout_proposal.png'),
                      'zip': str(PACK / 'battle_ground_01_doubao.zip')}, ensure_ascii=True))


if __name__ == '__main__':
    crop_references()
    draw_layout()
    archive_audit()
    package()
