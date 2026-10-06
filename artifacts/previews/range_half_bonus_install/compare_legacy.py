"""Control run of old regressions at full bonus efficiency, without touching production."""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
CONTROL = HERE / 'control' / 'project'
GODOT = r'D:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
TESTS = ['grenade_weapon_test', 'plasma_contact_test', 'weapon_trio_test',
         'tome_purse_weapon_test', 'nightwatch_spear_test', 'camp_dagger_test', 'meteor_flail_test']
CONTROL.mkdir(parents=True, exist_ok=True)
(CONTROL.parent / '.gdignore').write_text('', encoding='utf-8')
for directory in ['assets', 'autoloads', 'data_config', 'scenes', 'scripts', 'shaders']:
    shutil.copytree(ROOT / directory, CONTROL / directory, dirs_exist_ok=True)
shutil.copy2(ROOT / 'project.godot', CONTROL / 'project.godot')
# Reuse only imports referenced by real project assets, not the screenshot archive.
for config in (ROOT / 'assets').rglob('*.import'):
    for relative in re.findall(r'res://(\.godot/imported/[^"\s]+)', config.read_text(encoding='utf-8')):
        source = ROOT / relative
        if source.is_file():
            target = CONTROL / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
stat = CONTROL / 'scripts/data/stat_definitions.gd'
content = stat.read_text(encoding='utf-8').replace('RANGE_BONUS_EFFICIENCY: float = 0.5', 'RANGE_BONUS_EFFICIENCY: float = 1.0')
stat.write_text(content, encoding='utf-8')
for name in TESTS:
    # These seven files had no user edits before this task; restore their old
    # range assertions in this control project only.
    relative = f'scripts/tests/{name}.gd'
    original = subprocess.check_output(['git', 'show', f'HEAD:{relative}'], cwd=ROOT)
    (CONTROL / relative).write_bytes(original)
print('CONTROL_PROJECT_READY', flush=True)
subprocess.run([GODOT, '--headless', '--editor', '--path', str(CONTROL), '--quit',
                '--log-file', str(HERE / 'control_editor.log')], timeout=120, check=True)
current = {entry['name']: entry for entry in json.loads((HERE / 'regressions.json').read_text(encoding='utf-8'))}
results = []
for name in TESTS:
    log = HERE / f'control_{name}.log'
    run = subprocess.run([GODOT, '--headless', '--path', str(CONTROL), '--scene',
                          f'res://scenes/tests/{name}.tscn', '--log-file', str(log)], timeout=180)
    text = log.read_text(encoding='utf-8')
    old_failures = [line for line in text.splitlines() if 'FAIL ' in line]
    new_failures = [line for line in current[name]['errors'] if 'FAIL ' in line]
    entry = dict(name=name, control_exit=run.returncode, control_failures=old_failures,
                 current_failures=new_failures, same_failures=old_failures == new_failures,
                 introduced=[line for line in new_failures if line not in old_failures])
    results.append(entry)
    print(json.dumps(dict(name=name, full_efficiency_failures=len(old_failures),
                         half_efficiency_failures=len(new_failures), introduced=entry['introduced']), ensure_ascii=True), flush=True)
(HERE / 'legacy_control.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(1 if any(entry['introduced'] for entry in results) else 0)
