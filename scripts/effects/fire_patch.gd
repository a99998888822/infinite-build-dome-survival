extends Area2D
class_name FirePatch

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")

const MERGE_DISTANCE: float = 64.0
const MAX_ACTIVE_FIELDS: int = 6
const MAX_FIELD_RADIUS: float = 58.0
const FLAME_TONGUE_COUNT: int = 8
const EMBER_INTERVAL_SECONDS: float = 0.20
const LIGHT_REFRESH_SECONDS: float = 0.22
const LIGHT_DURATION_SECONDS: float = 0.26

var _context: RefCounted = null
var _radius: float = 30.0
var _base_radius: float = 30.0
var _remaining: float = 2.0
var _tick_timer: float = 0.0
var _ember_timer: float = 0.0
var _light_timer: float = 0.0
var _visual_elapsed: float = 0.0
var _stack_strength: float = 1.0
var _source_weapon_id: String = ""
var _collision_shape: CollisionShape2D = null
var _flame_tongues: Array[Dictionary] = []


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
	patch.collision_mask = 3
	patch.monitoring = true
	patch.monitorable = false
	patch.add_to_group("fire_patches")
	patch._initialize_flame_tongues()
	patch._emit_ignition_burst(patch_position, field_strength)
	return patch


static func _resolve_radius(context: RefCounted) -> float:
	var radius := 30.0
	if context != null:
		radius *= maxf(context.get_resolved_parameter("area_size_multiplier", 1.0), 0.25)
	return radius


static func _resolve_duration(context: RefCounted) -> float:
	return maxf(context.get_resolved_parameter("patch_duration", 2.0), 0.2) if context != null else 2.0


static func _get_source_weapon_id(context: RefCounted) -> String:
	return str(context.get("source_weapon_id")) if context != null else ""


func _ready() -> void:
	z_index = 42
	if not is_in_group("fire_patches"):
		add_to_group("fire_patches")
	if _flame_tongues.is_empty():
		_initialize_flame_tongues()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_remaining -= delta
	_tick_timer -= delta
	_ember_timer -= delta
	_light_timer -= delta
	_visual_elapsed += delta
	if _ember_timer <= 0.0:
		var emission_multiplier: float = _context.get_resolved_parameter("particle_rate", 1.0) if _context != null else 1.0
		_ember_timer = maxf(EMBER_INTERVAL_SECONDS / maxf(emission_multiplier, 0.25), 0.08)
		_emit_embers()
	if _light_timer <= 0.0:
		_light_timer = LIGHT_REFRESH_SECONDS
		_refresh_field_light()
	if _tick_timer <= 0.0:
		var interval: float = _context.get_resolved_parameter("tick_interval", 0.25) if _context != null else 0.25
		_tick_timer = maxf(interval, 0.08)
		_apply_tick_damage()
	queue_redraw()
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
	_emit_ignition_burst(patch_position, field_strength)


func _update_collision_radius() -> void:
	if _collision_shape == null:
		return
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = _radius


func _initialize_flame_tongues() -> void:
	_flame_tongues.clear()
	for index in FLAME_TONGUE_COUNT:
		var angle := TAU * float(index) / float(FLAME_TONGUE_COUNT) + randf_range(-0.28, 0.28)
		var radial := randf_range(0.12, 0.78)
		_flame_tongues.append({
			"anchor": Vector2(cos(angle) * _base_radius * radial, sin(angle) * _base_radius * radial * 0.28),
			"phase": randf_range(0.0, TAU),
			"height": randf_range(12.0, 24.0),
			"width": randf_range(3.5, 6.5),
		})


func _emit_ignition_burst(burst_position: Vector2, field_strength: float) -> void:
	var intensity := clampf(0.45 + sqrt(maxf(field_strength, 0.05)) * 0.16, 0.45, 1.0)
	var flame_color := _get_flame_tint()
	var parameters := _build_particle_parameters()
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_pool_flame", burst_position, Vector2.UP, intensity, flame_color, parameters)
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_pool_ember", burst_position, Vector2.UP, intensity, flame_color, parameters)


