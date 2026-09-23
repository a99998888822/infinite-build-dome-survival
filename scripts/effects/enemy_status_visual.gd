extends Node2D

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")
const FOOT_FLAME_INTERVAL: float = 0.16

var _foot_flame_timer: float = 0.0
var _enemy: Node = null
var _elapsed: float = 0.0
var _draw_frame: int = -1
var _draw_status_mask: int = -1


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
	if _enemy.has_status("burning") and not _enemy.has_status("holy_flame") and not _enemy.has_status("dark_flame"):
		_foot_flame_timer -= delta
		if _foot_flame_timer <= 0.0:
			_foot_flame_timer = FOOT_FLAME_INTERVAL
			var parent := _enemy.get_parent()
			if parent != null:
				var flame_color := Color.WHITE if _enemy.has_status("holy_flame") else Color.TRANSPARENT
				var flame_parameters := {
					"count_multiplier": 0.35,
					"spawn_extent_multiplier": 0.62,
					"fire_white": _enemy.has_status("holy_flame"),
					"fire_dark": _enemy.has_status("dark_flame"),
				}
				PARTICLE_WORLD_SCRIPT.emit_profile(parent, "fire_flame", _enemy.global_position + Vector2(0.0, 12.0), Vector2.UP, 0.75, flame_color, flame_parameters)
	else:
		_foot_flame_timer = 0.0
	# The silhouettes animate at 12 fps. Redraw immediately for status changes,
	# but avoid rebuilding identical pixel polygons every render frame.
	var next_frame := int(_elapsed * 12.0)
	var mask := 0
	var statuses := ["wet", "light", "dark", "frozen", "slowed", "holy_flame", "dark_flame"]
	for index in statuses.size():
		if _enemy.has_status(statuses[index]): mask |= 1 << index
	if next_frame != _draw_frame or mask != _draw_status_mask:
		_draw_frame = next_frame
		_draw_status_mask = mask
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
	elif _enemy.has_status("slowed"):
		for side in [-1, 1]:
			PIXEL.line(self, Vector2(side * 7, 12), Vector2(side * 14, 12), Color(0.48, 0.73, 0.79, 0.75))
	if _enemy.has_status("holy_flame") or _enemy.has_status("dark_flame"):
		_draw_transformed_flame(_enemy.has_status("holy_flame"))


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
	var width := clampf(body_radius * 1.10, 15.0, 25.0)
	var shell := PackedVector2Array([
		Vector2(-width, 12), Vector2(-width - 3, -4), Vector2(-width * 0.55, -24),
		Vector2(width * 0.45, -29), Vector2(width + 3, -7), Vector2(width, 14), Vector2(-width, 12),
	])
	# Transparent central pane keeps the monster readable inside the ice.
	PIXEL.polygon(self, shell, Color(0.30, 0.71, 0.87, 0.13))
	PIXEL.path(self, shell, Color(0.69, 0.95, 0.98, 0.92), 2)
	PIXEL.polygon(self, PackedVector2Array([shell[0], shell[1], shell[2], Vector2(-width * 0.65, 8)]), Color(0.25, 0.63, 0.79, 0.5))
	PIXEL.polygon(self, PackedVector2Array([shell[3], shell[4], shell[5], Vector2(width * 0.65, 1)]), Color(0.57, 0.85, 0.95, 0.38))
	for side in [-1.0, 1.0]:
		SHAPES.shard(self, Vector2(side * width, 11), Vector2(side * 0.3, -1), 17, 4)
		PIXEL.path(self, PackedVector2Array([Vector2(side * width, -12), Vector2(side * (width - 5), -6), Vector2(side * (width - 2), 1)]), Color(0.81, 0.99, 1.0, 0.78), 2)
	PIXEL.line(self, Vector2(-width, 14), Vector2(width, 14), Color(0.37, 0.72, 0.83, 0.92), 4)


func _draw_transformed_flame(holy: bool) -> void:
	var clock := floorf(_elapsed * 12.0) / 12.0
	for index in range(3):
		var side := float(index - 1)
		var height := 17.0 if index == 1 else 32.0 + sin(clock * 6 + index * 2) * 5.0
		SHAPES.flame(self, Vector2(side * 16, 18), height, 11 if holy else 13, clock * (6 if holy else -5) + index * 2, holy)
	if holy:
		SHAPES.star(self, Vector2(0, -33), 6 + sin(clock * 3), Color(1.0, 0.88, 0.44, 0.92))
		for side in [-1.0, 1.0]:
			PIXEL.line(self, Vector2(side * 10, -28), Vector2(side * 17, -24), Color(0.96, 0.69, 0.21, 0.8), 2)
	else:
		for index in range(3):
			var age := fmod(clock * 0.75 + index * 0.33, 1.0)
			var ember := Vector2(sin(age * 6 + index * 2) * 22, 10 - age * 38)
			PIXEL.block(self, ember, Vector2(2, 4), Color(0.60, 0.44, 0.85, (1.0 - age) * 0.8))
