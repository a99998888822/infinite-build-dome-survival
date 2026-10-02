"""Build the style-only next batch without uploading identity imagery."""
from pathlib import Path
import json,shutil,hashlib,zipfile
HERE=Path(__file__).resolve().parent;PLAN=HERE.parents[1];ROOT=PLAN.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=PLAN/'references/U01_darkest_style_no_text.png'
shutil.copy2(source,HERE/'01_style_reference.png')
icons=json.loads((PLAN/'icon_manifest.json').read_text(encoding='utf-8'))
start=next(i for i,a in enumerate(icons) if a['key']=='relic_cultic_holy_shield');chosen=icons[start:start+12]
assert len(chosen)==12 and all(a['table']=='relics' and a['status']!='installed' for a in chosen)
items=[]
for i,icon in enumerate(chosen):
 path=icon['original_path'].removeprefix('res://');assert (ROOT/path).is_file()
 items.append({'row':i//4+1,'column':i%4+1,'key':icon['key'],'name':icon['names'][0],
  'config_ids':icon['config_ids'],'source':path,'source_sha256':sha(ROOT/path),
  'output_filename':icon['key']+'.png','pixel_target':[32,32]})
manifest={'status':'awaiting_highres_generation','method':'Original object designs from one style reference plus concise text; no identity images supplied.',
 'layout':{'columns':4,'rows':3,'preferred_canvas':[3072,2304]},'style_reference_source':source.relative_to(ROOT).as_posix(),
 'style_reference_sha256':sha(source),'split_rule':'Inspect actual count, identity and location before cropping; do not assume generation follows grid order.',
 'items':items}
(HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(HERE/'relics_sheet_04_doubao.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for name in ['README.md','01_style_reference.png','doubao_prompt.txt','manifest.json']:archive.write(HERE/name,name)
with zipfile.ZipFile(HERE/'relics_sheet_04_doubao.zip') as archive:
 assert len([name for name in archive.namelist() if name.endswith('.png')])==1
 assert hashlib.sha256(archive.read('01_style_reference.png')).hexdigest()==sha(source)
print('Prepared 12-item style-only pack; prompt characters:',len((HERE/'doubao_prompt.txt').read_text(encoding='utf-8')))
