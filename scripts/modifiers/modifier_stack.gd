extends RefCounted
class_name ModifierStack

var base_stats: Dictionary = {}
var modifiers: Array[Modifier] = []


func set_base_stat(stat_id: String, value: float) -> void:
	base_stats[stat_id] = StatDefinitions.clamp_stat_value(stat_id, value)


func set_base_stats(stats: Dictionary) -> void:
	base_stats.clear()
	for stat_id in stats.keys():
		set_base_stat(str(stat_id), float(stats[stat_id]))


func get_base_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	if base_stats.has(stat_id):
		return float(base_stats[stat_id])
	if StatDefinitions.has_stat(stat_id):
		return StatDefinitions.get_default_value(stat_id)
	return fallback_base_value


func add_modifier(modifier: Modifier) -> bool:
	if modifier == null:
		push_warning("Cannot add null modifier.")
		return false

	var errors := modifier.validate()
	if not errors.is_empty():
		for error in errors:
			push_warning(error)
		return false

	var modifier_to_add := modifier.duplicate_modifier()
	if not _apply_stack_rule(modifier_to_add):
		_sort_modifiers()
		return true
	modifiers.append(modifier_to_add)
	_sort_modifiers()
	return true


func add_modifier_from_dictionary(data: Dictionary) -> Modifier:
	var modifier := Modifier.from_dictionary(data)
	if add_modifier(modifier):
		return modifier
	return null


func remove_modifier(modifier_id: String) -> void:
	for index in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].id == modifier_id:
			modifiers.remove_at(index)


func remove_by_source(source_type: String, source_id: String) -> void:
	for index in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].matches_source(source_type, source_id):
			modifiers.remove_at(index)


func remove_by_source_type(source_type: String) -> void:
	for index in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].source_type == source_type:
			modifiers.remove_at(index)


func remove_by_target_scope(target_scope: String) -> void:
	for index in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].target_scope == target_scope:
			modifiers.remove_at(index)


func has_modifier(modifier_id: String) -> bool:
	for modifier in modifiers:
		if modifier.id == modifier_id:
			return true
	return false


func get_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	if stat_id == "damage_taken_percent":
		var armor_rate := StatDefinitions.calculate_damage_taken_from_armor(get_stat("armor"))
		var other_rate := _calculate_regular_stat(stat_id, fallback_base_value)
		return StatDefinitions.clamp_stat_value(stat_id, armor_rate * other_rate / 100.0)
	return _calculate_regular_stat(stat_id, fallback_base_value)


func get_all_modifiers(stat_id: String = "") -> Array[Modifier]:
	var result: Array[Modifier] = []
	for modifier in modifiers:
		if stat_id.is_empty() or modifier.stat == stat_id:
			result.append(modifier.duplicate_modifier())
	return result


func tick(delta: float) -> void:
	for modifier in modifiers:
		modifier.tick(delta)
	for index in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].is_expired():
			modifiers.remove_at(index)


func clear() -> void:
	base_stats.clear()
	modifiers.clear()


func clear_modifiers() -> void:
	modifiers.clear()


func debug_stat(stat_id: String) -> Dictionary:
	var base_value := get_base_stat(stat_id)
	var regular_value := _calculate_regular_stat(stat_id)
	var final_value := get_stat(stat_id)
	var stat_modifiers: Array[Dictionary] = []

	for modifier in modifiers:
		if modifier.stat == stat_id:
			stat_modifiers.append(modifier.to_dictionary())

	var debug_data := {
		"stat": stat_id,
		"display_name": StatDefinitions.get_display_name(stat_id),
		"category": StatDefinitions.get_category(stat_id),
		"base_value": base_value,
		"regular_value": regular_value,
		"final_value": final_value,
		"modifiers": stat_modifiers,
	}

	if stat_id == "damage_taken_percent":
		debug_data["armor"] = get_stat("armor")
		debug_data["armor_damage_taken_rate"] = StatDefinitions.calculate_damage_taken_from_armor(get_stat("armor"))
	return debug_data


func get_modifier_count(stat_id: String = "") -> int:
	if stat_id.is_empty():
		return modifiers.size()
	var count := 0
	for modifier in modifiers:
		if modifier.stat == stat_id:
			count += 1
	return count


