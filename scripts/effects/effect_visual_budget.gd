extends "res://scripts/effects/thunder_fire_visual_budget.gd"
## Independent admission per visual family. Gameplay never reads these tiers.
var metadata_key: StringName

func _exit_tree() -> void:
	if get_parent() != null and get_parent().has_meta(metadata_key) and get_parent().get_meta(metadata_key) == self:
		get_parent().remove_meta(metadata_key)

static func claim_visual(parent: Node, kind: String, point: Vector2) -> int:
	if not bool(GameGlobal.get_runtime_flag("review_visual_adaptive", true)): return Tier.FULL
	var key := StringName("effect_visual_budget_" + kind)
	var budget = parent.get_meta(key) if parent.has_meta(key) else null
	if not is_instance_valid(budget):
		budget = new()
		budget.metadata_key = key
		parent.add_child(budget)
		parent.set_meta(key, budget)
	return budget.claim(point)
