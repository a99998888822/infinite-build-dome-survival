extends Node2D
const BAKED = preload("res://scripts/effects/baked_pixel_frames.gd")

const FIRE_VISUAL = preload("res://scripts/effects/pixel_fire_visual.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")
const FROST = preload("res://scripts/effects/frost_pattern.gd")
const DRAW_STATUSES := ["wet", "light", "dark", "frozen", "slowed", "holy_flame", "dark_flame"]

var _flame_visual: Node2D
var _enemy: Node = null
var _elapsed: float = 0.0
var _draw_frame: int = -1
var _draw_status_mask: int = -1
var _status_revision := -1
var _status_mask := 0
var _draw_body_radius := -1.0


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
	if _status_revision != _enemy.status_visual_revision:
		_status_revision = _enemy.status_visual_revision
		_status_mask = _enemy.get_status_visual_mask()
		_sync_flame()
	var mask := _status_mask & 31
	# These icons, the ice shell and the slowed footprint contain no clock.
	# Position is inherited; flames continue to animate on their shared clock.
	var radius := _get_body_radius() if mask != 0 else -1.0
	if mask != _draw_status_mask or radius != _draw_body_radius:
		_draw_body_radius = radius
		_draw_status_mask = mask
		queue_redraw()


func _sync_flame() -> void:
	var burning := (_status_mask & (128 | 32 | 64)) != 0
	if burning and not is_instance_valid(_flame_visual):
		_flame_visual = FIRE_VISUAL.new()
		add_child(_flame_visual)
		_flame_visual.setup_status(_get_body_radius())
	elif not burning and is_instance_valid(_flame_visual):
		_flame_visual.queue_free()
		_flame_visual = null
	if is_instance_valid(_flame_visual):
		_flame_visual.set_palette(2 if (_status_mask & 64) != 0 else (1 if (_status_mask & 32) != 0 else 0))


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
		draw_set_transform(Vector2(0,12))
		BAKED.draw(self,"slowed",0,Vector2.ONE * _get_body_radius()*0.88/16.0)
		draw_set_transform(Vector2.ZERO)


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
	BAKED.draw(self, "ice_shell", int(round(clampf(body_radius*1.1,15,25)-15)))

