"""Export source-derived cavern candidates; current approved PNGs are unchanged.

This preserves the original crop recipe. Later approved pixel edits remain in
the current PNG/PXG files; this is not a byte-exact rebuild of those edits.
"""
from pathlib import Path
import argparse,json
import numpy as np
from PIL import Image
from scipy import ndimage
import cavern_image_processing as art
ROOT=Path(__file__).resolve().parents[2]
REVIEW=ROOT/'artifacts/sources/cavern'

def export(output):
    OUT=Path(output).resolve()
    assert not OUT.is_relative_to(ROOT/'assets'), 'Use a separate candidate directory'
    OUT.mkdir(parents=True,exist_ok=True)
    NEAR = Image.Resampling.NEAREST

    art.SOURCES = {p.name: p for p in REVIEW.rglob('*.png')}
    scope = {name:getattr(art,name) for name in ['read','crop_prop','grade','scene_material']}

    def save(im, name):
        im.convert('RGBA').save(OUT / (name + '.png'))
        return 'res://assets/sprites/background/cavern/' + name + '.png'

    config = {'ground': [], 'details': [], 'rubble': [], 'grass': [], 'ruins': [], 'props': [], 'foreground': [],
              'ground_texture_density': 1,
              'method': 'Solid source-colour floor, complete catalog 01, source-derived cracks, rubble and existing grass; exterior-connected cutouts; no image model.'}

    def aligned_panorama():
        """Isolate five complete openings; repair clipped tops with sampled rock.

        All openings share a 12..90px vertical register. Crops retain their aspect
        ratio, with 105..135px of dark wall between them instead of edge-to-edge art.
        """
        void = np.array([21,16,28],dtype=np.float32)
        modules = []
        alignment = []
        for index, box, gap in [
            (1,(.07,.07,.91,.88),115), (5,(.14,0,.88,.63),135),
            (3,(.18,0,.76,.67),120), (2,(.48,.03,.87,.64),105),
            (4,(.38,.12,.88,.63),125)]:
            source = scope['read'](f'far_background_{index}.png')
            source = source.crop(tuple(round(box[i]*(source.width if i%2==0 else source.height)) for i in range(4)))
            a = np.array(source).astype(np.float32)
            # The original outer purple is background, not part of the opening.
            bg = np.median(np.concatenate([a[-24:,:,:3].reshape(-1,3),a[:,:12,:3].reshape(-1,3)]),axis=0)
            luminance = a[:,:,:3] @ np.array([.2126,.7152,.0722])
            active = luminance > float(bg @ np.array([.2126,.7152,.0722]))+8
            ys,xs = np.nonzero(active)
            if len(xs): source = source.crop((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))
            source = scope['grade'](source,.80,.60)
            width = round(source.width*78/source.height)
            source = source.resize((width,78),NEAR)
            a = np.array(source).astype(np.float32)
            # Complete cut upper edges with a shallow, irregular arch cap, using
            # dark rock tones sampled from each source rather than a hard crop line.
            y,x = np.mgrid[0:78,0:width]
            u = np.abs((x-(width-1)/2)/max(1,width/2))
            cap = 3 + 12*u**2 + 2*np.sin(x/9+index)
            floor = 76 - 3*np.sin(x/13+index)**2
            edge = np.clip((y-cap)/5,0,1)*np.clip((floor-y)/5,0,1)
            edge *= np.clip(x/12,0,1)*np.clip((width-1-x)/12,0,1)
            base = np.percentile(a[:,:,:3].reshape(-1,3),15,axis=0)
            rgb = np.clip(a[:,:,:3]-base+void,0,255)
            a[:,:,:3] = void+(rgb-void)*edge[:,:,None]
            a[:,:,3] = 255
            module = Image.fromarray(a.astype('uint8'))
            modules.append((module,gap))
            alignment.append({'source':f'far_background_{index}.png','crop':box,
                              'opening_top':12,'opening_bottom':90,'width':width,'wall_gap':gap,
                              'repair':'source-colour rocky cap and blended outer wall'})
        strip = Image.new('RGBA',(sum(im.width+gap for im,gap in modules),103),tuple(void.astype(int))+(255,))
        cursor = 0
        for im,gap in modules:
            strip.alpha_composite(im,(cursor+gap//2,12))
            cursor += im.width+gap
        config['panorama_modules'] = alignment
        return strip.resize((strip.width*2,206),NEAR)

    config['panorama'] = save(aligned_panorama(), 'panorama_aligned')
    for name, box, height, brightness in [
        ('arch', (.52,.52,.96,.97), 54, .58),
        ('pillar', (.60,.03,.89,.47), 46, .46),
        ('obelisk', (.12,.04,.38,.46), 37, .46),
        ('lamp', (.12,.53,.38,.94), 39, .60)]:
        im = scope['crop_prop']('ground_view1 (6).png', box)
        im = scope['grade'](im, brightness, .7)
        display_size = [round(im.width*height/im.height),height]
        im = im.resize((display_size[0]*4,height*4), NEAR)
        a = np.array(im)
        a[:,:,3] = (a[:,:,3] * np.clip((im.height-1-np.arange(im.height))[:,None]/24,0,1)).astype('uint8')
        config['ruins'].append({'id': name, 'texture': save(Image.fromarray(a), 'ruin_'+name),'display_size':display_size})

    for name, source, box, width, material in [
        ('rock','ground_Barier1.png',(.035,.025,.465,.335),75,'stone'),
        # Stay inside the sheet's black separator lines; they are not the backing.
        ('log','ground_wood1.png',(.01,.51,.49,.74),69,'wood')]:
        im = scope['scene_material'](scope['crop_prop'](source,box),material)
        im = im.resize((width,round(im.height*width/im.width)),NEAR)
        im = art.outline_exterior(im)
        config['props'].append({'id':name,'texture':save(im,'prop_'+name)})

    for i,box in enumerate([(.613,.894,.69,.95),(.691,.905,.741,.951)]):
        im = scope['scene_material'](art.loose_stone_source(i),'stone')
        im = im.resize([(100,56),(64,44)][i],NEAR)
        config['rubble'].append({'id':'loose_stone_'+str(i),'texture':save(im,'rubble_'+str(i)),'texture_density':4.0})

    front = art.remove_back(scope['read']('front_view1.png'),'checker')
    # The source has four large corner masses. Remove only isolated checker
    # compression specks, never any connected pixels within those rock masses.
    a = np.array(front)
    labels,_ = ndimage.label(a[:,:,3]>0)
    sizes = np.bincount(labels.ravel())
    a[(labels>0)&(sizes[labels]<256),3] = 0
    front = Image.fromarray(a)
    for i, (box, width, corner, edge_offset) in enumerate([
        ((0,0,850,590),228,(0,0),(0,0)),
        ((2030,0,2752,590),207,(1,0),(0,0)),
        ((0,570,1170,1536),270,(0,1),(-4,4)),
        ((1670,700,2752,1536),280,(1,1),(4,4))]):
        im = front.crop(box)
        display_size = [(114,79),(104,85),(135,111),(140,108)][i]
        # Keep the cropped outer edges attached to their original screen corners.
        # The HUD overlays this frame; do not shift corner art to dodge the HUD.
        offset = [edge_offset[j]-corner[j]*display_size[j] for j in range(2)]
        config['foreground'].append({'texture':save(im,'foreground_'+str(i)),
                                     'corner':list(corner),'offset':offset,'display_size':list(display_size)})
    (OUT/'cavern_battlefield.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'exports':len(list(OUT.glob('*.png'))),'ground_materials':len(config['ground'])}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    export(parser.parse_args().output)
