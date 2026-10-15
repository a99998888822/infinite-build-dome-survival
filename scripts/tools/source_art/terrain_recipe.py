"""Reusable terrain painting recipe; caller must supply an input texture."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

HERE = None
SOURCE = None
W, H = 1088, 800
rng = np.random.default_rng(20261015)


def field(gx, gy):
    grid = rng.random((gy, gx))
    xx = np.arange(W) * gx / W
    yy = np.arange(H) * gy / H
    x0 = xx.astype(int)
    y0 = yy.astype(int)
    u = xx - x0
    v = yy - y0
    u = u*u*(3-2*u)
    v = v*v*(3-2*v)
    a = grid[y0[:, None] % gy, x0[None, :] % gx]
    b = grid[y0[:, None] % gy, (x0[None, :]+1) % gx]
    c = grid[(y0[:, None]+1) % gy, x0[None, :] % gx]
    d = grid[(y0[:, None]+1) % gy, (x0[None, :]+1) % gx]
    return (a*(1-u)+b*u)*(1-v[:, None]) + (c*(1-u)+d*u)*v[:, None]


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def generate(source, output):
    global SOURCE, HERE, rng
    SOURCE = Path(source).resolve()
    HERE = Path(output).resolve()
    HERE.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(20261015)
    src = Image.open(SOURCE).convert('RGB').resize((W, H), Image.Resampling.BOX)
    original = np.asarray(src, dtype=float)/255
    broad = field(6, 5)
    middle = field(16, 12)
    fine = field(48, 36)
    grain = field(145, 108)
    moisture = broad*.50 + middle*.28 + fine*.15 + grain*.07
    grass = smooth(.36, .52, moisture)
    soil = 1-grass
    # Slow, connected biomes and low-contrast surface grain.
    texture = np.asarray(src.filter(ImageFilter.GaussianBlur(1.1)), dtype=float).mean(2)
    texture = np.clip((texture-texture.mean())/23, -1.4, 1.4)
    grass_dark = np.array([43, 53, 49.0])
    grass_light = np.array([65, 77, 64.0])
    tint = np.clip(.46 + (middle-.5)*.38 + (fine-.5)*.23 + texture*.045, 0, 1)
    green = grass_dark[None, None, :]*(1-tint[..., None]) + grass_light[None, None, :]*tint[..., None]
    earth = np.array([68, 67, 62.0])[None, None, :] + (texture*4 + (middle-.5)*8)[..., None]*np.array([1, .96, .9])
    colors = green*grass[..., None] + earth*soil[..., None]
    colors += ((grain-.5)*7 + (fine-.5)*4)[..., None]
    # Tiny stone inclusions are rare and are not outlined like obstacles.
    stone_mask = smooth(.75, .85, field(24, 18)) * soil * .18
    colors = colors*(1-stone_mask[..., None]) + np.array([73, 78, 72])[None, None, :]*stone_mask[..., None]
    im = Image.fromarray(np.uint8(np.clip(colors, 0, 255)), 'RGB')
    draw = ImageDraw.Draw(im)
    # Rooted clusters of short 1-3 pixel strokes. Most grass is painted flat.
    for _ in range(45000):
        x, y = int(rng.integers(2, W-3)), int(rng.integers(4, H-2))
        if grass[y, x] < .6 or rng.random() > grass[y, x]*.73:
            continue
        base = np.asarray(im.getpixel((x, y)), dtype=int)
        delta = rng.choice([-6, -4, 5, 7])
        color = tuple(np.clip(base + np.array([delta, delta, delta*.55]), 0, 255).astype(int))
        for dx, length in [(-1, 1), (0, 2), (2, 1)]:
            draw.line((x+dx, y, x+dx+1, y-length), fill=color, width=1)
    # No dithering; 64 shared colors keeps coherent patches.
    im = im.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    im = im.resize((2176, 1600), Image.Resampling.NEAREST)
    im.save(HERE / 'ground.png')
    context = np.zeros((H, W, 4), dtype=np.uint8)
    context[..., :3] = np.asarray(im.resize((W,H), Image.Resampling.NEAREST))
    context[..., 3] = np.uint8(np.clip(grass,0,1)*255)
    Image.fromarray(context, 'RGBA').resize((272,200), Image.Resampling.BOX).save(HERE / 'ground_context.png')
    contact = Image.new('RGBA', (96,48))
    d = ImageDraw.Draw(contact)
    for margin, alpha in [(0,10),(3,16),(6,22),(10,30),(15,39)]:
        d.ellipse((margin, margin//2, 95-margin, 47-margin//2), fill=(19,23,18,alpha))
    contact.save(HERE / 'contact_shadow.png')
    provenance = {'method':'local source-derived palette repaint, periodic value fields, rooted short-grass strokes; no image API',
                  'source': str(SOURCE), 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                  'dimensions':[2176,1600], 'context_dimensions':[272,200], 'palette_colors':64,
                  'grass_coverage':float((grass>.6).mean()), 'terrain_projection':'145/220, applied once in Godot',
                  'production_assets_modified':False}
    (HERE / 'asset_provenance.json').write_text(json.dumps(provenance, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(provenance))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Terrain recipe; original historic input was retired, so supply a source explicitly")
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    generate(args.source, args.output)
