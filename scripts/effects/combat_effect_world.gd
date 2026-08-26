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
	if weapon.has_method("has_effect") and weapon.has_effect("fire"):
		FIRE_SEED_SCRIPT.spawn(parent, hit_position, weapon, damage_event, direction)
	if weapon.has_method("has_effect") and weapon.has_effect("explosion"):
		EXPLOSION_EFFECT_SCRIPT.spawn(parent, hit_position, weapon, damage_event)
	if body is EnemyController and weapon.has_method("has_effect") and weapon.has_effect("lightning"):
		LIGHTNING_EFFECT_SCRIPT.spawn(parent, hit_position, body, weapon, damage_event, direction)
