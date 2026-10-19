extends Node
const COST = preload("res://scripts/tests/fixtures/dense_cost_counters.gd")

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	get_parent()._physics_process(delta)
	COST.weapon_usec += Time.get_ticks_usec() - started
