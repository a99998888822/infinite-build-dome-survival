"""Pack all remaining six relics with one style reference and no identity images."""
from pathlib import Path
import json,shutil,hashlib,zipfile
HERE=Path(__file__).resolve().parent;PLAN=HERE.parents[1];ROOT=PLAN.parents[2]
KEYS=['relic_medical_cutback','relic_welfare_cutback','relic_annual_leave_cutback',
 'relic_salary_adjustment','relic_perpetual_annuity_scroll','relic_bankruptcy_reorg']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=PLAN/'references/U01_darkest_style_no_text.png'
shutil.copy2(source,HERE/'01_style_reference.png')
icons={a['key']:a for a in json.loads((PLAN/'icon_manifest.json').read_text(encoding='utf-8'))}
current={a['key'] for a in json.loads((PLAN/'batches/relics_sheet_08/manifest.json').read_text(encoding='utf-8'))['items']}
remaining={a['key'] for a in icons.values() if a['table']=='relics' and a['status']!='installed' and a['key'] not in current}
assert remaining==set(KEYS) and len(KEYS)==6
prompt=(HERE/'doubao_prompt.txt').read_text(encoding='utf-8');items=[]
for i,key in enumerate(KEYS):
 icon=icons[key];path=icon['original_path'].removeprefix('res://');assert (ROOT/path).is_file()
 assert icon['names'][0] in prompt
 items.append({'row':i//3+1,'column':i%3+1,'key':key,'name':icon['names'][0],
  'config_ids':icon['config_ids'],'source':path,'source_sha256':sha(ROOT/path),
  'output_filename':key+'.png','pixel_target':[64,64]})
manifest={'status':'awaiting_highres_generation','method':'Original designs from one style reference and text; no identity images.',
 'covers_all_remaining_relics':True,'layout':{'columns':3,'rows':2,'preferred_canvas':[3072,2304],'bottom_white_band_percent':10},
 'style_reference_source':source.relative_to(ROOT).as_posix(),'style_reference_sha256':sha(source),
 'split_rule':'Inspect actual count, identity and location before cropping; do not assume generation follows grid order.','items':items}
(HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(HERE/'relics_sheet_09_doubao.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for name in ['README.md','01_style_reference.png','doubao_prompt.txt','manifest.json']:archive.write(HERE/name,name)
with zipfile.ZipFile(HERE/'relics_sheet_09_doubao.zip') as archive:
 assert len([name for name in archive.namelist() if name.endswith('.png')])==1
 assert hashlib.sha256(archive.read('01_style_reference.png')).hexdigest()==sha(source)
 assert archive.read('doubao_prompt.txt')==(HERE/'doubao_prompt.txt').read_bytes()
print('Prepared all 6 remaining relics; style-only; prompt characters:',len(prompt))
