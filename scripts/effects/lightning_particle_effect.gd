extends Node2D
class_name LightningParticleEffect

signal ground_strike_landed

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const PIXEL_BOLT = preload("res://scripts/effects/lightning_pixel_bolt.gd")
const HIT_SPRITE_BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
const GROUND_ARC_BURST = preload("res://scripts/effects/lightning_ground_arc_burst.gd")

const STEP_SECONDS := 0.08
const FLASH_SECONDS := STEP_SECONDS * 2.0
const DARK_SECONDS := 0.04
const TOTAL_SECONDS := FLASH_SECONDS * 2.0 + DARK_SECONDS
const CONTROL_JITTER_PIXELS := 20.0
const HIT_BURST_COUNT_MULTIPLIER := 0.5
const HIT_BURST_DISTANCE_MULTIPLIER := 0.5
const HIT_BURST_GLOW_RADIUS_MULTIPLIER := 0.5

const CHAIN_CONTROL_POINT_SPACING: float = 24.0
const CHAIN_CONTROL_POINT_JITTER: float = 26.0
const CHAIN_GLOW_RADIUS_MULTIPLIER: float = 0.5
const GROUND_STRIKE_CONTROL_POINT_SPACING: float = 24.0
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
var _chain_finished: bool = false
var _path_pulses: Array[Dictionary] = []
var _control_point_spacing: float = CHAIN_CONTROL_POINT_SPACING
var _control_point_envelope_power: float = 1.3
var _is_ground_strike: bool = false
var _ground_strike_damage_radius: float = 0.0
var _ground_strike_position: Vector2 = Vector2.ZERO
var _ground_strike_impact_age: float = -1.0
var _ground_strike_damage_applied: bool = false
var _audio_impact: RefCounted = null


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
	effect._audio_impact = AudioManager.current_combat_audio()
	# Each attachment owns a chain; global modifiers still apply to every chain.
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "lightning", {
		"damage": maxf(damage_event.get_elemental_base_damage() * 0.55, 1.0),
		"chain_count": DEFAULT_CHAIN_COUNT,
		"chain_interval": DEFAULT_CHAIN_INTERVAL,
		"jump_radius": DEFAULT_JUMP_RADIUS,
		"stun_duration": DEFAULT_STUN_DURATION,
		"detonate_burning": 1.0,
	}, attachment_item_id)
	effect._cache_resolved_parameters()
	# chain_count means additional victims after the directly struck target.
	effect._remaining_jumps = 1 + maxi(0, int(roundi(effect._get_cached_parameter("chain_count", DEFAULT_CHAIN_COUNT) + effect._get_cached_parameter("control_power", 0.0) / 10.0)))
	effect._chain_selection_step = 0
	effect._jump_radius = maxf(effect._get_cached_parameter("jump_radius", DEFAULT_JUMP_RADIUS) * effect._get_cached_parameter("attack_range_multiplier", 1.0), 32.0)
	# Bind an instance id instead of the enemy object itself. Enemies can be
	# freed while the delayed chain hop is waiting in EffectScheduler.
	EffectScheduler.schedule(0.0, Callable(effect, "_strike_chain").bind(first_enemy.get_instance_id(), hit_position), effect)


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
	effect._control_point_spacing = GROUND_STRIKE_CONTROL_POINT_SPACING
	effect._control_point_envelope_power = 0.65
	effect._context = EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "electric_spark", {
		"damage_multiplier": 0.6,
		"strike_height": strike_height,
		"detonate_burning": 1.0,
	}, effect._attachment_item_id)
	# Resolve the configured multiplier once, before the shared final rounding.
	effect._context.set_parameter("damage", maxf(damage_event.get_elemental_base_damage() * effect._context.get_resolved_parameter("damage_multiplier", 0.6), 1.0))
	effect._cache_resolved_parameters()
	effect._chain_finished = true
	EffectScheduler.schedule(0.0, Callable(effect, "_strike_ground").bind(ground_position), effect)
	return effect


