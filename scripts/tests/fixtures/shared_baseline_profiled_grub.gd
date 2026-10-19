extends "res://scripts/tests/fixtures/dense_profiled_grub.gd"
## Frozen hit presentation for the immediate-before performance control.
const BASELINE_HIT_VISUAL = preload("res://scripts/tests/fixtures/shared_baseline_enemy_hit_visual.gd")

func _show_hit_visual() -> void:
	if COST.no_hit_visual or sprite == null or not is_inside_tree(): return
	if not is_instance_valid(_hit_visual):
		_hit_visual = BASELINE_HIT_VISUAL.new()
		_hit_visual.name = "EnemyHitVisual"
		add_child(_hit_visual)
	_hit_visual.pulse(str(enemy_data.get("enemy_type", "normal")) not in ["elite", "boss"])
