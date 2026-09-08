extends Node2D
class_name LightningParticleEffect

signal ground_strike_landed

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")

const CHAIN_DISPLAY_ECHO_DELAY: float = 0.12
const CHAIN_CONTROL_POINT_SPACING: float = 24.0
const CHAIN_CONTROL_POINT_JITTER: float = 26.0
const BOLT_PULSE_LIFETIME: float = 0.38
const BOLT_CORE_PARTICLE_SIZE: Vector2 = Vector2(4.0, 2.0)
const BOLT_COMPANION_PARTICLE_SIZE: Vector2 = Vector2(3.0, 2.0)
const BOLT_GLOW_PARTICLE_SIZE: float = 5.0
const BOLT_PARTICLE_SPACING: float = 3.25
const BOLT_MICRO_JITTER: float = 2.2
const GROUND_STRIKE_ECHO_COUNT: int = 2
const GROUND_STRIKE_CHAIN_COUNT: int = 2
const GROUND_STRIKE_CONTROL_POINT_SPACING: float = 24.0
const GROUND_STRIKE_JITTER_MULTIPLIER: float = 12.0 / CHAIN_CONTROL_POINT_JITTER
const GROUND_STRIKE_SAMPLE_JITTER_MULTIPLIER: float = 0.0
const GROUND_STRIKE_PARTICLE_SPACING: float = 1.5
const GROUND_STRIKE_IMPACT_RING_LIFETIME: float = 0.42
const GROUND_STRIKE_IMPACT_RING_START_RADIUS: float = 7.0
const DEFAULT_CHAIN_COUNT: float = 1.0
const DEFAULT_CHAIN_INTERVAL: float = 0.10
const DEFAULT_JUMP_RADIUS: float = 170.0
const DEFAULT_STUN_DURATION: float = 0.5

var _parent_root: Node = null
var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _direction: Vector2 = Vector2.RIGHT
var _attachment_item_id: String = ""
var _context: RefCounted = null
var _resolved_parameters: Dictionary = {}
var _visited: Dictionary = {}
var _remaining_jumps: int = 0
var _chain_selection_step: int = 0
var _jump_radius: float = 170.0
var _pending_display_echoes: int = 0
var _chain_finished: bool = false
var _bolt_pulses: Array[Dictionary] = []
var _display_echo_count: int = 2
var _control_point_jitter_multiplier: float = 1.0
var _sample_jitter_multiplier: float = 1.0
var _longitudinal_sample_jitter_multiplier: float = 1.0
var _bolt_particle_spacing: float = BOLT_PARTICLE_SPACING
var _control_point_spacing: float = CHAIN_CONTROL_POINT_SPACING
var _control_point_envelope_power: float = 1.3
var _is_ground_strike: bool = false
var _ground_strike_damage_radius: float = 0.0
var _ground_strike_position: Vector2 = Vector2.ZERO
var _ground_strike_impact_age: float = -1.0
var _ground_strike_damage_applied: bool = false
var _light_field: Node = null


func _exit_tree() -> void:
	if EffectScheduler != null and EffectScheduler.has_method("cancel_owner"):
		EffectScheduler.cancel_owner(self)


static func spawn(parent: Node, hit_position: Vector2, first_body: Node, weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2, attachment_item_id: String = "") -> void:
	var first_enemy := first_body as EnemyController
	if parent == null or weapon == null or damage_event == null or first_enemy == null:
		return
	var visual_parent := PARTICLE_WORLD_SCRIPT.find_render_world(parent)
	if visual_parent != null:
		parent = visual_parent
	var effect := LightningParticleEffect.new()
	parent.add_child(effect)
	effect._parent_root = parent
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._attachment_item_id = attachment_item_id
	effect._direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "lightning", {
		"damage": maxf(float(damage_event.damage) * 0.55, 1.0),
		"chain_count": DEFAULT_CHAIN_COUNT,
		"chain_interval": DEFAULT_CHAIN_INTERVAL,
		"jump_radius": DEFAULT_JUMP_RADIUS,
		"stun_duration": DEFAULT_STUN_DURATION,
		"detonate_burning": 1.0,
	}, effect._attachment_item_id)
	effect._cache_resolved_parameters()
	effect._remaining_jumps = maxi(2, int(roundi(effect._get_cached_parameter("chain_count", DEFAULT_CHAIN_COUNT) + effect._get_cached_parameter("control_power", 0.0) / 10.0)))
	effect._chain_selection_step = 0
	effect._jump_radius = maxf(effect._get_cached_parameter("jump_radius", DEFAULT_JUMP_RADIUS) * effect._get_cached_parameter("attack_range_multiplier", 1.0), 32.0)
	effect.call_deferred("_strike_chain", first_enemy, hit_position)


