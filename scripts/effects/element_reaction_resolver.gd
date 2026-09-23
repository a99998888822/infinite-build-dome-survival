extends RefCounted
class_name ElementReactionResolver

const REACTION_VISUAL = preload("res://scripts/effects/element_reaction_visual.gd")
const REFLECTION = preload("res://scripts/effects/light_reflection_effect.gd")

const ELEMENT_WATER: String = "water"
const ELEMENT_FIRE: String = "fire"
const ELEMENT_ICE: String = "ice"
const ELEMENT_ELECTRIC: String = "electric"
const ELEMENT_LIGHT: String = "light"
const ELEMENT_DARK: String = "dark"

const DEFAULT_WET_DURATION: float = 5.0
const DEFAULT_WET_SLOW_MULTIPLIER: float = 0.8
const DEFAULT_BURN_DURATION: float = 3.0
const DEFAULT_BURN_TICK_DAMAGE_PERCENT: float = 0.10
const DEFAULT_FREEZE_DURATION: float = 1.0
const DEFAULT_ICE_SLOW_DURATION: float = 3.0
const DEFAULT_ICE_SLOW_MULTIPLIER: float = 0.45
const DEFAULT_STUN_DURATION: float = 0.5
const DEFAULT_LIGHT_DURATION: float = 5.0
const DEFAULT_DARK_DURATION: float = 2.0
const DEFAULT_STEAM_DAMAGE_MULTIPLIER: float = 1.5
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
	AudioManager.begin_combat_audio()

	var parent: Node = reaction_data.get("parent", enemy.get_parent())
	var hit_position: Vector2 = reaction_data.get("hit_position", enemy.global_position)
	var source_id := str(reaction_data.get("source_id", "element_%s" % element_id))
	var was_holy: bool = enemy.has_status("holy_flame")
	var was_dark_flame: bool = enemy.has_status("dark_flame")
	match element_id:
		ELEMENT_WATER:
			if enemy.has_status("burning"):
				var steam_damage := _get_steam_damage(reaction_data)
				_emit_steam(parent, hit_position)
				var original_damage := maxi(int(roundi(float(reaction_data.get("original_damage", reaction_data.get("damage", 0.0))))), 1)
				var damage_components: Array[int] = [original_damage, maxi(steam_damage - original_damage, 0)]
				enemy.take_damage(
					steam_damage,
					source_id,
					false,
					hit_position.direction_to(enemy.global_position),
					damage_components,
				)
				result["steam_damage"] = steam_damage
				if not enemy.has_status("dark_flame"):
					enemy.clear_burning()
					result["neutralized"] = true
			elif enemy.has_status("slowed") and not enemy.has_status("frozen"):
				_freeze(enemy, reaction_data, parent, hit_position)
				result["wet_consumed"] = true
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
				var damage_components: Array[int] = [original_damage, maxi(steam_damage - original_damage, 0)]
				enemy.take_damage(
					steam_damage,
					source_id,
					false,
					hit_position.direction_to(enemy.global_position),
					damage_components,
				)
				result["steam_damage"] = steam_damage
				result["wet_consumed"] = true
				if enemy.has_status("dark"):
					enemy.apply_burning(
						DARK_FLAME_DURATION,
						maxf(float(reaction_data.get("burn_tick_damage", original_damage * DEFAULT_BURN_TICK_DAMAGE_PERCENT)), 0.0),
						source_id,
						false,
						true,
					)
				else:
					result["neutralized"] = true
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
				_freeze(enemy, reaction_data, parent, hit_position)
				result["wet_consumed"] = true
			elif not enemy.has_status("frozen"):
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
				emit_feedback(parent, "conduct", hit_position)
		ELEMENT_LIGHT:
			if enemy.has_status("dark"):
				enemy.clear_blind()
				result["neutralized"] = true
				emit_feedback(parent, "cancel", hit_position)
			else:
				enemy.apply_light(maxf(float(reaction_data.get("light_duration", DEFAULT_LIGHT_DURATION)), 0.1))
		ELEMENT_DARK:
			if enemy.has_status("light"):
				enemy.clear_light()
				result["neutralized"] = true
				emit_feedback(parent, "cancel", hit_position)
			else:
				enemy.apply_blind(maxf(float(reaction_data.get("dark_duration", DEFAULT_DARK_DURATION)), 0.1))
	if not was_holy and enemy.has_status("holy_flame"):
		emit_feedback(parent, "holy", hit_position)
	if not was_dark_flame and enemy.has_status("dark_flame"):
		emit_feedback(parent, "dark_flame", hit_position)
	var damage_event: DamageEvent = reaction_data.get("damage_event")
	if damage_event != null and enemy.claim_light_reflection():
		result["light_freeze"] = true
		var direction := Vector2.RIGHT
		if is_instance_valid(damage_event.source_player):
			direction = damage_event.source_player.global_position.direction_to(enemy.global_position)
		REFLECTION.spawn(parent, hit_position, direction, damage_event)
	AudioManager.end_combat_audio()
	return result


static func _emit_steam(parent: Node, hit_position: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	emit_feedback(parent, "steam", hit_position)


static func _get_steam_damage(reaction_data: Dictionary) -> int:
	var original_damage := maxf(float(reaction_data.get("original_damage", reaction_data.get("damage", 0.0))), 0.0)
	return maxi(1, int(roundi(original_damage * float(reaction_data.get("steam_damage_multiplier", DEFAULT_STEAM_DAMAGE_MULTIPLIER)))))


static func _emit_ice_crystal(parent: Node, hit_position: Vector2) -> void:
	emit_feedback(parent, "freeze", hit_position)


static func _freeze(enemy: Node, data: Dictionary, parent: Node, hit_position: Vector2) -> void:
	enemy.clear_wet()
	var thaw_data := data.duplicate()
	thaw_data["wet_duration"] = DEFAULT_WET_DURATION
	enemy.apply_freeze(maxf(float(data.get("freeze_duration", DEFAULT_FREEZE_DURATION)), 0.1), thaw_data)
	_emit_ice_crystal(parent, hit_position)


static func emit_feedback(parent: Node, kind: String, hit_position: Vector2, options: Dictionary = {}) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	AudioManager.play_reaction_sfx(kind)
	REACTION_VISUAL.spawn(parent, kind, hit_position, options)
