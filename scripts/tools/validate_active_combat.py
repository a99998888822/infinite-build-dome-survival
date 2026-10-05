"""Run bounded headless regressions and retain complete UTF-8 logs."""
import argparse
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('scenes', nargs='+')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = root / 'artifacts/previews/active_combat/formal_r01/validation'
out.mkdir(parents=True, exist_ok=True)
godot = Path('D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
failed = False
for scene in args.scenes:
    command = [str(godot), '--headless', '--path', str(root)]
    if scene == 'editor':
        command += ['--editor', '--quit']
    else:
        command += ['--scene', f'res://scenes/tests/{scene}.tscn', '--quit-after', '7200']
    command += ['--verbose', '--', '--transient-session']
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, timeout=120)
        log = (result.stdout + result.stderr).decode('utf-8', errors='replace')
        (out / f'{scene}.log').write_text(log, encoding='utf-8')
        errors = [line for line in log.splitlines() if re.search(r'FAIL|SCRIPT ERROR|Parse Error|Compile Error|leaked|still in use', line)]
        summary = [line for line in log.splitlines() if re.search(r'checks=|COMPLETE|_ROWS', line)]
        print(scene, 'exit=', result.returncode, *summary, *errors[:24], sep='\n', flush=True)
        failed |= result.returncode != 0 or bool(errors)
    except subprocess.TimeoutExpired:
        failed = True
        print(scene, 'TIMEOUT', flush=True)
raise SystemExit(1 if failed else 0)
