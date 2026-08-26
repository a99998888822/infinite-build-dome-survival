extends Node2D

const PARTICLE_ROWS: int = 3
const PARTICLES_PER_ROW: int = 8
const BODY_RADIUS: Vector2 = Vector2(23.0, 14.0)
const PARTICLE_SIZE: Vector2 = Vector2(3.0, 2.0)

var _remaining: float = 0.65
var _duration: float = 0.65
var _elapsed: float = 0.0


static func attach(parent: Node2D, duration: float = 0.65) -> Node2D:
	if parent == null:
		return null
	var visual_script: Script = load("res://scripts/effects/lightning_status_visual.gd") as Script
	var visual: Node2D = visual_script.new() as Node2D
	parent.add_child(visual)
	visual.set("_duration", maxf(duration, 0.15))
	visual.set("_remaining", maxf(duration, 0.15))
	return visual


func refresh(duration: float = 0.65) -> void:
	_duration = maxf(_duration, duration)
	_remaining = maxf(_remaining, duration)


func _ready() -> void:
	z_index = 20
	position = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(_remaining / maxf(_duration, 0.01), 0.0, 1.0)
	for row_index in PARTICLE_ROWS:
		var row_phase: float = float(row_index) * 1.9
		for particle_index in PARTICLES_PER_ROW:
			var ratio: float = float(particle_index) / float(PARTICLES_PER_ROW)
			var orbit_angle: float = _elapsed * (5.0 + float(row_index) * 0.7) + ratio * TAU + row_phase
			var wave: float = sin(_elapsed * 13.0 + ratio * 15.0 + row_phase) * 2.8
			var particle_position := Vector2(
				cos(orbit_angle) * (BODY_RADIUS.x + wave),
				sin(orbit_angle) * (BODY_RADIUS.y + wave * 0.45),
			)
			var tangent := Vector2(-sin(orbit_angle), cos(orbit_angle)).angle()
			var particle_alpha: float = (0.55 + 0.45 * sin(_elapsed * 18.0 + ratio * TAU + row_phase)) * fade
			var blue_color := Color(0.20, 0.55, 1.0, particle_alpha * 0.72)
			var white_color := Color(0.88, 0.97, 1.0, particle_alpha)
			draw_set_transform(particle_position.round(), tangent, Vector2.ONE)
			draw_circle(Vector2.ZERO, 3.2, Color(0.25, 0.62, 1.0, particle_alpha * 0.12))
			draw_rect(Rect2(-PARTICLE_SIZE * 0.5, PARTICLE_SIZE), blue_color)
			draw_rect(Rect2(-Vector2(2.0, 0.8), Vector2(4.0, 1.6)), white_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
