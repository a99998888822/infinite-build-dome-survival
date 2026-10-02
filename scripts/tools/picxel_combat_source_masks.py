from pathlib import Path
import numpy as np
from scipy import ndimage as nd
from scipy.spatial import ConvexHull
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'artifacts/sources/character_frames'

def poly(shape,points):
    im=Image.new('L',shape);ImageDraw.Draw(im).polygon(points,fill=255)
    return np.asarray(im)>0

WALK=[(370,18),(408,28),(430,89),(422,140),(445,133),(468,164),(491,168),(511,228),(558,196),(605,250),(612,364),(580,525),(541,649),(511,649),(476,613),(464,660),(479,696),(440,713),(278,711),(264,683),(272,645),(207,625),(192,604),(159,612),(131,574),(139,550),(128,511),(119,479),(152,434),(195,430),(194,389),(189,333),(207,274),(211,207),(221,165),(271,131),(280,104),(317,134),(319,77),(340,38)]
ATTACK=[(398,19),(423,67),(421,124),(449,122),(496,149),(518,181),(596,210),(644,320),(650,441),(643,525),(618,623),(578,604),(508,556),(514,650),(542,687),(535,710),(417,716),(389,684),(372,643),(307,648),(287,687),(266,714),(191,716),(185,686),(209,635),(225,535),(224,475),(260,388),(272,309),(269,251),(179,252),(132,244),(132,194),(147,152),(171,97),(126,102),(111,80),(117,60),(169,54),(194,47),(254,48),(268,65),(313,67),(327,20)]
SWING=[(448,120),(482,130),(507,194),(514,220),(549,220),(586,275),(617,385),(632,566),(631,647),(589,666),(555,644),(502,657),(542,690),(534,715),(400,711),(392,678),(388,614),(313,640),(278,622),(258,649),(257,686),(231,716),(181,716),(177,686),(204,615),(216,530),(235,445),(264,380),(280,318),(291,218),(328,190),(395,173),(410,144)]
LIFT=[(214,1),(258,12),(277,32),(310,42),(327,49),(356,80),(366,112),(372,85),(415,51),(449,69),(468,120),(461,146),(490,173),(520,197),(548,191),(579,218),(623,234),(648,336),(674,457),(673,584),(662,636),(605,585),(514,449),(505,588),(509,651),(537,699),(512,709),(416,705),(390,642),(305,652),(281,699),(191,716),(187,687),(211,643),(229,523),(233,475),(270,397),(286,355),(282,303),(270,264),(249,241),(181,222),(163,194),(165,152),(190,120),(211,74),(229,64),(233,49),(197,23)]

def boss(image,group,index):
    arr=np.asarray(image.convert('RGB')).astype(float)
    h,w=arr.shape[:2]; yy,xx=np.indices((h,w))
    left=np.median(arr[:,5:85],axis=1);right=np.median(arr[:,665:710],axis=1)
    # Smooth the reference background vertically, excluding tiny footer labels.
    left=nd.median_filter(left,size=(51,1));right=nd.median_filter(right,size=(51,1))
    bg=left[:,None,:]+(right-left)[:,None,:]*np.clip((xx[:,:,None]-45)/640,0,1)
    distance=np.sqrt(((arr-bg)**2).sum(axis=2))
    shape=WALK if group=='boss_walk' else ATTACK if index<=6 else LIFT if index==7 else SWING
    allowed=poly((w,h),shape)
    allowed |= (yy>=610)&(yy<712)&(xx>180)&(xx<558)
    if group=='boss_attack' and index==6:
        allowed |= poly((w,h),[(139,23),(272,29),(333,63),(330,110),(261,86),(192,83),(132,58)])
    candidate=(distance>10)&allowed
    candidate=nd.binary_closing(candidate,iterations=2)
    labels,n=nd.label(candidate); sizes=np.bincount(labels.ravel());sizes[0]=0
    mask=labels==sizes.argmax()
    mask=nd.binary_fill_holes(mask)
    # Foot plates are convex at this resolution. Recover their dark interiors
    # from connected source highlights, without retaining the floor shadow.
    feet=(yy>=610)&(yy<710)&(xx>185)&(xx<553)&(np.max(arr-bg,axis=2)>9)
    connected=nd.binary_dilation(feet,iterations=4)
    labels,_=nd.label(connected)
    footmask=np.zeros_like(mask)
    for label in range(1,labels.max()+1):
        y,x=np.where(feet&(labels==label))
        if len(x)<100: continue
        points=np.column_stack((x,y))
        if np.ptp(x)<3 or np.ptp(y)<3:continue
        hull=ConvexHull(points)
        footmask |= poly((w,h),[tuple(p) for p in points[hull.vertices]])
    mask[yy>=642]=footmask[yy>=642]
    if group=='boss_attack':
        mask |= candidate & (yy>=642)&(yy<657)&(xx>295)&(xx<410)
    if group=='boss_attack' and index==6:
        top=poly((w,h),[(145,25),(161,27),(209,40),(237,34),(263,46),(274,64),(332,81),(329,102),(265,84),(203,69),(166,56),(147,64),(132,52),(133,39)])
        top |= poly((w,h),[(336,47),(370,40),(382,45),(397,38),(417,58),(423,91),(329,105)])
        mask[yy<70] &= top[yy<70]
    # Keep the lower cape darker than the blue backdrop, but remove cast shadow.
    mask &= allowed
    components,_=nd.label(mask)
    areas=np.bincount(components.ravel());areas[0]=0
    mask &= areas[components]>90
    # Preserve only the saturated source light, not its dark rectangular backdrop.
    if group=='boss_attack' and index>=8:
        effect=(arr[:,:,2]-arr[:,:,0]>75)&(arr[:,:,2]>150)&(arr[:,:,1]>75)
        effect &= ~poly((w,h),[(0,0),(155,0),(155,55),(0,55)])
        mask |= effect
    result=image.convert('RGBA');result.putalpha(Image.fromarray((mask*255).astype('uint8')))
    return result,distance

def beginner(image):
    rgb=np.asarray(image.convert('RGB')).astype(np.int16)
    lo,hi=rgb.min(2),rgb.max(2)
    yy,xx=np.indices(lo.shape)
    background=(lo>200)&(hi-lo<27)
    background |= (yy>840)&(lo>94)&(hi-lo<14)
    foreground=~background
    foreground &= (yy>20)&(xx>90)&(xx<665)
    labels,_=nd.label(foreground);areas=np.bincount(labels.ravel());areas[0]=0
    main=labels==areas.argmax()
    # The closed source outlines enclose the pale shirt and steel blade.
    mask=nd.binary_fill_holes(main)
    result=image.convert('RGBA');result.putalpha(Image.fromarray((mask*255).astype('uint8')))
    return result


def enemy(image):
    rgb=np.asarray(image.convert('RGB')).astype(np.int16)
    lo=rgb.min(2)
    yy,xx=np.indices(lo.shape)
    foreground=(lo<123)&(xx>130)&(xx<600)&(yy>25)&(yy<700)
    labels,_=nd.label(foreground);areas=np.bincount(labels.ravel());areas[0]=0
    mask=nd.binary_fill_holes(labels==areas.argmax())
    result=image.convert('RGBA');result.putalpha(Image.fromarray((mask*255).astype('uint8')))
    return result