func _strike_chain(target_id: int, from_position: Vector2) -> void:
	if _weapon == null or _damage_event == null:
		_finish_chain()
		return
	var current := instance_from_id(target_id) as EnemyController
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
	AudioManager.begin_combat_audio(_audio_impact)
	_audio_impact = null # Later hops are separate contacts with their own reactions.
	AudioManager.play_enchantment_sfx("lightning")
	_emit_hit_burst(current.global_position, from_position.direction_to(current.global_position))
	var reaction_result := ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(current, "electric", {
		"parent": _parent_root,
		"hit_position": current.global_position,
		"source_id": _damage_event.source_weapon_id,
		"stun_duration": _get_cached_parameter("stun_duration", DEFAULT_STUN_DURATION),
		"detonate_burning": _get_cached_parameter("detonate_burning", 1.0),
	})
	if bool(reaction_result.get("burning_detonated", false)):
		AudioManager.mark_combat_reaction("thunder_fire")
		EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, current.global_position, _weapon, _damage_event, "", 1.8, 72.0, "thunder_fire")
	var damage := maxi(1, int(roundi(_get_cached_parameter("damage", 1.0))))
	current.take_damage(damage, _damage_event.source_weapon_id, false, from_position.direction_to(current.global_position))
	if bool(reaction_result.get("extra_trigger", false)):
		current.take_damage(damage, _damage_event.source_weapon_id, false, from_position.direction_to(current.global_position))
	AudioManager.end_combat_audio()
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
		AudioManager.begin_combat_audio()
		AudioManager.play_enchantment_sfx("electric_spark")
		_damage_ground_enemies(ground_position)
		AudioManager.end_combat_audio()
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
		# Capture the reaction on contact, including a lethal first strike.
		var reaction_result := ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "electric", {
			"parent": _parent_root,
			"hit_position": enemy.global_position,
			"source_id": _damage_event.source_weapon_id,
			"stun_duration": _get_cached_parameter("stun_duration", DEFAULT_STUN_DURATION),
			"detonate_burning": _get_cached_parameter("detonate_burning", 1.0),
		})
		var dealt_damage := enemy.take_damage(
			damage,
			strike_damage_event.source_weapon_id,
			strike_damage_event.is_critical,
			hit_direction,
		)
		if dealt_damage > 0:
			_emit_hit_burst(enemy.global_position, hit_direction)
		if bool(reaction_result.get("burning_detonated", false)):
			AudioManager.mark_combat_reaction("thunder_fire")
			EXPLOSION_EFFECT_SCRIPT.spawn(_parent_root, enemy.global_position, _weapon, _damage_event, "", 1.8, 72.0, "thunder_fire")
		if bool(reaction_result.get("extra_trigger", false)):
			# Keep the extra hit; its only additional visual is the short blue cue.
			enemy.take_damage(damage, _damage_event.source_weapon_id, false, hit_direction)


func _schedule_next(origin: Vector2) -> void:
	if _remaining_jumps <= 0:
		_finish_chain()
		return
	# Every hop is measured from the previous target. Do not fall back to a
	# global random enemy when the local chain radius contains no candidates.
	var next_target := _find_farthest_enemy(origin) if _chain_selection_step == 0 else _find_random_enemy(origin)
	if next_target == null:
		_finish_chain()
		return
	_chain_selection_step += 1
	var chain_interval := clampf(_get_cached_parameter("chain_interval", DEFAULT_CHAIN_INTERVAL), 0.02, 0.5)
	EffectScheduler.schedule(chain_interval, Callable(self, "_strike_chain").bind(next_target.get_instance_id(), origin), self)


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


func _find_random_enemy(origin: Vector2) -> EnemyController:
	var candidates: Array[EnemyController] = []
	var jump_radius_squared := _jump_radius * _jump_radius
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy != null and enemy.is_alive() and not _visited.has(enemy.get_instance_id()) and origin.distance_squared_to(enemy.global_position) <= jump_radius_squared:
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi_range(0, candidates.size() - 1)]


func _emit_hit_burst(hit_position: Vector2, burst_direction: Vector2) -> void:
	var context_parameters := {
		"count_multiplier": _get_cached_parameter("count_multiplier", 1.0) * HIT_BURST_COUNT_MULTIPLIER,
		"speed_multiplier": _get_cached_parameter("speed_multiplier", 1.0),
		"size_multiplier": _get_cached_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": _get_cached_parameter("lifetime_multiplier", 1.0),
		"glow_multiplier": _get_cached_parameter("glow_multiplier", 1.0),
		"glow_radius_multiplier": (1.0 if _is_ground_strike else CHAIN_GLOW_RADIUS_MULTIPLIER) * HIT_BURST_GLOW_RADIUS_MULTIPLIER,
		"alpha_multiplier": _get_cached_parameter("alpha_multiplier", 1.0),
		"distance_multiplier": _get_cached_parameter("attack_range_multiplier", 1.0) * HIT_BURST_DISTANCE_MULTIPLIER,
	}
	var intensity: float = _get_cached_parameter("attack_range_multiplier", 1.0)
	HIT_SPRITE_BURST.spawn(_parent_root, hit_position, burst_direction, intensity, context_parameters)


static func alpha_at(age: float) -> float:
	if age < 0.0 or age >= TOTAL_SECONDS:
		return 0.0
	if age >= FLASH_SECONDS and age < FLASH_SECONDS + DARK_SECONDS:
		return 0.0
	var local_age := age if age < FLASH_SECONDS else age - FLASH_SECONDS - DARK_SECONDS
	if local_age < STEP_SECONDS:
		return 1.0
	return 0.6


