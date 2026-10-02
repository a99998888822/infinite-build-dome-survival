"""Assemble existing drawer parts for reference only; no AI redraw/pixelization."""
from pathlib import Path
import hashlib
import json
from PIL import Image

TASK = Path(__file__).resolve().parent
ROOT = TASK.parents[2]
OUTPUT = TASK / 'references'
ASSETS = ROOT / 'assets/ui/stats_drawer'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parts = {name: Image.open(ASSETS / ('stats_' + name + '.png')).convert('RGBA')
             for name in ('board_top', 'board_bottom', 'rail_left', 'rail_right', 'wood_tile')}
    output = Image.new('RGBA', (313, 558))

    def tile(source, box):
        left, top, right, bottom = box
        for y in range(top, bottom, source.height):
            for x in range(left, right, source.width):
                crop = source.crop((0, 0, min(source.width, right - x), min(source.height, bottom - y)))
                output.alpha_composite(crop, (x, y))

    # Match the existing skin's native 313px construction, without downscaling.
    tile(parts['wood_tile'], (20, 30, 292, 528))
    top_h, bottom_h = parts['board_top'].height, parts['board_bottom'].height
    tile(parts['rail_left'], (0, top_h, 25, 558 - bottom_h))
    tile(parts['rail_right'], (288, top_h, 313, 558 - bottom_h))
    output.alpha_composite(parts['board_top'], (0, 0))
    output.alpha_composite(parts['board_bottom'], (0, 558 - bottom_h))
    OUTPUT.mkdir(exist_ok=True)
    native = OUTPUT / 'U01_stats_original_structure.png'
    enlarged = OUTPUT / 'U01_stats_original_structure_2x.png'
    output.save(native)
    output.resize((626, 1116), Image.Resampling.NEAREST).save(enlarged)
    manifest = {'purpose': 'Original drawer structure reference, not a new approved design or generated HD artwork.',
                'native_size': [313, 558], 'upload_size': [626, 1116],
                'method': 'Native pixel assembly using the current skin geometry. The upload version uses nearest-neighbor 2x enlargement only.',
                'sources': [{'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)} for p in sorted(ASSETS.glob('*.png'))],
                'outputs': [{'path': p.relative_to(TASK).as_posix(), 'sha256': sha(p)} for p in (native, enlarged)],
                'identity_notes': 'Preserve metal edging and sparse leather ties. The separate interactive leather handle is not baked into the new panel. Existing chains are secondary, not the main design requirement.'}
    (OUTPUT / 'U01_stats_reference_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'structure_reference': str(enlarged), 'source_assets_unchanged': True}))

if __name__ == '__main__':
    main()
