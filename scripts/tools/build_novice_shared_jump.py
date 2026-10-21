"""Check the approved shared jump; --write rebuilds its atlas from retained grids."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image
from art_source_archive import grid_image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/sprites/player/actions/novice_96'
SOURCE = ROOT / 'artifacts/editable/player/novice_jump_20261019'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    approved = json.loads((ASSETS / 'approved_frames.json').read_text(encoding='utf-8'))
    config = json.loads((ASSETS / 'animations.json').read_text(encoding='utf-8'))
    clips = config['clips']
    assert clips['jump_forward'] == clips['jump_backward'], 'Jump clips must share texture, timing and alignment'
    shared = clips['jump_forward']
    assert shared['frames'] == 6 and shared['frame_durations'] == [0.12] * 6
    assert shared['offset'] == [0, 3]
    atlas = Image.new('RGBA', (576, 96))
    for i in range(1, 7):
        base = SOURCE / f'player_jump{i}-96-detail-face'
        frame = grid_image(base.with_suffix('.pxg'))
        reference = Image.open(base.with_suffix('.png')).convert('RGBA')
        assert frame.size == (96, 96) and frame.tobytes() == reference.tobytes()
        digest = hashlib.sha256(frame.tobytes()).hexdigest()
        for action in ['jump_forward', 'jump_backward']:
            assert digest == approved['frames'][action][i - 1], (action, i)
        atlas.paste(frame, ((i - 1) * 96, 0))
    target = ROOT / shared['texture'].removeprefix('res://')
    if args.write:
        atlas.save(target)
    assert Image.open(target).convert('RGBA').tobytes() == atlas.tobytes()
    assert hashlib.sha256(target.read_bytes()).hexdigest() == approved['atlas_sha256']['jump.png']
    for source, expected in approved['source_sha256'].items():
        assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest() == expected, source
    colors = atlas.getcolors(atlas.width * atlas.height)
    assert {rgba[3] for _, rgba in colors} == {0, 255}
    assert len({rgba[:3] for _, rgba in colors if rgba[3]}) <= 16
    print('PASS: both jumps share six exact approved 96px frames, 0.72s timing, 3px foot alignment, binary alpha and <=16 colors')


if __name__ == '__main__':
    main()
