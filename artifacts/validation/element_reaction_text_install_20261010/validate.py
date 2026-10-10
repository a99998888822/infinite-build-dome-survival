"""Validate the installed default and related battle systems sequentially."""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent / 'validation'
GODOT = 'D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
jobs = [
    ('editor', ['--editor', '--quit']),
    ('reaction_text', ['--script', 'res://artifacts/validation/element_reaction_text_install_20261010/launch.gd']),
    ('elements', ['--scene', 'res://scenes/tests/element_reaction_test.tscn']),
    ('lightning', ['--scene', 'res://scenes/tests/lightning_pixel_test.tscn']),
    ('r02', ['--scene', 'res://scenes/tests/combat_feedback_r02_test.tscn']),
    ('active', ['--scene', 'res://scenes/tests/active_combat_integration_test.tscn']),
    ('main', ['--scene', 'res://scenes/core/game_root.tscn', '--quit-after', '120']),
]
cleanup_check = '--cleanup-check' in sys.argv
if cleanup_check:
    jobs = [job for job in jobs if job[0] in ['editor', 'reaction_text']]
prefix = 'cleanup_' if cleanup_check else ''
results = []
for name, args in jobs:
    run = subprocess.run(
        [GODOT, '--headless', '--path', str(ROOT), *args, '--',
         '--transient-session'],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150,
    )
    (OUT / f'{prefix}{name}.log').write_bytes(run.stdout)
    lines = run.stdout.decode('utf-8', errors='replace').splitlines()
    results.append(dict(
        name=name, exit_code=run.returncode,
        errors=[x for x in lines if any(t in x for t in ['ERROR:', 'SCRIPT ERROR', 'FAIL '])],
        warnings=[x for x in lines if 'WARNING:' in x or 'Unable to' in x],
        summary=[x for x in lines if 'checks=' in x],
    ))
    print(json.dumps(results[-1]), flush=True)
(OUT / f'{prefix}suite.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(int(any(r['exit_code'] or r['errors'] for r in results)))