static func spawn_ground_strike(parent: Node, ground_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "", strike_height: float = 182.0, damage_radius: float = 20.0) -> LightningParticleEffect:
	if parent == null or weapon == null or damage_event == null:
		return null
	var visual_parent := PARTICLE_WORLD_SCRIPT.find_render_world(parent)
	if visual_parent != null:
		parent = visual_parent
	var effect := LightningParticleEffect.new()
	parent.add_child(effect)
	effect._parent_root = parent
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._attachment_item_id = attachment_item_id
	effect._is_ground_strike = true
	effect._ground_strike_damage_radius = maxf(damage_radius, 1.0)
	effect._ground_strike_position = ground_position
	effect._ground_strike_damage_applied = false
	effect.global_position = ground_position
	effect._direction = Vector2.DOWN
	effect._display_echo_count = GROUND_STRIKE_ECHO_COUNT
	effect._control_point_jitter_multiplier = GROUND_STRIKE_JITTER_MULTIPLIER
	effect._sample_jitter_multiplier = GROUND_STRIKE_SAMPLE_JITTER_MULTIPLIER
	effect._longitudinal_sample_jitter_multiplier = 0.0
	effect._bolt_particle_spacing = GROUND_STRIKE_PARTICLE_SPACING
	effect._control_point_spacing = GROUND_STRIKE_CONTROL_POINT_SPACING
	effect._control_point_envelope_power = 0.65
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "electric_spark", {
		"damage": maxf(float(damage_event.damage) * 0.72, 1.0),
		"strike_height": strike_height,
		"detonate_burning": 1.0,
	}, effect._attachment_item_id)
	effect._cache_resolved_parameters()
	effect._chain_finished = true
	effect.call_deferred("_strike_ground", ground_position)
	return effect


func _strike_chain(target: Node, from_position: Vector2) -> void:
	if _weapon == null or _damage_event == null:
		_finish_chain()
		return
	var current := target as EnemyController
	if current == null:
		_finish_chain()
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
	var reaction_result := ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(current, "electric", {
		"parent": _parent_root,
		"hit_position": current.global_position,
		"source_id": _damage_event.source_weapon_id,
		"stun_duration": _get_cached_parameter("stun_duration", DEFAULT_STUN_DURATION),
		"detonate_burning": _get_cached_parameter("detonate_burning", 1.0),
	})
	if bool(reaction_result.get("burning_detonated", false)):
		for explosion_instance in _weapon.get_effect_instances("explosion"):
			EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, current.global_position, _weapon, _damage_event, str(explosion_instance.get("item_instance_id", "")))
	var damage := maxi(1, int(roundi(_get_cached_parameter("damage", 1.0))))
	current.take_damage(damage, _damage_event.source_weapon_id, false, from_position.direction_to(current.global_position))
	if bool(reaction_result.get("extra_trigger", false)):
		_remaining_jumps += 1
	if _remaining_jumps <= 0:
		_finish_chain()
		return
	_remaining_jumps -= 1
	_schedule_next(current.global_position)


func _strike_ground(ground_position: Vector2) -> void:
	if _context == null:
		queue_free()
		return
	var strike_height := maxf(_get_cached_parameter("strike_height", 182.0), 96.0)
	_ground_strike_position = ground_position
	_ground_strike_impact_age = 0.0
	_emit_bolt(ground_position + Vector2.UP * strike_height, ground_position)
	_emit_hit_burst(ground_position, Vector2.DOWN)
	if not _ground_strike_damage_applied:
		_ground_strike_damage_applied = true
		_damage_ground_enemies(ground_position)
	ground_strike_landed.emit()
	_try_finish_chain()


