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
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")


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
	for water_instance in weapon.get_effect_instances("water"):
		WATER_WAVE_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(water_instance.get("item_instance_id", "")))
	for light_sword_instance in weapon.get_effect_instances("light_sword"):
		LIGHT_SWORD_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(light_sword_instance.get("item_instance_id", "")))
	for black_hole_instance in weapon.get_effect_instances("black_hole"):
		BLACK_HOLE_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(black_hole_instance.get("item_instance_id", "")))
	for fire_instance in weapon.get_effect_instances("fire"):
		var fire_result := _apply_element(body, "fire", parent, damage_event, hit_position)
		if not bool(fire_result.get("neutralized", false)):
			FIRE_SEED_SCRIPT.spawn(parent, hit_position, weapon, damage_event, direction, str(fire_instance.get("item_instance_id", "")))
	for explosion_instance in weapon.get_effect_instances("explosion"):
		EXPLOSION_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(explosion_instance.get("item_instance_id", "")))
	for spark_instance in weapon.get_effect_instances("electric_spark"):
		ELECTRIC_SPARK_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(spark_instance.get("item_instance_id", "")))
	for ice_instance in weapon.get_effect_instances("ice"):
		ICE_FIELD_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(ice_instance.get("item_instance_id", "")))
	if body is EnemyController:
		for lightning_instance in weapon.get_effect_instances("lightning"):
			LIGHTNING_EFFECT_SCRIPT.spawn(parent, hit_position, body, weapon, damage_event, direction, str(lightning_instance.get("item_instance_id", "")))


static func _apply_element(enemy: Node, element_id: String, parent: Node, damage_event: DamageEvent, hit_position: Vector2) -> Dictionary:
	if enemy == null or not (enemy is EnemyController):
		return {}
	return ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, element_id, {
		"parent": parent,
		"hit_position": hit_position,
		"source_id": damage_event.source_weapon_id,
		"damage": damage_event.damage,
		"original_damage": damage_event.original_damage,
	})
