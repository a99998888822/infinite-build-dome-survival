"""One-source, non-destructive high-res-to-pixel-art review pipeline.

The source-specific background seeds apply to the unnumbered supplied portrait.
They must be checked before reusing this mask on other expressions.
"""
from pathlib import Path
import argparse
import hashlib
import json
import tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / 'artifacts/previews/goblin_reprint'
OUT = SOURCE_DIR / 'pixel_review'
TEMP = Path(tempfile.gettempdir()) / 'codex-goblin-pixel-review'
INK = np.array([18, 25, 28], dtype=np.uint8)


def extract(source):
    rgb = np.asarray(source.convert('RGB'))
    a = rgb.astype(np.int16)
    paper = (a.min(2) > 168) & ((a.max(2)-a.min(2)) < 65) & (a[:,:,0] >= a[:,:,1]-8)
    seeds = np.zeros(paper.shape, bool)
    seeds[[0,-1],:] = paper[[0,-1],:]
    seeds[:,[0,-1]] = paper[:,[0,-1]]
    # These enclosed paper regions are the gaps inside the two bent arms.
    for x,y in [(500,1190),(1090,1220)]:
        assert paper[y,x], 'Recheck the source-specific enclosed-background seed'
        seeds[y,x] = True
    outside = ndi.binary_propagation(seeds, mask=paper)
    mask = ~outside
    labels,_ = ndi.label(mask)
    counts=np.bincount(labels.ravel());counts[0]=0
    mask=labels==counts.argmax()
    # The bottom strip contains green hands and a neutral shadow cast on the
    # original tabletop. Retain skin and gold, including their dark contour.
    green=(a[:,:,1]-a[:,:,2]>19)&(a[:,:,0]-a[:,:,2]>8)&(a[:,:,1]>50)&(a[:,:,1]-a[:,:,0]>-30)
    hand=ndi.binary_fill_holes(ndi.binary_closing(green,iterations=3))
    hand=ndi.binary_dilation(hand,iterations=4)
    mask[1356:,:] &= hand[1356:,:]
    labels,_=ndi.label(mask)
    counts=np.bincount(labels.ravel());counts[0]=0
    mask=labels==counts.argmax()
    rgba=np.dstack((rgb,mask.astype(np.uint8)*255))
    rgba[~mask,:3]=0
    return Image.fromarray(rgba)


