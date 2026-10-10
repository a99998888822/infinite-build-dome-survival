"""Sequential headless regression checks for the installed cooldown border."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent/'validation'
GODOT = 'D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
JOBS = [
    ('editor', ['--editor', '--quit']),
    ('headless', ['--scene', 'res://scenes/tests/weapon_cooldown_feedback_test.tscn']),
    ('active_combat', ['--scene', 'res://scenes/tests/active_combat_integration_test.tscn']),
    ('r02', ['--scene', 'res://scenes/tests/combat_feedback_r02_test.tscn']),
    ('main', ['--scene', 'res://scenes/core/game_root.tscn', '--quit-after', '120']),
]

results = []
for name, args in JOBS:
    command = [GODOT, '--headless', '--path', str(ROOT), *args, '--', '--transient-session']
    run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
    (OUT/f'{name}.log').write_bytes(run.stdout)
    output = run.stdout.decode('utf-8', errors='replace')
    errors = [line for line in output.splitlines() if any(token in line for token in ['SCRIPT ERROR', 'Parse Error', 'Compile Error', 'FAIL ', 'ERROR:'])]
    results.append(dict(name=name, exit_code=run.returncode, errors=errors,
                        summary=[line for line in output.splitlines() if 'checks=' in line]))
    print(json.dumps(results[-1]), flush=True)
(OUT/'suite.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(int(any(r['exit_code'] or r['errors'] for r in results)))
