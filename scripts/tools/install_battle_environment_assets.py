"""Install the approved 128px PNGs unchanged, with measured content bounds.

Only the explicitly listed superseded decoration files are removed. The sky,
central floor, HUD textures and original external review folders are preserved.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/sprites/background/wetland'
# Physical extent is the longest visible side in world units before depth.
SPECS = [
    ('ruin_curved_wall',176), ('ruin_sloped_wall',176), ('ruin_brick_wall',176),
    ('ruin_twin_pillar_wall',184), ('ruin_broken_arch',156),
    ('ruin_square_pillar',104), ('ruin_broken_column',100), ('ruin_short_column',70),
    ('ruin_stone_block',64), ('ruin_eroded_pillar',104),
    ('decal_single_brick',44), ('decal_stacked_bricks',62), ('decal_brick_fragments',80),
    ('decal_scattered_stones',76), ('decal_high_rubble',86), ('decal_low_rubble',78),
    ('decal_flat_stones',82), ('decal_compact_moss',20), ('decal_long_moss',26),
    ('decal_wet_moss',32), ('decal_vertical_crack',72), ('decal_forked_crack',76),
    ('decal_fine_crack',72), ('decal_spreading_crack',94), ('decal_cyan_crack',96),
    ('decal_mossy_crack',98), ('decal_wet_patch',104), ('decal_puddle',96),
    ('fx_fine_ripples',58), ('fx_cyan_ripples',58),
]
LEGACY = [
    'decal_brick_01','decal_brick_02','decal_crack_01','decal_crack_02','decal_crack_03',
    'decal_moss_01','decal_moss_02','decal_rubble_01','decal_rubble_02',
    'ruin_low_wall_01','ruin_low_wall_02','ruin_broken_pillar','fx_wet_ripple',
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path,help='Approved review package directory')
    args = parser.parse_args()
    source = args.source.resolve() / '128px'
    # Validate every source before modifying the project.
    entries = []
    for n,(asset_id,extent) in enumerate(SPECS,1):
        matches = list(source.glob(f'{n:02d}_*.png'))
        assert len(matches)==1, (n,matches)
        path = matches[0]
        with Image.open(path) as im:
            assert im.size==(128,128) and im.mode=='RGBA',path
            assert set(im.getchannel('A').tobytes())=={0,255},path
            bbox=im.getbbox()
            opaque_colors={c[:3] for amount,c in im.getcolors(16384) if c[3]}
            assert len(opaque_colors)<=16,path
        entries.append((path,asset_id,{'texture':f'res://assets/sprites/background/wetland/{asset_id}.png',
            'source_file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'content_rect':[bbox[0],bbox[1],bbox[2]-bbox[0],bbox[3]-bbox[1]],
            'world_extent':extent}))
    DEST.mkdir(parents=True,exist_ok=True)
    for path,asset_id,entry in entries:
        target=DEST/(asset_id+'.png')
        shutil.copyfile(path,target)
        assert hashlib.sha256(target.read_bytes()).hexdigest()==entry['sha256']
    old = [DEST/(name+suffix) for name in LEGACY for suffix in ('.png','.png.import')]
    old += [DEST.parent/(f'background-stone-piller{n}'+suffix)
            for n in (1,2) for suffix in ('.png','.png.import','.aseprite')]
    removed=[]
    for path in old:
        assert path.resolve().is_relative_to((ROOT/'assets/sprites/background').resolve())
        if path.is_file():
            path.unlink()
            removed.append(path.relative_to(ROOT).as_posix())
    ids=[s[0] for s in SPECS]
    config={'schema_version':1,'source_package':'battle_scene_picxel_review/128px',
        'canvas_size':[128,128],'scale_basis':'longest visible side; uniform aspect-preserving scaling',
        'ground_slots':['brick','brick','crack','crack','wet','moss','moss','rubble','rubble'],
        'groups':{'wall':ids[:5],'pillar':ids[5:10],'brick':ids[10:13],
                  'rubble':ids[13:17],'moss':ids[17:20],'crack':ids[20:26],
                  'wet':ids[26:28],'ripple':ids[28:30]},
        'assets':{asset_id:entry for path,asset_id,entry in entries}}
    (ROOT/'data_config/battle_scenery.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'copied':len(entries),'removed':removed},indent=2))


if __name__=='__main__': main()
