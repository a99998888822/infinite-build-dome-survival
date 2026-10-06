from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
base=Path(__file__).parent
target=base/'project/review_assets'
target.mkdir(exist_ok=True)
sheet=Image.new('RGBA',(512,384))
frames=[]
for i in range(48):
    a=np.asarray(Image.open(base/f'baked-raw/frame_{i:02d}.png').convert('RGBA')).astype(np.float32)
    alpha=a[:,:,3:]
    # Transparent SubViewport readback contains premultiplied RGB. PNGs used
    # with the normal CanvasItem blend must store straight alpha colors.
    rgb=np.divide(a[:,:,:3]*255,alpha,out=np.zeros_like(a[:,:,:3]),where=alpha>0)
    a[:,:,:3]=np.clip(np.rint(rgb),0,255)
    im=Image.fromarray(a.astype(np.uint8))
    frames.append(im)
    sheet.paste(im,((i%8)*64,(i//8)*64))
sheet.save(target/'yellow_warning_60fps.png')
preview=Image.new('RGB',sheet.size,(31,46,36))
preview.paste(sheet,mask=sheet.getchannel('A'))
preview.resize((1024,768),Image.Resampling.NEAREST).save(base/'atlas-preview.png')
metadata={'frame_size':[64,64],'columns':8,'rows':6,'frame_count':48,'fps':60,'charge_seconds':.5,'fade_seconds':.28,'radius':20,'pivot':[32,32],'last_frame_transparent':True,'alpha':'straight; unpremultiplied from Godot readback','source_sha256':hashlib.sha256((base/'original-electric-spark.gd').read_bytes()).hexdigest(),'generation':'GPU bake of existing production drawing code; no image generation API'}
(target/'yellow_warning_60fps.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print('Atlas built',sheet.size,'PNG bytes',(target/'yellow_warning_60fps.png').stat().st_size)
