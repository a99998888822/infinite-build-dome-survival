"""Prepare a style-only weapon packet and register its current 11 configured icons."""
from pathlib import Path
import json,hashlib,zipfile
from PIL import Image
HERE=Path(__file__).resolve().parent;PLAN=HERE.parents[1];ROOT=PLAN.parents[2]
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):
 text=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
 if p.exists() and b'\r\n' in p.read_bytes():text=text.replace('\n','\r\n')
 p.write_bytes(text.encode('utf-8'))
ref_specs=[
 ('01_steel_ink_reference.png','artifacts/reference/darkest_dungeon/u=2637947151,2706126914&fm=253&fmt=auto&app=120&f=JPEG.webp',[0,0,800,245],'Primary: dark metal planes, clear edges and hard shadows; omit identity and composition.'),
 ('02_arcane_color_reference.png','artifacts/reference/cuthulu/u=3055906668,2960803188&fm=253&fmt=auto&app=120&f=JPEG.webp',[0,0,500,450],'Secondary: violet/cyan and aged-gold accents only; omit figure, glow, fine linework and composition.')]
refs=[]
for name,source,box,purpose in ref_specs:
 path=ROOT/source;im=Image.open(path).convert('RGB');assert box[2]<=im.width and box[3]<=im.height
 im.crop(box).save(HERE/name)
 refs.append({'file':name,'source':source,'source_sha256':sha(path),'source_canvas':im.size,'crop_xyxy':box,'output_sha256':sha(HERE/name),'purpose':purpose,'method':'Local crop; no image generation or pixel conversion.'})
write(HERE/'reference_manifest.json',refs)
config=read(ROOT/'data_config/weapons.json');assert len(config)==11
icons=read(PLAN/'icon_manifest.json');by_key={a['key']:a for a in icons}
items=[];prompt=(HERE/'doubao_prompt.txt').read_text(encoding='utf-8')
for i,entry in enumerate(config):
 source=entry['icon'].removeprefix('res://');key=Path(source).stem;path=ROOT/source
 assert path.is_file() and entry['display_name'] in prompt
 size=list(Image.open(path).size)
 items.append({'row':i//4+1,'column':i%4+1,'key':key,'name':entry['display_name'],'config_ids':[entry['id']],
  'source':source,'source_sha256':sha(path),'current_size':size,'output_filename':key+'.png','pixel_target':[64,64]})
 if key not in by_key:
  item={'key':key,'names':[entry['display_name']],'config_ids':[entry['id']],'table':'weapons','batch':'weapons_01',
   'original_path':entry['icon'],'original_size':size,'highres_name':key+'.png','highres_size':[1024,1024],
   'draft_pixel_size':[64,64],'detail_pixel_size':None,'prompt_file':'batches/weapons_sheet_01/doubao_prompt.txt'}
  insert=next(j for j,a in enumerate(icons) if a['table']!='weapons');icons.insert(insert,item);by_key[key]=item
 item=by_key[key];assert item['config_ids']==[entry['id']] and item['original_path']==entry['icon']
 item.update(status='awaiting_highres_generation',generation_batch='weapons_sheet_01',generation_package='batches/weapons_sheet_01/README.md',
  draft_pixel_size=[64,64],detail_pixel_size=None,prompt_file='batches/weapons_sheet_01/doubao_prompt.txt',
  integration='Candidate 64px icon; inspect new art then align UI as needed. Battle sprites/projectiles are separate assets.')
assert len({a['key'] for a in items})==11
manifest={'status':'awaiting_highres_generation','scope':'11 current weapon UI icons only',
 'method':'From-scratch objects guided by concise descriptions and two distinct style references; no existing item images.',
 'layout':{'columns':4,'rows':3,'empty_cells':[[3,4]],'preferred_canvas':[4096,3072],'bottom_white_band_percent':10},
 'references':[a['file'] for a in refs],'split_rule':'Inspect actual positions, identities and count before cropping.','items':items}
write(HERE/'manifest.json',manifest);write(PLAN/'icon_manifest.json',icons)
coverage=read(PLAN/'asset_coverage.json');by_path={a['path']:a for a in coverage}
for item in items:
 path=item['source']
 if path not in by_path:
  a={'path':path};coverage.append(a);by_path[path]=a
 by_path[path].update(current_canvas=item['current_size'],recipe='batches/weapons_sheet_01/README.md',phase='P2',status='awaiting_highres_generation',sha256=item['source_sha256'])
write(PLAN/'asset_coverage.json',coverage)
with zipfile.ZipFile(HERE/'weapons_sheet_01_doubao.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in ['README.md','doubao_prompt.txt','manifest.json','reference_manifest.json']+[r['file'] for r in refs]:z.write(HERE/name,name)
with zipfile.ZipFile(HERE/'weapons_sheet_01_doubao.zip') as z:
 assert z.testzip() is None and len([n for n in z.namelist() if n.endswith('.png')])==2
for a in items:assert sha(ROOT/a['source'])==a['source_sha256']
assert len(icons)==111 and len([a for a in icons if a['table']=='weapons'])==11
assert len([a for a in icons if a['table']=='relics' and a['status']=='installed'])==90
print('Prepared 11 weapons, 2 new style crops; production assets unchanged; prompt characters:',len(prompt))