func _damage_ground_enemies(ground_position: Vector2) -> void:
	var radius := _ground_strike_damage_radius
	var damage := maxi(1, int(roundi(_get_cached_parameter("damage", 1.0))))
	var candidate_enemies: Dictionary = {}
	if radius <= 0.0 or _damage_event == null:
		return

	# The group pass is deliberately kept as a fallback for the landing frame:
	# an enemy can be in the scene while its physics shape has not been flushed
	# into the direct-space query yet.
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(ground_position) <= radius * radius:
			candidate_enemies[enemy.get_instance_id()] = enemy

	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, ground_position)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy := result.get("collider") as EnemyController
		if enemy != null and enemy.is_alive():
			candidate_enemies[enemy.get_instance_id()] = enemy

	for enemy_variant in candidate_enemies.values():
		var enemy := enemy_variant as EnemyController
		if enemy == null or not enemy.is_alive():
			continue
		var hit_direction := ground_position.direction_to(enemy.global_position)
		if hit_direction.is_zero_approx():
			hit_direction = Vector2.DOWN
		var strike_damage_event := _damage_event.duplicate_event()
		strike_damage_event.hit_position = enemy.global_position
		var dealt_damage := enemy.take_damage(
			damage,
			strike_damage_event.source_weapon_id,
			strike_damage_event.is_critical,
			hit_direction,
		)
		if dealt_damage > 0:
			_emit_hit_burst(enemy.global_position, hit_direction)
		var reaction_result := ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "electric", {
			"parent": _parent_root,
			"hit_position": enemy.global_position,
			"source_id": _damage_event.source_weapon_id,
			"stun_duration": _get_cached_parameter("stun_duration", DEFAULT_STUN_DURATION),
			"detonate_burning": _get_cached_parameter("detonate_burning", 1.0),
		})
		if bool(reaction_result.get("burning_detonated", false)):
			for explosion_instance in _weapon.get_effect_instances("explosion"):
				EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, enemy.global_position, _weapon, _damage_event, str(explosion_instance.get("item_instance_id", "")))
		if bool(reaction_result.get("extra_trigger", false)):
			var extra_damage := enemy.take_damage(damage, _damage_event.source_weapon_id, false, hit_direction)
			if extra_damage > 0:
				_emit_hit_burst(enemy.global_position, hit_direction)
			_emit_bolt(ground_position + Vector2.UP * _get_cached_parameter("strike_height", 182.0), ground_position)


func _schedule_next(origin: Vector2) -> void:
	if _remaining_jumps <= 0:
		_finish_chain()
		return
	var next_target := _find_farthest_enemy(origin) if _chain_selection_step == 0 else _find_random_enemy()
	if next_target == null:
		_finish_chain()
		return
	_chain_selection_step += 1
	var chain_interval := clampf(_get_cached_parameter("chain_interval", DEFAULT_CHAIN_INTERVAL), 0.02, 0.5)
	EffectScheduler.schedule(chain_interval, Callable(self, "_strike_chain").bind(next_target, origin), self)


func _find_farthest_enemy(origin: Vector2) -> EnemyController:
	var farthest: EnemyController = null
	var farthest_distance := -1.0
	var jump_radius_squared := _jump_radius * _jump_radius
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or _visited.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance <= jump_radius_squared and distance >= farthest_distance:
			farthest_distance = distance
			farthest = enemy
	return farthest


func _find_random_enemy() -> EnemyController:
	var candidates: Array[EnemyController] = []
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy != null and enemy.is_alive() and not _visited.has(enemy.get_instance_id()):
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi_range(0, candidates.size() - 1)]


func _emit_hit_burst(hit_position: Vector2, burst_direction: Vector2) -> void:
	var context_parameters := {
		"count_multiplier": _get_cached_parameter("count_multiplier", 1.0),
		"speed_multiplier": _get_cached_parameter("speed_multiplier", 1.0),
		"size_multiplier": _get_cached_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": _get_cached_parameter("lifetime_multiplier", 1.0),
		"glow_multiplier": _get_cached_parameter("glow_multiplier", 1.0),
		"alpha_multiplier": _get_cached_parameter("alpha_multiplier", 1.0),
		"distance_multiplier": _get_cached_parameter("attack_range_multiplier", 1.0),
	}
	var intensity: float = _get_cached_parameter("attack_range_multiplier", 1.0)
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, "lightning_flash", hit_position, Vector2.ZERO, intensity, Color.WHITE, context_parameters)
	PARTICLE_WORLD_SCRIPT.emit_profile(_parent_root, "lightning_impact", hit_position, burst_direction, intensity, Color.WHITE, context_parameters)


