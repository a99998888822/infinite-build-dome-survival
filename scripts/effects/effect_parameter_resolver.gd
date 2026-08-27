extends RefCounted

const EFFECT_CONTEXT_SCRIPT = preload("res://scripts/effects/effect_context.gd")


static func build_weapon_context(weapon: Variant, effect_id: String, base_parameters: Dictionary = {}) -> RefCounted:
	var context := EFFECT_CONTEXT_SCRIPT.new()
	context.effect_id = effect_id
	context.parameters = base_parameters.duplicate(true)
	context.parameters["projectile_count"] = _get_weapon_stat(weapon, "projectile_count", 1.0)
	context.parameters["area_size_multiplier"] = 1.0 + _get_weapon_stat(weapon, "area_size", 0.0) / 100.0
	context.parameters["control_power"] = _get_weapon_stat(weapon, "control_power", 0.0)
	context.parameters["speed_multiplier"] = 1.0
	context.parameters["size_multiplier"] = 1.0
	context.parameters["lifetime_multiplier"] = 1.0
	context.parameters["gravity_multiplier"] = 1.0
	context.parameters["drag_multiplier"] = 1.0
	context.parameters["intensity_multiplier"] = 1.0
	context.parameters["glow_multiplier"] = 1.0
	if weapon != null:
		var attached_items: Array = weapon.get_attached_item_instances() if weapon.has_method("get_attached_item_instances") else []
		for attached_item in attached_items:
			if not (attached_item is Dictionary):
				continue
			var effect_parameters: Variant = attached_item.get("effect_parameters", {})
			if effect_parameters is Dictionary:
				for channel in effect_parameters.keys():
					context.parameters[str(channel)] = effect_parameters[channel]
			var rolled_parameters: Variant = attached_item.get("rolled_parameters", {})
			if rolled_parameters is Dictionary:
				for channel in rolled_parameters.keys():
					context.parameters[str(channel)] = rolled_parameters[channel]
		context.source_weapon_id = str(weapon.weapon_id)
		var raw_tags: Variant = weapon.weapon_data.get("tags", [])
		if raw_tags is Array:
			for tag in raw_tags:
				context.tags.append(str(tag))
		if weapon.has_method("get_rarity_color"):
			context.color_override = weapon.get_rarity_color()
		if weapon.has_method("get_effect_modifiers"):
			context.add_modifiers(weapon.get_effect_modifiers(effect_id))
	return context


static func _get_weapon_stat(weapon: Variant, stat_id: String, fallback: float) -> float:
	if weapon == null or not weapon.has_method("get_stat"):
		return fallback
	return float(weapon.get_stat(stat_id))
