"""Validate retained art inputs and export exact current player/finance artwork.

Default is read-only. --output writes reconstructed PNGs to a separate directory.
"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PLAYER_MANIFEST = ROOT/'artifacts/sources/player_actions/novice_128/manifest.json'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def grid_image(path):
    """Read the self-contained color table in an existing Picxel grid."""
    header, body = Path(path).read_text(encoding='utf-8').split('---', 1)
    colors = {'.': (0, 0, 0, 0)}
    for line in header.splitlines():
        if len(line) > 4 and line[1:4] == ': #':
            value = line.split('#', 1)[1].strip()
            colors[line[0]] = tuple(int(value[i:i+2], 16) for i in (0, 2, 4)) + (255,)
    rows = body.strip().splitlines()
    assert rows and all(len(row) == len(rows[0]) for row in rows), path
    pixels = bytes(c for row in rows for char in row for c in colors[char])
    return Image.frombytes('RGBA', (len(rows[0]), len(rows)), pixels)


def player_atlases():
    doc = json.loads(PLAYER_MANIFEST.read_text(encoding='utf-8'))
    current = json.loads((ROOT/'assets/sprites/player/actions/novice_128/animations.json').read_text(encoding='utf-8'))
    assert doc['clips'] == current['clips'], 'Animation mapping or timing is stale'
    result = {}
    for action, clip in doc['clips'].items():
        records = sorted((r for r in doc['frames'] if r['action'] == action), key=lambda r: r['frame'])
        assert [r['frame'] for r in records] == list(range(clip['frames'])), action
        atlas = Image.new('RGBA', (128 * len(records), 128))
        for record in records:
            for field in ['source', 'editable']:
                assert digest(ROOT/record[field]) == record[field+'_sha256'], record[field]
            frame = grid_image(ROOT/record['editable'])
            assert frame.size == (128, 128), record['editable']
            atlas.paste(frame, (record['frame'] * 128, 0))
        result[clip['texture'].removeprefix('res://')] = atlas
    return result


def finance_background():
    base = ROOT/'artifacts/editable/finance_background'
    mapping = json.loads((base/'source-map.json').read_text(encoding='utf-8'))
    source = Image.open(ROOT/mapping['source']).convert('RGBA')
    bank = Image.open(base/'pixel_background.png').convert('RGBA')
    mask = Image.open(base/'scroll_mask.png').convert('L')
    # Also check that editable tiles represent the retained pixel background.
    for tile in mapping['tiles']:
        grid = grid_image(ROOT/tile['grid'])
        x, y = tile['column'] * 128, tile['row'] * 128
        w, h = min(128, bank.width-x), min(128, bank.height-y)
        if w > 0 and h > 0:
            assert grid.crop((0, 0, w, h)).tobytes() == bank.crop((x, y, x+w, y+h)).tobytes(), tile['grid']
    return Image.composite(source, bank.resize(source.size, Image.Resampling.NEAREST), mask)


def check_sources():
    def check_paths(value):
        if isinstance(value, dict):
            for child in value.values():
                check_paths(child)
        elif isinstance(value, list):
            for child in value:
                check_paths(child)
        elif isinstance(value, str):
            rel = value.removeprefix('res://')
            if rel.startswith(('assets/', 'artifacts/', 'scripts/')) and '*' not in rel and '\n' not in rel:
                assert (ROOT/rel).exists(), rel

    for folder in ['sources', 'editable']:
        for manifest in (ROOT/'artifacts'/folder).rglob('*.json'):
            check_paths(json.loads(manifest.read_text(encoding='utf-8')))
    index = json.loads((ROOT/'artifacts/sources/index.json').read_text(encoding='utf-8'))
    for row in index:
        assert digest(ROOT/row['retained']) == row['sha256'], row['retained']
        for asset in row.get('assets', []):
            assert (ROOT/asset).exists(), asset
    editable = json.loads((ROOT/'artifacts/editable/index.json').read_text(encoding='utf-8'))
    for row in editable['assets']:
        assert digest(ROOT/row['asset']) == row['sha256'], row['asset']
        if row.get('editable'):
            assert (ROOT/row['editable']).is_file(), row['editable']
    return len(index), len(editable['assets'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Read-only verification (default)')
    parser.add_argument('--output', type=Path, help='Export reconstructed PNGs here; does not install them')
    args = parser.parse_args()
    sources, entries = check_sources()
    images = player_atlases()
    images['assets/ui/finance/finance_background.png'] = finance_background()
    for rel, image in images.items():
        current = Image.open(ROOT/rel).convert('RGBA')
        assert current.size == image.size and current.tobytes() == image.tobytes(), rel
        if args.output:
            output = args.output.resolve()/Path(rel).relative_to('assets')
            assert not output.is_relative_to(ROOT/'assets'), 'Use a separate export directory'
            output.parent.mkdir(parents=True, exist_ok=True)
            image.save(output)
    print(json.dumps({'sources': sources, 'editable_entries': entries, 'player_frames': 61,
                      'exact_reconstructed_images': len(images), 'status': 'pass'}))


if __name__ == '__main__':
    main()