func _emit_bolt(start_position: Vector2, end_position: Vector2) -> void:
	if start_position.distance_squared_to(end_position) <= 1.0:
		return
	# Both spells use the existing ground strike's sparse control geometry.
	_control_point_envelope_power = 0.65
	var lifetime_scale := clampf(_get_cached_parameter("lifetime_multiplier", 1.0), 0.5, 2.0)
	var bolt := _create_bolt_path(start_position, end_position)
	var ground_arc: Sprite2D = null
	if _is_ground_strike and not _ground_strike_damage_applied:
		ground_arc = GROUND_ARC_BURST.spawn(self, end_position, bolt.base_alpha)
	# One initial path per contact, followed by one independently drawn echo path.
	_path_pulses.append({"bolt": bolt, "age": 0.0, "scale": lifetime_scale,
		"start": start_position, "end": end_position, "initial_points": bolt.points.duplicate(), "echoed": false, "ground_arc": ground_arc})


func _create_bolt_path(start_position: Vector2, end_position: Vector2, previous_points := PackedVector2Array()) -> Node2D:
	_control_point_spacing = minf(GROUND_STRIKE_CONTROL_POINT_SPACING, start_position.distance_to(end_position) * 0.5)
	var direction := start_position.direction_to(end_position)
	var jitter := minf(CONTROL_JITTER_PIXELS, start_position.distance_to(end_position) * 0.3)
	var controls := _build_bolt_control_points(start_position, end_position, direction, direction.orthogonal(), jitter / CHAIN_CONTROL_POINT_JITTER)
	var bolt := PIXEL_BOLT.new()
	for point in controls:
		bolt.points.append(to_local(point).round())
	# Even a very short, rounded path must not accidentally repeat its first shape.
	if bolt.points == previous_points:
		var middle: int = bolt.points.size() / 2
		bolt.points[middle] = (bolt.points[middle] + direction.orthogonal() * 6.0).round()
	bolt.base_alpha = clampf(_get_cached_parameter("alpha_multiplier", 1.0), 0.0, 2.0)
	bolt.rim_enabled = false
	bolt.cell_size = 2
	bolt.grid_origin = to_local(Vector2.ZERO)
	bolt.build()
	add_child(bolt)
	return bolt


func _finish_chain() -> void:
	_chain_finished = true
	_try_finish_chain()


func _try_finish_chain() -> void:
	var ring_active := _is_ground_strike and _ground_strike_impact_age >= 0.0 and _ground_strike_impact_age < GROUND_STRIKE_IMPACT_RING_LIFETIME
	if _chain_finished and _path_pulses.is_empty() and not ring_active:
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
	add_to_group("combat_particle_counters")
	z_index = 81
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for index in range(_path_pulses.size() - 1, -1, -1):
		var pulse := _path_pulses[index]
		var ground_arc := pulse.get("ground_arc") as Sprite2D
		pulse.age += delta / float(pulse.scale)
		if pulse.age >= TOTAL_SECONDS:
			if is_instance_valid(ground_arc):
				ground_arc.hide()
				ground_arc.queue_free()
			pulse.bolt.queue_free()
			_path_pulses.remove_at(index)
			continue
		if not pulse.echoed and pulse.age >= FLASH_SECONDS + DARK_SECONDS:
			pulse.bolt.hide()
			pulse.bolt.queue_free()
			pulse.bolt = _create_bolt_path(pulse.start, pulse.end, pulse.initial_points)
			pulse.echoed = true
			# New node and new random geometry; no second strike or damage event.
		pulse.bolt.modulate.a = alpha_at(pulse.age)
		if is_instance_valid(ground_arc):
			ground_arc.sync_pulse(pulse.echoed, pulse.bolt.modulate.a)
	if _is_ground_strike and _ground_strike_impact_age >= 0.0:
		_ground_strike_impact_age += delta
		queue_redraw()
	_try_finish_chain()


func get_active_particle_count() -> int:
	return 0


func _draw() -> void:
	if _is_ground_strike and _ground_strike_impact_age >= 0.0 and _ground_strike_impact_age < GROUND_STRIKE_IMPACT_RING_LIFETIME:
		var impact_ratio := clampf(_ground_strike_impact_age / GROUND_STRIKE_IMPACT_RING_LIFETIME, 0.0, 1.0)
		var impact_center := to_local(_ground_strike_position)
		var impact_radius := lerpf(GROUND_STRIKE_IMPACT_RING_START_RADIUS, _ground_strike_damage_radius, impact_ratio)
		var impact_alpha := (1.0 - impact_ratio) * 0.68
		draw_circle(impact_center, impact_radius, Color(1.0, 0.92, 0.42, impact_alpha * 0.10))
		draw_arc(impact_center, impact_radius, 0.0, TAU, 32, Color(1.0, 0.96, 0.58, impact_alpha), 2.0, true)
