"""Capture the remaining two approved examples using production resources."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GODOT = r'D:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
for family in ['area', 'combined']:
    log = HERE / f'production_{family}.log'
    result = subprocess.run([sys.executable, str(ROOT / 'scripts/tools/run_godot_background.py'),
                             '--godot', GODOT, '--log', str(log), '--timeout', '120', '--',
                             '--path', str(ROOT), '--fixed-fps', '60', '--scene',
                             'res://artifacts/previews/range_half_bonus_install/production_capture.tscn', '--',
                             f'--family={family}', '--mode=half', '--capture',
                             f'--capture-dir={HERE / "captures" / family}'], cwd=ROOT, timeout=135)
    text = log.read_text(encoding='utf-8')
    assert result.returncode == 0 and not any(t in text for t in ['SCRIPT ERROR', 'ERROR:', 'FAIL ', 'WARNING:'])
    proof = json.loads(log.with_suffix('.json').read_text(encoding='utf-8'))
    assert proof['foreground_samples'] == 0 and proof['verified_desktop'] == proof['private_desktop']
    print('PRODUCTION_GPU_PASS', family, flush=True)

for family in ['range', 'area', 'combined']:
    before = json.loads((ROOT / 'artifacts/previews/range_half_bonus_review/captures' / f'{family}_half/report.json').read_text(encoding='utf-8'))
    after = json.loads((HERE / f'captures/{family}/report.json').read_text(encoding='utf-8'))
    assert before['failures'] == after['failures'] == 0
    for expected, actual in zip(before['cases'], after['cases']):
        for key in ['score', 'range_attribute', 'area_attribute', 'actual_range', 'blast_radius', 'single_damage', 'hits', 'expected_targets']:
            assert actual[key] == expected[key], (family, key, actual[key], expected[key])
    print('APPROVED_PREVIEW_MATCH', family, flush=True)
