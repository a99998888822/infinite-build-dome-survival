from PIL import Image, ImageEnhance
import numpy as np
from scipy import ndimage

SOURCES = {}
used = []

def loose_stone_source(index):
    """Isolate the two loose stones without the neighbouring wall's shadow."""
    box = [(1274,1841,1404,1919),(1430,1860,1511,1920)][index]
    a = np.array(read('ground_Barier1.png').crop(box))
    body = a[:,:,:3].mean(axis=2)>48
    labels,count = ndimage.label(body,structure=np.ones((3,3)))
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    body = labels==sizes.argmax()
    body = ndimage.binary_fill_holes(ndimage.binary_closing(body,iterations=2))
    # The source has a narrow dark outline that falls below the body threshold.
    mask = ndimage.binary_dilation(body,iterations=3)
    a[~mask] = 0
    return Image.fromarray(a)

def outline_exterior(im, colour=(19,16,27)):
    """Recolour the one-pixel outer rim; preserve holes, alpha and interior RGB."""
    a = np.array(im.convert('RGBA'))
    padded = np.pad(a[:,:,3]==0,1,constant_values=True)
    seed = np.zeros_like(padded)
    seed[0,:] = seed[-1,:] = True
    seed[:,0] = seed[:,-1] = True
    exterior = ndimage.binary_propagation(seed,mask=padded)
    edge = ndimage.binary_dilation(exterior,structure=ndimage.generate_binary_structure(2,1))[1:-1,1:-1] & (a[:,:,3]>0)
    a[edge,:3] = colour
    return Image.fromarray(a)

def read(name):
    used.append(name)
    return Image.open(SOURCES[name]).convert('RGBA')

def remove_back(im, kind='solid', background_seeds=()):
    """Remove only verified background connected to the outside of the image.

    Interior matching colours are artwork, not an excuse to create holes.
    Checkerboard seeds use its light cells so a gray rock touching the canvas
    edge cannot seed a flood through its own face.
    """
    a = np.array(im)
    rgb = a[:, :, :3].astype(np.int16)
    if kind == 'checker':
        eligible = (rgb.max(2)-rgb.min(2) <= 2) & (rgb.mean(2) >= 48) & (rgb.mean(2) <= 140)
        seed_eligible = eligible & (rgb.mean(2) >= 100)
    elif kind == 'magenta':
        eligible = (rgb[:,:,0]>70) & (rgb[:,:,2]>70) & (rgb[:,:,0]>rgb[:,:,1]+8) & (rgb[:,:,2]>rgb[:,:,1]+8)
        seed_eligible = eligible
    else:
        perimeter = np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
        sample = perimeter[perimeter[:,3]>0,:3].astype(np.int16)
        if not len(sample): return im.copy()
        colors, counts = np.unique((sample//4)*4,axis=0,return_counts=True)
        mode = colors[counts.argmax()]
        bg = np.median(sample[np.max(np.abs(sample-mode),axis=1)<=4],axis=0)
        eligible = np.max(np.abs(rgb-bg),axis=2) <= 6
        seed_eligible = eligible
    eligible |= a[:, :, 3] == 0
    seed_eligible |= a[:,:,3] == 0
    seed = np.zeros(eligible.shape, bool)
    seed[0] = seed_eligible[0]
    seed[-1] = seed_eligible[-1]
    seed[:,0] |= seed_eligible[:,0]
    seed[:,-1] |= seed_eligible[:,-1]
    # A reviewed source may contain an actual enclosed backing hole. Only an
    # explicit seed can open it; matching interior colours stay opaque otherwise.
    for x,y in background_seeds:
        if not (0 <= x < im.width and 0 <= y < im.height and eligible[y,x]):
            raise ValueError(f'Invalid reviewed background seed: {(x,y)}')
        seed[y,x] = True
    connected = ndimage.binary_propagation(seed, mask=eligible)
    a[connected, 3] = 0
    return Image.fromarray(a)

def crop_prop(name, box, kind='solid'):
    im = read(name)
    x0, y0, x1, y1 = box
    im = im.crop((int(x0*im.width), int(y0*im.height), int(x1*im.width), int(y1*im.height)))
    im = remove_back(im, kind)
    bounds = im.getchannel('A').getbbox()
    return im.crop(bounds) if bounds else im

def grade(im, brightness=1.0, saturation=0.85):
    alpha = im.getchannel('A')
    result = ImageEnhance.Color(im.convert('RGB')).enhance(saturation)
    result = ImageEnhance.Brightness(result).enhance(brightness).convert('RGBA')
    result.putalpha(alpha)
    return result

def scene_material(im, material):
    """Share purple shadows / moss-gray light, while retaining material chroma."""
    arr = np.array(im).astype(np.float32)
    rgb = arr[:, :, :3]
    lum = rgb @ np.array([.2126, .7152, .0722])
    stops = np.array([0, 35, 80, 140, 220, 255])
    palette = np.array([[19,16,27], [36,30,43], [64,64,73],
                        [83,99,91], [114,127,106], [125,141,116]])
    if material == 'wood':
        palette = np.array([[21,17,29], [40,30,42], [66,46,59],
                            [94,69,76], [119,94,93], [128,111,99]])
    mapped = np.stack([np.interp(lum, stops, palette[:,c]) for c in range(3)], axis=2)
    chroma = .15 if material == 'wood' else .22
    mapped += (rgb-lum[:,:,None])*chroma
    arr[:,:,:3] = np.clip(mapped, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))