func _emit_bolt(start_position: Vector2, end_position: Vector2) -> void:
	var chain_count := GROUND_STRIKE_CHAIN_COUNT if _is_ground_strike else 1
	for chain_index in chain_count:
		_emit_bolt_pulse(start_position, end_position, chain_index)
	for echo_index in range(1, _display_echo_count):
		_pending_display_echoes += 1
		EffectScheduler.schedule(CHAIN_DISPLAY_ECHO_DELAY * float(echo_index), Callable(self, "_emit_bolt_echo").bind(start_position, end_position), self)


func _emit_bolt_echo(start_position: Vector2, end_position: Vector2) -> void:
	_pending_display_echoes = maxi(_pending_display_echoes - 1, 0)
	if _is_ground_strike:
		_bolt_pulses.clear()
	var chain_count := GROUND_STRIKE_CHAIN_COUNT if _is_ground_strike else 1
	for chain_index in chain_count:
		_emit_bolt_pulse(start_position, end_position, chain_index)
	_try_finish_chain()


func _emit_bolt_pulse(start_position: Vector2, end_position: Vector2, path_index: int = 0) -> void:
	var distance := start_position.distance_to(end_position)
	if distance <= 1.0:
		return
	var bolt_direction := start_position.direction_to(end_position)
	var perpendicular := bolt_direction.orthogonal()
	var strand_count := 1 if _is_ground_strike else clampi(int(roundi(_get_cached_parameter("projectile_count", 1.0))), 1, 3)
	var size_multiplier := clampf(_get_cached_parameter("size_multiplier", 1.0), 0.5, 2.0)
	var glow_multiplier := clampf(_get_cached_parameter("glow_multiplier", 1.0), 0.25, 3.0)
	var lifetime_multiplier := clampf(_get_cached_parameter("lifetime_multiplier", 1.0), 0.5, 2.0)
	var alpha_multiplier := clampf(_get_cached_parameter("alpha_multiplier", 1.0), 0.0, 2.0)
	var control_points := _get_bolt_control_points(start_position, end_position, bolt_direction, perpendicular, path_index)
	var control_segment_count := control_points.size() - 1
	var inverse_control_segment_count := 1.0 / float(control_segment_count)
	for strand_index in strand_count:
		var strand_offset := (float(strand_index) - float(strand_count - 1) * 0.5) * 1.2
		var particle_points := PackedVector2Array()
		var particle_rotations := PackedFloat32Array()
		for control_index in control_segment_count:
			var segment_start: Vector2 = control_points[control_index] + perpendicular * strand_offset
			var segment_end: Vector2 = control_points[control_index + 1] + perpendicular * strand_offset
			var segment_distance := segment_start.distance_to(segment_end)
			var sample_count := maxi(1, int(ceil(segment_distance / _bolt_particle_spacing)))
			var segment_direction := segment_start.direction_to(segment_end)
			var segment_perpendicular := segment_direction.orthogonal()
			for sample_index in sample_count:
				var sample_ratio := float(sample_index) / float(sample_count)
				var sample_position := segment_start.lerp(segment_end, sample_ratio)
				if not segment_direction.is_zero_approx() and sample_index > 0 and sample_index < sample_count:
					var path_ratio := (float(control_index) + sample_ratio) * inverse_control_segment_count
					var jitter_envelope := pow(sin(path_ratio * PI), _control_point_envelope_power)
					sample_position += segment_perpendicular * randf_range(-BOLT_MICRO_JITTER, BOLT_MICRO_JITTER) * _sample_jitter_multiplier * jitter_envelope
					sample_position += segment_direction * randf_range(-0.7, 0.7) * _longitudinal_sample_jitter_multiplier * jitter_envelope
				var sample_point := to_local(sample_position).round()
				if particle_points.is_empty() or particle_points[particle_points.size() - 1].distance_squared_to(sample_point) > 0.25:
					particle_points.append(sample_point)
					particle_rotations.append(randf_range(-PI, PI))
			var end_point := to_local(segment_end).round()
			if particle_points.is_empty() or particle_points[particle_points.size() - 1].distance_squared_to(end_point) > 0.25:
				particle_points.append(end_point)
				particle_rotations.append(randf_range(-PI, PI))
		var strand_color := Color.WHITE
		if strand_index > 0:
			strand_color.a = 0.9
		strand_color.a *= alpha_multiplier
		_bolt_pulses.append({
			"points": particle_points,
			"rotations": particle_rotations,
			"age": 0.0,
			"lifetime": BOLT_PULSE_LIFETIME * lifetime_multiplier,
			"color": strand_color,
			"size_multiplier": size_multiplier,
			"particle_size": BOLT_CORE_PARTICLE_SIZE if strand_index == 0 else BOLT_COMPANION_PARTICLE_SIZE,
			"glow_size": BOLT_GLOW_PARTICLE_SIZE * glow_multiplier,
			"is_core": strand_index == 0,
		})
	_emit_bolt_light(start_position.lerp(end_position, 0.5), distance, glow_multiplier)
	queue_redraw()


