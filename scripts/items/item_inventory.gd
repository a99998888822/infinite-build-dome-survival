extends RefCounted
class_name ItemInventory

signal items_changed
signal item_added(item_instance: Dictionary)

var _items: Array[Dictionary] = []
var _next_instance_number: int = 1
var _next_acquired_order: int = 1
var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func clear() -> void:
	_items.clear()
	_next_instance_number = 1
	_next_acquired_order = 1
	items_changed.emit()


func add_item_from_base(
	base_item_id: String,
	source_id: String = "",
	equipped_weapon_id: String = ""
) -> Dictionary:
	var base_data := DataRegistry.get_record("augmentations", base_item_id)
	if base_data.is_empty():
		push_warning("[ItemInventory] missing augmentation config: %s" % base_item_id)
		return {}
	var item := {
		"item_instance_id": "item_%06d" % _next_instance_number,
		"base_item_id": base_item_id,
		"category": str(base_data.get("category", "augmentation")),
		"rarity": str(base_data.get("rarity", "common")),
		"display_name": str(base_data.get("display_name", base_item_id)),
		"description": str(base_data.get("description", "")),
		"icon": str(base_data.get("icon", "")),
		"effect_ids": _to_string_array(base_data.get("effect_ids", [])),
		"effect_parameters": _duplicate_dictionary(base_data.get("effect_parameters", {})),
		"modifiers": _duplicate_dictionary_array(base_data.get("modifiers", [])),
		"rolled_parameters": _roll_instance_parameters(base_data, source_id),
		"source_id": source_id,
		"acquired_order": _next_acquired_order,
		"equipped_weapon_id": equipped_weapon_id,
	}
	_next_instance_number += 1
	_next_acquired_order += 1
	_items.append(item)
	item_added.emit(item.duplicate(true))
	items_changed.emit()
	return item.duplicate(true)


func get_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _items:
		result.append(item.duplicate(true))
	result.sort_custom(Callable(self, "_compare_acquired_order"))
	return result


func get_available_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _items:
		if str(item.get("equipped_weapon_id", "")).is_empty():
			result.append(item.duplicate(true))
	result.sort_custom(Callable(self, "_compare_acquired_order"))
	return result


func find_item(item_instance_id: String) -> Dictionary:
	for item in _items:
		if str(item.get("item_instance_id", "")) == item_instance_id:
			return item.duplicate(true)
	return {}


func set_equipped_weapon(item_instance_id: String, weapon_id: String) -> bool:
	for item in _items:
		if str(item.get("item_instance_id", "")) != item_instance_id:
			continue
		var current_weapon_id := str(item.get("equipped_weapon_id", ""))
		if not current_weapon_id.is_empty() and not weapon_id.is_empty() and current_weapon_id != weapon_id:
			return false
		item["equipped_weapon_id"] = weapon_id
		items_changed.emit()
		return true
	return false


func clear_equipped_weapon(item_instance_id: String) -> bool:
	return set_equipped_weapon(item_instance_id, "")


func get_equipped_item_for_weapon(weapon_id: String) -> Dictionary:
	for item in _items:
		if str(item.get("equipped_weapon_id", "")) == weapon_id:
			return item.duplicate(true)
	return {}


func get_item_count(include_equipped: bool = true) -> int:
	return _items.size() if include_equipped else get_available_items().size()


func _roll_instance_parameters(base_data: Dictionary, source_id: String) -> Dictionary:
	var result: Dictionary = {}
	if source_id != "drop":
		return result
	var ranges: Variant = base_data.get("instance_parameter_ranges", [])
	if not (ranges is Array):
		return result
	for range_data in ranges:
		if not (range_data is Dictionary):
			continue
		var channel := str(range_data.get("channel", "")).strip_edges()
		if channel.is_empty():
			continue
		var minimum := float(range_data.get("min", 0.0))
		var maximum := maxf(float(range_data.get("max", minimum)), minimum)
		var step := maxf(float(range_data.get("step", 0.0)), 0.0)
		var value := _random.randf_range(minimum, maximum)
		if step > 0.0:
			value = minimum + roundf((value - minimum) / step) * step
		value = clampf(value, minimum, maximum)
		if channel in ["chain_count", "child_count", "extra_target_hits"]:
			result[channel] = int(roundf(value))
		else:
			result[channel] = value
	return result


func _to_string_array(raw_values: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_values is Array:
		for value in raw_values:
			result.append(str(value))
	return result


func _duplicate_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return raw_value.duplicate(true)
	return {}


func _duplicate_dictionary_array(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_values is Array:
		for value in raw_values:
			if value is Dictionary:
				result.append(value.duplicate(true))
	return result


func _compare_acquired_order(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("acquired_order", 0)) < int(right.get("acquired_order", 0))
