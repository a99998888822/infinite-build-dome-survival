"""Compose existing references for a shape-preserving redraw; no AI generation."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile
from PIL import Image

HERE = Path(__file__).resolve().parent
PLAN = HERE.parents[2]
ROOT = PLAN.parents[2]
REVIEW = ROOT / 'artifacts/previews/art_refresh_v1/weapons_sheet_01/design_review_r02'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    text = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
    if path.exists() and b'\r\n' in path.read_bytes():
        text = text.replace('\n', '\r\n')
    path.write_bytes(text.encode('utf-8'))

config = read(ROOT / 'data_config/weapons.json')
previous = read(HERE.parent / 'manifest.json')
assert len(config) == len(previous['items']) == 11
board = Image.new('RGB', (1536, 1152), 'white')
items = []
for index, (entry, prior) in enumerate(zip(config, previous['items'])):
    relative = entry['icon'].removeprefix('res://')
    path = ROOT / relative
    assert entry['id'] in prior['config_ids'] and relative == prior['source']
    assert sha(path) == prior['source_sha256'], 'Production art changed; review before rebuilding.'
    with Image.open(path) as source:
        assert source.size == (64, 64)
        tile = source.convert('RGBA').resize((320, 320), Image.Resampling.NEAREST)
    board.paste(tile, ((index % 4) * 384 + 32, (index // 4) * 384 + 32), tile)
    items.append(dict(prior))
board.save(HERE / '01_weapon_identity.png')
shutil.copyfile(HERE.parent / '01_steel_ink_reference.png', HERE / '02_drawing_style.png')

REVIEW.mkdir(parents=True, exist_ok=True)
rejected_input = Path('C:/Users/mi/AppData/Local/Temp/codex-clipboard-8aec1be8-4e2f-425e-a670-12c01f96734b.png')
rejected_copy = REVIEW / 'weapons_sheet_01_rejected_source.png'
if not rejected_copy.exists():
    shutil.copyfile(rejected_input, rejected_copy)
elif rejected_input.exists():
    assert sha(rejected_input) == sha(rejected_copy)
with Image.open(rejected_copy) as rejected:
    rejected_size = list(rejected.size)
style_source = read(HERE.parent / 'reference_manifest.json')[0]
manifest = {
    'status': 'awaiting_highres_generation',
    'revision': 'identity_r02',
    'scope': '11 weapon UI icons; 64x64 target after high-resolution review.',
    'method': 'Redraw existing identity in updated illustration style, not free redesign.',
    'reference_processing': 'Existing PNGs composed at 5x nearest-neighbor on white; existing style crop copied. No image model, pixel conversion or production installation.',
    'layout': previous['layout'],
    'references': [
        {'file': '01_weapon_identity.png', 'role': 'Identity only: silhouette, topology, orientation, proportions, key ornaments and main colors.', 'sha256': sha(HERE / '01_weapon_identity.png'), 'sources': [i['source'] for i in items]},
        {'file': '02_drawing_style.png', 'role': 'Drawing style only: dark outline, broad planes and hard shadows. Do not borrow object design or force its palette.', 'sha256': sha(HERE / '02_drawing_style.png'), 'provenance': style_source}
    ],
    'rejected_input': {'path': rejected_copy.relative_to(ROOT).as_posix(), 'sha256': sha(rejected_copy), 'size': rejected_size, 'status': 'rejected_by_user_for_identity_drift', 'usage': 'Review record only; do not upload as a new design reference.'},
    'items': items,
}
write(HERE / 'manifest.json', manifest)

icons = read(PLAN / 'icon_manifest.json')
by_key = {item['key']: item for item in icons}
package_relative = 'batches/weapons_sheet_01/identity_r02/'
for item in items:
    target = by_key[item['key']]
    target.update(status='awaiting_highres_generation', generation_revision='identity_r02',
                  generation_package=package_relative + 'README.md',
                  prompt_file=package_relative + 'doubao_prompt.txt')
write(PLAN / 'icon_manifest.json', icons)
coverage = read(PLAN / 'asset_coverage.json')
by_path = {item['path']: item for item in coverage}
for item in items:
    by_path[item['source']].update(recipe=package_relative + 'README.md', status='awaiting_highres_generation')
write(PLAN / 'asset_coverage.json', coverage)
previous.update(status='highres_rejected_by_user', next_revision='identity_r02/README.md',
                rejection='Generated weapon identity deviated from current icons; user requested closer designs.')
write(HERE.parent / 'manifest.json', previous)

files = ['README.md', 'doubao_prompt.txt', '01_weapon_identity.png', '02_drawing_style.png', 'manifest.json']
archive = HERE / 'weapons_sheet_01_identity_r02_doubao.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for name in files:
        bundle.write(HERE / name, name)
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert sorted(bundle.namelist()) == sorted(files)
for item in items:
    assert sha(ROOT / item['source']) == item['source_sha256']
print('Prepared identity_r02: 11 original icon references, one style crop, revised prompt; production unchanged.')
