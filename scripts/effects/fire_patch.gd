extends Area2D
class_name FirePatch

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const FIRE_VISUAL = preload("res://scripts/effects/pixel_fire_visual.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")

const MERGE_DISTANCE: float = 64.0
const MAX_ACTIVE_FIELDS: int = 6
const MAX_FIELD_RADIUS: float = 58.0
const MAX_WIND_FIELD_RADIUS: float = 96.0
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
var _flame_visual: Node2D
var _light_field: Node = null
var _visual_palette := 0
var _palette_remaining := 0.0


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
	patch._create_flame_visual()
	patch._play_ignition_sound(context)
	return patch


static func _resolve_radius(context: RefCounted) -> float:
	var radius := 30.0
	if context != null:
		radius *= maxf(context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 0.25)
	return minf(radius, MAX_FIELD_RADIUS)


static func _resolve_duration(context: RefCounted) -> float:
	return maxf(context.get_resolved_parameter("patch_duration", 3.0), 0.2) if context != null else 3.0


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
	if _palette_remaining > 0.0:
		_palette_remaining -= delta
		if _palette_remaining <= 0.0:
			_visual_palette = 0
			if is_instance_valid(_flame_visual): _flame_visual.set_palette(0)
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
	_radius = maxf(_radius, minf(MAX_FIELD_RADIUS, maxf(incoming_radius + distance * 0.45, _base_radius + sqrt(_stack_strength) * 3.6)))
	if _source_weapon_id.is_empty():
		_source_weapon_id = _get_source_weapon_id(context)
	_update_collision_radius()
	_update_flame_extent()
	_play_ignition_sound(context)


func expand_from_wind(radius_multiplier: float = 1.35) -> void:
	var safe_multiplier := maxf(radius_multiplier, 1.0)
	_radius = maxf(_radius, minf(MAX_WIND_FIELD_RADIUS, _radius * safe_multiplier))
	_base_radius = maxf(_base_radius, _radius)
	_update_collision_radius()
	_update_flame_extent()
	_play_ignition_sound()


static func expand_nearby_fields(center: Vector2, search_radius: float, radius_multiplier: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("fire_patches"):
		var patch := node as FirePatch
		if patch == null or not is_instance_valid(patch) or patch._remaining <= 0.0:
			continue
		if patch.global_position.distance_to(center) <= search_radius + patch._radius:
			patch.expand_from_wind(radius_multiplier)


func _update_collision_radius() -> void:
	if _collision_shape == null:
		return
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = _radius


func _create_flame_visual() -> void:
	if is_instance_valid(_flame_visual): return
	_flame_visual = FIRE_VISUAL.new()
	add_child(_flame_visual)
	_flame_visual.setup_field(_radius, _get_flame_color_tint())


func _update_flame_extent() -> void:
	if is_instance_valid(_flame_visual):
		_flame_visual.setup_field(_radius, _get_flame_color_tint())


func _play_ignition_sound(source_context: RefCounted = null) -> void:
	var audio_impact: RefCounted = source_context.get_meta("combat_audio_impact") if source_context != null and source_context.has_meta("combat_audio_impact") else null
	AudioManager.begin_combat_audio(audio_impact)
	AudioManager.play_enchantment_sfx("fire")
	AudioManager.end_combat_audio()


func _refresh_field_light() -> void:
	if _light_field == null or not is_instance_valid(_light_field) or not _light_field.has_method("add_light"):
		_light_field = PARTICLE_WORLD_SCRIPT.find_light_field(self)
	var light_field := _light_field
	if light_field == null or not light_field.has_method("add_light"):
		return
	var energy := clampf(0.22 + sqrt(_stack_strength) * 0.06, 0.22, 0.46)
	light_field.call("add_light", global_position, _get_flame_tint(), energy, _radius * 1.25, LIGHT_DURATION_SECONDS)


func _get_flame_tint() -> Color:
	if _visual_palette == 1: return Color(1.0, 0.96, 0.82)
	if _visual_palette == 2: return Color(0.13, 0.05, 0.22)
	return _context.get_tinted_color(Color(1.0, 0.55, 0.10, 1.0)) if _context != null else Color(1.0, 0.55, 0.10, 1.0)


static func tint_nearby_fields(tree: SceneTree, center: Vector2, radius: float, palette: int, duration: float) -> void:
	# Visual recoloring only; field size, ticks, lifetime and statuses stay intact.
	for field: FirePatch in tree.get_nodes_in_group("fire_patches"):
		if field.global_position.distance_squared_to(center) > pow(radius + field._radius, 2): continue
		field._visual_palette = palette
		field._palette_remaining = duration
		if is_instance_valid(field._flame_visual): field._flame_visual.set_palette(palette)


func _get_flame_color_tint() -> Color:
	return _context.get_tinted_color(Color.WHITE) if _context != null else Color.WHITE


func _apply_tick_damage() -> void:
	AudioManager.begin_combat_audio()
	var original_damage := 0.0
	var burn_duration := 3.0
	if _context != null:
		original_damage = maxf(_context.get_resolved_parameter("original_damage", _context.get_resolved_parameter("damage", 0.0)), 0.0)
		burn_duration = maxf(_context.get_resolved_parameter("burn_duration", 3.0), 0.2)
	for body in get_overlapping_bodies():
		if body is EnemyController:
			var enemy := body as EnemyController
			if enemy.is_alive():
				ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, "fire", {
					"parent": get_parent(),
					"hit_position": enemy.global_position,
					"source_id": _source_weapon_id if not _source_weapon_id.is_empty() else "fire_patch",
					"original_damage": original_damage,
					"burn_duration": burn_duration,
				})
	AudioManager.end_combat_audio()
