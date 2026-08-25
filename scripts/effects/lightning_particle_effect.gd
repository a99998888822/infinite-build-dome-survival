extends Node2D
class_name LightningParticleEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")

var _parent_root: Node = null
var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _direction: Vector2 = Vector2.RIGHT
var _context: RefCounted = null
var _visited: Dictionary = {}
var _remaining_jumps: int = 0
var _jump_radius: float = 170.0
var _last_position: Vector2 = Vector2.ZERO


static func spawn(parent: Node, hit_position: Vector2, first_body: Node, weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := LightningParticleEffect.new()
	parent.add_child(effect)
	effect._parent_root = parent
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	effect._last_position = weapon.owner_player.global_position if weapon.owner_player != null else hit_position - effect._direction * 42.0
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "lightning", {
		"damage": maxf(float(damage_event.damage) * 0.55, 1.0),
		"chain_count": 3.0,
		"jump_radius": 170.0,
		"detonate_burning": 1.0,
	})
	effect._remaining_jumps = maxi(0, int(roundi(effect._context.get_resolved_parameter("chain_count", 3.0) + effect._context.get_resolved_parameter("control_power", 0.0) / 10.0)))
	effect._jump_radius = maxf(effect._context.get_resolved_parameter("jump_radius", 170.0) * effect._context.get_resolved_parameter("area_size_multiplier", 1.0), 32.0)
	effect.call_deferred("_strike_chain", first_body, effect._last_position)


func _strike_chain(target: Node, from_position: Vector2) -> void:
	if _weapon == null or _damage_event == null:
		queue_free()
		return
	var current := target as EnemyController
	if current == null or not current.is_alive():
		current = _find_nearest_enemy(from_position)
	if current == null:
		_emit_bolt(from_position, from_position + _direction * 42.0)
		queue_free()
		return
	var key := current.get_instance_id()
	if _visited.has(key):
		queue_free()
		return
	_visited[key] = true
	_emit_bolt(from_position, current.global_position)
	if current.has_status("burning") and _context.get_resolved_parameter("detonate_burning", 1.0) > 0.0:
		current.clear_burning()
		EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, current.global_position, _weapon, _damage_event)
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	current.take_damage(damage, _damage_event.source_weapon_id, false, from_position.direction_to(current.global_position))
	current.apply_lightning_visual(0.7)
	if _remaining_jumps <= 0:
		queue_free()
		return
	_remaining_jumps -= 1
	var next_target := _find_nearest_enemy(current.global_position)
	if next_target == null:
		queue_free()
		return
	call_deferred("_strike_chain", next_target, current.global_position)


func _find_nearest_enemy(origin: Vector2) -> EnemyController:
	var nearest: EnemyController = null
	var nearest_distance := _jump_radius * _jump_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or _visited.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _emit_bolt(start_position: Vector2, end_position: Vector2) -> void:
	var distance := start_position.distance_to(end_position)
	var steps := maxi(2, int(ceil(distance / 9.0)))
	var perpendicular := start_position.direction_to(end_position).orthogonal()
	var previous := start_position
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var point := start_position.lerp(end_position, t)
		if index > 0 and index < steps:
			point += perpendicular * randf_range(-8.0, 8.0)
		var bolt_direction := previous.direction_to(point)
		var common_parameters := {
			"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0) * maxf(_context.get_resolved_parameter("particle_rate", 1.0), 0.2),
			"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0),
			"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0),
			"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0),
			"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0),
			"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0),
		}
		var blue_color: Color = _context.get_tinted_color(Color(0.24, 0.68, 1.0, 1.0))
		var core_color: Color = Color.WHITE
		PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "lightning_blue", point, bolt_direction, 0.55, blue_color, common_parameters)
		PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "lightning_core", point, bolt_direction, 1.0, core_color, common_parameters)
		if index % 2 == 0:
			PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "lightning_spark", point, bolt_direction, 0.7, Color.TRANSPARENT, common_parameters)
		previous = point
