"""Check current terrain/UI packages, or install explicitly supplied native files.

No arguments only checks; no historical artifacts directory is read or created.
"""
from pathlib import Path
import argparse,hashlib,json,shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
GROUPS={
    'stats_drawer': ('assets/ui/stats_drawer',None),
    'green_ground': ('assets/sprites/background/green_ground','data_config/green_battlefield.json'),
    'meadow': ('assets/sprites/background/meadow',None),
}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def run_cli(group):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--source',type=Path,help='Package root with paths relative to the project root')
    parser.add_argument('--backup-dir',type=Path)
    args=parser.parse_args()
    if args.check and args.source:parser.error('--check and --source are mutually exclusive')
    if args.source and not args.backup_dir:parser.error('--source requires --backup-dir')
    folder,config=GROUPS[group]
    targets=sorted(p for p in (ROOT/folder).iterdir() if p.suffix in {'.png','.json'})
    if config:targets.append(ROOT/config)
    staged=[]
    for target in targets:
        source=args.source/target.relative_to(ROOT) if args.source else target
        if target.suffix=='.png':
            with Image.open(target) as current,Image.open(source) as incoming:
                incoming.load()
                if incoming.format!='PNG' or incoming.size!=current.size:
                    raise ValueError('Incompatible native image: '+str(source))
        else:json.loads(source.read_text(encoding='utf-8'))
        staged.append((source,target,digest(source)))
    if args.source:
        args.backup_dir.mkdir(parents=True,exist_ok=False)
        for _,target,_ in staged:
            backup=args.backup_dir/target.relative_to(ROOT)
            backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,backup)
        for source,target,expected in staged:
            if source.resolve()!=target.resolve():shutil.copy2(source,target)
            assert digest(target)==expected
        # A changed PNG becomes the authoritative editable raster until new grids
        # are reviewed. Do not claim that an older grid still matches it.
        index=ROOT/'artifacts/editable/index.json'
        if index.exists():
            data=json.loads(index.read_text(encoding='utf-8'))
            replaced={target.relative_to(ROOT).as_posix():expected for _,target,expected in staged}
            for item in data['assets']:
                if item['asset'] in replaced and item['sha256']!=replaced[item['asset']]:
                    item.pop('editable_frames',None)
                    item.update(sha256=replaced[item['asset']],editable=item['asset'],mode='native_png')
            index.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS: {group}: {len(staged)} current native files; historical packages not required')

