"""Prepare all currently configured unique augmentation icon design tasks."""
from pathlib import Path
import json,hashlib,zipfile
from PIL import Image
HERE=Path(__file__).resolve().parent;PLAN=HERE.parents[1];ROOT=PLAN.parents[2]
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    text=json.dumps(value,ensure_ascii=False,indent=2)+'\n'
    if p.exists() and b'\r\n' in p.read_bytes():text=text.replace('\n','\r\n')
    p.write_bytes(text.encode('utf-8'))
config=read(ROOT/'data_config/augmentations.json');groups={}
for entry in config:groups.setdefault(entry['icon'],[]).append(entry)
assert len(config)==13 and len(groups)==12
source='artifacts/reference/darkest_dungeon/u=1960619763,3771408159&fm=253&fmt=auto&app=120&f=JPEG.webp'
crop=[245,55,568,390];reference=HERE/'01_arcane_ink_reference.png'
Image.open(ROOT/source).convert('RGB').crop(crop).save(reference)
prompt=(HERE/'doubao_prompt.txt').read_text(encoding='utf-8')
icons=read(PLAN/'icon_manifest.json');by_key={a['key']:a for a in icons}
items=[]
for index,(resource,entries) in enumerate(groups.items()):
    path=resource.removeprefix('res://');key=Path(path).stem;names=[a['display_name'] for a in entries];ids=[a['id'] for a in entries]
    assert all(name in prompt for name in names)
    canvas=list(Image.open(ROOT/path).size) if path.endswith('.png') else [64,64]
    items.append({'row':index//4+1,'column':index%4+1,'key':key,'names':names,'config_ids':ids,'source':path,
                  'source_sha256':sha(ROOT/path),'current_canvas':canvas,'output_filename':key+'.png','pixel_target':[64,64],
                  'future_png_path':'assets/ui/icons/augmentations/'+key+'.png','config_path_change_on_install':path.endswith('.svg')})
    if key not in by_key:
        item={'key':key,'names':names,'config_ids':ids,'table':'augmentations','batch':'augmentations_01','original_path':resource,
              'original_size':canvas,'highres_name':key+'.png','highres_size':[1024,1024]}
        icons.append(item);by_key[key]=item
    by_key[key].update(names=names,config_ids=ids,status='awaiting_highres_generation',generation_batch='augmentations_sheet_01',
                      generation_package='batches/augmentations_sheet_01/README.md',prompt_file='batches/augmentations_sheet_01/doubao_prompt.txt',
                      draft_pixel_size=[64,64],detail_pixel_size=None)
manifest={'status':'awaiting_highres_generation','scope':'12 unique augmentation UI icons for 13 configuration records; effects excluded.',
          'layout':{'columns':4,'rows':3,'preferred_canvas':[4096,3072],'bottom_white_band_percent':10},
          'method':'Style-only image plus semantic identity cues; allow new silhouettes and arrangements.',
          'reference':{'file':reference.name,'source':source,'source_sha256':sha(ROOT/source),'crop_xyxy':crop,'sha256':sha(reference)},'items':items}
write(HERE/'manifest.json',manifest);write(PLAN/'icon_manifest.json',icons)
coverage=read(PLAN/'asset_coverage.json');by_path={a['path']:a for a in coverage}
for item in items:
    if item['source'] not in by_path:
        c={'path':item['source'],'current_canvas':item['current_canvas'],'phase':'P2','sha256':item['source_sha256']};coverage.append(c);by_path[item['source']]=c
    by_path[item['source']].update(recipe='batches/augmentations_sheet_01/README.md',status='awaiting_highres_generation')
write(PLAN/'asset_coverage.json',coverage)
with zipfile.ZipFile(HERE/'augmentations_sheet_01_doubao.zip','w',zipfile.ZIP_DEFLATED) as bundle:
    for name in ['README.md','doubao_prompt.txt','01_arcane_ink_reference.png','manifest.json']:bundle.write(HERE/name,name)
assert len(icons)==113
for item in items:assert sha(ROOT/item['source'])==item['source_sha256']
print('Prepared 12 augmentation icons for 13 configs; single new style crop; no production/config changes.')
