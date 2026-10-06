"""Reuse the accepted fixture with a plain production WeaponInstance."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
source = (ROOT / 'artifacts/previews/range_half_bonus_review/review.gd').read_text(encoding='utf-8')
source = '\n'.join(line for line in source.splitlines() if not line.startswith('const PREVIEW_WEAPON = ')) + '\n'
changes = {
    'source = PREVIEW_WEAPON.new()': 'source = WeaponInstance.new()',
    '\tsource.bonus_efficiency = 0.5 if review_mode == "half" else 1.0\n': '',
    '\tsource.refresh_geometry()\n': '',
    'source.bonus_efficiency': 'StatDefinitions.RANGE_BONUS_EFFICIENCY',
}
for old, new in changes.items():
    assert old in source, old
    source = source.replace(old, new)
source = source.replace('raw_range == (0 if family == "area" else score)', 'source.get_script() == preload("res://scripts/weapons/weapon_instance.gd") and raw_range == (0 if family == "area" else score)')
source = source.replace('Real GameRoot and native casting/collision/VFX. Raw equipment stats preserved; preview-only cast snapshots halve the two bonuses. Stationary durable native enemies, fixed camera, seeded environment. No production resource edits.', 'Production GameRoot and plain WeaponInstance; unified production bonus formulas, native casting/collision/VFX, raw attributes preserved. Stationary durable native targets and fixed camera, matching the approved review fixture.')
(HERE / 'production_capture.gd').write_text(source, encoding='utf-8')
(HERE / 'production_capture.tscn').write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://artifacts/previews/range_half_bonus_install/production_capture.gd" id="1"]\n\n[node name="ProductionRangeCapture" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
print('PRODUCTION_CAPTURE_READY: plain WeaponInstance, no preview adapter or stat pre-scaling')
