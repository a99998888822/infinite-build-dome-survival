extends RefCounted
class_name ElementReactionResolver

const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")

const ELEMENT_WATER: String = "water"
const ELEMENT_FIRE: String = "fire"
const ELEMENT_ICE: String = "ice"
const ELEMENT_ELECTRIC: String = "electric"
const ELEMENT_LIGHT: String = "light"
const ELEMENT_DARK: String = "dark"

const DEFAULT_WET_DURATION: float = 3.0
const DEFAULT_WET_SLOW_MULTIPLIER: float = 0.8
const DEFAULT_BURN_DURATION: float = 3.0
const DEFAULT_BURN_TICK_DAMAGE_PERCENT: float = 0.10
const DEFAULT_FREEZE_DURATION: float = 1.0
const DEFAULT_ICE_SLOW_DURATION: float = 1.8
const DEFAULT_ICE_SLOW_MULTIPLIER: float = 0.45
const DEFAULT_STUN_DURATION: float = 0.5
const DEFAULT_LIGHT_DURATION: float = 5.0
const DEFAULT_DARK_DURATION: float = 2.0
const DEFAULT_STEAM_DAMAGE_MULTIPLIER: float = 1.15
const DARK_FLAME_DURATION: float = 10.0


static func apply_element(enemy: Node, element_id: String, reaction_data: Dictionary = {}) -> Dictionary:
	var result := {
		"element_id": element_id,
		"extra_trigger": false,
		"neutralized": false,
		"wet_consumed": false,
		"steam_damage": 0,
		"light_freeze": false,
		"burning_detonated": false,
		"reaction_id": "",
	}
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
		return result

	var parent: Node = reaction_data.get("parent", enemy.get_parent())
	var hit_position: Vector2 = reaction_data.get("hit_position", enemy.global_position)
	var source_id := str(reaction_data.get("source_id", "element_%s" % element_id))
	match element_id:
		ELEMENT_WATER:
			if enemy.has_status("burning"):
				var steam_damage := _get_steam_damage(reaction_data)
				_emit_steam(parent, hit_position)
				var original_damage := maxi(int(roundi(float(reaction_data.get("original_damage", reaction_data.get("damage", 0.0))))), 1)
				enemy.take_damage(
					steam_damage,
					source_id,
					false,
					hit_position.direction_to(enemy.global_position),
					[original_damage, maxi(steam_damage - original_damage, 0)],
				)
				result["steam_damage"] = steam_damage
				if not enemy.has_status("dark_flame"):
					enemy.clear_burning()
					result["neutralized"] = true
			else:
				enemy.apply_wet(
					maxf(float(reaction_data.get("wet_duration", DEFAULT_WET_DURATION)), 0.1),
					clampf(float(reaction_data.get("wet_slow_multiplier", DEFAULT_WET_SLOW_MULTIPLIER)), 0.05, 1.0),
				)
		ELEMENT_FIRE:
			if enemy.has_status("wet"):
				var steam_damage := _get_steam_damage(reaction_data)
				enemy.clear_wet()
				_emit_steam(parent, hit_position)
				var original_damage := maxi(int(roundi(float(reaction_data.get("original_damage", reaction_data.get("damage", 0.0))))), 1)
				enemy.take_damage(
					steam_damage,
					source_id,
					false,
					hit_position.direction_to(enemy.global_position),
					[original_damage, maxi(steam_damage - original_damage, 0)],
				)
				result["steam_damage"] = steam_damage
				result["neutralized"] = true
				result["wet_consumed"] = true
			else:
				var original_damage := maxf(float(reaction_data.get("original_damage", reaction_data.get("damage", 0.0))), 0.0)
				var tick_damage := float(reaction_data.get("burn_tick_damage", original_damage * DEFAULT_BURN_TICK_DAMAGE_PERCENT))
				var is_dark_flame: bool = enemy.has_status("dark")
				enemy.apply_burning(
					DARK_FLAME_DURATION if is_dark_flame else maxf(float(reaction_data.get("burn_duration", DEFAULT_BURN_DURATION)), 0.1),
					maxf(tick_damage, 0.0),
					source_id,
					enemy.has_status("light"),
					is_dark_flame,
				)
		ELEMENT_ICE:
			if enemy.has_status("wet"):
				result["light_freeze"] = enemy.has_status("light")
				enemy.clear_wet()
				enemy.apply_freeze(maxf(float(reaction_data.get("freeze_duration", DEFAULT_FREEZE_DURATION)), 0.1))
				_emit_ice_crystal(parent, hit_position)
				result["wet_consumed"] = true
			else:
				enemy.apply_slow(
					maxf(float(reaction_data.get("slow_duration", DEFAULT_ICE_SLOW_DURATION)), 0.1),
					clampf(float(reaction_data.get("slow_multiplier", DEFAULT_ICE_SLOW_MULTIPLIER)), 0.05, 1.0),
				)
		ELEMENT_ELECTRIC:
			enemy.apply_lightning_stun(maxf(float(reaction_data.get("stun_duration", DEFAULT_STUN_DURATION)), 0.1))
			if enemy.has_status("burning") and float(reaction_data.get("detonate_burning", 0.0)) > 0.0:
				enemy.clear_burning()
				result["burning_detonated"] = true
				result["reaction_id"] = "thunder_fire_blast"
			elif enemy.has_status("wet"):
				enemy.clear_wet()
				result["extra_trigger"] = true
				result["wet_consumed"] = true
		ELEMENT_LIGHT:
			if enemy.has_status("dark"):
				enemy.clear_blind()
				result["neutralized"] = true
			else:
				enemy.apply_light(maxf(float(reaction_data.get("light_duration", DEFAULT_LIGHT_DURATION)), 0.1))
				result["light_freeze"] = enemy.has_status("frozen")
		ELEMENT_DARK:
			if enemy.has_status("light"):
				enemy.clear_light()
				result["neutralized"] = true
			else:
				enemy.apply_blind(maxf(float(reaction_data.get("dark_duration", DEFAULT_DARK_DURATION)), 0.1))
	return result


static func _emit_steam(parent: Node, hit_position: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	PARTICLE_WORLD_SCRIPT.emit_profile(parent, "steam_burst", hit_position, Vector2.UP, 1.0)


static func _get_steam_damage(reaction_data: Dictionary) -> int:
	var original_damage := maxf(float(reaction_data.get("original_damage", reaction_data.get("damage", 0.0))), 0.0)
	return maxi(1, int(roundi(original_damage * float(reaction_data.get("steam_damage_multiplier", DEFAULT_STEAM_DAMAGE_MULTIPLIER)))))


static func _emit_ice_crystal(parent: Node, hit_position: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	PARTICLE_WORLD_SCRIPT.emit_profile(parent, "ice_burst", hit_position, Vector2.ZERO, 1.0, Color.TRANSPARENT, {
		"count_multiplier": 0.65,
		"size_multiplier": 1.25,
		"lifetime_multiplier": 1.25,
	})
