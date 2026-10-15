"""Current rubble material simplification; accepts an image, returns an image."""
import numpy as np
from scipy import ndimage as ndi
from PIL import Image

def simplify_q(im,index):
    a=np.array(im.convert('RGBA'));mask=a[:,:,3]>0
    # Keep the existing silhouette and separate pebbles. Median lighting removes
    # speckled texture; the original dark connected seams retain stacked faces.
    lum=a[:,:,:3]@np.array([.2126,.7152,.0722])
    filled=lum[tuple(ndi.distance_transform_edt(~mask,return_distances=False,return_indices=True))]
    soft=ndi.median_filter(filled,size=3 if index<3 or index in [4,5] else 1)
    if index==2:
        palette=np.array([[26,30,29],[78,68,56],[105,90,70],[120,107,85],[136,135,124]],dtype=np.uint8)
        levels=np.digitize(soft,[39,80,104,125])
    elif index<2:
        palette=np.array([[26,30,29],[42,46,42],[68,66,59],[122,121,111],[136,135,124]],dtype=np.uint8)
        levels=np.digitize(soft,[36,59,91,130])
    else:
        palette=np.array([[20,26,26],[41,52,51],[61,73,70],[114,126,116],[135,145,134]],dtype=np.uint8)
        levels=np.digitize(soft,[33,62,92,132])
    # One local majority pass removes isolated colour sparks without dithering.
    for _ in range(2 if index in [0,1,4,5] else 1):
        votes=np.stack([ndi.uniform_filter((levels==i).astype(float),size=3,mode='nearest') for i in range(5)])
        mode=votes.argmax(0);strength=votes.max(0)
        levels=np.where(strength>=.56,mode,levels)
    labels,count=ndi.label(mask,structure=np.ones((3,3)))
    outside=~ndi.binary_fill_holes(mask)
    edge=mask&ndi.binary_dilation(outside,structure=ndi.generate_binary_structure(2,1))
    areas=np.bincount(labels.ravel())
    # A tiny pebble needs a lit centre more than a solid black silhouette.
    edge&=areas[labels]>=12
    levels[edge]=0
    result=a.copy();result[:,:,:3]=palette[levels];result[~mask]=0
    assert np.array_equal(result[:,:,3],a[:,:,3])
    return Image.fromarray(result)
