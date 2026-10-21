extends RefCounted

const EFFECT_CONTEXT_SCRIPT = preload("res://scripts/effects/effect_context.gd")
static var _cached_inputs: Array = []
static var _cached_context: RefCounted
static var _cached_frame := -1
static var _cached_weapon_id := 0
static var _cached_all_modifiers: Array = []


static func build_weapon_context(weapon: Variant, effect_id: String, base_parameters: Dictionary = {}, attachment_item_id: String = "") -> RefCounted:
	return _build_context(_capture_inputs(weapon, effect_id, base_parameters, attachment_item_id))


# Read-only contexts for repeated reaction detonations. Compare actual inputs,
# including modifiers and attachment order, so a damage callback can change them.
static func build_cached_weapon_context(weapon: Variant, effect_id: String, base_parameters: Dictionary = {}, attachment_item_id: String = "") -> RefCounted:
	var frame := Engine.get_process_frames()
	if frame == _cached_frame and _matches_cached_weapon(weapon, effect_id, base_parameters, attachment_item_id):
		return _cached_context
	var inputs := _capture_inputs(weapon, effect_id, base_parameters, attachment_item_id)
	if frame != _cached_frame or inputs != _cached_inputs:
		_cached_inputs = inputs
		_cached_frame = frame
		_cached_context = _build_context(inputs)
	# Only the concrete weapon's getters have the known backing data below.
	# Custom providers/subclasses keep the original getter-based path.
	_cached_weapon_id = 0
	_cached_all_modifiers = []
	if weapon != null and weapon.get_script() != null and weapon.get_script().resource_path == "res://scripts/weapons/weapon_instance.gd":
		_cached_weapon_id = weapon.get_instance_id()
		_cached_all_modifiers = weapon.effect_modifiers.duplicate(true)
	return _cached_context


static func _matches_cached_weapon(weapon: Variant, effect_id: String, base_parameters: Dictionary, attachment_item_id: String) -> bool:
	if _cached_weapon_id == 0 or weapon == null or weapon.get_instance_id() != _cached_weapon_id: return false
	if _cached_inputs[0] != effect_id or _cached_inputs[1] != base_parameters or _cached_inputs[2] != attachment_item_id: return false
	# Read live stats in the original order. Compare nested values against the
	# detached snapshot, so direct edits inside a damage callback are visible too.
	var stats: Array = _cached_inputs[3]
	if _get_weapon_stat(weapon, "projectile_count", 1.0) != stats[0]: return false
	if _get_weapon_stat(weapon, "area_size", 0.0) != stats[1]: return false
	if _get_weapon_stat(weapon, "damage_area_size", 0.0) != stats[2]: return false
	if _get_weapon_stat(weapon, "control_power", 0.0) != stats[3]: return false
	return weapon._attached_item_instances == _cached_inputs[4] \
		and str(weapon.weapon_id) == _cached_inputs[5] \
		and weapon.weapon_data.get("tags", []) == _cached_inputs[6] \
		and weapon.get_rarity_color() == _cached_inputs[7] \
		and weapon.effect_modifiers == _cached_all_modifiers


static func _capture_inputs(weapon: Variant, effect_id: String, base_parameters: Dictionary, attachment_item_id: String) -> Array:
	var stats := [
		_get_weapon_stat(weapon, "projectile_count", 1.0),
		_get_weapon_stat(weapon, "area_size", 0.0),
		_get_weapon_stat(weapon, "damage_area_size", 0.0),
		_get_weapon_stat(weapon, "control_power", 0.0)]
	var items: Array = weapon.get_attached_item_instances() if weapon != null and weapon.has_method("get_attached_item_instances") else []
	var modifiers: Array = weapon.get_effect_modifiers(effect_id, attachment_item_id) if weapon != null and weapon.has_method("get_effect_modifiers") else []
	var tags: Variant = weapon.weapon_data.get("tags", []) if weapon != null else []
	return [effect_id, base_parameters.duplicate(true), attachment_item_id, stats, items,
		str(weapon.weapon_id) if weapon != null else "",
		tags.duplicate() if tags is Array else [],
		weapon.get_rarity_color() if weapon != null and weapon.has_method("get_rarity_color") else Color.TRANSPARENT, modifiers, weapon != null]


static func _build_context(inputs: Array) -> RefCounted:
	var effect_id: String = inputs[0]
	var attachment_item_id: String = inputs[2]
	var context := EFFECT_CONTEXT_SCRIPT.new()
	context.effect_id = effect_id
	context.parameters = inputs[1].duplicate(true)
	context.parameters["projectile_count"] = inputs[3][0]
	context.parameters["attack_range_multiplier"] = StatDefinitions.calculate_attack_range_multiplier(inputs[3][1])
	context.parameters["damage_area_size_multiplier"] = StatDefinitions.calculate_damage_area_multiplier(inputs[3][2])
	context.parameters["control_power"] = inputs[3][3]
	context.parameters["speed_multiplier"] = 1.0
	context.parameters["size_multiplier"] = 1.0
	context.parameters["lifetime_multiplier"] = 1.0
	context.parameters["gravity_multiplier"] = 1.0
	context.parameters["drag_multiplier"] = 1.0
	context.parameters["intensity_multiplier"] = 1.0
	context.parameters["glow_multiplier"] = 1.0
	if inputs[9]:
		var attached_items: Array = inputs[4]
		for attached_item in attached_items:
			if not (attached_item is Dictionary):
				continue
			if not attachment_item_id.is_empty() and str(attached_item.get("item_instance_id", "")) != attachment_item_id:
				continue
			# Base/rolled values belong to this effect only. Cross-effect bonuses
			# are explicitly scoped modifiers, resolved below by the weapon.
			if not effect_id in attached_item.get("effect_ids", []):
				continue
			var effect_parameters: Variant = attached_item.get("effect_parameters", {})
			if effect_parameters is Dictionary:
				for channel in effect_parameters.keys():
					context.parameters[str(channel)] = effect_parameters[channel]
			var rolled_parameters: Variant = attached_item.get("rolled_parameters", {})
			if rolled_parameters is Dictionary:
				for channel in rolled_parameters.keys():
					context.parameters[str(channel)] = rolled_parameters[channel]
		context.source_weapon_id = inputs[5]
		var raw_tags: Variant = inputs[6]
		if raw_tags is Array:
			for tag in raw_tags:
				context.tags.append(str(tag))
		context.color_override = inputs[7]
		context.add_modifiers(inputs[8])
	return context


static func _get_weapon_stat(weapon: Variant, stat_id: String, fallback: float) -> float:
	if weapon == null or not weapon.has_method("get_stat"):
		return fallback
	return float(weapon.get_stat(stat_id))
