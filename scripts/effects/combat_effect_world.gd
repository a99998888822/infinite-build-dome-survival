extends RefCounted
class_name CombatEffectWorld

const FIRE_SEED_SCRIPT = preload("res://scripts/effects/fire_seed.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/effects/lightning_particle_effect.gd")


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
	for fire_instance in weapon.get_effect_instances("fire"):
		FIRE_SEED_SCRIPT.spawn(parent, hit_position, weapon, damage_event, direction, str(fire_instance.get("item_instance_id", "")))
	for explosion_instance in weapon.get_effect_instances("explosion"):
		EXPLOSION_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event, str(explosion_instance.get("item_instance_id", "")))
	if body is EnemyController:
		for lightning_instance in weapon.get_effect_instances("lightning"):
			LIGHTNING_EFFECT_SCRIPT.spawn(parent, hit_position, body, weapon, damage_event, direction, str(lightning_instance.get("item_instance_id", "")))
