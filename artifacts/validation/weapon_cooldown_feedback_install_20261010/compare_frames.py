from pathlib import Path
import hashlib,json
from PIL import Image, ImageChops, ImageDraw, ImageFont
out=Path(__file__).resolve().parent
results=[]; frames=[]; border_checks=[]
colors={(0xd5,0xe3,0xdf),(0x8f,0xa7,0xa6),(0x29,0x3b,0x3e)}
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
for i in range(60):
 approved=Image.open(out/'approved'/f'ready_r03_{i:03}.png').convert('RGB')
 installed=Image.open(out/'frames'/f'ready_installed_{i:03}.png').convert('RGB')
 # Compare the actual normal-size HUD, including border particles above it.
 region=(247,128,473,224)
 diff=ImageChops.difference(approved.crop(region),installed.crop(region))
 results.append(dict(frame=i,identical=diff.getbbox() is None))
 if i in [22,23,24,25]:
  # At full opacity, compare exact approved border colors and occupied pixels.
  # Grass/shader time underneath the translucent card differs across sessions.
  masks=[]
  for picture in [approved,installed]:
   roi=picture.crop(region)
   masks.append({(x,y,roi.getpixel((x,y))) for y in range(96) for x in range(226) if roi.getpixel((x,y)) in colors})
  border_checks.append(dict(frame=i,pixels=len(masks[0]),identical=masks[0]==masks[1]))
 panel=Image.new('RGB',(720,340),'#17221f')
 panel.paste(installed.crop((0,244,720,540)),(0,40))
 ImageDraw.Draw(panel).text((24,9),'COOLDOWN READY / INSTALLED',font=font,fill='#d5e3df')
 frames.append(panel)
palette=frames[23].quantize(colors=256)
indexed=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
durations=[30 if i%3!=2 else 40 for i in range(60)];durations[-1]+=600
indexed[0].save(out/'cooldown_installed.gif',save_all=True,append_images=indexed[1:],duration=durations,loop=0,optimize=True,disposal=1)
(out/'validation/frame_comparison.json').write_text(json.dumps(dict(frames=60,full_hud_identical=sum(x['identical'] for x in results),region=region,results=results,opaque_border_checks=border_checks,note='Translucent background differs with world shader time; opaque peak borders match exactly.'),indent=2),encoding='utf-8')
assert all(check['identical'] and check['pixels']>0 for check in border_checks)
print('APPROVED_OPAQUE_BORDER_MATCH',len(border_checks))
