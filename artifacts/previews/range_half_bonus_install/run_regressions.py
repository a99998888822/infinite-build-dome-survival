"""Run affected production regressions headlessly and retain individual logs."""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GODOT = r'D:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
SCENES = ['active_range_rules_test', 'range_relic_test', 'attribute_enchantment_test',
          'enchantment_stacking_test', 'grenade_weapon_test', 'hammer_density_test',
          'element_reaction_test', 'water_ice_atlas_test', 'plasma_contact_test',
          'weapon_trio_test', 'tome_purse_weapon_test', 'nightwatch_spear_test',
          'camp_dagger_test', 'meteor_flail_test', 'enchantment_tooltip_balance_test',
          'active_combat_integration_test']
names = sys.argv[1:] or SCENES
if not sys.argv[1:]:
    log = HERE / 'editor.log'
    result = subprocess.run([GODOT, '--headless', '--editor', '--path', str(ROOT), '--quit',
                             '--log-file', str(log)], cwd=ROOT, timeout=120)
    text = log.read_text(encoding='utf-8')
    errors = [line for line in text.splitlines() if any(t in line for t in ['SCRIPT ERROR', 'ERROR:', 'WARNING:'])]
    print('EDITOR', result.returncode, errors, flush=True)
    assert result.returncode == 0 and not errors
results = []
for name in names:
    log = HERE / f'{name}.log'
    result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--scene',
                             f'res://scenes/tests/{name}.tscn', '--log-file', str(log)], cwd=ROOT, timeout=180)
    text = log.read_text(encoding='utf-8')
    errors = [line for line in text.splitlines() if any(t in line for t in ['SCRIPT ERROR', 'ERROR:', 'FAIL ', 'WARNING:'])]
    # Some existing negative-data tests deliberately emit validator warnings.
    expected_validator_warning = name == 'attribute_enchantment_test'
    serious = [line for line in errors if not (expected_validator_warning and 'WARNING:' in line and '[DataValidator]' in line)]
    summary = [line for line in text.splitlines() if re.search(r'checks=|failures=|_PASS|_TEST ', line)]
    entry = dict(name=name, exit=result.returncode, errors=serious, summary=summary[-3:])
    results.append(entry)
    print(json.dumps(entry, ensure_ascii=True), flush=True)
(HERE / ('regressions.json' if names == SCENES else 'rerun.json')).write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(1 if any(r['exit'] or r['errors'] for r in results) else 0)
