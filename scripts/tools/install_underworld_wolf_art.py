"""Check production wolf artwork; --rebuild-atlases uses its current PNGs.

Formal PNGs and SpriteFrames metadata are authoritative; historical processing
folders are unused. No arguments only validates, without writing any resource.
"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/sprites/enemies/underworld_wolf'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--rebuild-atlases', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((DEST/'manifest.json').read_text(encoding='utf-8'))
    assert manifest['canvas'] == [128,128]
    records = {(r['action'],r['number']):r for r in manifest['frames']}
    counts = {'move':7,'attack':4,'jump':10}
    assert records.keys() == {(a,i) for a,n in counts.items() for i in range(1,n+1)}
    palette = {tuple(bytes.fromhex(c[1:])) for c in manifest['palette']}
    groups = {}
    for action,count in counts.items():
        frames = []
        for number in range(1,count+1):
            record = records[action,number]
            path = DEST/record['output']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
            image = Image.open(path).convert('RGBA')
            assert image.size == (128,128) and set(image.getchannel('A').tobytes()) == {0,255}
            colors = {rgba[:3] for _,rgba in image.getcolors(128*128) if rgba[3]}
            assert len(colors) <= 16 and colors <= palette
            frames.append(image)
        groups[action] = frames
    text = (DEST/'wolf_sprite_frames.tres').read_text(encoding='utf-8')
    metadata = {}
    for line in text.splitlines():
        if line.startswith('metadata/'):
            key,value = line.split(' = ',1)
            metadata[key] = json.loads(value)
    assert metadata['metadata/animation_sequences'] == manifest['animation_sequences']
    transforms = {f'{a}:{i-1}':{'sprite_scale':r['sprite_scale'],'sprite_offset':r['sprite_offset']}
                  for (a,i),r in records.items()}
    assert metadata['metadata/frame_transforms'] == transforms
    assert 'res://artifacts/' not in text
    for action,frames in groups.items():
        atlas = DEST/'atlases'/f'{action}.png'
        expected = Image.new('RGBA',(128*len(frames),128))
        for i,frame in enumerate(frames):
            expected.paste(frame,(128*i,0))
        if args.rebuild_atlases:
            expected.save(atlas)
        actual = Image.open(atlas).convert('RGBA')
        assert actual.size == expected.size and actual.tobytes() == expected.tobytes(), atlas
    print('WOLF_PRODUCTION_VALID frames=21 atlases=3 metadata=9_animations historical_packages_required=false')


if __name__ == '__main__':
    main()
