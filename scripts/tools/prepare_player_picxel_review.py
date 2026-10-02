"""Prepare supplied player art for Picxel with a fixed animation canvas.

Local background extraction and pixel conversion only. Runtime assets are never
written. Source poses are retained; this does not synthesize missing animation.
"""
from pathlib import Path
from argparse import ArgumentParser, Namespace
import hashlib
import json
import shutil
import sys

import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / '.agents/skills/picxel-external-images'
TASK = ROOT / 'artifacts/previews/player_picxel'
TEMP = Path('C:/Users/mi/AppData/Local/Temp/player-picxel-review')
SOURCE = ROOT / 'artifacts/sources/character_frames'
sys.path.insert(0, str(SKILL / 'scripts'))
import external_pixel as external

PALETTES = {
    'beginner': ['#252e2d', '#9b9987', '#b8b3a0', '#d4c9b3',
                 '#be9e88', '#ead1b9', '#f4e6d0', '#304e4b',
                 '#4e6d66', '#71928a', '#453a32', '#695544',
                 '#8a7258', '#78908d', '#c2cdca', '#53b7a4'],
    'capitalist': ['#11191f', '#202832', '#313b47', '#485260',
                   '#575b61', '#858786', '#b3b1a4', '#c0a797',
                   '#e6cabc', '#f4e5d6', '#315754', '#518b83',
                   '#8bc1b8', '#786b50', '#b7a37b', '#f2f0df'],
}


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def extract(image, character, frame):
    rgb = np.asarray(image.convert('RGB')).astype(np.int16)
    lo, hi = rgb.min(axis=2), rgb.max(axis=2)
    background = (lo > 200) & (hi - lo < 27)
    # The supplied floor shadows are neutral grey; boots and cane are dark or brown.
    yy, xx = np.indices(lo.shape)
    background |= (yy > 840) & (lo > 94) & (hi - lo < 14)
    foreground = ~background
    foreground[:20] = False
    foreground[:, :90] = False
    foreground[:, 650:] = False
    labels, count = ndimage.label(foreground)
    areas = np.bincount(labels.ravel()); areas[0] = 0
    main = labels == int(areas.argmax())
    filled = ndimage.binary_fill_holes(main)
    # Recover enclosed pale face/shirt regions; leave visible arm/leg gaps transparent.
    protect = (yy < 375)
    if character == 'beginner':
        protect |= (xx > 315) & (xx < 465) & (yy > 345) & (yy < 565)
        # Pale steel is not background. These source-specific blade polygons
        # were inspected separately for each pose; only enclosed holes refill.
        blades = {
            1: [(306,615),(340,633),(535,723),(566,768),(510,766),(296,666)],
            2: [(330,611),(358,627),(589,708),(626,744),(572,750),(319,660)],
            3: [(348,614),(389,626),(614,691),(654,733),(593,743),(338,668)],
            4: [(320,610),(357,626),(568,709),(609,753),(545,758),(308,667)],
            5: [(287,615),(327,627),(526,725),(561,776),(494,772),(280,670)],
            6: [(278,620),(322,640),(509,744),(545,794),(472,786),(265,675)],
        }
        blade = Image.new('L', image.size)
        ImageDraw.Draw(blade).polygon(blades[frame], fill=255)
        protect |= np.asarray(blade) > 0
    else:
        protect |= (xx > 325) & (xx < 450) & (yy > 345) & (yy < 480)
    mask = main | (filled & protect)
    alpha = Image.fromarray((mask * 255).astype('uint8'))
    result = image.convert('RGBA')
    result.putalpha(alpha)
    clean = Image.new('RGBA', image.size)
    clean.paste(result, (0, 0), alpha)
    return clean


