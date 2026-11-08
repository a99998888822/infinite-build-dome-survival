from pathlib import Path
from PIL import Image
import numpy as np
import json
ROOT=Path(__file__).resolve().parents[2]
RAW=ROOT/'artifacts/reviews/approved-weapon-vfx-bake/raw'
OUT=ROOT/'assets/effects/approved_weapons'
OUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((RAW/'manifest.json').read_text(encoding='utf-8'))
definitions={}
for key,info in manifest.items():
    frames=[]
    for i in range(info['count']):
        pixels=np.array(Image.open(RAW/key/f'{i:03d}.png').convert('RGBA'))
        alpha=pixels[:,:,3:4].astype(np.float32)
        pixels[:,:,:3]=np.clip(np.rint(pixels[:,:,:3].astype(np.float32)*255.0/np.maximum(alpha,1.0)),0,255).astype(np.uint8)
        frames.append(Image.fromarray(pixels))
    bounds=[b for im in frames if (b:=im.getchannel('A').getbbox())]
    assert bounds,key
    crop=[max(0,min(b[0] for b in bounds)-2),max(0,min(b[1] for b in bounds)-2),min(512,max(b[2] for b in bounds)+2),min(320,max(b[3] for b in bounds)+2)]
    w,h=crop[2]-crop[0],crop[3]-crop[1]
    cols=min(8,len(frames))
    sheet=Image.new('RGBA',(w*cols,h*((len(frames)+cols-1)//cols)))
    for i,im in enumerate(frames): sheet.paste(im.crop(crop),((i%cols)*w,(i//cols)*h))
    sheet.save(OUT/f'{key}.png',optimize=True)
    definitions[key]={'size':[w,h],'origin':[crop[0]-128,crop[1]-160],'count':len(frames),'columns':cols,'fps':info['fps']}
    (OUT/f'{key}.png.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=false\n',encoding='utf-8')
(OUT/'manifest.json').write_text(json.dumps(definitions,indent=2),encoding='utf-8')
source='extends RefCounted\n## Generated offline; immutable shared atlases. No runtime image creation.\n'
source+='const DEFINITIONS := '+json.dumps(definitions)+'\n'
source+='const TEXTURES := {\n'+',\n'.join('"'+k+'":preload("res://assets/effects/approved_weapons/'+k+'.png")' for k in definitions)+'\n}\n'
(ROOT/'scripts/effects/approved_weapon_frames.gd').write_text(source,encoding='utf-8')
print('RGBA8 MiB',sum(Image.open(OUT/f'{k}.png').width*Image.open(OUT/f'{k}.png').height*4 for k in definitions)/1048576)
