extends RefCounted
## First-use render warmup for enchantment effect families.
##
## The dungeon loading screen already presents weapon, hit, bolt and burst
## samples. Fire seeds, water waves, element reaction cues and fire patches were
## still compiled on their first real cast, which showed up as a 60 ms frame the
## first time a run touched fire or water. This presents those families while the
## loading curtain is still opaque.
##
## Samples use a throwaway weapon and damage event. No enemy exists yet, so the
## damage these effects carry lands nowhere.

const FIRE_SEED = preload("res://scripts/effects/fire_seed.gd")
const FIRE_VISUAL = preload("res://scripts/effects/pixel_fire_visual.gd")
const WATER_WAVE = preload("res://scripts/effects/water_wave_effect.gd")
const REACTION_VISUAL = preload("res://scripts/effects/element_reaction_visual.gd")
const REACTION_TEXT = preload("res://scripts/effects/element_reaction_text.gd")
const EXPLOSION = preload("res://scripts/effects/explosion_effect.gd")
const ICE_FIELD = preload("res://scripts/effects/ice_field_effect.gd")
const ELECTRIC_SPARK = preload("res://scripts/effects/electric_spark_effect.gd")
const PARAMETER_RESOLVER = preload("res://scripts/effects/effect_parameter_resolver.gd")

const REACTION_KINDS: Array[String] = ["steam", "conduct", "freeze", "wet_spread"]


static func prepare(parent: Node2D) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var weapon := _sample_weapon()
	var event := _sample_event()
	for effect_id in ["fire", "water"]:
		weapon._attached_item_instances[0]["effect_ids"] = [effect_id]
		if effect_id == "fire":
			FIRE_SEED.spawn(parent, parent.global_position, weapon, event, Vector2.RIGHT)
			# The ground pool itself is an Area2D, and entry samples must never
			# carry gameplay bodies. Warm its flame geometry directly instead.
			var flame := FIRE_VISUAL.new()
			parent.add_child(flame)
			flame.setup_field(30.0, Color.WHITE)
		else:
			WATER_WAVE.spawn(parent, parent.global_position, weapon, event)
	weapon._attached_item_instances[0]["effect_ids"] = ["explosion"]
	EXPLOSION.spawn(parent, parent.global_position, weapon, event)
	weapon._attached_item_instances[0]["effect_ids"] = ["ice"]
	ICE_FIELD.spawn(parent, parent.global_position, weapon, event)
	# The warning ring and its deferred ground strike are separate draw paths.
	weapon._attached_item_instances[0]["effect_ids"] = ["electric_spark"]
	ELECTRIC_SPARK.spawn(parent, parent.global_position, weapon, event)
	for kind in REACTION_KINDS:
		REACTION_VISUAL.spawn(parent, kind, parent.global_position)
		REACTION_TEXT.spawn(parent, kind, parent.global_position)


static func _sample_weapon() -> WeaponInstance:
	var weapon := WeaponInstance.new()
	weapon.weapon_id = "render_warmup"
	weapon.weapon_data = {"hit_radius": 14.0, "tags": []}
	weapon.runtime_stats = {"area_size": 0.0, "damage_area_size": 0.0}
	weapon._attached_item_instances = [{"effect_ids": ["fire"], "effect_parameters": {}}]
	return weapon


static func _sample_event() -> DamageEvent:
	return DamageEvent.create({"damage": 1, "original_damage": 1, "source_weapon_id": "render_warmup"})
