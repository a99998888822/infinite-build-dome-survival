"""Hash existing production resources before/after this artifact-only preview."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def manifest():
    result = {}
    for directory in ['assets', 'autoloads', 'data_config', 'scenes', 'scripts', 'shaders']:
        for path in (ROOT / directory).rglob('*'):
            if path.is_file():
                result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    result['project.godot'] = hashlib.sha256((ROOT / 'project.godot').read_bytes()).hexdigest()
    return result


if sys.argv[1] == 'before':
    data = manifest()
    (HERE / 'production_before.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
    print('PRODUCTION_SNAPSHOT', len(data))
else:
    before = json.loads((HERE / 'production_before.json').read_text(encoding='utf-8'))
    after = manifest()
    changes = [name for name in before.keys() | after.keys() if before.get(name) != after.get(name)]
    (HERE / 'production_verification.json').write_text(json.dumps({'files': len(before), 'changed': changes}, indent=2), encoding='utf-8')
    print('PRODUCTION_UNCHANGED' if not changes else 'PRODUCTION_CHANGED', len(before), changes)
    assert not changes
