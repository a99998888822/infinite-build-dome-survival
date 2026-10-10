"""Install the approved R01 bytes, preserving the previous production files."""
from pathlib import Path
import hashlib
import json
import shutil

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
REVIEW=ROOT/'artifacts/previews/pixel_effects_r01_20261010'
manifest=json.loads((REVIEW/'manifest.json').read_text(encoding='utf-8'))
targets={key:('assets/sprites/effects/wind_blade.png' if key=='wind_blade' else
              'assets/sprites/weapons/meteor_flail/meteor_flail_trail.png' if key=='flail_trail' else
              f'assets/sprites/weapons/mobility/{key}.png') for key in manifest['effects']}
for key,entry in manifest['effects'].items():
    assert hashlib.sha256((REVIEW/entry['candidate']).read_bytes()).hexdigest()==entry['sha256'],key
for relative in list(targets.values())+['scripts/effects/wind_blade_effect.gd','scripts/weapons/meteor_flail.gd']:
    source=ROOT/relative
    backup=OUT/'before'/relative
    if source.exists() and not backup.exists():
        backup.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,backup)
report={}
for key,relative in targets.items():
    source=REVIEW/manifest['effects'][key]['candidate']
    target=ROOT/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    digest=hashlib.sha256(target.read_bytes()).hexdigest()
    assert digest==manifest['effects'][key]['sha256']
    report[key]={'path':relative,'sha256':digest}
(OUT/'installed_assets.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('APPROVED_ASSETS_INSTALLED',len(report))
