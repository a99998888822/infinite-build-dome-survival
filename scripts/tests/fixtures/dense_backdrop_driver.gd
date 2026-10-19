extends Node
## Call the original backdrop process at its position in the scene tree.
const COST = preload("res://scripts/tests/fixtures/dense_cost_counters.gd")

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	get_parent()._process(delta)
	COST.backdrop_usec += Time.get_ticks_usec() - started