def normalize(highres, size, factor=4):
    crop=highres.crop(highres.getbbox())
    width,height=size
    # Keep the entire tall hat, ears and fingers; never stretch into the frame.
    margin=max(3,round(height*0.036))*factor
    scale=min((width*factor-2*margin)/crop.width,(height*factor-2*margin)/crop.height)
    scaled=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
    frame=Image.new('RGBA',(width*factor,height*factor))
    position=((frame.width-scaled.width)//2,frame.height-margin-scaled.height)
    frame.alpha_composite(scaled,position)
    return frame


def bilateral(frame):
    a=np.asarray(frame).astype(np.float32)
    rgb,alpha=a[:,:,:3],a[:,:,3]/255.0
    result=np.zeros_like(rgb);total=np.zeros_like(alpha)
    radius=2
    p=np.pad(rgb,((radius,radius),(radius,radius),(0,0)),mode='edge')
    ap=np.pad(alpha,radius,mode='constant')
    h,w=alpha.shape
    for dy in range(-radius,radius+1):
        for dx in range(-radius,radius+1):
            sample=p[radius+dy:radius+dy+h,radius+dx:radius+dx+w]
            valid=ap[radius+dy:radius+dy+h,radius+dx:radius+dx+w]
            distance=((sample-rgb)**2).sum(2)
            weight=np.exp(-distance/(2*24.0**2)-(dx*dx+dy*dy)/(2*1.5**2))*valid
            result+=sample*weight[:,:,None];total+=weight
    a[:,:,:3]=result/np.maximum(total[:,:,None],1e-5)
    a[alpha==0,:3]=0
    return Image.fromarray(np.clip(a,0,255).astype('uint8'))


def build_palette(frames):
    pixels=[]
    for frame in frames:
        a=np.asarray(frame)
        valid=a[:,:,3]>=128
        colors=a[:,:,:3][valid]
        # Preserve additional skin and brass shades despite the large dark coat.
        salient=(colors[:,1].astype(int)-colors[:,2]>20)&(colors[:,0]>50)
        pixels.extend([colors,colors[salient]])
    colors=np.concatenate(pixels)
    rgb=colors.astype(int)
    # Reserve colors by material. Otherwise the large black hat and coat use
    # most of an adaptive palette and the brass monocle becomes muddy green.
    gold=(rgb[:,0]-rgb[:,1]>12)&(rgb[:,0]-rgb[:,2]>24)
    ivory=(rgb.min(1)>100)&((rgb.max(1)-rgb.min(1))<40)&~gold
    skin=(rgb[:,1]-rgb[:,2]>15)&(rgb[:,1]>=rgb[:,0]-12)&(rgb[:,0]>45)&~gold&~ivory
    cloth=~(gold|ivory|skin)
    palette=[]
    for mask,count in [(skin,12),(gold,6),(ivory,4),(cloth,9)]:
        training=Image.fromarray(colors[mask].reshape(1,-1,3))
        quantized=training.quantize(colors=count,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
        palette.extend(np.array(quantized.getpalette()[:count*3],dtype='uint8').reshape(-1,3))
    return np.array(palette,dtype='uint8')


def palette_map(rgb,palette):
    # A luma-weighted RGB distance keeps the dark suit separated from green skin.
    diff=rgb.astype(np.float32)[:,:,None,:]-palette.astype(np.float32)[None,None,:,:]
    return (diff[:,:, :,0]**2*.30+diff[:,:,:,1]**2*.59+diff[:,:,:,2]**2*.11).argmin(2)


def clean_clusters(indices,alpha,palette):
    output=indices.copy();changes=0
    h,w=alpha.shape
    # Protect face/monocle, hands and high-contrast metal details.
    yy,xx=np.mgrid[:h,:w]
    protected=((yy>=h*.32)&(yy<=h*.58)&(xx>=w*.30)&(xx<=w*.68)) | (yy>=h*.83)
    color=palette[indices].astype(int)
    protected |= (color[:,:,0]-color[:,:,2]>36)&(color[:,:,0]>125)
    interior=ndi.binary_erosion(alpha,iterations=1)
    for y,x in zip(*np.where(interior&~protected)):
        block=indices[y-1:y+2,x-1:x+2].ravel()
        own=indices[y,x]
        if np.count_nonzero(block==own)>2:
            continue
        counts=np.bincount(block,minlength=len(palette));mode=counts.argmax()
        difference=np.linalg.norm(palette[own].astype(float)-palette[mode])
        if counts[mode]>=5 and difference<48:
            output[y,x]=mode;changes+=1
    return output,changes


def finish(frame,size,palette):
    reduced=bilateral(frame).resize(size,Image.Resampling.LANCZOS)
    a=np.asarray(reduced).copy()
    alpha=a[:,:,3]>=128
    # Remove disconnected subpixel remnants without touching the main silhouette.
    labels,n=ndi.label(alpha)
    counts=np.bincount(labels.ravel());counts[0]=0
    removed=int(np.sum(alpha&~(labels==counts.argmax())))
    alpha=labels==counts.argmax()
    indices=palette_map(a[:,:,:3],palette)
    indices,changes=clean_clusters(indices,alpha,palette)
    rgb=palette[indices]
    # One native pixel, four-neighbour outline: no blur and no alpha fringe.
    outline=ndi.binary_dilation(alpha,structure=ndi.generate_binary_structure(2,1))&~alpha
    rgb[outline]=INK
    visible=alpha|outline
    rgb[~visible]=0
    output=Image.fromarray(np.dstack((rgb,visible.astype('uint8')*255)))
    colors=np.unique(rgb[visible],axis=0)
    return output,{'size':list(size),'opaque_colors':len(colors),'merged_color_specks':changes,'removed_disconnected_pixels':removed,
                   'alpha_values':np.unique(np.asarray(output)[:,:,3]).tolist(),'bbox':list(output.getbbox())}


def font(size,bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc' if bold else 'C:/Windows/Fonts/msyh.ttc',size)


def review(source,primary,detail,palette):
    board=Image.new('RGBA',(1800,1080),'#202925');d=ImageDraw.Draw(board)
    d.text((48,32),'高清原图 → 像素艺术试样',font=font(40,True),fill='#eee6cc')
    d.text((50,94),'默认表情单张试处理 · 透明背景 · 无抖动限色 · 细碎色点清理 · 1px外轮廓',font=font(22),fill='#acb99f')
    columns=[(32,'原图 1536×1536'),(620,'128×112 · 当前单帧规格'),(1208,'192×168 · 细节对照')]
    for x,title in columns:
        d.rounded_rectangle((x,150,x+560,770),radius=12,fill='#3b473d',outline='#65715a',width=2)
        d.text((x+22,174),title,font=font(25,True),fill='#e1d5b0')
    original=source.copy();original.thumbnail((510,510),Image.Resampling.LANCZOS)
    board.alpha_composite(original.convert('RGBA'),(57+(510-original.width)//2,230))
    p=primary.resize((512,448),Image.Resampling.NEAREST)
    board.alpha_composite(p,(644,265))
    # Integer scaling is mandatory in review: do not resample pixel art to fit.
    q=detail.resize((576,504),Image.Resampling.NEAREST)
    board.alpha_composite(q,(1200,240))
    d.text((660,725),'4倍最近邻放大',font=font(21),fill='#bac4aa')
    d.text((1240,725),'3倍最近邻放大',font=font(21),fill='#bac4aa')
    d.text((48,805),'原尺寸检查',font=font(26,True),fill='#e1d5b0')
    for x,bg in [(290,'#18231f'),(470,'#dedbc5')]:
        d.rectangle((x,805,x+155,957),fill=bg)
        board.alpha_composite(primary,(x+14,826))
    d.text((296,972),'128×112 深底',font=font(18),fill='#b2bfa7')
    d.text((476,972),'128×112 浅底',font=font(18),fill='#b2bfa7')
    d.rectangle((670,795,900,987),fill='#18231f')
    board.alpha_composite(detail,(689,807))
    d.text((674,1000),'192×168 原尺寸',font=font(18),fill='#b2bfa7')
    d.text((996,815),'同一套色板 · 最多32种不透明颜色',font=font(23),fill='#e1d5b0')
    for i,color in enumerate(np.vstack((palette,INK))):
        x=998+(i%16)*44;y=870+(i//16)*44
        d.rectangle((x,y,x+35,y+35),fill=tuple(color.tolist()))
    d.text((996,985),'审阅试样，尚未替换正式游戏素材。',font=font(21),fill='#b2bfa7')
    board.convert('RGB').save(OUT/'comparison.png')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path)
    args=parser.parse_args()
    source_path=args.source or min(SOURCE_DIR.glob('*.png'),key=lambda p:len(p.name))
    original_hash=hashlib.sha256(source_path.read_bytes()).hexdigest()
    source=Image.open(source_path).convert('RGB')
    assert source.size==(1536,1536),'Recheck masking coordinates for this source size'
    OUT.mkdir(exist_ok=True);TEMP.mkdir(exist_ok=True)
    highres=extract(source)
    highres.save(TEMP/'extracted.png')
    sizes=[(128,112),(192,168)]
    frames=[normalize(highres,size) for size in sizes]
    palette=build_palette([f.resize(size,Image.Resampling.LANCZOS) for f,size in zip(frames,sizes)])
    report={'source':source_path.relative_to(ROOT).as_posix(),'source_sha256':original_hash,'source_size':list(source.size),
            'mode':'deterministic postprocessing of supplied art; no image generation',
            'mask':'border-connected paper, two arm-gap seeds, skin-guided lower hand mask',
            'dithering':False,'maximum_colors':32,'outline_native_pixels':1,'outputs':{}}
    outputs=[]
    for frame,size in zip(frames,sizes):
        result,stats=finish(frame,size,palette)
        name=f'goblin_idle_{size[0]}x{size[1]}.png'
        result.save(OUT/name)
        report['outputs'][name]=stats
        outputs.append(result)
        assert stats['alpha_values']==[0,255] and stats['opaque_colors']<=32
        box=stats['bbox'];assert box[0]>0 and box[1]>0 and box[2]<size[0] and box[3]<size[1]
    review(source,*outputs,palette)
    (OUT/'palette.json').write_text(json.dumps(np.vstack((palette,INK)).tolist(),indent=2)+'\n',encoding='utf-8')
    assert hashlib.sha256(source_path.read_bytes()).hexdigest()==original_hash
    (OUT/'processing_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=True))


if __name__=='__main__':
    main()
