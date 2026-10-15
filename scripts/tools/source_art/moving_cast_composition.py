"""Compose the retained moving-cast donor onto source gait frames."""
from pathlib import Path
import argparse, json
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parents[3]
def foreground(a):
    # Only identifies this video's pink backdrop, including enclosed hand gaps.
    hsv=cv2.cvtColor(a,cv2.COLOR_RGB2HSV)
    return ~((hsv[:,:,0]>=145)&(hsv[:,:,0]<=179)&(hsv[:,:,1]>=40)&(a[:,:,0]>a[:,:,1]*1.22)&(a[:,:,0]>a[:,:,2]*1.10))

def compose(donor, base):
    donor=donor.convert("RGB")
    base=base.convert("RGB")
    arr=np.array(donor)
    mask=Image.new('L',donor.size)
    d=ImageDraw.Draw(mask)
    # Shoulder/cape transition, raised sleeve and palm from the same reference.
    d.polygon([(341,407),(360,398),(387,382),(417,391),(454,405),
               (507,411),(539,399),(575,351),(625,354),(640,387),
               (638,452),(594,473),(525,487),(474,488),(430,474),
               (395,451),(367,446),(347,430)],fill=255)
    # Replace the old hanging far arm and its overlap with the right torso/cape.
    d.polygon([(391,450),(399,468),(408,508),(420,541),(418,556),
               (426,597),(431,638),(429,708),(563,708),(563,462)],fill=255)
    mask=mask.filter(ImageFilter.GaussianBlur(1.1))

    template=arr[411:431,346:367]
    target=np.array(base)
    search=target[394:450,324:412]
    match=cv2.matchTemplate(search,template,cv2.TM_CCOEFF_NORMED)
    _,score,_,position=cv2.minMaxLoc(match)
    dx=position[0]+324-346;dy=position[1]+394-411
    # The donor background is remapped to the target's local background;
    # character pixels retain their source RGB without color grading.
    original_bg=~foreground(arr)
    corrected=arr.copy()
    for y in range(arr.shape[0]):
        ty=min(max(y+dy,0),target.shape[0]-1)
        color=np.median(target[ty,660:706],axis=0)
        donor_color=np.median(arr[y,660:706],axis=0)
        delta=color-donor_color
        corrected[y,original_bg[y]]=np.clip(arr[y,original_bg[y]].astype(float)+delta,0,255).astype(np.uint8)
    shifted=Image.fromarray(corrected).transform(donor.size,Image.Transform.AFFINE,(1,0,-dx,0,1,-dy),Image.Resampling.NEAREST)
    shifted_mask=mask.transform(donor.size,Image.Transform.AFFINE,(1,0,-dx,0,1,-dy),Image.Resampling.NEAREST)
    composed=Image.composite(shifted,base,shifted_mask)
    # Keep the original moving trousers in front of the borrowed far-side cape.
    hsv=cv2.cvtColor(target,cv2.COLOR_RGB2HSV)
    trousers=((hsv[:,:,0]>=95)&(hsv[:,:,0]<=125)&(hsv[:,:,1]<=150)&
              (hsv[:,:,2]>=25)&(hsv[:,:,2]<=210)).astype(np.uint8)
    trousers[:638]=0;trousers[735:]=0;trousers[:,:270]=0;trousers[:,510:]=0
    trousers=cv2.dilate(trousers,np.ones((7,7),np.uint8))
    trousers[:638]=0
    composed=Image.composite(base,composed,Image.fromarray(trousers*255))
    return composed

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    recipe=json.loads((ROOT/'artifacts/sources/player_actions/novice_128/composition/recipe.json').read_text(encoding='utf-8'))
    donor=Image.open(ROOT/recipe['donor'])
    args.output.mkdir(parents=True,exist_ok=True)
    for i,row in enumerate(recipe['frames']):
        result=compose(donor,Image.open(ROOT/row['source']))
        expected=Image.open(ROOT/row['output']).convert('RGB')
        assert result.tobytes()==expected.tobytes(),row['output']
        result.save(args.output/f'{i:02d}.png')
    print('MOVING_CAST_COMPOSITION_PASS 8')
