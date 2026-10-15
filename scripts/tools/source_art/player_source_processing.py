"""Reusable segmentation for supplied novice action references.

Returns edited in-memory images; no task folders, installation or model calls.
The approved PXG grids remain the authoritative current artwork.
"""
from pathlib import Path
import cv2
import numpy as np
from scipy import ndimage as ndi
from PIL import Image
def cutout(path):
    im=Image.open(path).convert('RGB');a=np.array(im)
    hsv=cv2.cvtColor(a,cv2.COLOR_RGB2HSV)
    r,g,b=np.moveaxis(a.astype(float),-1,0)
    # The video's pink hue shifts between actions. Its blue/green ratio
    # separates it from reddish leather; a fixed narrow hue band does not.
    candidate=(hsv[:,:,0]>=148)&(hsv[:,:,1]>=35)&(hsv[:,:,2]>=60)&(r>g+30)&(r>b+10)&(b>g+8)
    labels,_=ndi.label(candidate,ndi.generate_binary_structure(2,1))
    ids=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]));ids=ids[ids>0]
    exterior=np.isin(labels,ids)
    cc,_=ndi.label(~exterior,np.ones((3,3)));areas=np.bincount(cc.ravel());areas[0]=0
    keep=ndi.binary_fill_holes(cc==areas.argmax())
    if keep.mean()>0.60:raise ValueError(f'{path.name}: exterior was not isolated')
    rgba=np.dstack([a,np.uint8(keep)*255]);result=Image.fromarray(rgba)
    # Largest light warm connected area is this frame's head, not a shared box.
    warm=keep&(r>130)&(g>85)&(b>60)&(r>g)&(np.indices(keep.shape)[0]<650)
    heads,_=ndi.label(warm,np.ones((3,3)));counts=np.bincount(heads.ravel());counts[0]=0
    head=ndi.binary_fill_holes(heads==counts.argmax())
    hy,hx=np.where(head);headbox=[int(hx.min()),int(hy.min()),int(hx.max()+1),int(hy.max()+1)]
    return result,headbox,int((candidate&keep).sum())

def matte(im):
    rgb=np.asarray(im.convert('RGB'))
    r,g,b=np.moveaxis(rgb.astype(float),-1,0)
    hsv=cv2.cvtColor(rgb,cv2.COLOR_RGB2HSV)
    pink=((hsv[:,:,0]>=145)&(hsv[:,:,1]>35)&(r>g+20)&(b>g+7))
    keep=~pink
    labels,n=ndi.label(keep,np.ones((3,3)))
    sizes=np.bincount(labels.ravel());sizes[0]=0
    keep=labels==sizes.argmax()
    keep=ndi.binary_closing(keep,iterations=2)
    # Only actual image-background color is removed inside the silhouette.
    # Do not fill the arm/leg holes or keep disconnected video watermarks.
    result=Image.fromarray(np.dstack([rgb,keep.astype(np.uint8)*255]))
    warm=keep&(r>145)&(g>100)&(b>65)&(r>g+6)&(g>b+4)
    labs,n=ndi.label(warm,np.ones((3,3)))
    sizes=np.bincount(labs.ravel());sizes[0]=0
    head=ndi.binary_fill_holes(labs==sizes.argmax())
    yy,xx=np.where(head)
    hb=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
    return result,hb

def move_matte(image):
    a = np.array(image.convert('RGB'))
    hsv = cv2.cvtColor(a, cv2.COLOR_RGB2HSV)
    r,g,b = np.moveaxis(a.astype(float),-1,0)
    pink = (hsv[:,:,0]>=148)&(hsv[:,:,1]>=30)&(hsv[:,:,2]>=38)&(r>g+12)&(r>b+4)&(b>g+4)
    labels,_ = ndi.label(pink, ndi.generate_binary_structure(2,1))
    ids = np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]))
    exterior = np.isin(labels, ids[ids>0])
    cc,_ = ndi.label(~exterior, np.ones((3,3)))
    areas = np.bincount(cc.ravel()); areas[0] = 0
    keep = ndi.binary_fill_holes(cc==areas.argmax())
    assert .05 < keep.mean() < .5
    return a, keep, pink

def extract_video_frames(video, indices, output):
    """Extract explicitly selected source frames; caller supplies the video."""
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened(): raise ValueError(f'Cannot open video: {video}')
    try:
        for index in indices:
            capture.set(cv2.CAP_PROP_POS_FRAMES, index)
            ok, frame = capture.read()
            if not ok: raise ValueError(f'Unavailable video frame: {index}')
            Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)).save(output/f'{index:04d}.png')
    finally: capture.release()
