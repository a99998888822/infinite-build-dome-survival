extends Node2D
class_name BlackHoleEffect

const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")

const DEFAULT_RADIUS: float = 100.0
const DEFAULT_DURATION: float = 0.85
const DEFAULT_PULL_SPEED: float = 150.0
const DEFAULT_DARK_DURATION: float = 2.0

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _context: RefCounted = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _pull_speed: float = DEFAULT_PULL_SPEED
var _dark_duration: float = DEFAULT_DARK_DURATION
var _elapsed: float = 0.0
var _targets: Array[EnemyController] = []


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := BlackHoleEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "black_hole", {
		"damage_multiplier": 0.65,
		"radius": DEFAULT_RADIUS,
		"duration": DEFAULT_DURATION,
		"pull_speed": DEFAULT_PULL_SPEED,
		"dark_duration": DEFAULT_DARK_DURATION,
	}, attachment_item_id)
	effect._radius = maxf(effect._context.get_resolved_parameter("radius", DEFAULT_RADIUS) * effect._context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 24.0)
	effect._duration = maxf(effect._context.get_resolved_parameter("duration", DEFAULT_DURATION), 0.1)
	effect._pull_speed = maxf(effect._context.get_resolved_parameter("pull_speed", DEFAULT_PULL_SPEED), 1.0)
	effect._dark_duration = maxf(effect._context.get_resolved_parameter("dark_duration", DEFAULT_DARK_DURATION), 0.1)
	effect.call_deferred("_arm")


func _ready() -> void:
	z_index = 79
	queue_redraw()


func _arm() -> void:
	_collect_targets()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	for enemy in _targets:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		enemy.global_position = enemy.global_position.move_toward(global_position, _pull_speed * delta)
	if _elapsed >= _duration:
		queue_free()
		return
	queue_redraw()


func _collect_targets() -> void:
	if _context == null or _damage_event == null:
		return
	var damage := maxi(1, int(roundi(float(_damage_event.original_damage) * _context.get_resolved_parameter("damage_multiplier", 0.65))))
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
		_targets.append(enemy)
		var had_light := enemy.has_status("light")
		if had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
			})
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, global_position.direction_to(enemy.global_position))
		if not had_light:
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "dark", {
				"parent": get_parent(),
				"hit_position": enemy.global_position,
				"source_id": _damage_event.source_weapon_id,
				"dark_duration": _dark_duration,
			})


func _draw() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := 0.35 + 0.65 * (1.0 - progress)
	draw_circle(Vector2.ZERO, _radius, Color(0.08, 0.06, 0.14, 0.10 * fade))
	draw_circle(Vector2.ZERO, _radius * 0.22, Color(0.01, 0.01, 0.02, 0.96 * fade))
	for index in range(3):
		var ring_radius := _radius * (0.38 + float(index) * 0.17)
		var start_angle := _elapsed * (2.0 + float(index) * 0.55) + float(index) * 1.4
		draw_arc(Vector2.ZERO, ring_radius, start_angle, start_angle + PI * 1.45, 28, Color(0.42, 0.34, 0.62, 0.72 * fade), 2.0, true)
		draw_arc(Vector2.ZERO, ring_radius, start_angle + PI, start_angle + PI * 2.45, 28, Color(0.12, 0.10, 0.20, 0.8 * fade), 2.0, true)
