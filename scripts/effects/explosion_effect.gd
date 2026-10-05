extends Node2D
class_name ExplosionEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const DESTRUCTIBLE_TEST_AREA_SCRIPT = preload("res://scripts/terrain/destructible_test_area.gd")
const REACTION_VISUAL = preload("res://scripts/effects/element_reaction_visual.gd")

const BASE_DAMAGE_RADIUS: float = 96.0
const BASE_SHOCKWAVE_RADIUS: float = 55.2

# Cache both hits and misses, invalidated by any scene hierarchy change.
static var _terrain_cache_tree: SceneTree
static var _terrain_cache_root: Node
static var _terrain_cache_node: Node
static var _terrain_cache_valid := false

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _hit_position: Vector2 = Vector2.ZERO
var _attachment_item_id: String = ""
var _damage_multiplier_override: float = -1.0
var _radius_override: float = -1.0
var _reaction_id: String = ""
var _audio_impact: RefCounted = null
var weapon: WeaponInstance:
	get: return _weapon
var cancelled := false


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "", damage_multiplier_override: float = -1.0, radius_override: float = -1.0, reaction_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := ExplosionEffect.new()
	parent.add_child(effect)
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._hit_position = hit_position
	effect._attachment_item_id = attachment_item_id
	effect._damage_multiplier_override = damage_multiplier_override
	effect._radius_override = radius_override
	effect._reaction_id = reaction_id
	effect._audio_impact = AudioManager.current_combat_audio()
	if reaction_id.is_empty():
		effect.add_to_group("weapon_runtime_effects")
	EffectScheduler.schedule(0.0, Callable(effect, "_detonate"), effect)


func _detonate() -> void:
	if cancelled or _weapon == null or _damage_event == null:
		queue_free()
		return
	if _reaction_id.is_empty():
		# Keep the legacy effect ID for equipped scrolls. Only elemental reactions
		# use the damaging explosion path below; this enchantment is pure control.
		_shockwave()
		return
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(_weapon, _reaction_id, {
		"damage": maxf(_damage_event.get_elemental_base_damage() * (0.8 if _damage_multiplier_override <= 0.0 else _damage_multiplier_override), 1.0),
		"radius": BASE_DAMAGE_RADIUS if _radius_override <= 0.0 else _radius_override,
		"damage_falloff": 0.0,
	}, _attachment_item_id)
	var radius := maxf(context.get_resolved_parameter("radius", BASE_DAMAGE_RADIUS) * context.get_resolved_parameter("damage_area_size_multiplier", 1.0), 12.0)
	var damage := maxi(1, int(roundi(context.get_resolved_parameter("damage", 1.0))))
	var particle_parameters := _build_particle_parameters(context, radius)
	AudioManager.begin_combat_audio(_audio_impact)
	AudioManager.play_reaction_sfx(_reaction_id)
	if _reaction_id == "thunder_fire":
		PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_burst", _hit_position,
			Vector2.ZERO, 1.0, Color(1.0, 0.72, 0.12), particle_parameters)
	else:
		REACTION_VISUAL.spawn(get_parent(), _reaction_id, _hit_position, {"radius": radius})
	_damage_enemies(radius, damage, context.get_resolved_parameter("damage_falloff", 0.0))
	var destroyed_materials := _damage_terrain(radius)
	_emit_material_debris(destroyed_materials, particle_parameters)
	AudioManager.end_combat_audio()
	queue_free()


func _shockwave() -> void:
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(_weapon, "explosion", {
		"radius": BASE_SHOCKWAVE_RADIUS, "knockback_speed": 450.0, "knockback_duration": 0.3,
	}, _attachment_item_id)
	# Pure displacement has no damage area; Domain does not enlarge this wave.
	var radius := maxf(12, context.get_resolved_parameter("radius", BASE_SHOCKWAVE_RADIUS))
	# Enemy deceleration scales with initial speed. Halving speed while keeping
	# duration halves the displacement without changing the affected radius.
	var speed := maxf(1, context.get_resolved_parameter("knockback_speed", 450))
	var duration := maxf(0.05, context.get_resolved_parameter("knockback_duration", 0.3))
	var fallback := Vector2.RIGHT
	if is_instance_valid(_damage_event.source_player):
		fallback = _damage_event.source_player.global_position.direction_to(_hit_position)
		if fallback.is_zero_approx(): fallback = Vector2.RIGHT
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		# Radial pressure respects the same displacement immunity as wind.
		if not is_instance_valid(enemy) or not enemy.is_alive() or not enemy.can_be_pushed_by_wind():
			continue
		var offset := enemy.global_position - _hit_position
		if offset.length_squared() > radius * radius:
			continue
		enemy.apply_knockback(offset.normalized() if not offset.is_zero_approx() else fallback, speed, duration)
	AudioManager.begin_combat_audio(_audio_impact)
	AudioManager.play_enchantment_sfx("explosion")
	AudioManager.end_combat_audio()
	# Reuse the original square burst. Override its warm palette only here;
	# reactions and terrain debris still use their own colors and full radius.
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_burst", _hit_position,
		Vector2.ZERO, 1.0, Color.WHITE, _build_particle_parameters(context, radius))
	queue_free()


