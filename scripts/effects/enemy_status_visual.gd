extends Node2D

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const FOOT_FLAME_INTERVAL: float = 0.16

var _foot_flame_timer: float = 0.0
var _enemy: Node = null
var _elapsed: float = 0.0


func _ready() -> void:
	z_index = 25
	_enemy = get_parent()
	queue_redraw()


func _process(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	if _enemy.has_status("burning"):
		_foot_flame_timer -= delta
		if _foot_flame_timer <= 0.0:
			_foot_flame_timer = FOOT_FLAME_INTERVAL
			var parent := _enemy.get_parent()
			if parent != null:
				var flame_color := Color.WHITE if _enemy.has_status("holy_flame") else Color.TRANSPARENT
				var flame_parameters := {
					"count_multiplier": 0.7,
					"spawn_extent_multiplier": 0.62,
					"fire_white": _enemy.has_status("holy_flame"),
					"fire_dark": _enemy.has_status("dark_flame"),
				}
				PARTICLE_WORLD_SCRIPT.emit_profile(parent, "fire_flame", _enemy.global_position + Vector2(0.0, 12.0), Vector2.UP, 0.75, flame_color, flame_parameters)
	else:
		_foot_flame_timer = 0.0
	queue_redraw()


func _draw() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var icon_index := 0
	if _enemy.has_status("wet"):
		var body_radius := _get_body_radius()
		_draw_water_drop(Vector2(body_radius * 1.05 + icon_index * body_radius * 0.5, -body_radius * 1.15), clampf(body_radius * 0.18, 2.0, 5.0))
		icon_index += 1
	if _enemy.has_status("light"):
		var light_radius := _get_body_radius()
		_draw_light_sun(Vector2(light_radius * 1.05 + icon_index * light_radius * 0.5, -light_radius * 1.15), clampf(light_radius * 0.19, 2.0, 5.0))
		icon_index += 1
	if _enemy.has_status("dark"):
		var dark_radius := _get_body_radius()
		_draw_dark_eye(Vector2(dark_radius * 1.05 + icon_index * dark_radius * 0.5, -dark_radius * 1.15), clampf(dark_radius * 0.20, 2.0, 5.0))
		icon_index += 1
	if _enemy.has_status("frozen"):
		_draw_frozen_crystals(_get_body_radius())


func _get_body_radius() -> float:
	if _enemy == null:
		return 10.0
	var collision_shape := _enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return maxf((collision_shape.shape as CircleShape2D).radius, 4.0)
	var sprite := _enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		var frame_width := float(sprite.texture.get_width()) / float(maxi(sprite.hframes, 1))
		var frame_height := float(sprite.texture.get_height()) / float(maxi(sprite.vframes, 1))
		return maxf(maxf(frame_width * absf(sprite.scale.x), frame_height * absf(sprite.scale.y)) * 0.5, 4.0)
	return 10.0


func _draw_water_drop(center: Vector2, icon_radius: float) -> void:
	var half_width := icon_radius * 0.78
	var points := PackedVector2Array([
		center + Vector2(0.0, -icon_radius),
		center + Vector2(half_width, icon_radius * 0.22),
		center + Vector2(icon_radius * 0.62, icon_radius * 0.72),
		center + Vector2(icon_radius * 0.28, icon_radius),
		center + Vector2(-icon_radius * 0.28, icon_radius),
		center + Vector2(-icon_radius * 0.62, icon_radius * 0.72),
		center + Vector2(-half_width, icon_radius * 0.22),
	])
	draw_colored_polygon(points, Color(0.30, 0.78, 1.0, 0.95))


func _draw_light_sun(center: Vector2, icon_radius: float) -> void:
	draw_circle(center, icon_radius * 0.52, Color.WHITE)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var inner := center + Vector2.from_angle(angle) * icon_radius * 0.76
		var outer := center + Vector2.from_angle(angle) * icon_radius * 1.08
		draw_line(inner, outer, Color.WHITE, maxf(icon_radius * 0.22, 1.0), true)


func _draw_dark_eye(center: Vector2, icon_radius: float) -> void:
	var eye_width := icon_radius * 1.35
	var eye_height := icon_radius * 0.72
	var points := PackedVector2Array([
		center + Vector2(-eye_width, 0.0),
		center + Vector2(-eye_width * 0.42, -eye_height),
		center + Vector2.ZERO,
		center + Vector2(eye_width * 0.42, -eye_height),
		center + Vector2(eye_width, 0.0),
		center + Vector2(eye_width * 0.42, eye_height),
		center + Vector2.ZERO,
		center + Vector2(-eye_width * 0.42, eye_height),
	])
	draw_colored_polygon(points, Color(0.58, 0.60, 0.64, 0.96))
	draw_circle(center, icon_radius * 0.34, Color(0.20, 0.22, 0.26, 1.0))
	draw_line(center + Vector2(-eye_width * 0.92, eye_height * 1.15), center + Vector2(eye_width * 0.92, -eye_height * 1.15), Color(0.36, 0.38, 0.42, 1.0), maxf(icon_radius * 0.28, 1.0), true)


func _draw_frozen_crystals(body_radius: float) -> void:
	var pillar_count := 8
	var ring_radius := body_radius * 1.12
	var pillar_width := clampf(body_radius * 0.24, 2.0, 5.0)
	var pillar_height := clampf(body_radius * 0.78, 7.0, 18.0)
	for index in range(pillar_count):
		var angle := float(index) * TAU / float(pillar_count)
		var center := Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius * 0.72)
		var width_scale := 0.82 + float(index % 3) * 0.12
		var height_scale := 0.86 + float(index % 2) * 0.16
		var width := pillar_width * width_scale
		var height := pillar_height * height_scale
		var points := PackedVector2Array([
			center + Vector2(-width * 0.5, height * 0.5),
			center + Vector2(-width * 0.38, -height * 0.24),
			center + Vector2(0.0, -height * 0.5),
			center + Vector2(width * 0.38, -height * 0.24),
			center + Vector2(width * 0.5, height * 0.5),
		])
		draw_colored_polygon(points, Color(0.54, 0.86, 1.0, 0.72))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0.88, 0.98, 1.0, 0.94), 1.0, true)