def prepare():
    if (TASK / 'work/batch-report.json').exists():
        raise ValueError('Final task already exists; use the preserved inputs')
    for directory in ('refs', 'prepared'):
        (TASK / directory).mkdir(parents=True, exist_ok=True)
    TEMP.mkdir(parents=True, exist_ok=True)
    records = []
    cutouts = []
    folders = sorted(p for p in SOURCE.iterdir() if p.is_dir())
    assert len(folders) == 2
    for character, folder in zip(('beginner', 'capitalist'), folders):
        for path in sorted(folder.glob('*.png')):
            index = int(path.stem.rsplit('walk', 1)[1])
            name = f'{character}_walk{index:02d}'
            image = Image.open(path).convert('RGBA')
            assert image.size == (720, 960)
            cut = extract(image, character, index)
            box = cut.getbbox()
            head_box = cut.crop((0, 20, 720, 320)).getbbox()
            head_x = (head_box[0] + head_box[2]) / 2
            # Original pixels retain their scale. Same 18-source-pixel grid for all
            # combat frames; exactly 9 source pixels per showcase grid cell.
            offset = (round(576 - head_x), 1008 - box[3])
            prepared = Image.new('RGBA', (1152, 1152))
            prepared.alpha_composite(cut, offset)
            prepared.save(TASK / 'prepared' / f'{name}.png')
            reference = TASK / 'refs' / f'{name}.png'
            if not reference.exists():
                shutil.copyfile(path, reference)
            assert reference.read_bytes() == path.read_bytes(), 'Reference copy differs from source'
            beginner = character == 'beginner'
            source_face = [0.4, 0.19, 0.70, 0.37] if beginner else [0.40, 0.25, 0.69, 0.41]
            face_box = [(source_face[0]*720+offset[0])/1152,
                        (source_face[1]*960+offset[1])/1152,
                        (source_face[2]*720+offset[0])/1152,
                        (source_face[3]*960+offset[1])/1152]
            anchor = {
                'subject': 'Blond young adventurer with green cape and steel sword' if beginner else 'Young banker in dark suit, tall top hat, monocle and teal cane gem',
                'kind': 'sprite', 'size': 128, 'palette': PALETTES[character],
                'keep': ['Original three-quarter right-facing pose and proportions',
                         'Both hands, feet and held object stay complete',
                         'Blond bangs, teal eyes, green cape, leather boots and steel sword' if beginner else 'Tall hat, near-eye monocle, suit lapels, bow tie and cane',
                         'Uniform source scale, horizontal head anchor and planted-foot baseline'],
                'drop': ['Light studio background, cast floor shadow and detached footer', 'Subpixel fabric and hair texture'],
                'regions': [{'name': 'face', 'box': face_box, 'detail': 'fine'}],
                'faces': [{'box': face_box, 'complex': True,
                           'expression': 'Neutral focused expression with small closed mouth' if beginner else 'Calm half-lidded expression with small closed mouth',
                           'gaze': 'Eyes face image-right; teal irises sit under the upper lids, far eye partly occluded by bangs' if beginner else 'Head faces right; half-lidded pupils sit left/central within the iris, with sclera toward image-right; near eye visible through monocle',
                           'reason': 'Small eyes and dark upper lids require comparison after reduction'}],
                'original_face_box': source_face,
            }
            write(TASK / 'refs' / f'{name}.anchor.json', anchor)
            records.append({'name': name, 'character': character, 'frame': index,
                            'source': path.relative_to(ROOT).as_posix(),
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                            'source_bbox': box, 'source_head_center_x': head_x,
                            'translation': offset, 'prepared_canvas': [1152,1152],
                            'source_baseline_y': box[3], 'prepared_baseline_y': 1008})
            cutouts.append((name, cut))
    write(TASK / 'source-map.json', {'method': 'Observed light-background extraction, fixed source scale and translated animation anchors; Picxel palette majority voting',
                                   'image_model_used': False, 'records': records})
    board = Image.new('RGB', (7*224, 2*310), '#586c74')
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
    for record, (_, image) in zip(records, cutouts):
        col = record['frame']-1; row = 0 if record['character']=='beginner' else 1
        thumb=image.copy();thumb.thumbnail((212,270))
        board.paste(thumb,(col*224+(224-thumb.width)//2,row*310+8),thumb)
        draw.text((col*224+8,row*310+282),record['name'],font=font,fill='white')
    board.save(TEMP/'cutouts.png')
    print(json.dumps({'prepared':len(records),'cutout_review':str(TEMP/'cutouts.png')}))


def build(sample=False):
    if sample:
        base=TEMP/'sample_v2'
        for directory in ('refs','prepared'):
            (base/directory).mkdir(parents=True,exist_ok=True)
        for name in ('beginner_walk03','capitalist_walk07'):
            for ending in ('.png','.anchor.json'):
                shutil.copyfile(TASK/'refs'/(name+ending),base/'refs'/(name+ending))
            shutil.copyfile(TASK/'prepared'/(name+'.png'),base/'prepared'/(name+'.png'))
    else:
        base=TASK
    # Picxel's default per-image crop would change the frame origin and scale.
    # Keep this task's already aligned, integer-divisible high-resolution canvas.
    original_square = external.px._square
    def fixed_canvas(image, size):
        assert image.size == (1152,1152) and 1152 % size == 0
        return image
    external.px._square = fixed_canvas
    try:
        result = external.build(Namespace(refs=base/'refs',out=base/'work',
                                          prepared_dir=base/'prepared',sizes=[64,128],background='none'))
        if result == 0:
            refine_contours(base)
        return result
    finally:
        external.px._square=original_square


def refine_contours(base):
    report = external.read(base/'work/batch-report.json')
    source_map = {r['name']:r for r in external.read(TASK/'source-map.json')['records']}
    records = []
    for entry in report['jobs']:
        image = np.asarray(Image.open(base/'prepared'/(entry['name']+'.png')).convert('RGBA'))
        opaque = image[:,:,3] > 127
        lum = image[:,:,:3].astype(float) @ np.array([0.2126,0.7152,0.0722])
        lum[~opaque] = 255
        # Recover original narrow ink lines which plain colour-majority voting
        # loses. This follows source line evidence, not a generic face template.
        blackhat = ndimage.grey_closing(lum, size=(9,9)) - lum
        source_ink = (blackhat > 28) & (lum < 105) & opaque
        for size in (64,128):
            path = base/'work'/f"{entry['name']}-{size}.pxg"
            sheet = external.px.load(path)
            pixels = np.asarray(sheet.image().convert('RGBA')).copy()
            alpha = pixels[:,:,3] > 127
            block = 1152 // size
            ink_fraction = source_ink.reshape(size,block,size,block).mean(axis=(1,3))
            recover = (ink_fraction >= (0.085 if size==64 else 0.12)) & alpha
            # Hair, eyelids and monocle are reviewed separately. Broad automatic
            # line emphasis here would turn nearby eyelids into a black band.
            face_end = int((375 + source_map[entry['name']]['translation'][1]) / block) + 1
            recover[:face_end] = False
            character = entry['name'].split('_')[0]
            ink = np.array(tuple(int(PALETTES[character][0][i:i+2],16) for i in (1,3,5)))
            pixels[recover,:3] = ink
            # Add a single external contour before any eye refinement. Cardinal
            # dilation keeps sharp diagonal corners and does not blur RGB/alpha.
            outline = ndimage.binary_dilation(alpha) & ~alpha
            pixels[outline,:3] = ink
            pixels[outline,3] = 255
            palette = PALETTES[character]
            colors = {chr(65+i):c for i,c in enumerate(palette)}
            symbols = {tuple(int(c[i:i+2],16) for i in (1,3,5)):s for s,c in colors.items()}
            rows = [''.join(symbols[tuple(p[:3])] if p[3] else '.' for p in row) for row in pixels]
            refined_path = base/'work'/f"{entry['name']}-{size}-detail.pxg"
            refined = external.px.Sheet(refined_path.stem,size,'sprite',sheet.palette,colors,rows,refined_path)
            refined_path.write_text(refined.dump(),encoding='utf-8')
            errors,warnings=external.px.check(refined)
            assert not errors,errors
            external.px.render(refined,base/'work')
            records.append({'name':entry['name'],'size':size,'original_ink_cells':int(recover.sum()),
                            'external_contour_cells':int(outline.sum()),'warnings':warnings})
    write(base/'work/local-repairs.json',{'method':'Restore source narrow ink and one-pixel silhouette; before eye inspection; no post-face smoothing','records':records})
    refine_faces(base)
    review_details(base)


def refine_faces(base):
    report = external.read(base/'work/batch-report.json')
    # Coordinates are final-grid observations, with each original gaze checked
    # in the source face contact sheet. Never derive these from anchor fractions.
    beginner_eyes = {1:(18,18),2:(18,19),3:(19,20),4:(19,20),5:(19,20),6:(19,19)}
    capitalist_rims = {1:19,2:19,3:18,4:18,5:18,6:18,7:18}
    for entry in report['jobs']:
        name = entry['name']; frame = int(name[-2:])
        path = base/'work'/f'{name}-64-detail.pxg'
        sheet = external.px.load(path)
        anchor = external.px.load_anchor(base/'refs'/f'{name}.anchor.json')
        if name.startswith('beginner'):
            y,far_y = beginner_eyes[frame]
            patches = [
                {'face':0,'feature':'eye','box':[32,y-1,34,y+1],
                 'rows':['AAA','GAP','GPG'],'eyes':[{'box':[32,y-1,34,y+1],'light':'G','dark':'A'}]},
                {'face':0,'feature':'eye','box':[37,far_y-1,38,far_y+1],
                 'rows':['AA','AP','FP']},
            ]
        else:
            y = capitalist_rims[frame]
            rows = [list(r) for r in sheet.rows]
            # Accessory pass: a four-pixel monocle ring, retaining a half-lidded eye.
            for x,yy,symbol in [(32,y,'K'),(33,y,'K'),(31,y+1,'K'),(34,y+1,'K'),
                                (31,y+2,'K'),(34,y+2,'K'),(32,y+3,'M'),(33,y+3,'L')]:
                rows[yy][x]=symbol
            sheet.rows=[''.join(r) for r in rows]
            accessory=base/'work'/f'{name}-64-accessory.pxg'
            sheet.name=accessory.stem;sheet.path=accessory
            accessory.write_text(sheet.dump(),encoding='utf-8')
            patches=[{'face':0,'feature':'eye','box':[32,y+1,33,y+2],
                      'rows':['AA','LP'],'eyes':[{'box':[32,y+1,33,y+2],'light':'P','dark':'A'}]},
                     {'face':0,'feature':'eye','box':[36,y+1,37,y+2],'rows':['AA','LI']}]
        plan={'source':sheet.name,'size':64,'patches':patches}
        write(base/'work'/f'{name}-64.face.json',plan)
        final=external.px.face_patch(sheet,anchor,plan)
        final.path.write_text(final.dump(),encoding='utf-8')
        external.px.render(final,base/'work')
        path128=base/'work'/f'{name}-128-detail.pxg'
        sheet128=external.px.load(path128)
        if name.startswith('beginner'):
            cy,fy={1:(36,37),2:(37,38),3:(39,40),4:(39,40),5:(39,40),6:(38,39)}[frame]
            patches128=[{'face':0,'feature':'eye','box':[66,cy-1,67,cy+1],
                         'rows':['PA','PP','PG'],'eyes':[{'box':[66,cy-1,67,cy+1],'light':'G','dark':'A'}]},
                        {'face':0,'feature':'eye','box':[74,fy-2,75,fy],'rows':['AG','PG','PF']}]
        else:
            cy={1:40,2:40,3:38,4:38,5:39,6:39,7:39}[frame]
            rows=[list(r) for r in sheet128.rows]
            for xx,yy,s in [(63,cy,'K'),(63,cy+1,'K')]: rows[yy][xx]=s
            sheet128.rows=[''.join(r) for r in rows]
            sheet128.path=base/'work'/f'{name}-128-accessory.pxg'
            sheet128.name=sheet128.path.stem
            sheet128.path.write_text(sheet128.dump(),encoding='utf-8')
            patches128=[{'face':0,'feature':'eye','box':[66,cy,68,cy+1],
                         'rows':['AMP','ILI'],'eyes':[{'box':[66,cy,68,cy+1],'light':'P','dark':'A'}]}]
        plan128={'source':sheet128.name,'size':128,'patches':patches128}
        write(base/'work'/f'{name}-128.face.json',plan128)
        final128=external.px.face_patch(sheet128,anchor,plan128)
        final128.path.write_text(final128.dump(),encoding='utf-8')
        external.px.render(final128,base/'work')


def final_path(base,name,size):
    suffix = 'detail-face' if name.startswith('beginner') else 'accessory-face'
    return base/'work'/f'{name}-{size}-{suffix}.pxg'


def review_details(base):
    report = external.read(base/'work/batch-report.json')
    board=Image.new('RGB',(7*200,2*400),'#66817b')
    d=ImageDraw.Draw(board);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    for entry in report['jobs']:
        col=int(entry['name'][-2:])-1 if len(report['jobs'])>2 else 0
        row=0 if entry['name'].startswith('beginner') else 1
        im=Image.open(final_path(base,entry['name'],64).with_suffix('.png')).convert('RGBA')
        big=im.resize((192,192),Image.Resampling.NEAREST)
        board.paste(big,(col*200,row*400+24),big)
        detail=Image.open(final_path(base,entry['name'],128).with_suffix('.png')).convert('RGBA')
        board.paste(detail,(col*200+8,row*400+234),detail)
        board.paste(im,(col*200+135,row*400+252),im)
        d.text((col*200+8,row*400+4),entry['name'],font=font,fill='#ffffff')
    if len(report['jobs'])==2: board=board.crop((0,0,220,800))
    board.save(base/'work/detail-review.png')


if __name__=='__main__':
    parser=ArgumentParser()
    parser.add_argument('stage',choices=['prepare','sample','build'])
    args=parser.parse_args()
    if args.stage=='prepare': prepare()
    else: raise SystemExit(build(args.stage=='sample'))
