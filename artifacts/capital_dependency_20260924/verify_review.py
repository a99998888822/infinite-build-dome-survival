"""Validate review text as UTF-8 and report final Godot logs without console encoding assumptions."""
from pathlib import Path
import json
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
paths = [ROOT / p for p in [
    'data_config/relics.json', 'scripts/tests/relic_consistency_test.gd',
    'data_config/erosion_pressure_rules.json', 'data_config/README.md',
    'scripts/player/player_controller.gd', 'scripts/data/data_validator.gd',
    'scripts/waves/wave_manager.gd', 'scripts/tests/erosion_pressure_test.gd',
    'docs/main/18-humanity_erosion_gameplay_design.md',
    'augmentations_list.md', 'docs/main/5-relic_bond_design.md',
    'docs/asset/asset_checklist_summary.md',
    'scripts/data/humanity_economy.gd', 'scripts/data/stat_definitions.gd',
    'scripts/ui/wrapped_tooltip_label.gd', 'scripts/ui/battle_hud.gd',
    'scripts/ui/finance_popup.gd', 'scripts/ui/finance_ui_style.gd',
    'scripts/ui/enchantment_workbench.gd', 'scripts/ui/shop_offer_generator.gd',
    'scripts/ui/preparation_offer_card.gd', 'scripts/core/main_flow_coordinator.gd',
    'scripts/rewards/battle_finance_system.gd', 'scripts/rewards/inventory_trade_service.gd',
    'scripts/tests/humanity_economy_test.gd', 'scenes/tests/humanity_economy_test.tscn',
    'docs/main/19-capital_dependency_relic_review.md',
]]
paths += [p for p in OUT.iterdir() if p.suffix in ('.py', '.json', '.html', '.md') and p.name != 'verification.json']
problems = []
for path in paths:
    raw = path.read_bytes()
    text = raw.decode('utf-8')
    for index, line in enumerate(text.splitlines(), 1):
        if chr(0xfffd) in line or '?' * 4 in line:
            problems.append({'path': str(path.relative_to(ROOT)), 'line': index,
                             'text': line.encode('unicode_escape').decode('ascii')})
logs = {}
for name in ['humanity_final.log', 'visual_final.log', 'visual_final_errors.log', 'finance_final.log',
             'bootstrap_final.log', 'main_final.log', 'editor_workspace_final.log',
             'balance_relics.log', 'balance_humanity.log', 'balance_bootstrap.log', 'balance_workspace_editor.log',
             'implementation_editor.log', 'implementation_erosion.log', 'implementation_relics.log',
             'implementation_humanity.log', 'implementation_bootstrap.log', 'implementation_workspace_editor.log']:
    path = OUT / name
    text = path.read_text(encoding='utf-8') if path.exists() else ''
    logs[name] = {
        'script_errors': re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|Compile Error|^FAIL ).*$', text, re.M),
        'completion': re.findall(r'^.*(?:COMPLETE checks=|DONE failures=|self-test passed|validation warnings:|validation errors:|game root ready).*$', text, re.M),
        'cleanup_messages': re.findall(r'^.*(?:leaked|resources still in use at exit).*$', text, re.M),
    }
report = {'utf8_files_checked': len(paths), 'text_problems': problems, 'logs': logs}
(OUT / 'verification.json').write_text(json.dumps(report, ensure_ascii=True, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=True, indent=2))
assert not problems
assert not any(log['script_errors'] for log in logs.values())
