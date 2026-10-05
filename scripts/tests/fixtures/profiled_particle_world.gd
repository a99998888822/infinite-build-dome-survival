extends "res://scripts/effects/particle_world.gd"
## Timers wrap unchanged production methods. CPU times exclude driver/GPU work.
var sim_usec := 0
var draw_usec := 0
var emit_usec := 0
var sim_calls := 0
var draw_calls := 0
var emit_calls := 0

func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	super._process(delta)
	sim_usec += Time.get_ticks_usec() - start
	sim_calls += 1

func _draw() -> void:
	var start := Time.get_ticks_usec()
	super._draw()
	draw_usec += Time.get_ticks_usec() - start
	draw_calls += 1

func emit_event(event: Variant) -> void:
	var start := Time.get_ticks_usec()
	super.emit_event(event)
	emit_usec += Time.get_ticks_usec() - start
	emit_calls += 1

func reset_timing() -> void:
	sim_usec = 0
	draw_usec = 0
	emit_usec = 0
	sim_calls = 0
	draw_calls = 0
	emit_calls = 0
