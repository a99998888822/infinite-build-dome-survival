extends Node2D
## A presentation-only clock. Damage, death signals and rewards stay synchronous.
const DURATION := 2.4
const CONVERGENCE_SECONDS := 1.5
const CAMERA_ENTER_SECONDS := 1.7
const CAMERA_RETURN_START := 1.8
const SLOW_SCALE := 0.2
var manager: Node
var active := false
var elapsed := 0.0
var subject: EnemyController
var camera: Camera2D
var previous_camera: Camera2D
var saved_scale := 1.0
var start_zoom := Vector2.ONE
var start_center := Vector2.ZERO
var focus := Vector2.ZERO
var _clock_usec := 0

func begin(enemy: EnemyController) -> bool:
	if active or not is_instance_valid(manager.player): return false
	previous_camera = manager.player.get_viewport().get_camera_2d()
	if previous_camera == null: return false
	subject = enemy
	subject.set_meta("final_execution", true)
	subject.z_index = 95
	focus = enemy.global_position + Vector2(0, -12)
	start_center = previous_camera.get_screen_center_position()
	start_zoom = previous_camera.zoom
	saved_scale = Engine.time_scale
	elapsed = 0.0
	_clock_usec = Time.get_ticks_usec()
	active = true
	z_index = 90
	camera = Camera2D.new()
	add_child(camera)
	camera.global_position = start_center
	camera.zoom = start_zoom
	camera.make_current()
	Engine.time_scale = SLOW_SCALE
	queue_redraw()
	return true

func _process(_delta: float) -> void:
	if not active: return
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _clock_usec) / 1000000.0
	_clock_usec = now
	if not is_instance_valid(manager.player) or not manager.player.is_alive() or not manager.running or manager.run_statistics.frozen:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	elapsed += real_delta
	var enter := smoothstep(0.0, CAMERA_ENTER_SECONDS, elapsed)
	var leave := smoothstep(CAMERA_RETURN_START, DURATION, elapsed)
	var weight := enter * (1.0 - leave)
	camera.zoom = start_zoom * lerpf(1.0, 1.425, weight)
	var return_center: Vector2 = manager.player.global_position + previous_camera.offset
	camera.global_position = start_center.lerp(focus, enter).lerp(return_center, leave).round()
	if is_instance_valid(subject):
		subject.modulate.a = 1.0 - smoothstep(1.7, 2.15, elapsed)
	queue_redraw()
	if elapsed >= DURATION: cancel()

func cancel() -> void:
	if not active: return
	active = false
	Engine.time_scale = saved_scale
	if is_instance_valid(previous_camera): previous_camera.make_current()
	if is_instance_valid(camera):
		camera.enabled = false
		camera.queue_free()
	if is_instance_valid(subject): subject.queue_free()
	subject = null
	queue_redraw()

func _exit_tree() -> void:
	cancel()

func _draw() -> void:
	if not active: return
	var strength := smoothstep(0.0, 0.20, elapsed) * (1.0 - smoothstep(1.7, DURATION, elapsed))
	var center := to_local(focus).snapped(Vector2(2, 2))
	draw_rect(Rect2(center - Vector2(5000, 5000), Vector2(10000, 10000)), Color(0.015, 0.02, 0.045, strength * 0.48))
	# Fixed angular variation avoids noisy particles and keeps the target readable.
	for i in 15:
		var angle := TAU * float(i) / 15.0 + sin(float(i) * 7.3) * 0.12
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.orthogonal()
		var delay := fmod(float(i) * 0.073, 0.24)
		var travel := clampf((elapsed - delay) / CONVERGENCE_SECONDS, 0.0, 1.0)
		var arrival := smoothstep(0.78, 1.0, travel)
		var inner := lerpf(220.0 + fmod(float(i) * 37.0, 100.0), 0.0, travel)
		var length := (65.0 + fmod(float(i) * 37.0, 105.0)) * (1.0 - arrival)
		var outer := inner + length
		var width := (1.5 + fmod(float(i) * 1.3, 3.5)) * (1.0 - arrival)
		if elapsed <= delay or travel >= 0.99: continue
		var vertices := PackedVector2Array()
		for point in [direction * inner, direction * (inner + length * 0.3) + side * width, direction * outer + side * width * 0.4, direction * (outer + 12.0 * (1.0 - arrival)), direction * outer - side * width * 0.4, direction * (inner + length * 0.3) - side * width]:
			vertices.append(center + point) # The world viewport provides pixel stepping.
		var tint := Color("ffe6a0") if i % 3 == 0 else Color("fff8dd")
		tint.a = strength * smoothstep(0.0, 0.12, travel) * (1.0 - arrival)
		draw_colored_polygon(vertices, tint)
	var flash := smoothstep(1.25, 1.7, elapsed) * (1.0 - smoothstep(1.7, 2.05, elapsed))
	if flash > 0.0:
		draw_rect(Rect2(center - Vector2(12, 4), Vector2(24, 8)), Color(1.0, 0.92, 0.7, flash * 0.8))
		draw_rect(Rect2(center - Vector2(4, 12), Vector2(8, 24)), Color(1.0, 0.97, 0.86, flash * 0.8))
