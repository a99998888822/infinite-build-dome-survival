extends Node2D
const PARTICLE_ROWS := 3
const PARTICLES_PER_ROW := 8
const DEFAULT_RADIUS := 20.0
const RING_FADE_SECONDS := 0.28
const BODY_RADIUS := Vector2(23,14)
const PARTICLE_SIZE := Vector2(3,2)
var _elapsed := 0.0
var _strike_landed := false
var _ring_fade_start_elapsed := 0.5
var _ring_radius := 20.0

func _draw() -> void:
	var fade := 1.0
	if _strike_landed:
		fade = 1.0 - clampf((_elapsed - _ring_fade_start_elapsed) / RING_FADE_SECONDS, 0.0, 1.0)
	var radius_scale := _ring_radius / DEFAULT_RADIUS
	for row_index in PARTICLE_ROWS:
		var row_phase := float(row_index) * 1.9
		for particle_index in PARTICLES_PER_ROW:
			var ratio := float(particle_index) / float(PARTICLES_PER_ROW)
			var orbit_angle := _elapsed * (5.0 + float(row_index) * 0.7) + ratio * TAU + row_phase
			var wave := sin(_elapsed * 13.0 + ratio * 15.0 + row_phase) * 2.8
			var particle_position := Vector2(
				cos(orbit_angle) * (BODY_RADIUS.x + wave),
				sin(orbit_angle) * (BODY_RADIUS.y + wave * 0.45),
			) * radius_scale
			var tangent := Vector2(-sin(orbit_angle), cos(orbit_angle)).angle()
			var particle_alpha := (0.55 + 0.45 * sin(_elapsed * 18.0 + ratio * TAU + row_phase)) * fade
			var yellow_color := Color(1.0, 0.62, 0.06, particle_alpha * 0.72)
			var bright_yellow_color := Color(1.0, 0.94, 0.34, particle_alpha)
			draw_set_transform(particle_position.round(), tangent, Vector2.ONE)
			draw_circle(Vector2.ZERO, 3.2, Color(1.0, 0.72, 0.08, particle_alpha * 0.12))
			draw_rect(Rect2(-PARTICLE_SIZE * 0.5, PARTICLE_SIZE), yellow_color)
			draw_rect(Rect2(-Vector2(2.0, 0.8), Vector2(4.0, 1.6)), bright_yellow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
