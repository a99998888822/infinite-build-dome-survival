extends Node2D
class_name ExplosionEffect

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const DESTRUCTIBLE_TEST_AREA_SCRIPT = preload("res://scripts/terrain/destructible_test_area.gd")

const BASE_DAMAGE_RADIUS: float = 96.0

const MATERIAL_PARTICLE_PROFILES: Dictionary = {
	"soil": "explosion_soil_debris",
	"wood": "explosion_wood_debris",
	"stone": "explosion_stone_debris",
}

var _weapon: WeaponInstance = null
var _damage_event: DamageEvent = null
var _hit_position: Vector2 = Vector2.ZERO
var _attachment_item_id: String = ""


static func spawn(parent: Node, hit_position: Vector2, weapon: WeaponInstance, damage_event: DamageEvent, attachment_item_id: String = "") -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var effect := ExplosionEffect.new()
	parent.add_child(effect)
	effect._weapon = weapon
	effect._damage_event = damage_event
	effect._hit_position = hit_position
	effect._attachment_item_id = attachment_item_id
	effect.call_deferred("_detonate")


func _detonate() -> void:
	if _weapon == null or _damage_event == null:
		queue_free()
		return
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(_weapon, "explosion", {
		"damage": maxf(float(_damage_event.damage) * 0.8, 1.0),
		"radius": BASE_DAMAGE_RADIUS,
		"damage_falloff": 0.0,
	}, _attachment_item_id)
	var radius := maxf(context.get_resolved_parameter("radius", BASE_DAMAGE_RADIUS) * context.get_resolved_parameter("area_size_multiplier", 1.0), 12.0)
	var damage := maxi(1, int(roundi(context.get_resolved_parameter("damage", 1.0))))
	var particle_parameters := _build_particle_parameters(context, radius)
	var flash_color: Color = context.get_tinted_color(Color(1.0, 0.74, 0.25, 1.0))
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_spark", _hit_position, Vector2.ZERO, 1.0, flash_color, particle_parameters)
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "explosion_debris", _hit_position, Vector2.ZERO, 1.0, Color.TRANSPARENT, particle_parameters)
	_damage_enemies(radius, damage, context.get_resolved_parameter("damage_falloff", 0.0))
	var destroyed_materials := _damage_terrain(radius)
	_emit_material_debris(destroyed_materials, particle_parameters)
	queue_free()


func _build_particle_parameters(context: RefCounted, radius: float) -> Dictionary:
	var area_size_multiplier: float = float(context.get_resolved_parameter("area_size_multiplier", 1.0))
	var particle_rate := maxf(context.get_resolved_parameter("particle_rate", 1.0), 0.0)
	return {
		"count_multiplier": context.get_resolved_parameter("count_multiplier", 1.0) * particle_rate,
		"speed_multiplier": context.get_resolved_parameter("speed_multiplier", 1.0),
		"size_multiplier": context.get_resolved_parameter("size_multiplier", 1.0) * area_size_multiplier,
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
	var results := space_state.intersect_shape(query, 64)
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
	var terrain := root.find_child("DestructibleTestArea", true, false)
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
	for material_data in destroyed_materials:
		var material_id := str(material_data.get("material_id", "soil"))
		var profile_id := str(MATERIAL_PARTICLE_PROFILES.get(material_id, MATERIAL_PARTICLE_PROFILES["soil"]))
		var material_position: Vector2 = material_data.get("position", _hit_position)
		var debris_direction := _hit_position.direction_to(material_position)
		if debris_direction.is_zero_approx():
			debris_direction = Vector2.UP
		var material_parameters := particle_parameters.duplicate(true)
		material_parameters["count_multiplier"] = float(material_parameters.get("count_multiplier", 1.0)) * 0.35
		PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), profile_id, material_position, debris_direction, 0.8, Color.TRANSPARENT, material_parameters)
