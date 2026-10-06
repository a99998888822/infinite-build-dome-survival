"""Record six native battle comparisons on verified private desktops."""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GODOT = r'D:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
families = sys.argv[1:] or ['range', 'area', 'combined']
for family in families:
    for mode in ['current', 'half']:
        label = f'{family}_{mode}'
        log = HERE / f'{label}.log'
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/tools/run_godot_background.py'),
                                 '--godot', GODOT, '--log', str(log), '--timeout', '120', '--',
                                 '--path', str(ROOT), '--fixed-fps', '60',
                                 '--scene', 'res://artifacts/previews/range_half_bonus_review/review.tscn', '--',
                                 f'--family={family}', f'--mode={mode}', '--capture',
                                 f'--capture-dir={HERE / "captures" / label}'], cwd=ROOT, timeout=135)
        text = log.read_text(encoding='utf-8')
        bad = [line for line in text.splitlines() if any(x in line for x in ['SCRIPT ERROR', 'ERROR:', 'FAIL ', 'WARNING:'])]
        report = json.loads(log.with_suffix('.json').read_text(encoding='utf-8'))
        print(f'CAPTURE {label} exit={result.returncode} errors={bad}', flush=True)
        assert result.returncode == 0 and not bad and 'failures=0' in text
        assert report['foreground_samples'] == 0 and report['verified_desktop'] == report['private_desktop']