func _apply_stack_rule(modifier_to_add: Modifier) -> bool:
	match modifier_to_add.stack_rule:
		Modifier.STACK_RULE_UNIQUE:
			remove_modifier(modifier_to_add.id)
		Modifier.STACK_RULE_REPLACE_SAME_SOURCE:
			_remove_by_stack_key(modifier_to_add.get_stack_key())
		Modifier.STACK_RULE_STACK_ADD:
			pass
		Modifier.STACK_RULE_STACK_WITH_LIMIT:
			_apply_stack_with_limit(modifier_to_add)
		Modifier.STACK_RULE_REFRESH_DURATION:
			return not _refresh_existing(modifier_to_add)
		Modifier.STACK_RULE_EXCLUSIVE_GROUP:
			_remove_exclusive_group(modifier_to_add)
	return true


func _apply_stack_with_limit(modifier_to_add: Modifier) -> void:
	var max_stacks := int(modifier_to_add.metadata.get("max_stacks", 1))
	if max_stacks <= 0:
		return

	var stack_key := modifier_to_add.get_stack_key()
	while _count_stack_key(stack_key) >= max_stacks:
		var removed := _remove_first_by_stack_key(stack_key)
		if not removed:
			return


func _refresh_existing(modifier_to_add: Modifier) -> bool:
	for modifier in modifiers:
		if modifier.id == modifier_to_add.id:
			modifier.refresh_duration(modifier_to_add.duration)
			modifier.value = modifier_to_add.value
			modifier.priority = modifier_to_add.priority
			modifier.tags = modifier_to_add.tags.duplicate()
			modifier.metadata = modifier_to_add.metadata.duplicate(true)
			return true
	return false


func _remove_exclusive_group(modifier_to_add: Modifier) -> void:
	var exclusive_group := str(modifier_to_add.metadata.get("exclusive_group", modifier_to_add.id))
	for index in range(modifiers.size() - 1, -1, -1):
		var modifier := modifiers[index]
		if modifier.stack_rule != Modifier.STACK_RULE_EXCLUSIVE_GROUP:
			continue
		var modifier_group := str(modifier.metadata.get("exclusive_group", modifier.id))
		if modifier_group == exclusive_group:
			modifiers.remove_at(index)


func _remove_by_stack_key(stack_key: String) -> void:
	for index in range(modifiers.size() - 1, -1, -1):
		if modifiers[index].get_stack_key() == stack_key:
			modifiers.remove_at(index)


func _remove_first_by_stack_key(stack_key: String) -> bool:
	for index in range(0, modifiers.size()):
		if modifiers[index].get_stack_key() == stack_key:
			modifiers.remove_at(index)
			return true
	return false


func _count_stack_key(stack_key: String) -> int:
	var count := 0
	for modifier in modifiers:
		if modifier.get_stack_key() == stack_key:
			count += 1
	return count


func _calculate_regular_stat(stat_id: String, fallback_base_value: float = 0.0) -> float:
	var value := get_base_stat(stat_id, fallback_base_value)
	var add_flat_total := 0.0
	var add_percent_total := 0.0
	var multiply_total := 1.0
	var min_cap_value := -INF
	var max_cap_value := INF

	for modifier in modifiers:
		if modifier.stat != stat_id:
			continue
		match modifier.operation:
			Modifier.OPERATION_OVERRIDE:
				value = modifier.value
			Modifier.OPERATION_ADD_FLAT:
				add_flat_total += modifier.value
			Modifier.OPERATION_ADD_PERCENT:
				add_percent_total += modifier.value
			Modifier.OPERATION_MULTIPLY:
				multiply_total *= modifier.value
			Modifier.OPERATION_MIN_CAP:
				min_cap_value = maxf(min_cap_value, modifier.value)
			Modifier.OPERATION_MAX_CAP:
				max_cap_value = minf(max_cap_value, modifier.value)

	value += add_flat_total
	value *= 1.0 + add_percent_total / 100.0
	value *= multiply_total
	if min_cap_value != -INF:
		value = maxf(value, min_cap_value)
	if max_cap_value != INF:
		value = minf(value, max_cap_value)
	return StatDefinitions.clamp_stat_value(stat_id, value)


func _sort_modifiers() -> void:
	modifiers.sort_custom(Callable(self, "_compare_modifier_priority"))


func _compare_modifier_priority(a: Modifier, b: Modifier) -> bool:
	if a.priority == b.priority:
		return a.id < b.id
	return a.priority < b.priority
