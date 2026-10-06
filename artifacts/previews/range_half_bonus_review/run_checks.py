"""Sequential headless validation for the preview scenes only."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GODOT = r'D:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
for family in ['area', 'combined']:
    log = HERE / f'headless_{family}.log'
    result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--fixed-fps', '60',
                             '--scene', 'res://artifacts/previews/range_half_bonus_review/review.tscn',
                             '--log-file', str(log), '--', f'--family={family}', '--mode=half',
                             f'--capture-dir={HERE / ("check_" + family)}'], cwd=ROOT, timeout=120)
    text = log.read_text(encoding='utf-8')
    bad = [line for line in text.splitlines() if any(x in line for x in ['SCRIPT ERROR', 'ERROR:', 'FAIL ', 'WARNING:'])]
    print(f'HEADLESS {family} exit={result.returncode} errors={bad}', flush=True)
    assert result.returncode == 0 and not bad and 'failures=0' in text
