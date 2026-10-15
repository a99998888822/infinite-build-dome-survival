"""Generate the current cloud texture and authored rock-light mask."""
from pathlib import Path
import argparse
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[3]
def periodic_noise(rng, frequencies, weights):
    result = np.zeros((512, 512), dtype=np.float32)
    for freq, weight in zip(frequencies, weights):
        small = rng.random((freq, freq))
        tiled = np.tile(small, (3, 3))
        image = Image.fromarray(np.uint8(tiled*255)).resize((1536,1536),Image.Resampling.BICUBIC)
        result += np.asarray(image,dtype=np.float32)[512:1024,512:1024]/255*weight
    return np.uint8(np.clip(result,0,1)*255)

def generate(output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(6041026)
    cloud = periodic_noise(rng, [5,10,20],[.78,.16,.06])
    detail = periodic_noise(rng, [8,16,32],[.72,.21,.07])
    Image.fromarray(np.stack([cloud,detail,detail],axis=-1)).save(output/'cloud_noise.png')

    source = Image.open(ROOT/'assets/sprites/background/cavern/prop_rock.png').convert('RGBA')
    mask = Image.new('L',source.size,0)
    draw = ImageDraw.Draw(mask)
    # Authored top planes from the inspected 75x65 sprite; sides and cracks excluded.
    draw.polygon([(13,20),(28,3),(39,1),(51,6),(53,14),(47,21),(30,18)],fill=235)
    draw.polygon([(3,33),(13,20),(29,18),(40,27),(42,37),(28,40),(15,38)],fill=175)
    draw.polygon([(46,19),(53,8),(64,20),(69,29),(55,34),(43,34)],fill=145)
    a = np.array(source)
    m = np.array(mask)
    m[(a[:,:,3]<128)|(a[:,:,:3].max(axis=2)<65)] = 0
    Image.fromarray(m).save(output/'rock_face_mask.png')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    generate(parser.parse_args().output)
