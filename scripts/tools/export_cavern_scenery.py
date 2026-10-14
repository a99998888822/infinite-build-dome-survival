"""Export supplied, reviewed artwork locally; no image generation or source edits.

Requires the extracted archive and V06 review under artifacts/analysis. Runtime
exports are checked in, so the game does not depend on this local input folder.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage
import cavern_image_processing as art

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'artifacts/analysis/battle_scene_20261012'
OUT = ROOT / 'assets/sprites/background/cavern'
OUT.mkdir(parents=True, exist_ok=True)
NEAR = Image.Resampling.NEAREST

art.SOURCES = {p.name: p for p in (REVIEW / 'sucai').rglob('*.png')}
scope = {name:getattr(art,name) for name in ['read','crop_prop','grade','scene_material']}

def save(im, name):
    im.convert('RGBA').save(OUT / (name + '.png'))
    return 'res://assets/sprites/background/cavern/' + name + '.png'

config = {'ground': [], 'details': [], 'rubble': [], 'grass': [], 'ruins': [], 'props': [], 'foreground': [],
          'ground_texture_density': 1,
          'parallax': {'ground': 1.0, 'ruins': .26, 'cavern': .08},
          'method': 'Solid source-colour floor, complete catalog 01, source-derived cracks, rubble and existing grass; exterior-connected cutouts; no image model.'}

def complete_reference_ground(row):
    # Full authored silhouette and original RGB; calibrated tilt applied once.
    raw = Image.open(REVIEW / 'imports/background_new_20261013/background_new' / row['source']).convert('RGBA')
    raw = raw.crop(tuple(row['crop_box']))
    # Reviewed holes in this exact source's saturated magenta backing, in crop
    # coordinates. They are gaps around stones, not grey rock faces. Keep this
    # source-specific list out of the generic exterior-only cutout operation.
    holes = [(1518,20),(1580,88),(2184,110),(1184,116),(2610,128),(1358,134),
             (2416,146),(1302,156),(2528,156),(912,168),(2500,172),(2544,172),
             (2224,282),(284,446),(350,450),(291,454),(270,467),(333,470),
             (412,488),(281,595),(376,630),(2440,636),(2521,700),(416,702),
             (2188,712),(2190,715),(2468,731),(2462,746),(2450,752),(2396,758),
             (2238,764),(2400,770),(2238,779),(2482,779),(2492,783),(1954,803),
             (1819,840),(2387,842),(2387,844),(1170,880),(976,900),(1756,924),
             (1758,924),(1760,924),(562,930),(924,958)]
    raw = art.remove_back(raw,'magenta',holes)
    width = 1376
    im = raw.resize((width,round(raw.height*width/raw.width*row['relative_y_correction'])),NEAR)
    pixels = np.array(im)
    rgb = pixels[:,:,:3].astype(np.int16)
    # Remove the one-pixel matte fringe left by the magenta source. This is
    # a binary cutout cleanup, never a feather or an RGB blur.
    outside = np.zeros(pixels.shape[:2],bool)
    outside[0] = pixels[0,:,3]==0
    outside[-1] = pixels[-1,:,3]==0
    outside[:,0] |= pixels[:,0,3]==0
    outside[:,-1] |= pixels[:,-1,3]==0
    outside = ndimage.binary_propagation(outside,mask=pixels[:,:,3]==0)
    pixels[ndimage.binary_dilation(outside,structure=np.ones((3,3))),3] = 0
    im = Image.fromarray(pixels)
    opaque = pixels[:,:,3]>0
    colors,counts = np.unique(rgb[opaque],axis=0,return_counts=True)
    config['floor_color'] = [int(v)/255.0 for v in colors[counts.argmax()]]+[1.0]
    moss = opaque & (rgb[:,:,1]-rgb[:,:,2]>15) & (rgb[:,:,1]-rgb[:,:,0]>5)
    ys,xs = np.nonzero(moss)
    anchors = []
    for u,v in [(.12,.34),(.25,.74),(.42,.21),(.56,.54),(.74,.69),(.86,.36),(.85,.86),(.40,.89)]:
        nearest = ((xs-u*im.width)**2+(ys-v*im.height)**2).argmin()
        anchors.append([int(xs[nearest])-im.width*.5,int(ys[nearest])-im.height*.5])
    config['grass_anchors'] = anchors
    return im

def export_ground_details(im):
    # Isolate authored crack/chip contours at the already calibrated tilt. No
    # resize, erosion, blur or new colour. Transparent space replaces the base.
    pixels = np.array(im)
    dark = (pixels[:,:,3]>0) & (pixels[:,:,:3].mean(2)<62)
    labels,_ = ndimage.label(dark)
    for i,box in enumerate([(636,60,721,99),(913,62,1005,88),(568,84,620,106),
                            (802,85,879,108),(718,127,779,151),(1028,150,1090,175)]):
        x0,y0,x1,y1 = box
        region = labels[y0:y1,x0:x1]
        counts = np.bincount(region.ravel())
        counts[0] = 0
        selected = labels==int(counts.argmax())
        part = pixels.copy()
        part[~selected,3] = 0
        cut = Image.fromarray(part)
        cut = cut.crop(cut.getchannel('A').getbbox())
        config['details'].append({'id':'reference_crack_'+str(i),
                                  'texture':save(cut,'detail_crack_'+str(i)),
                                  'source':'reference_moss_full','scale':1})
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
manifest = json.loads((REVIEW / 'preview_v06/new_ground_manifest.json').read_text(encoding='utf-8'))
for row in manifest:
    if row['catalog_number'] != 1: continue
    original = complete_reference_ground(row)
    export_ground_details(original)
    config['ground'].append({'id': row['material'], 'textures': [save(original,'reference_moss_full')],
                             'catalog_number': row['catalog_number'],
                             'source_sha256': row['source_sha256'],
                             'relative_y_correction': row['relative_y_correction']})

for name in ['G09_grass_short-32','G10_grass_dense-32','G11_grass_long-32']:
    source = ROOT/'assets/sprites/background/green_ground'/(name+'.png')
    im = Image.open(source).convert('RGBA')
    im = im.crop(im.getchannel('A').getbbox())
    config['grass'].append({'id':name,'texture':save(im,'grass_'+name[4:-3]),
                            'source':'res://assets/sprites/background/green_ground/'+name+'.png'})

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
(ROOT/'data_config/cavern_battlefield.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'exports':len(list(OUT.glob('*.png'))),'ground_materials':len(config['ground'])}))
