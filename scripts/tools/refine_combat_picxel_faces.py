"""Apply source-localized mouth/eye patches to the review grids only."""
from argparse import ArgumentParser
from pathlib import Path
import json
import subprocess
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd
import build_combat_picxel_review as t


def patch(path,anchor,patches):
    record={'source':path.stem,'size':t.external.px.load(path).size,'patches':patches}
    output=path.with_suffix('.face.json')
    t.write(output,record)
    subprocess.run([sys.executable,'-B',str(t.SKILL/'vendor/picxel/scripts/picxel.py'),'face',str(path),'--anchor',str(anchor),'--patch',str(output)],check=True)


def enemy_mouths():
    base=t.TASK/'enemy_walk'
    for i in range(1,8):
        name=f'enemy_walk_{i:02d}'
        original=np.asarray(Image.open(base/'refs'/f'{name}.png').convert('RGB'))
        # AI-inspected mouth-only ROI; locate the dark circular cavity inside it.
        dark=original[330:418,370:478].max(2)<68
        labels,_=nd.label(dark);counts=np.bincount(labels.ravel());counts[0]=0
        y,x=nd.center_of_mass(dark,labels,int(counts.argmax()))
        gx,gy=int((x+370+24)/12),int((y+330+36)/12)
        path=base/'work'/f'{name}-64-detail.pxg'
        anchor=json.loads((base/'refs'/f'{name}.anchor.json').read_text(encoding='utf-8'))
        anchor['faces'][0]['complex']=True
        anchor['faces'][0]['reason']='Observed thin circular mouth rim breaks after 64px palette voting; preserve hollow eyes and repair only the source-localized mouth.'
        observed=base/'work'/f'{name}.face-anchor.json'
        t.write(observed,anchor)
        grid=t.external.px.load(path)
        symbols={c:s for s,c in grid.colors.items()}
        rim=symbols['#97a18b'];inside=symbols['#142028']
        rows=[list(row[gx-2:gx+3]) for row in grid.rows[gy-2:gy+3]]
        for yy in range(5):
            for xx in range(5):
                if xx in (0,4) and yy in (0,4):continue
                rows[yy][xx]=rim if xx in (0,4) or yy in (0,4) else inside
        patch(path,observed,[{'face':0,'feature':'mouth','box':[gx-2,gy-2,gx+2,gy+2],'rows':[''.join(row) for row in rows]}])


def beginner_eyes():
    base=t.TASK/'beginner'
    near64=(18,18,19,20,19,19,19,19)
    far64=(18,19,20,20,20,20,19,19)
    near128=(36,37,38,39,39,39,38,38)
    far128=(37,38,39,40,39,39,39,38)
    # Coordinates observed in the final grids and checked against each original
    # iris; these are not reused from the preceding six-frame revision.
    for i in range(1,9):
        name=f'beginner_{i:02d}'
        for size in (64,128):
            path=base/'work'/f'{name}-{size}-detail.pxg'
            grid=t.external.px.load(path);symbols={c:s for s,c in grid.colors.items()}
            a=symbols['#252e2d'];g=symbols['#f4e6d0'];p=symbols['#53b7a4'];f=symbols['#ead1b9']
            if size==64:
                y,fy=near64[i-1],far64[i-1]
                patches=[{'face':0,'feature':'eye','box':[32,y-1,34,y+1],
                          'rows':[a*3,g+a+p,g+p+g],'eyes':[{'box':[32,y-1,34,y+1],'light':g,'dark':a}]},
                         {'face':0,'feature':'eye','box':[37,fy-1,38,fy+1],'rows':[a*2,a+p,f+p]}]
            else:
                y,fy=near128[i-1],far128[i-1]
                patches=[{'face':0,'feature':'eye','box':[66,y-1,67,y+1],
                          'rows':[p+a,p*2,p+g],'eyes':[{'box':[66,y-1,67,y+1],'light':g,'dark':a}]},
                         {'face':0,'feature':'eye','box':[74,fy-2,75,fy],'rows':[a+g,p+g,p+f]}]
            patch(path,base/'refs'/f'{name}.anchor.json',patches)


if __name__=='__main__':
    parser=ArgumentParser(description=__doc__)
    parser.add_argument('subject',choices=['enemy','beginner'])
    args=parser.parse_args()
    enemy_mouths() if args.subject=='enemy' else beginner_eyes()
