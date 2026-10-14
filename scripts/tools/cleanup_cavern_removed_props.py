"""Scoped removal of A02/A03/A04/A06/A07, preserving shared-sheet neighbours."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/analysis/obstacle_revision_20261013'
CAT=ROOT/'artifacts/analysis/obstacle_catalog_20261013'
OLD=ROOT/'artifacts/analysis/battle_scene_20261012'
OUT.mkdir(parents=True,exist_ok=True)
REMOVED={'A02':'broken_pillar','A03':'crate','A04':'barrel','A06':'urn','A07':'crate_stack'}
REGIONS={
 'ground_Barier1.png':[(.06,.655,.45,.99)],
 'ground_block2.png':[(.015,.02,.26,.255),(.775,.025,.985,.265),(.26,.28,.66,.61)],
 'ground_block3.png':[(.265,.015,.495,.36)]}

def safe(path):
    path=path.resolve()
    assert path.is_relative_to(ROOT) and '.git' not in path.parts
    return path

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def run(apply=False):
    paths=[ROOT/p for p in subprocess.check_output(['rg','--files','-uuu','-g','!.git/**'],cwd=ROOT).decode('utf-8').splitlines()]
    raw=[p for p in paths if p.name in REGIONS]
    source_hashes={sha(p):p.name for p in raw}
    source_sizes={p.stat().st_size for p in raw}
    deleted_textures=[ROOT/f'assets/sprites/background/cavern/prop_{name}.png' for name in REMOVED.values()]
    texture_hashes={sha(p) for p in deleted_textures if p.exists()}
    texture_sizes={p.stat().st_size for p in deleted_textures if p.exists()}
    erase=set(); sanitize={p:REGIONS[p.name] for p in raw}
    for path in paths:
        if not path.is_file():continue
        name=path.name
        if any(name.startswith('prop_'+v+'.') or name.startswith('prop_'+v+'-') for v in REMOVED.values()):erase.add(safe(path))
        if path.suffix.lower() in {'.png','.jpg','.webp'} and path.stat().st_size in source_sizes|texture_sizes:
            digest=sha(path)
            if digest in source_hashes:sanitize[path]=REGIONS[source_hashes[digest]]
            if digest in texture_hashes:erase.add(safe(path))
    # Remove the superseded A gallery and captures that contain the deleted art.
    for folder in ['cards','crops']:
        for p in (CAT/folder).glob('A*'):
            if p.name[:3] in REMOVED:erase.add(safe(p))
    for p in (CAT/'runtime').glob('attachment_*.png'):erase.add(safe(p))
    for p in (CAT/'sheets').glob('group_[12]_*.png'):erase.add(safe(p))
    # Old composites are flattened renderings of this retired prop selection.
    # Keep independent ground, foreground and panorama exports.
    for directory in list(OLD.glob('preview_v0[1-5]'))+list(OLD.glob('runtime_v*')):
        if directory.name.startswith('runtime_v') and int(directory.name[9:])>=15:continue
        for p in directory.rglob('*'):
            if not p.is_file():continue
            if p.suffix.lower() not in {'.png','.jpg','.gif','.webp','.mp4'}:continue
            if any(k in p.name for k in ['foreground','panorama','ground_cutout','paving','terrain']):continue
            if directory.name.startswith('preview_') or any(k in p.name for k in ['tour_','entry_','cavern_still','live_combat','scenery_tour','before_after','barrier_preview']):erase.add(safe(p))
    for p in OLD.glob('contact_*.jpg'):erase.add(safe(p))
    keep_config=json.loads((ROOT/'data_config/cavern_meadow_battlefield.json').read_text(encoding='utf-8'))
    depth=json.loads((ROOT/'data_config/cavern_battlefield.json').read_text(encoding='utf-8'))
    keep_paths={ROOT/r['texture'][6:] for key in ['props','rubble','grass'] for r in keep_config[key]}
    keep_paths|={ROOT/r['texture'][6:] for key in ['rubble','ruins','foreground'] for r in depth[key]}
    keep_hashes={str(p):sha(p) for p in keep_paths}
    assert not erase.intersection(keep_paths)
    plan={'removed':REMOVED,'files':[str(p) for p in sorted(erase)],'source_sheets':[str(p) for p in sanitize],
        'source_regions':REGIONS,'preserved_runtime_sha256':keep_hashes,
        'original_archive_exists':Path('C:/Users/mi/Desktop/sucai.rar').exists()}
    (OUT/'cleanup_plan.json').write_text(json.dumps(plan,indent=2),encoding='utf-8')
    print(json.dumps({'delete_count':len(erase),'shared_sheets_to_sanitize':len(sanitize),
                      'preserved_runtime_files':len(keep_paths),'delete_bytes':sum(p.stat().st_size for p in erase)}))
    if not apply:return
    sheet_records=[]
    for path,regions in sanitize.items():
        safe(path)
        a=np.array(Image.open(path).convert('RGBA'));b=a.copy();mask=np.zeros(a.shape[:2],dtype=bool)
        boxes=[]
        for region in regions:
            box=tuple(int(v*(a.shape[1] if i%2==0 else a.shape[0])) for i,v in enumerate(region))
            x0,y0,x1,y1=box;mask[y0:y1,x0:x1]=True;boxes.append(box)
        b[mask]=0
        before_hash=sha(path)
        Image.fromarray(b).save(path)
        checked=np.array(Image.open(path).convert('RGBA'))
        assert np.array_equal(checked[~mask],a[~mask]) and not np.any(checked[mask])
        sheet_records.append({'path':str(path),'removed_boxes':boxes,'before_sha256':before_hash,'after_sha256':sha(path),
                              'unchanged_outside_removed_regions':True})
    depth['props']=[r for r in depth['props'] if r['id'] in {'rock','log'}]
    for row in depth['props']:row['catalog_id']='A01' if row['id']=='rock' else 'A05'
    (ROOT/'data_config/cavern_battlefield.json').write_text(json.dumps(depth,indent=2)+'\n',encoding='utf-8')
    for p in sorted(erase):safe(p).unlink()
    assert not any(p.exists() for p in erase)
    assert all(sha(Path(p))==digest for p,digest in keep_hashes.items())
    report={**plan,'applied':True,'source_sheet_repairs':sheet_records,'deleted_count':len(erase),
            'deleted_pxg_count':sum(p.suffix=='.pxg' for p in erase),
            'note':'No deleted-A Picxel grids existed; generated PNGs, source regions and cached imports removed.'}
    (OUT/'cleanup_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('CLEANUP_COMPLETE')

if __name__=='__main__':run('--apply' in sys.argv)
