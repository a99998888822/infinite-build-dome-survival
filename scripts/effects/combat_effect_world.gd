extends RefCounted
class_name CombatEffectWorld

const FIRE_SEED_SCRIPT = preload("res://scripts/effects/fire_seed.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/effects/lightning_particle_effect.gd")
const ELECTRIC_SPARK_EFFECT_SCRIPT = preload("res://scripts/effects/electric_spark_effect.gd")
const ICE_FIELD_EFFECT_SCRIPT = preload("res://scripts/effects/ice_field_effect.gd")
const WATER_WAVE_EFFECT_SCRIPT = preload("res://scripts/effects/water_wave_effect.gd")
const LIGHT_SWORD_EFFECT_SCRIPT = preload("res://scripts/effects/light_sword_effect.gd")
const BLACK_HOLE_EFFECT_SCRIPT = preload("res://scripts/effects/black_hole_effect.gd")
const WIND_BLADE_EFFECT_SCRIPT = preload("res://scripts/effects/wind_blade_effect.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const FIRE_PATCH_SCRIPT = preload("res://scripts/effects/fire_patch.gd")


static func trigger_weapon_impact(
	parent: Node,
	weapon: WeaponInstance,
	damage_event: DamageEvent,
	hit_position: Vector2,
	direction: Vector2 = Vector2.RIGHT,
	body: Node = null
) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	var visual_parent := _get_visual_parent(parent)
	for water_instance in weapon.get_effect_instances("water"):
		WATER_WAVE_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, str(water_instance.get("item_instance_id", "")))
	for light_sword_instance in weapon.get_effect_instances("light_sword"):
		LIGHT_SWORD_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, str(light_sword_instance.get("item_instance_id", "")))
	for black_hole_instance in weapon.get_effect_instances("black_hole"):
		BLACK_HOLE_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, str(black_hole_instance.get("item_instance_id", "")))
	for fire_instance in weapon.get_effect_instances("fire"):
		var fire_result := _apply_element(body, "fire", visual_parent, damage_event, hit_position)
		if not bool(fire_result.get("neutralized", false)):
			FIRE_SEED_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, direction, str(fire_instance.get("item_instance_id", "")))
	for explosion_instance in weapon.get_effect_instances("explosion"):
		EXPLOSION_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, str(explosion_instance.get("item_instance_id", "")))
	for spark_instance in weapon.get_effect_instances("electric_spark"):
		ELECTRIC_SPARK_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, str(spark_instance.get("item_instance_id", "")))
	for ice_instance in weapon.get_effect_instances("ice"):
		ICE_FIELD_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, str(ice_instance.get("item_instance_id", "")))
	if body is EnemyController:
		for lightning_instance in weapon.get_effect_instances("lightning"):
			LIGHTNING_EFFECT_SCRIPT.spawn(visual_parent, hit_position, body, weapon, damage_event, direction, str(lightning_instance.get("item_instance_id", "")))
		for wind_instance in weapon.get_effect_instances("wind"):
			_apply_wind(visual_parent, body, weapon, damage_event, hit_position, direction, str(wind_instance.get("item_instance_id", "")))


static func _get_visual_parent(parent: Node) -> Node:
	var render_world := PARTICLE_WORLD_SCRIPT.find_render_world(parent)
	return render_world if render_world != null else parent


static func _apply_element(enemy: Node, element_id: String, parent: Node, damage_event: DamageEvent, hit_position: Vector2) -> Dictionary:
	if enemy == null or not (enemy is EnemyController):
		return {}
	return ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, element_id, {
		"parent": parent,
		"hit_position": hit_position,
		"source_id": damage_event.source_weapon_id,
		"damage": damage_event.damage,
		"original_damage": damage_event.original_damage,
		"source_player": damage_event.source_player,
	})


static func _apply_wind(parent: Node, enemy: EnemyController, weapon: WeaponInstance, damage_event: DamageEvent, hit_position: Vector2, direction: Vector2, attachment_item_id: String) -> void:
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "wind", {
		"damage_multiplier": 0.7,
		"knockback_speed": 900.0,
		"knockback_duration": 0.34,
		"blade_speed": 480.0,
		"blade_lifetime": 0.46,
		"field_search_radius": 18.0,
		"field_radius_multiplier": 1.35,
		"wet_propagation_radius": 92.0,
		"wet_propagation_limit": 4.0,
		"wet_duration": 3.0,
		"wet_slow_multiplier": 0.8,
	}, attachment_item_id)
	var away_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	if damage_event.source_player != null and is_instance_valid(damage_event.source_player):
		away_direction = damage_event.source_player.global_position.direction_to(enemy.global_position)
	if away_direction.is_zero_approx():
		away_direction = Vector2.RIGHT
	WIND_BLADE_EFFECT_SCRIPT.spawn(parent, hit_position, away_direction, context.get_resolved_parameter("blade_speed", 480.0), context.get_resolved_parameter("blade_lifetime", 0.46))
	enemy.apply_knockback(away_direction, context.get_resolved_parameter("knockback_speed", 900.0), context.get_resolved_parameter("knockback_duration", 0.34))
	var wind_damage := maxi(1, int(roundi(float(damage_event.original_damage) * context.get_resolved_parameter("damage_multiplier", 0.7))))
	enemy.take_damage(wind_damage, damage_event.source_weapon_id, false, away_direction)
	var search_radius := maxf(context.get_resolved_parameter("field_search_radius", 18.0), 0.0)
	var field_multiplier := maxf(context.get_resolved_parameter("field_radius_multiplier", 1.35), 1.0)
	FIRE_PATCH_SCRIPT.expand_nearby_fields(enemy.global_position, search_radius, field_multiplier)
	for node in enemy.get_tree().get_nodes_in_group("ice_fields"):
		var ice_field := node as IceFieldEffect
		if ice_field != null and is_instance_valid(ice_field) and ice_field.global_position.distance_to(enemy.global_position) <= search_radius + ice_field._radius:
			ice_field.expand_from_wind(field_multiplier)
	if enemy.has_status("wet"):
		var propagation_radius := maxf(context.get_resolved_parameter("wet_propagation_radius", 92.0), 0.0)
		var propagation_limit := clampi(int(roundi(context.get_resolved_parameter("wet_propagation_limit", 4.0))), 0, 16)
		var propagated := 0
		for node in EnemyRegistry.get_registered_enemies():
			var other := node as EnemyController
			if other == null or other == enemy or not other.is_alive() or enemy.global_position.distance_to(other.global_position) > propagation_radius:
				continue
			other.apply_wet(
				maxf(context.get_resolved_parameter("wet_duration", 3.0), 0.1),
				clampf(context.get_resolved_parameter("wet_slow_multiplier", 0.8), 0.05, 1.0),
			)
			propagated += 1
			if propagated >= propagation_limit:
				break
