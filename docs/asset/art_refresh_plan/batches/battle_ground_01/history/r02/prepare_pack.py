"""Build r02 documentation, reference aids and diagrams, not pixel/game art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json
import zipfile

PACK = Path(__file__).resolve().parent
ROOT = PACK.parents[4]
FONT = Path('C:/Windows/Fonts/msyh.ttc')
BOLD = Path('C:/Windows/Fonts/msyhbd.ttc')
REVISION = 'r02'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def crop_references():
    # Designed color guide, not source-photo sampling or a generated texture.
    colors = ['#20352c', '#314936', '#4b6246', '#657652',
              '#383930', '#514f40', '#56635b', '#768175']
    palette = Image.new('RGB', (960, 360), '#e1e2d9')
    draw = ImageDraw.Draw(palette)
    for i, color in enumerate(colors):
        x, y = 24 + (i % 4)*234, 24 + (i // 4)*168
        draw.rectangle((x, y, x+210, y+144), fill=color)
    target = PACK / '01_ground_palette_reference.png'
    palette.save(target)
    entries = [{
        'file': target.name, 'type': 'designed_palette_reference',
        'created_by': 'local solid-color drawing; not AI image generation',
        'colors': colors, 'source_photo': None,
        'output_sha256': digest(target),
        'usage': 'G01–G05只参考配色：上排植被，下排左侧土、右侧石；画风由提示词定义，不复制排版。',
        'limitations': '人工指定的建议色系，并非从原图采样，也不是最终像素色板；不要求模型精确复现HEX。',
    }]
    specs = [
        ('02_vegetation_reference.png', 'b861aTower-Interior-1.webp',
         (1300, 925, 1870, 1080),
         '仅参考低植被成簇节奏与暗部层次；宽叶团块由文字定义，不复制针叶、树干或建筑。'),
    ]
    for out_name, source_name, box, usage in specs:
        source = ROOT / 'artifacts/reference/scene' / source_name
        target = PACK / out_name
        with Image.open(source) as original:
            original.convert('RGB').crop(box).save(target)
            source_size = list(original.size)
        entries.append({
            'file': out_name, 'type': 'source_crop', 'source': source.relative_to(ROOT).as_posix(),
            'source_sha256': digest(source), 'source_size': source_size,
            'crop_xyxy': list(box), 'resized': False,
            'output_sha256': digest(target), 'usage': usage,
        })
    (PACK / 'reference_manifest.json').write_text(
        json.dumps({'revision': REVISION, 'status': 'reference_aids_only', 'references': entries,
                    'retired': {'file': '01_ground_planes_reference.png',
                                'archive': 'history/r01/01_ground_planes_reference.png',
                                'reason': '溪流、岩石与长明暗带容易被复制为地表构图，r02不再上传。'}},
                   ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def draw_layout():
    # Diagram only: flat symbols, no generated or repainted production textures.
    im = Image.new('RGB', (1440, 940), '#101c20')
    d = ImageDraw.Draw(im)

    def text(x, y, value, size=22, color='#dfdfca', bold=False):
        d.text((x, y), value, font=ImageFont.truetype(str(BOLD if bold else FONT), size), fill=color)

    text(42, 27, '暗绿遗址 · 战斗地面布局提案 r02', 36, bold=True)
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
    text(190, 820, '不透明草底＋区域遮罩；地貌跨区块延伸，128px 母纹理不限定地图大小。', 21, '#b6c3b4')
    text(44, 870, '战斗优先', 23, bold=True)
    text(190, 873, '低矮植被避开密集战斗与预警；黄昏 / 夜晚共用素材，分别调整场景配色。', 21, '#b6c3b4')
    im.save(PACK / 'layout_proposal.png')


def draw_layering():
    im = Image.new('RGB', (1440, 820), '#101c20')
    d = ImageDraw.Draw(im)

    def text(x, y, value, size=22, color='#dfdfca', bold=False):
        d.text((x, y), value, font=ImageFont.truetype(str(BOLD if bold else FONT), size), fill=color)

    text(42, 28, '不透明纹理如何拼接？', 36, bold=True)
    text(44, 83, 'r02 拼接原理示意｜仅用几何色块说明，不是生成稿或像素成品', 22, '#a5b8ad')
    titles = ['1  草地母纹理', '2  石砖母纹理', '3  区域遮罩', '4  游戏中合成']
    captions = [('不透明，铺满底层', 'G01一直覆盖地面'),
                ('不透明，不预先抠底', 'G04 / G05提供材质'),
                ('白色显示，黑色隐藏', '由后处理／场景生成'),
                ('只在选定区域显示石砖', '其余位置露出草地')]
    shape = [(15,125),(55,110),(67,61),(119,70),(156,28),(214,43),
             (260,96),(249,152),(283,178),(235,229),(165,213),(115,259),
             (62,238),(63,186),(20,178)]
    grass = Image.new('RGB', (300, 300), '#314936')
    gd = ImageDraw.Draw(grass)
    for x, y in [(16,21),(108,35),(219,8),(70,102),(160,138),(241,210),(20,248),(146,269)]:
        gd.polygon([(x,y+10),(x+7,y),(x+11,y+7),(x+20,y+2),(x+24,y+12)], fill='#4b6246')
    stone = Image.new('RGB', (300, 300), '#768175')
    sd = ImageDraw.Draw(stone)
    for row, y in enumerate(range(0,300,30)):
        sd.line((0,y,299,y), fill='#56635b', width=3)
        for x in range(-30+(row%2)*30,330,60):
            sd.line((x,y,x,y+30), fill='#56635b', width=3)
    mask = Image.new('L', (300,300), 0)
    ImageDraw.Draw(mask).polygon(shape, fill=255)
    composite = grass.copy()
    composite.paste(stone, mask=mask)
    for i, picture in enumerate([grass, stone, mask.convert('RGB'), composite]):
        x = 44+i*350
        text(x, 147, titles[i], 25, bold=True)
        im.paste(picture, (x,196))
        d.rectangle((x,196,x+299,495), outline='#81937e', width=2)
        text(x, 518, captions[i][0], 21)
        text(x, 555, captions[i][1], 19, '#a5b8ad')
    d.line((44,609,1396,609), fill='#3e534b', width=2)
    text(44, 636, '透明由用途决定', 25, bold=True)
    text(292, 641, '母纹理保持不透明；材质边界交给遮罩；灌木才从白底抠成透明精灵。', 21, '#b6c3b4')
    text(44, 694, '过渡另行修整', 25, bold=True)
    text(292, 699, '正式边界加入草叶、露土、残砖和内外角；图中直切边仅解释合成原理。', 21, '#b6c3b4')
    text(44, 753, '平铺单独检查', 25, bold=True)
    text(292, 758, '抠底不解决接缝：均匀照明、无视觉中心、3×3重复检查仍需独立完成。', 21, '#b6c3b4')
    im.save(PACK / 'layering_explained.png')


def asset_manifest():
    stems = ['grass_sparse', 'grass_dense', 'wet_earth', 'paving_worn', 'paving_broken']
    assets = []
    for i, stem in enumerate(stems, 1):
        name = f'G{i:02d}_{stem}'
        assets.append({'id': f'G{i:02d}', 'input_stem': name,
                       'prompt': f'prompts/{name}.txt', 'reference': '01_ground_palette_reference.png',
                       'source_type': 'opaque_full_bleed_texture', 'requested_hd_size': [2048,2048],
                       'pixel_kind': 'tile', 'candidate_pixel_size': [128,128],
                       'master_alpha': 'opaque; RGB or alpha=255', 'background_removal': False,
                       'lighting': 'uniform diffuse; local short form shading only',
                       'status': 'awaiting_r02_hd_review'})
    for i, stem in [(6,'bush_round'),(7,'bush_long'),(8,'bush_sparse')]:
        assets.append({'id': f'G{i:02d}', 'output_stem': stem, 'input_stem': 'G06_G08_bushes',
                       'sheet_position_left_to_right': i-5, 'prompt': 'prompts/G06_G08_bushes.txt',
                       'reference': '02_vegetation_reference.png', 'source_type': 'isolated_white_background_sprite',
                       'requested_sheet_hd_size': [3072,1024], 'candidate_pixel_size': [128,128],
                       'master_alpha': 'transparent background', 'background_removal': True,
                       'status': 'awaiting_r02_hd_review'})
    data = {'revision': REVISION, 'input_directory': 'temp/battle_ground_01/r02/',
            'input_extensions': ['.png','.jpg','.jpeg','.webp'],
            'source_size_policy': 'highest native output; record actual dimensions, do not upscale or rename formats',
            'asset_count': 8, 'generation_count': 6, 'assets': assets,
            'generated_later': ['grass-earth pixel masks', 'grass-paving pixel masks',
                                'earth-paving pixel masks', 'worn-broken paving transitions',
                                'inner/outer corners', 'compatible internal texture variants'],
            'current_sample': {'id': 'G01', 'status': 'issues_recorded_not_approved',
                               'actual_size': [384,384], 'mode': 'RGB',
                               'source_sha256': digest(PACK/'audit/g01_r01/source.png')},
            'runtime_status': 'new terrain not installed; streaming requirements documented only'}
    (PACK/'asset_manifest.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def package():
    files = [PACK / name for name in ['START_HERE.md', 'REVIEW_CHECKLIST.md', 'NEXT_STEPS.md',
                                      '01_ground_palette_reference.png', '02_vegetation_reference.png',
                                      'reference_manifest.json', 'asset_manifest.json']]
    files += sorted((PACK / 'prompts').glob('*.txt'))
    manifest = {'revision': REVISION,
                'files': {path.relative_to(PACK).as_posix(): digest(path) for path in files}}
    manifest_file = PACK / 'package_manifest.json'
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    files.append(manifest_file)
    with zipfile.ZipFile(PACK / 'battle_ground_01_doubao.zip', 'w', zipfile.ZIP_DEFLATED) as z:
        for path in files:
            z.write(path, path.relative_to(PACK).as_posix())
    print(json.dumps({'revision': REVISION, 'reference_count': 2, 'prompt_count': 6,
                      'archive_file_count': len(files),
                      'diagram': str(PACK / 'layout_proposal.png'),
                      'zip': str(PACK / 'battle_ground_01_doubao.zip')}, ensure_ascii=True))


if __name__ == '__main__':
    crop_references()
    draw_layout()
    draw_layering()
    asset_manifest()
    package()