func _emit_bolt_light(global_position: Vector2, distance: float, glow_multiplier: float) -> void:
	if _parent_root == null:
		return
	if _light_field == null or not is_instance_valid(_light_field) or not _light_field.has_method("add_light"):
		_light_field = PARTICLE_WORLD_SCRIPT.find_light_field(_parent_root)
	var field := _light_field
	if field != null and field.has_method("add_light"):
		field.call("add_light", global_position, Color(0.74, 0.90, 1.0, 1.0), 0.18 * glow_multiplier, clampf(distance * 0.42, 36.0, 130.0), BOLT_PULSE_LIFETIME)


func _finish_chain() -> void:
	_chain_finished = true
	_try_finish_chain()


func _try_finish_chain() -> void:
	if _chain_finished and _pending_display_echoes <= 0 and _bolt_pulses.is_empty():
		queue_free()


func _build_bolt_control_points(
	start_position: Vector2,
	end_position: Vector2,
	bolt_direction: Vector2,
	perpendicular: Vector2,
	jitter_multiplier: float = 1.0
) -> Array[Vector2]:
	var distance := start_position.distance_to(end_position)
	var control_count := maxi(1, int(ceil(distance / _control_point_spacing)))
	var control_points: Array[Vector2] = [start_position]
	for control_index in range(1, control_count):
		var t := float(control_index) / float(control_count)
		var envelope := pow(sin(t * PI), _control_point_envelope_power)
		var offset := randf_range(-CHAIN_CONTROL_POINT_JITTER, CHAIN_CONTROL_POINT_JITTER) * jitter_multiplier * envelope
		control_points.append(start_position.lerp(end_position, t) + perpendicular * offset)
	control_points.append(end_position)
	return control_points


func _get_bolt_control_points(
	start_position: Vector2,
	end_position: Vector2,
	bolt_direction: Vector2,
	perpendicular: Vector2,
	path_index: int = 0
) -> Array[Vector2]:
	return _build_bolt_control_points(
		start_position,
		end_position,
		bolt_direction,
		perpendicular,
		_control_point_jitter_multiplier
	)


func _cache_resolved_parameters() -> void:
	if _context == null:
		_resolved_parameters.clear()
		return
	_resolved_parameters = {
		"chain_count": _context.get_resolved_parameter("chain_count", DEFAULT_CHAIN_COUNT),
		"chain_interval": _context.get_resolved_parameter("chain_interval", DEFAULT_CHAIN_INTERVAL),
		"jump_radius": _context.get_resolved_parameter("jump_radius", DEFAULT_JUMP_RADIUS),
		"stun_duration": _context.get_resolved_parameter("stun_duration", DEFAULT_STUN_DURATION),
		"detonate_burning": _context.get_resolved_parameter("detonate_burning", 1.0),
		"damage": _context.get_resolved_parameter("damage", 1.0),
		"control_power": _context.get_resolved_parameter("control_power", 0.0),
		"attack_range_multiplier": _context.get_resolved_parameter("attack_range_multiplier", 1.0),
		"projectile_count": _context.get_resolved_parameter("projectile_count", 1.0),
		"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0),
		"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0),
		"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0),
		"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0),
		"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0),
		"strike_height": _context.get_resolved_parameter("strike_height", 182.0),
	}