func _emit_embers() -> void:
	var visual_strength := clampf(0.72 + sqrt(_stack_strength) * 0.10, 0.72, 1.15)
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "fire_pool_ember", _random_pool_position(), Vector2.UP, visual_strength, _get_flame_tint(), _build_particle_parameters())


func _build_particle_parameters() -> Dictionary:
	return {
		"count_multiplier": _context.get_resolved_parameter("count_multiplier", 1.0) if _context != null else 1.0,
		"speed_multiplier": _context.get_resolved_parameter("speed_multiplier", 1.0) if _context != null else 1.0,
		"size_multiplier": _context.get_resolved_parameter("size_multiplier", 1.0) if _context != null else 1.0,
		"lifetime_multiplier": _context.get_resolved_parameter("lifetime_multiplier", 1.0) if _context != null else 1.0,
		"alpha_multiplier": _context.get_resolved_parameter("alpha_multiplier", 1.0) if _context != null else 1.0,
		"glow_multiplier": _context.get_resolved_parameter("glow_multiplier", 1.0) if _context != null else 1.0,
	}


func _refresh_field_light() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var light_field := parent.get_node_or_null("ParticleLightField")
	if light_field == null or not light_field.has_method("add_light"):
		return
	var energy := clampf(0.22 + sqrt(_stack_strength) * 0.06, 0.22, 0.46)
	light_field.call("add_light", global_position, _get_flame_tint(), energy, _radius * 1.25, LIGHT_DURATION_SECONDS)


func _random_pool_position() -> Vector2:
	var angle := randf_range(0.0, TAU)
	var radial := sqrt(randf()) * _radius
	var footprint := Vector2(cos(angle) * radial, sin(angle) * radial * 0.30)
	return global_position + footprint


func _get_flame_tint() -> Color:
	return _context.get_tinted_color(Color(1.0, 0.55, 0.10, 1.0)) if _context != null else Color(1.0, 0.55, 0.10, 1.0)


func _draw() -> void:
	var fade := clampf(_remaining / 0.35, 0.0, 1.0)
	var visual_scale := clampf(0.82 + sqrt(_stack_strength) * 0.12, 0.82, 1.34)
	var outer_color := Color(1.0, 0.12, 0.01, 0.72 * fade)
	var middle_color := _get_flame_tint()
	middle_color.a = 0.88 * fade
	var core_color := Color(1.0, 0.88, 0.22, 0.94 * fade)

	draw_set_transform(Vector2(0.0, _radius * 0.16), 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, _radius * 1.08, Color(0.46, 0.03, 0.01, 0.28 * fade))
	draw_circle(Vector2.ZERO, _radius * 0.76, Color(0.95, 0.16, 0.01, 0.34 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for tongue in _flame_tongues:
		var anchor: Vector2 = tongue["anchor"]
		var phase := float(tongue["phase"])
		var sway := sin(_visual_elapsed * 6.0 + phase) * 2.4
		var tongue_position := anchor + Vector2(sway, sin(_visual_elapsed * 4.0 + phase) * 1.2)
		var tongue_height := float(tongue["height"]) * visual_scale * (0.82 + 0.18 * sin(_visual_elapsed * 8.0 + phase))
		var tongue_width := float(tongue["width"]) * visual_scale
		draw_set_transform(tongue_position.round(), sway * 0.045, Vector2.ONE)
		_draw_flame_tongue(tongue_width, tongue_height, outer_color, middle_color, core_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flame_tongue(width: float, height: float, outer_color: Color, middle_color: Color, core_color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-width, 2.0),
		Vector2(-width * 0.58, -height * 0.42),
		Vector2(-width * 0.10, -height * 0.82),
		Vector2(width * 0.18, -height),
		Vector2(width * 0.62, -height * 0.34),
		Vector2(width, 2.0),
	]), outer_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-width * 0.58, 1.0),
		Vector2(-width * 0.26, -height * 0.34),
		Vector2(width * 0.10, -height * 0.72),
		Vector2(width * 0.42, -height * 0.24),
		Vector2(width * 0.56, 1.0),
	]), middle_color)
	draw_rect(Rect2(Vector2(-width * 0.34, -height * 0.18), Vector2(width * 0.68, height * 0.22)), core_color)


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
		elif body is PlayerController:
			var player := body as PlayerController
			player.take_damage(damage, "fire_patch")
