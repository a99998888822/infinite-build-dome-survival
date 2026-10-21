"""Validate all installed non-jump frames; --write rebuilds their exact atlases."""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image
from art_source_archive import grid_image

ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'assets/sprites/player/actions/novice_96'
MANIFEST=ROOT/'artifacts/sources/player/novice_actions_20261020/manifest.json'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args()
    archive=json.loads(MANIFEST.read_text(encoding='utf-8'))
    current=json.loads((ASSETS/'animations.json').read_text(encoding='utf-8'))
    approved=json.loads((ASSETS/'approved_frames.json').read_text(encoding='utf-8'))
    palette={tuple(bytes.fromhex(c[1:])) for c in archive['palette']}
    assert len(archive['frames'])==41 and current['clips']['move_sustain']['frames']==8
    for action,clip in archive['clips'].items():
        assert current['clips'][action]==clip,action+' timing or alignment changed'
        records=sorted([f for f in archive['frames'] if f['action']==action],key=lambda f:f['frame'])
        assert [f['frame'] for f in records]==list(range(clip['frames']))
        atlas=Image.new('RGBA',(96*len(records),96))
        for i,f in enumerate(records):
            for key in ['source','editable','png']:assert digest(ROOT/f[key])==f[key+'_sha256'],f[key]
            image=grid_image(ROOT/f['editable']);png=Image.open(ROOT/f['png']).convert('RGBA')
            assert image.size==(96,96) and image.tobytes()==png.tobytes()
            assert hashlib.sha256(image.tobytes()).hexdigest()==f['rgba_sha256']==approved['frames'][action][i]
            colors=image.getcolors(96*96);assert {rgba[3] for _,rgba in colors}=={0,255}
            assert {rgba[:3] for _,rgba in colors if rgba[3]}<=palette
            atlas.paste(image,(96*i,0))
        target=ROOT/clip['texture'].removeprefix('res://')
        if args.write:atlas.save(target)
        assert Image.open(target).convert('RGBA').tobytes()==atlas.tobytes()
        assert digest(target)==approved['atlas_sha256'][target.name]
    print('PASS: 41 exact approved 96px non-jump frames, shared 16-color palette, binary alpha, timing and 3px alignment; move_sustain has 8 frames.')

if __name__=='__main__':main()