func _get_cached_parameter(channel: String, fallback: float = 0.0) -> float:
	return float(_resolved_parameters.get(channel, fallback))


func _ready() -> void:
	z_index = 81
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for index in range(_bolt_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _bolt_pulses[index]
		pulse["age"] = float(pulse.get("age", 0.0)) + delta
		if float(pulse["age"]) >= float(pulse["lifetime"]):
			_bolt_pulses.remove_at(index)
		else:
			_bolt_pulses[index] = pulse
	if _is_ground_strike and _ground_strike_impact_age >= 0.0:
		_ground_strike_impact_age += delta
	queue_redraw()
	_try_finish_chain()


func _draw() -> void:
	if _is_ground_strike and _ground_strike_impact_age >= 0.0 and _ground_strike_impact_age < GROUND_STRIKE_IMPACT_RING_LIFETIME:
		var impact_ratio := clampf(_ground_strike_impact_age / GROUND_STRIKE_IMPACT_RING_LIFETIME, 0.0, 1.0)
		var impact_center := to_local(_ground_strike_position)
		var impact_radius := lerpf(GROUND_STRIKE_IMPACT_RING_START_RADIUS, _ground_strike_damage_radius, impact_ratio)
		var impact_alpha := (1.0 - impact_ratio) * 0.68
		draw_circle(impact_center, impact_radius, Color(1.0, 0.92, 0.42, impact_alpha * 0.10))
		draw_arc(impact_center, impact_radius, 0.0, TAU, 32, Color(1.0, 0.96, 0.58, impact_alpha), 2.0, true)
	for pulse in _bolt_pulses:
		var points: PackedVector2Array = pulse["points"]
		if points.size() < 2:
			continue
		var lifetime := maxf(float(pulse.get("lifetime", BOLT_PULSE_LIFETIME)), 0.01)
		var age_ratio := clampf(float(pulse.get("age", 0.0)) / lifetime, 0.0, 1.0)
		var fade := (1.0 - age_ratio) * (1.0 - age_ratio)
		var base_color: Color = pulse["color"]
		var alpha := base_color.a * fade
		if _is_ground_strike:
			var glow_alpha := alpha * 0.18
			var core_alpha := alpha * 0.96
			draw_polyline(points, Color(0.70, 0.90, 1.0, glow_alpha), 6.0, true)
			draw_polyline(points, Color(1.0, 1.0, 1.0, core_alpha), 2.3, true)
			continue
		var base_particle_size: Vector2 = pulse["particle_size"]
		var particle_size := Vector2(
			clampf(base_particle_size.x * float(pulse["size_multiplier"]), 2.0, 5.0),
			clampf(base_particle_size.y * float(pulse["size_multiplier"]), 1.5, 4.0)
		)
		var glow_size := clampf(float(pulse["glow_size"]) * float(pulse["size_multiplier"]), 3.0, 10.0)
		var rotations: PackedFloat32Array = pulse.get("rotations", PackedFloat32Array())
		for point_index in points.size():
			var point: Vector2 = points[point_index]
			var particle_rotation := float(rotations[point_index]) if point_index < rotations.size() else 0.0
			draw_set_transform(point, particle_rotation, Vector2.ONE)
			var glow_alpha := alpha * (0.12 if point_index % 3 == 1 else 0.08)
			draw_rect(Rect2(Vector2(-glow_size * 0.62, -glow_size * 0.30), Vector2(glow_size * 1.24, glow_size * 0.60)), Color(1.0, 1.0, 1.0, glow_alpha))
			var particle_alpha := alpha * (0.72 if point_index % 3 == 1 else 0.9)
			draw_rect(Rect2(-particle_size * 0.5, particle_size), Color(1.0, 1.0, 1.0, particle_alpha))
			if bool(pulse.get("is_core", false)) and point_index % 5 == 0:
				var highlight_size := Vector2(minf(particle_size.x, 2.0), minf(particle_size.y, 2.0))
				draw_rect(Rect2(-highlight_size * 0.5, highlight_size), Color(1.0, 1.0, 1.0, alpha * 0.82))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
