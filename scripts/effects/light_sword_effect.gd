extends Node2D
class_name LightSwordEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const LIGHT_REFLECTION_EFFECT_SCRIPT = preload("res://scripts/effects/light_reflection_effect.gd")

const DEFAULT_RADIUS: float = 78.0
const DEFAULT_DELAY: float = 0.5
const DEFAULT_FALL_SECONDS: float = 0.22
const DEFAULT_DISSOLVE_SECONDS: float = 0.75
const DEFAULT_LIGHT_DURATION: float = 5.0

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _delay: float = DEFAULT_DELAY
var _fall_seconds: float = DEFAULT_FALL_SECONDS
var _dissolve_seconds: float = DEFAULT_DISSOLVE_SECONDS
var _light_duration: float = DEFAULT_LIGHT_DURATION
var _elapsed: float = 0.0
var _strike_started: bool = false
var _landed: bool = false


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := LightSwordEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "light_sword", {
		"damage_multiplier": 0.9,
		"radius": DEFAULT_RADIUS,
		"delay": DEFAULT_DELAY,
		"fall_seconds": DEFAULT_FALL_SECONDS,
		"dissolve_seconds": DEFAULT_DISSOLVE_SECONDS,
		"light_duration": DEFAULT_LIGHT_DURATION,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 20.0)
	effect._delay = maxf(effect._context.get_resolved_parameter("delay", DEFAULT_DELAY), 0.05)
	effect._fall_seconds = maxf(effect._context.get_resolved_parameter("fall_seconds", DEFAULT_FALL_SECONDS), 0.05)
	effect._dissolve_seconds = maxf(effect._context.get_resolved_parameter("dissolve_seconds", DEFAULT_DISSOLVE_SECONDS), 0.2)
	effect._light_duration = maxf(effect._context.get_resolved_parameter("light_duration", DEFAULT_LIGHT_DURATION), 0.1)
	effect.call_deferred("_arm")


func _ready() -> void:
	z_index = 82
	queue_redraw()


func _arm() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	if not _strike_started and _elapsed >= _delay:
		_strike_started = true
	if _strike_started and not _landed and _elapsed >= _delay + _fall_seconds:
		_land()
	if _landed and _elapsed >= _delay + _fall_seconds + _dissolve_seconds:
		queue_free()
		return
	queue_redraw()


func _land() -> void:
	if _landed or _context == null or _damage_event == null:
		return
	_landed = true
	var damage := maxi(1, int(roundi(float(_damage_event.original_damage) * _context.get_resolved_parameter("damage_multiplier", 0.9))))
	var shape := CircleShape2D.new()
	shape.radius = _radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var handled: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or handled.has(enemy.get_instance_id()):
			continue
		handled[enemy.get_instance_id()] = true
		var had_dark := enemy.has_status("dark")
		if had_dark:
			var dark_reaction_result := ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "light", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"light_duration": _light_duration,
			})
			if bool(dark_reaction_result.get("light_freeze", false)):
				LIGHT_REFLECTION_EFFECT_SCRIPT.spawn(get_parent(), enemy.global_position, _get_reflection_direction(enemy), _damage_event)
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
		if not had_dark:
			var light_reaction_result := ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "light", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"light_duration": _light_duration,
			})
			if bool(light_reaction_result.get("light_freeze", false)):
				LIGHT_REFLECTION_EFFECT_SCRIPT.spawn(get_parent(), enemy.global_position, _get_reflection_direction(enemy), _damage_event)


func _get_reflection_direction(enemy: EnemyController) -> Vector2:
	if _damage_event != null and _damage_event.source_player != null:
		return _damage_event.source_player.global_position.direction_to(enemy.global_position)
	return global_position.direction_to(enemy.global_position)


func _draw() -> void:
	var sword_position := Vector2(0.0, -190.0)
	var fall_progress := 0.0
	if _strike_started:
		fall_progress = clampf((_elapsed - _delay) / _fall_seconds, 0.0, 1.0)
		sword_position.y = lerpf(-190.0, -88.0, fall_progress)
	if not _landed:
		_draw_sword(sword_position, 1.0)
	else:
		var dissolve_progress := clampf((_elapsed - _delay - _fall_seconds) / _dissolve_seconds, 0.0, 1.0)
		var fade := 1.0 - dissolve_progress
		_draw_sword(Vector2(0.0, -38.0), fade, true)
		draw_circle(Vector2.ZERO, _radius * 0.72, Color(1.0, 1.0, 1.0, 0.10 * fade))
		for index in range(8):
			var angle := float(index) * TAU / 8.0
			draw_line(Vector2.from_angle(angle) * (_radius * 0.42), Vector2.from_angle(angle) * (_radius * 0.92), Color(1.0, 1.0, 1.0, 0.65 * fade), 2.0, true)


func _draw_sword(position: Vector2, alpha: float = 1.0, embedded: bool = false) -> void:
	var color := Color(1.0, 1.0, 1.0, alpha)
	var edge_color := Color(0.78, 0.92, 1.0, alpha)
	var blade: PackedVector2Array
	var blade_start_y := 0.0
	if embedded:
		blade = PackedVector2Array([
			position + Vector2(-7.0, 0.0),
			position + Vector2(7.0, 0.0),
			position + Vector2(5.0, 38.0),
			position + Vector2(-5.0, 38.0),
		])
	else:
		blade = PackedVector2Array([
			position + Vector2(-7.0, 0.0),
			position + Vector2(7.0, 0.0),
			position + Vector2(4.0, 64.0),
			position + Vector2(0.0, 88.0),
			position + Vector2(-4.0, 64.0),
		])
	draw_colored_polygon(blade, color)
	draw_polyline(blade + PackedVector2Array([blade[0]]), edge_color, 1.5, true)
	draw_line(position + Vector2(-18.0, blade_start_y), position + Vector2(18.0, blade_start_y), color, 5.0, true)
	draw_line(position + Vector2(0.0, blade_start_y - 1.0), position + Vector2(0.0, blade_start_y - 23.0), color, 4.0, true)
	draw_circle(position + Vector2(0.0, blade_start_y - 29.0), 5.0, color)
