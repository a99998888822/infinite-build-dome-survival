"""Install approved PXG sources once; rebuild/check production PNGs without previews.

python scripts/tools/build_weapon_trio_art.py --source artifacts/previews/weapon_trio
python scripts/tools/build_weapon_trio_art.py --write
"""
from pathlib import Path
import argparse
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TENTACLE = ['coil','compress','raise','unroll_01','unroll_02','unroll_03','unroll_04','unroll_05','unroll_06','unroll_07','whip','whip_02','whip_03','impact','squash','rebound','recover_01','recover_02','recover']
HAMMER = ['emerge_0','emerge_1','emerge_2','emerge_3','windup','strike_0','strike_1','strike_2','slam']


def decode(path):
    head, body = path.read_text(encoding='utf-8').split('\n---\n')
    fields = dict(line.split(':',1) for line in head.splitlines())
    size = int(fields['size']); rows = body.splitlines()
    colors = {k:tuple(bytes.fromhex(v.strip()[1:]))+(255,) for k,v in fields.items() if len(k)==1}
    assert len(colors)<=16 and len(rows)==size and all(len(r)==size for r in rows)
    im=Image.new('RGBA',(size,size)); im.putdata([colors[c] if c!='.' else (0,0,0,0) for r in rows for c in r])
    box=im.getbbox(); assert box and min(box[:2])>0 and max(box[2:])<size
    return im


def main():
    p=argparse.ArgumentParser(); p.add_argument('--source',type=Path); p.add_argument('--write',action='store_true'); args=p.parse_args()
    groups=[]
    for name in ['copper_lamp','mutant_tentacle','earth_hammer']:
        groups.append((ROOT/'assets/ui/icons/weapons'/('weapon_'+name+'.png'),[(f'r02/icons/{name}-64.pxg', 'weapon_'+name+'.pxg')]))
    for name,folder,files in [
        ('copper_lamp','r02/effects',[f'fire_flow_{i:02}-128' for i in range(6)]),
        ('mutant_tentacle','r02/sprites',['tentacle_'+n+'-128' for n in TENTACLE]),
        ('earth_hammer','r03/sprites',['hammer_'+n+'-64' for n in HAMMER]),
        ('ground_cracks','r02/effects',[f'ground_crack_{i:02}-64' for i in range(3)]+['ground_branch-64'])]:
        groups.append((ROOT/'assets/sprites/weapons'/name/(name+'.png'),[(folder+'/'+n+'.pxg','source/'+n+'.pxg') for n in files]))
    if args.source:
        # Decode every input before installing any of the accepted source files.
        for _,entries in groups:
            for rel,_ in entries: decode(args.source/rel)
        for output,entries in groups:
            for rel,dest in entries:
                target=output.parent/dest; target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(args.source/rel,target)
    for output,entries in groups:
        frames=[decode(output.parent/dest) for _,dest in entries]
        n=frames[0].width; atlas=Image.new('RGBA',(n*len(frames),n))
        for i,im in enumerate(frames): atlas.paste(im,(i*n,0))
        if args.write or args.source: atlas.save(output)
        with Image.open(output) as actual:
            assert actual.mode=='RGBA' and actual.size==atlas.size and actual.tobytes()==atlas.tobytes(),output
        print(output.relative_to(ROOT),atlas.size,'OK')


if __name__=='__main__': main()
