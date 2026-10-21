"""Create review-only composition and snapshot production files before capture."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'temp/artifacts/analysis/cavern_population_review_20261013'
CONFIG = ROOT / 'data_config/reviews/cavern_population_review.json'


def main():
    meadow = json.loads((ROOT / 'data_config/cavern_meadow_battlefield.json').read_text(encoding='utf-8'))
    reference = json.loads((ROOT / 'docs/asset/config_reference_metadata.json').read_text(encoding='utf-8'))
    cave = reference['legacy_cavern_ground']
    tracked = set()
    for folder in ('assets/sprites/background/cavern', 'assets/sprites/background/wetland',
                   'assets/sprites/background/green_ground', 'assets/sprites/background/meadow'):
        tracked.update((ROOT / folder).glob('*.png'))
    for name in ('scenes/battle/battle_root.tscn', 'project.godot',
                 'data_config/cavern_meadow_battlefield.json', 'data_config/cavern_battlefield.json',
                 'docs/asset/config_reference_metadata.json',
                 'scripts/battle/cavern_meadow_backdrop.gd', 'scripts/battle/cavern_battle_backdrop.gd',
                 'scripts/battle/cavern_battle_horizon.gd'):
        tracked.add(ROOT / name)
    OUT.mkdir(parents=True, exist_ok=True)
    snapshot = OUT / 'production_before.json'
    if not snapshot.exists():
        snapshot.write_text(json.dumps({p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                       for p in sorted(tracked)}, indent=2), encoding='utf-8')
    meadow['source'] = 'Review only: approved A, B, C, D, Q with production meadow and grass'
    meadow['props'] = cave['props']
    for row in meadow['props']:
        size = Image.open(ROOT / row['texture'][6:]).size
        row['anchor'] = [size[0] / 2, size[1]]
    rubble = cave['rubble']
    for row in rubble:
        size = Image.open(ROOT / row['texture'][6:]).size
        row['anchor'] = [size[0] / 2, size[1]]
    meadow['rubble'] = rubble + meadow['rubble']
    meadow['review_only'] = True
    meadow['method'] = 'Terrain-matched batched grass, medium B/Q, sparse world-space A; inherited approved PNGs'
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(json.dumps(meadow, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'config': str(CONFIG), 'protected_files': len(tracked)}))


if __name__ == '__main__':
    main()
