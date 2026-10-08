"""Bounded Godot validation with complete logs and compact console results."""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = 'D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('scenes', nargs='+')
    parser.add_argument('--godot', default=DEFAULT_GODOT)
    parser.add_argument('--locale', default='zh_CN')
    args = parser.parse_args()
    output = ROOT / 'artifacts/localization/validation'
    output.mkdir(parents=True, exist_ok=True)
    failed = False
    for scene in args.scenes:
        command = [args.godot, '--headless', '--path', str(ROOT)]
        if scene == 'editor':
            command += ['--editor', '--quit']
        elif scene == 'main':
            command += ['--quit-after', '120']
        else:
            command += ['--scene', f'res://scenes/tests/{scene}.tscn', '--quit-after', '7200']
        command += ['--verbose', '--', '--transient-session', '--locale=' + args.locale]
        try:
            result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=150)
            log = (result.stdout + result.stderr).decode('utf-8', errors='replace')
            (output / f'{scene}_{args.locale}.log').write_text(log, encoding='utf-8')
            errors = [line for line in log.splitlines() if re.search(r'FAIL|SCRIPT ERROR|Parse Error|Compile Error|^ERROR:|UID duplicate|leaked|still in use', line)]
            summaries = [line for line in log.splitlines() if re.search(r'checks=|COMPLETE', line)]
            failed |= result.returncode != 0 or bool(errors)
            print(scene, 'exit=' + str(result.returncode), *summaries, *errors[:20], sep='\n', flush=True)
        except subprocess.TimeoutExpired:
            failed = True
            print(scene + ': TIMEOUT', flush=True)
    raise SystemExit(1 if failed else 0)


if __name__ == '__main__':
    main()