func cancel() -> void:
	cancelled = true
	EffectScheduler.cancel_owner(self)
	queue_free()


func _build_particle_parameters(context: RefCounted, radius: float) -> Dictionary:
	var particle_rate := maxf(context.get_resolved_parameter("particle_rate", 1.0), 0.0)
	return {
		"count_multiplier": context.get_resolved_parameter("count_multiplier", 1.0) * particle_rate,
		"speed_multiplier": context.get_resolved_parameter("speed_multiplier", 1.0),
		"size_multiplier": context.get_resolved_parameter("size_multiplier", 1.0),
		"lifetime_multiplier": context.get_resolved_parameter("lifetime_multiplier", 1.0),
		"alpha_multiplier": context.get_resolved_parameter("alpha_multiplier", 1.0),
		"glow_multiplier": context.get_resolved_parameter("glow_multiplier", 1.0),
		"distance_multiplier": radius / BASE_DAMAGE_RADIUS,
	}


func _damage_enemies(radius: float, damage: int, damage_falloff: float) -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _hit_position)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var results := space_state.intersect_shape(query, maxi(64, EnemyRegistry.get_registered_enemies().size()))
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive():
			continue
		var distance_ratio := clampf(enemy.global_position.distance_to(_hit_position) / radius, 0.0, 1.0)
		var falloff := clampf(damage_falloff, 0.0, 1.0)
		var scaled_damage := maxi(1, int(roundi(float(damage) * (1.0 - distance_ratio * falloff))))
		enemy.take_damage(scaled_damage, _damage_event.source_weapon_id, false, enemy.global_position.direction_to(_hit_position))


func _damage_terrain(radius: float) -> Array[Dictionary]:
	var destroyed_materials: Array[Dictionary] = []
	var root := get_tree().current_scene if get_tree() != null else null
	if root == null:
		return destroyed_materials
	var terrain := _find_terrain_cached(root)
	if terrain == null or terrain.get_script() != DESTRUCTIBLE_TEST_AREA_SCRIPT:
		return destroyed_materials
	if terrain.has_method("destroy_radius_with_materials"):
		var raw_result: Variant = terrain.call("destroy_radius_with_materials", _hit_position, radius)
		if raw_result is Array:
			for material_data in raw_result:
				if material_data is Dictionary:
					destroyed_materials.append(material_data)
	elif terrain.has_method("destroy_radius"):
		terrain.call("destroy_radius", _hit_position, radius)
	return destroyed_materials


func _emit_material_debris(destroyed_materials: Array[Dictionary], particle_parameters: Dictionary) -> void:
	if destroyed_materials.is_empty():
		return
	var material_parameters := particle_parameters.duplicate(true)
	material_parameters["count_multiplier"] = float(material_parameters.get("count_multiplier", 1.0)) * minf(float(destroyed_materials.size()) * 0.08, 0.5)
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_burst", _hit_position, Vector2.ZERO, 1.0, Color.TRANSPARENT, material_parameters)


static func _invalidate_terrain_cache() -> void:
	_terrain_cache_valid = false
	_terrain_cache_root = null
	_terrain_cache_node = null


static func _find_terrain_cached(root: Node) -> Node:
	var tree := root.get_tree()
	if tree != _terrain_cache_tree:
		if is_instance_valid(_terrain_cache_tree) and _terrain_cache_tree.tree_changed.is_connected(_invalidate_terrain_cache):
			_terrain_cache_tree.tree_changed.disconnect(_invalidate_terrain_cache)
		_terrain_cache_tree = tree
		tree.tree_changed.connect(_invalidate_terrain_cache)
		_invalidate_terrain_cache()
	if _terrain_cache_valid and _terrain_cache_root == root:
		return _terrain_cache_node if is_instance_valid(_terrain_cache_node) else null
	_terrain_cache_root = root
	_terrain_cache_node = root.find_child("DestructibleTestArea", true, false)
	_terrain_cache_valid = true
	return _terrain_cache_node
