extends Area2D
class_name FirePatch

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")

const MERGE_DISTANCE: float = 64.0
const MAX_ACTIVE_FIELDS: int = 6
const MAX_FIELD_RADIUS: float = 58.0
const LIGHT_REFRESH_SECONDS: float = 0.22
const LIGHT_DURATION_SECONDS: float = 0.26

var _context: RefCounted = null
var _radius: float = 30.0
var _base_radius: float = 30.0
var _remaining: float = 2.0
var _tick_timer: float = 0.0
var _light_timer: float = 0.0
var _stack_strength: float = 1.0
var _source_weapon_id: String = ""
var _collision_shape: CollisionShape2D = null
var _flame_emitters: Array[Node2D] = []


static func spawn(parent: Node, patch_position: Vector2, context: RefCounted, field_strength: float = 1.0) -> FirePatch:
	if parent == null:
		return null
	var merge_target: FirePatch = null
	var closest_field: FirePatch = null
	var closest_distance := INF
	var active_field_count := 0
	var tree := parent.get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("fire_patches"):
			var candidate := node as FirePatch
			if candidate == null or not is_instance_valid(candidate) or candidate.get_parent() != parent:
				continue
			active_field_count += 1
			var distance := candidate.global_position.distance_to(patch_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_field = candidate
			if candidate._can_absorb(patch_position, context):
				merge_target = candidate
				break
	if merge_target != null:
		merge_target._absorb_seed(patch_position, context, field_strength)
		return merge_target
	if active_field_count >= MAX_ACTIVE_FIELDS and closest_field != null:
		closest_field._absorb_seed(patch_position, context, field_strength)
		return closest_field

	var patch := FirePatch.new()
	parent.add_child(patch)
	patch.global_position = patch_position
	patch._context = context
	patch._base_radius = _resolve_radius(context)
	patch._radius = patch._base_radius
	patch._remaining = _resolve_duration(context)
	patch._stack_strength = maxf(field_strength, 0.05)
	patch._source_weapon_id = _get_source_weapon_id(context)
	patch._collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = patch._radius
	patch._collision_shape.shape = circle
	patch.add_child(patch._collision_shape)
	patch.collision_layer = 0
	patch.collision_mask = 2
	patch.monitoring = true
	patch.monitorable = false
	patch._create_particle_emitters()
	patch._emit_ignition_burst(patch_position, field_strength)
	return patch


static func _resolve_radius(context: RefCounted) -> float:
	var radius := 30.0
	if context != null:
		radius *= maxf(context.get_resolved_parameter("area_size_multiplier", 1.0), 0.25)
	return minf(radius, MAX_FIELD_RADIUS)


static func _resolve_duration(context: RefCounted) -> float:
	return maxf(context.get_resolved_parameter("patch_duration", 2.0), 0.2) if context != null else 2.0


static func _get_source_weapon_id(context: RefCounted) -> String:
	return str(context.get("source_weapon_id")) if context != null else ""


func _ready() -> void:
	z_index = 42
	if not is_in_group("fire_patches"):
		add_to_group("fire_patches")


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_remaining -= delta
	_tick_timer -= delta
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = LIGHT_REFRESH_SECONDS
		_refresh_field_light()
	if _tick_timer <= 0.0:
		var interval: float = _context.get_resolved_parameter("tick_interval", 0.25) if _context != null else 0.25
		_tick_timer = maxf(interval, 0.08)
		_apply_tick_damage()
	if _remaining <= 0.0:
		queue_free()


func _can_absorb(patch_position: Vector2, context: RefCounted) -> bool:
	if _remaining <= 0.0:
		return false
	var source_weapon_id := _get_source_weapon_id(context)
	if not _source_weapon_id.is_empty() and source_weapon_id != _source_weapon_id:
		return false
	return global_position.distance_to(patch_position) <= _radius + MERGE_DISTANCE


func _absorb_seed(patch_position: Vector2, context: RefCounted, field_strength: float) -> void:
	var incoming_radius := _resolve_radius(context)
	var incoming_duration := _resolve_duration(context)
	var distance := global_position.distance_to(patch_position)
	_stack_strength += maxf(field_strength, 0.05)
	_remaining = maxf(_remaining, incoming_duration)
	_base_radius = maxf(_base_radius, incoming_radius)
	_radius = minf(MAX_FIELD_RADIUS, maxf(_radius, maxf(incoming_radius + distance * 0.45, _base_radius + sqrt(_stack_strength) * 3.6)))
	if _source_weapon_id.is_empty():
		_source_weapon_id = _get_source_weapon_id(context)
	_update_collision_radius()
	_update_particle_extent()
	_emit_ignition_burst(patch_position, field_strength)


func _update_collision_radius() -> void:
	if _collision_shape == null:
		return
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = _radius


func _create_particle_emitters() -> void:
	if not _flame_emitters.is_empty():
		return
	var extent_multiplier := _get_particle_extent_multiplier()
	_flame_emitters.append(_create_emitter("fire_pool_base", 5.5, extent_multiplier))
	_flame_emitters.append(_create_emitter("fire_pool_flame", 2.4, extent_multiplier))
	_flame_emitters.append(_create_emitter("fire_pool_tongue", 6.0, extent_multiplier))
	_flame_emitters.append(_create_emitter("fire_pool_core", 5.0, extent_multiplier))
	_flame_emitters.append(_create_emitter("fire_pool_ember", 2.0, extent_multiplier))
	var configured_emitters: Array[Node2D] = []
	for emitter in _flame_emitters:
		if emitter != null:
			configured_emitters.append(emitter)
	_flame_emitters = configured_emitters


func _create_emitter(profile_id: String, particle_rate: float, extent_multiplier: float) -> Node2D:
	return PARTICLE_WORLD_SCRIPT.create_emitter(self, profile_id, _context, {
		"direction": Vector2.UP,
		"particle_rate": particle_rate,
		"max_emissions_per_frame": 1,
		"spawn_extent_multiplier": extent_multiplier,
		"use_context_color": false,
		"color_override": Color.TRANSPARENT,
		"color_tint": _get_flame_color_tint(),
	})


func _update_particle_extent() -> void:
	var extent_multiplier := _get_particle_extent_multiplier()
	for emitter in _flame_emitters:
		if emitter != null and is_instance_valid(emitter) and emitter.has_method("set_spawn_extent_multiplier"):
			emitter.call("set_spawn_extent_multiplier", extent_multiplier)


func _get_particle_extent_multiplier() -> float:
	return clampf(_radius / 30.0, 0.75, 1.8)


func _emit_ignition_burst(burst_position: Vector2, field_strength: float) -> void:
	var intensity := clampf(0.45 + sqrt(maxf(field_strength, 0.05)) * 0.16, 0.45, 1.0)
	var parameters := _build_particle_parameters()
	parameters["color_tint"] = _get_flame_color_tint()
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_pool_core", burst_position, Vector2.UP, intensity, Color.TRANSPARENT, parameters)
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_pool_ember", burst_position, Vector2.UP, intensity, Color.TRANSPARENT, parameters)


func _build_particle_parameters() -> Dictionary:
	return {
		"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0) if _context != null else 1.0,
		"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0) if _context != null else 1.0,
		"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0) if _context != null else 1.0,
		"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0) if _context != null else 1.0,
		"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0) if _context != null else 1.0,
		"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0) if _context != null else 1.0,
		"spawn_extent_multiplier": _get_particle_extent_multiplier(),
	}


func _refresh_field_light() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var light_field := parent.get_node_or_null("ParticleLightField")
	if light_field == null and get_tree() != null and get_tree().current_scene != null:
		light_field = get_tree().current_scene.find_child("ParticleLightField", true, false)
	if light_field == null or not light_field.has_method("add_light"):
		return
	var energy := clampf(0.22 + sqrt(_stack_strength) * 0.06, 0.22, 0.46)
	light_field.call("add_light", global_position, _get_flame_tint(), energy, _radius * 1.25, LIGHT_DURATION_SECONDS)


func _get_flame_tint() -> Color:
	return _context.get_tinted_color(Color(1.0, 0.55, 0.10, 1.0)) if _context != null else Color(1.0, 0.55, 0.10, 1.0)


func _get_flame_color_tint() -> Color:
	return _context.get_tinted_color(Color.WHITE) if _context != null else Color.WHITE


func _apply_tick_damage() -> void:
	var damage := 2
	var burn_damage := 1.0
	var burn_duration := 2.0
	if _context != null:
		damage = maxi(1, int(roundi(_context.get_resolved_parameter("damage", 2.0) * _stack_strength)))
		burn_damage = maxf(_context.get_resolved_parameter("burn_damage", 1.0), 1.0)
		burn_duration = maxf(_context.get_resolved_parameter("burn_duration", 2.0), 0.2)
	for body in get_overlapping_bodies():
		if body is EnemyController:
			var enemy := body as EnemyController
			if enemy.is_alive():
				enemy.apply_burning(burn_duration, burn_damage, "fire_patch")
				enemy.take_damage(damage, "fire_patch", false, Vector2.ZERO)
