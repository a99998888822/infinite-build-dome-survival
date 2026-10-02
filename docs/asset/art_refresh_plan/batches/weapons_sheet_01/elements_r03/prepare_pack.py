"""Package style-only references with element-based weapon design briefs."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

HERE = Path(__file__).resolve().parent
PLAN = HERE.parents[2]
ROOT = PLAN.parents[2]

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    text = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    if path.exists() and b'\r\n' in path.read_bytes():
        text = text.replace('\n', '\r\n')
    path.write_bytes(text.encode('utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

previous_path = HERE.parent / 'identity_r02/manifest.json'
previous = read(previous_path)
config = read(ROOT / 'data_config/weapons.json')
prompt = (HERE / 'doubao_prompt.txt').read_text(encoding='utf-8')
assert len(config) == len(previous['items']) == 11
for current, item in zip(config, previous['items']):
    assert current['id'] in item['config_ids']
    assert current['icon'].removeprefix('res://') == item['source']
    assert current['display_name'] in prompt
    assert sha(ROOT / item['source']) == item['source_sha256']

style = HERE / '01_drawing_style.png'
shutil.copyfile(HERE.parent / '01_steel_ink_reference.png', style)
briefs = [line for line in prompt.splitlines() if line.partition('.')[0].isdigit()]
assert len(briefs) == 11
manifest = {
    'status': 'awaiting_highres_generation',
    'revision': 'elements_r03',
    'scope': previous['scope'],
    'method': 'Extract identity cues into text; redesign silhouettes, proportions and arrangement. No original item images uploaded.',
    'layout': previous['layout'],
    'references': [{'file': style.name, 'role': 'Drawing style only: dark outlines, broad planes, hard shadows.', 'sha256': sha(style), 'provenance': previous['references'][1]['provenance']}],
    'identity_briefs': briefs,
    'items': previous['items'],
    'previous_feedback': {'revision': 'identity_r02', 'source': 'User textual feedback; no new output image provided.', 'issue': 'Generated shapes reportedly replicated original icons, with higher resolution only.'},
    'production_changes': False,
}
write(HERE / 'manifest.json', manifest)
relative = 'batches/weapons_sheet_01/elements_r03/'
icons = read(PLAN / 'icon_manifest.json')
by_key = {item['key']: item for item in icons}
for item in manifest['items']:
    by_key[item['key']].update(status='awaiting_highres_generation', generation_revision='elements_r03', generation_package=relative+'README.md', prompt_file=relative+'doubao_prompt.txt')
write(PLAN / 'icon_manifest.json', icons)
coverage = read(PLAN / 'asset_coverage.json')
by_path = {item['path']: item for item in coverage}
for item in manifest['items']:
    by_path[item['source']].update(recipe=relative+'README.md', status='awaiting_highres_generation')
write(PLAN / 'asset_coverage.json', coverage)
previous.update(status='revision_rejected_by_user_report', next_revision='../elements_r03/README.md', rejection='User reports original shapes were replicated; retain semantic cues but allow new designs.')
write(previous_path, previous)
initial_path = HERE.parent / 'manifest.json'
initial = read(initial_path)
initial['next_revision'] = 'elements_r03/README.md'
write(initial_path, initial)
names = ['README.md', 'doubao_prompt.txt', '01_drawing_style.png', 'manifest.json']
with zipfile.ZipFile(HERE/'weapons_sheet_01_elements_r03_doubao.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
    for name in names:
        bundle.write(HERE/name, name)
for item in manifest['items']:
    assert sha(ROOT/item['source']) == item['source_sha256']
print('Prepared elements_r03: 11 element briefs, one style image, no original-item reference; production unchanged.')
