"""Assemble existing icons as identity references; this does not redraw them."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

TASK = Path(__file__).resolve().parent
ROOT = TASK.parents[4]
PLAN = TASK.parents[1]
KEYS = [
    'relic_piggy_bank', 'relic_steel_vault', 'relic_gold_compass',
    'relic_compound_interest_tome', 'relic_periodic_dividend_clock', 'relic_quant_trading',
]
manifest = json.loads((PLAN / 'icon_manifest.json').read_text(encoding='utf-8'))
items = {item['key']: item for item in manifest}
board = Image.new('RGB', (1536, 1024), 'white')
records = []
for index, key in enumerate(KEYS):
    item = items[key]
    source = ROOT / item['original_path'].removeprefix('res://')
    original = Image.open(source).convert('RGBA')
    scaled = original.resize((384, 384), Image.Resampling.NEAREST)
    row, column = divmod(index, 3)
    board.paste(scaled, (column * 512 + 64, row * 512 + 64), scaled)
    records.append({'row': row + 1, 'column': column + 1, 'key': key,
        'name': item['names'][0], 'source': source.relative_to(ROOT).as_posix(),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'reference_cell_rect': [column * 512, row * 512, 512, 512],
        'output_filename': key + '.png', 'pixel_target': [32, 32]})
board.save(TASK / '02_identity_reference_white.png')
review = board.copy()
draw = ImageDraw.Draw(review)
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 28)
for item in records:
    x, y, _, _ = item['reference_cell_rect']
    draw.text((x + 20, y + 467), item['name'], font=font, fill='#333333')
review.save(TASK / 'review_labeled_do_not_upload.png')
shutil.copy2(PLAN / 'references/U01_darkest_style_no_text.png', TASK / '01_style_reference.png')
data = {'status': 'awaiting_highres_generation', 'method': 'Existing icons composited on white with nearest-neighbor 12x enlargement, not newly drawn art.',
    'layout': {'columns': 3, 'rows': 2, 'preferred_canvas': [3072, 2048], 'fallback_canvas': [1536, 1024]},
    'style_reference_source': 'docs/asset/art_refresh_plan/references/U01_darkest_style_no_text.png',
    'style_reference_sha256': hashlib.sha256((TASK / '01_style_reference.png').read_bytes()).hexdigest(),
    'split_rule': 'Inspect actual returned objects and order before cropping; do not blindly trust a perfect grid.', 'items': records}
(TASK / 'manifest.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'references_prepared': len(records), 'canvas': board.size, 'redrawn': False}))
