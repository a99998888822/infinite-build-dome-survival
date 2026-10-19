extends Node
## Preserve production scripts (ParticleWorld lookup checks the exact script path).
const COST = preload("res://scripts/tests/fixtures/dense_cost_counters.gd")
var category := "particle"

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	get_parent()._process(delta)
	var elapsed := Time.get_ticks_usec() - started
	match category:
		"particle": COST.particle_usec += elapsed
		"scheduler": COST.scheduler_usec += elapsed
		"feedback": COST.feedback_usec += elapsed
		"reflection": COST.reflection_usec += elapsed
