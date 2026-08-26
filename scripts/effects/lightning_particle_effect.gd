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


static func spawn(parent: Node, hit_position: Vector2, first_body: Node, weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2) -> void:
	var first_enemy := first_body as EnemyController
	if parent == null or weapon == null or damage_event == null or first_enemy == null:
		return
	var effect := LightningParticleEffect.new()
	parent.add_child(effect)
	effect._parent_root = parent
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "lightning", {
		"damage": maxf(float(damage_event.damage) * 0.55, 1.0),
		"chain_count": 3.0,
		"chain_interval": 0.06,
		"jump_radius": 170.0,
		"stun_duration": 0.7,
		"detonate_burning": 1.0,
	})
	effect._remaining_jumps = maxi(0, int(roundi(effect._context.get_resolved_parameter("chain_count", 3.0) + effect._context.get_resolved_parameter("control_power", 0.0) / 10.0)))
	effect._jump_radius = maxf(effect._context.get_resolved_parameter("jump_radius", 170.0) * effect._context.get_resolved_parameter("area_size_multiplier", 1.0), 32.0)
	effect.call_deferred("_strike_chain", first_enemy, hit_position)


func _strike_chain(target: Node, from_position: Vector2) -> void:
	if _weapon == null or _damage_event == null:
		queue_free()
		return
	var current := target as EnemyController
	if current == null:
		queue_free()
		return
	var key := current.get_instance_id()
	if _visited.has(key):
		_schedule_next(from_position)
		return
	_visited[key] = true
	if not current.is_alive():
		_emit_hit_burst(current.global_position, from_position.direction_to(current.global_position))
		_schedule_next(current.global_position)
		return
	_emit_bolt(from_position, current.global_position)
	_emit_hit_burst(current.global_position, from_position.direction_to(current.global_position))
	current.apply_lightning_stun(_context.get_resolved_parameter("stun_duration", 0.7))
	if current.has_status("burning") and _context.get_resolved_parameter("detonate_burning", 1.0) > 0.0:
		current.clear_burning()
		EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, current.global_position, _weapon, _damage_event)
	var damage := maxi(1, int(roundi(_context.get_resolved_parameter("damage", 1.0))))
	current.take_damage(damage, _damage_event.source_weapon_id, false, from_position.direction_to(current.global_position))
	if _remaining_jumps <= 0:
		queue_free()
		return
	_remaining_jumps -= 1
	_schedule_next(current.global_position)


func _schedule_next(origin: Vector2) -> void:
	if _remaining_jumps <= 0:
		queue_free()
		return
	var next_target := _find_nearest_enemy(origin)
	if next_target == null:
		queue_free()
		return
	var chain_interval := clampf(_context.get_resolved_parameter("chain_interval", 0.06), 0.01, 0.5)
	get_tree().create_timer(chain_interval).timeout.connect(Callable(self, "_strike_chain").bind(next_target, origin))


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


func _emit_hit_burst(hit_position: Vector2, burst_direction: Vector2) -> void:
	var context_parameters := {
		"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0),
		"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0),
		"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0),
		"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0),
		"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0),
		"distance_multiplier": _context.get_resolved_parameter("area_size_multiplier", 1.0),
	}
	var intensity: float = float(_context.get_resolved_parameter("area_size_multiplier", 1.0))
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, "lightning_flash", hit_position, Vector2.ZERO, intensity, Color.WHITE, context_parameters)
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, "lightning_impact", hit_position, burst_direction, intensity, Color.WHITE, context_parameters)


func _emit_bolt(start_position: Vector2, end_position: Vector2) -> void:
	var distance := start_position.distance_to(end_position)
	if distance <= 1.0:
		return
	var bolt_direction := start_position.direction_to(end_position)
	var perpendicular := bolt_direction.orthogonal()
	var strand_count := clampi(int(roundi(_context.get_resolved_parameter("projectile_count", 1.0))), 1, 3)
	var control_points := _build_bolt_control_points(start_position, end_position, bolt_direction, perpendicular)
	for strand_index in strand_count:
		var strand_offset := (float(strand_index) - float(strand_count - 1) * 0.5) * 1.2
		for control_index in range(control_points.size() - 1):
			var segment_start: Vector2 = control_points[control_index] + perpendicular * strand_offset
			var segment_end: Vector2 = control_points[control_index + 1] + perpendicular * strand_offset
			var segment_distance := segment_start.distance_to(segment_end)
			var sample_count := maxi(1, int(ceil(segment_distance / 3.5)))
			for sample_index in sample_count:
				var sample_start := segment_start.lerp(segment_end, float(sample_index) / float(sample_count))
				var sample_end := segment_start.lerp(segment_end, float(sample_index + 1) / float(sample_count))
				var segment_direction := sample_start.direction_to(sample_end)
				if segment_direction.is_zero_approx():
					segment_direction = bolt_direction
				_emit_filament(sample_start, segment_direction, strand_index)


func _build_bolt_control_points(
	start_position: Vector2,
	end_position: Vector2,
	bolt_direction: Vector2,
	perpendicular: Vector2
) -> Array[Vector2]:
	var distance := start_position.distance_to(end_position)
	var control_spacing := 24.0
	var control_count := maxi(1, int(ceil(distance / control_spacing)))
	var control_points: Array[Vector2] = [start_position]
	for control_index in range(1, control_count):
		var t := float(control_index) / float(control_count)
		var envelope := sin(t * PI)
		var offset := randf_range(-10.0, 10.0) * envelope
		control_points.append(start_position.lerp(end_position, t) + perpendicular * offset)
	control_points.append(end_position)
	return control_points


func _emit_filament(position: Vector2, direction: Vector2, strand_index: int) -> void:
	var common_parameters := {
		"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0),
		"speed_multiplier": minf(_context.get_resolved_parameter("speed_multiplier", 1.0), 1.35),
		"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0),
		"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0),
		"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0),
	}
	var profile_id := "lightning_filament_core" if strand_index == 0 else "lightning_filament"
	var color := Color.WHITE if strand_index == 0 else Color(0.90, 0.97, 1.0, 1.0)
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, profile_id, position, direction, 1.0, color, common_parameters)
