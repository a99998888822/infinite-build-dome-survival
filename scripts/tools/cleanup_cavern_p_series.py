"""Delete only the five rejected P assets and their workspace derivatives."""
from pathlib import Path
import hashlib,json,re,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/analysis/obstacle_revision_v02_20261013'
NAMES={'ruin_curved_wall','ruin_sloped_wall','ruin_stone_block','ruin_broken_column','ruin_brick_wall'}
MEDIA={'.png','.jpg','.jpeg','.webp','.gif','.pxg','.pal','.import','.ctex','.md5','.aseprite'}

def safe(p):
    p=p.resolve();assert p.is_relative_to(ROOT) and '.git' not in p.parts;return p
def match(v):return isinstance(v,str) and any(n in v for n in NAMES)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def prune(value):
    if isinstance(value,list):
        return [prune(x) for x in value if not match(x) and not (isinstance(x,dict) and any(match(x.get(k)) for k in ['id','name','asset','path','before','after','texture','sheet']))]
    if isinstance(value,dict):return {k:prune(v) for k,v in value.items() if not match(k)}
    return value

def main(apply=False):
    paths=[ROOT/p for p in subprocess.check_output(['rg','--files','-uuu','-g','!.git/**'],cwd=ROOT).decode('utf-8').splitlines()]
    removed={safe(p) for p in paths if p.is_file() and p.suffix.lower() in MEDIA and match(p.name)}
    hashes={sha(p) for p in removed if p.suffix=='.png'};sizes={p.stat().st_size for p in removed if p.suffix=='.png'}
    for p in paths:
        if p.is_file() and p.suffix in {'.png','.jpg','.webp'} and p.stat().st_size in sizes and sha(p) in hashes:removed.add(safe(p))
    catalog=ROOT/'artifacts/analysis/obstacle_catalog_20261013'
    for folder in ['cards','crops']:
        removed.update(safe(p) for p in (catalog/folder).glob('P*') if p.is_file())
    removed.update(safe(p) for p in (catalog/'runtime').glob('production_prop_*.png'))
    # Old P contact sheets contain flattened copies of the rejected originals.
    for folder in [ROOT/'artifacts/previews/edge_repair_20261013/review',ROOT/'artifacts/previews/edge_repair_20261013/picxel_stone_review']:
        for pattern in ['stone_*.png','review-*.png']:
            removed.update(safe(p) for p in folder.glob(pattern))
    for p in [ROOT/'artifacts/previews/edge_repair_20261013/stone_comparison.png']:
        if p.exists():removed.add(safe(p))
    # These review sheets will be rebuilt after capture, with no P group.
    removed.update(safe(p) for p in (catalog/'sheets').glob('*.png'))
    config=ROOT/'data_config/cavern_meadow_battlefield.json'
    plan={'removed_ids':sorted(NAMES),'files':[str(p) for p in sorted(removed)],'count':len(removed),
          'git_history_modified':False}
    (OUT/'p_cleanup_plan.json').write_text(json.dumps(plan,indent=2),encoding='utf-8')
    print(json.dumps({'files':len(removed),'bytes':sum(p.stat().st_size for p in removed)}))
    if not apply:return
    changed=[]
    for p in paths:
        if p.suffix!='.json' or not p.is_file() or OUT in p.parents:continue
        raw=p.read_text(encoding='utf-8-sig')
        if not match(raw):continue
        try:data=json.loads(raw)
        except ValueError:continue
        new=prune(data)
        if isinstance(new,dict) and 'initial_groups' in new and 'props' in new:
            new['initial_groups']=[]
        if new!=data:
            safe(p).write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');changed.append(str(p))
    active=json.loads(config.read_text(encoding='utf-8'));active['props']=[];active['initial_groups']=[]
    config.write_text(json.dumps(active,indent=2)+'\n',encoding='utf-8')
    for p in sorted(removed):safe(p).unlink()
    assert all(not p.exists() for p in removed)
    (OUT/'p_cleanup_report.json').write_text(json.dumps({**plan,'applied':True,'updated_manifests':changed},indent=2),encoding='utf-8')
    print('P_REMOVAL_COMPLETE')

if __name__=='__main__':main('--apply' in sys.argv)
