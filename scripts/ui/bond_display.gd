extends RefCounted
class_name BondDisplay

const BOND_LABEL_COLOR: String = "#F5D76E"
const ACTIVE_LAYER_COLOR: String = "#FFFFFF"
const LOCKED_LAYER_COLOR: String = "#8A8A8A"
const SPECIAL_TAG_NAMES: Dictionary = {
	"mystic": "\u795e\u79d8",
}


static func get_bond_id(record: Dictionary) -> String:
	return str(record.get("bond_id", "")).strip_edges()


static func get_bond_name(bond_id: String) -> String:
	var bond_data := DataRegistry.get_record("bonds", bond_id)
	return str(bond_data.get("name", bond_id))


static func build_item_bond_text(record: Dictionary, relic_system: RelicBondSystem = null) -> String:
	var bond_id := get_bond_id(record)
	if bond_id.is_empty():
		return ""
	var line := "[color=%s]\u7f81\u7eca[/color]\uff1a%s" % [BOND_LABEL_COLOR, get_bond_name(bond_id)]
	if relic_system != null:
		var count := relic_system.get_bond_count(bond_id)
		if count > 0:
			line += "[color=%s]\uff08\u5f53\u524d %d \u5c42\uff09[/color]" % [ACTIVE_LAYER_COLOR, count]
	return line


static func build_bond_tooltip_text(bond_id: String, relic_system: RelicBondSystem) -> String:
	var bond_name := get_bond_name(bond_id)
	var count := relic_system.get_bond_count(bond_id)
	var active_thresholds := relic_system.get_active_thresholds(bond_id)
	var bond_data := DataRegistry.get_record("bonds", bond_id)
	var lines: Array[String] = ["[color=%s]%s[/color]\uff08\u5f53\u524d %d\uff09" % [BOND_LABEL_COLOR, bond_name, count]]
	var thresholds: Variant = bond_data.get("thresholds", {})
	if thresholds is Dictionary:
		var keys: Array = thresholds.keys()
		keys.sort_custom(func(a, b): return int(str(a)) < int(str(b)))
		for key in keys:
			var threshold := int(str(key))
			var unlocked := active_thresholds.has(threshold)
			var layer_color := ACTIVE_LAYER_COLOR if unlocked else LOCKED_LAYER_COLOR
			var effects_text := _build_threshold_effects_text(thresholds[key])
			lines.append("[color=%s]%d[/color]\uff1a%s" % [layer_color, threshold, effects_text])
	return "\n".join(lines)


static func _build_threshold_effects_text(effects: Variant) -> String:
	var parts: Array[String] = []
	if effects is Array:
		for effect in effects:
			if not (effect is Dictionary):
				continue
			var effect_text := _build_single_effect_text(effect)
			if not effect_text.is_empty():
				parts.append(effect_text)
	return "\u3001".join(parts)


static func _build_single_effect_text(effect: Dictionary) -> String:
	if effect.has("stat"):
		var stat_id := str(effect.get("stat", ""))
		var display_name := StatDefinitions.get_display_name(stat_id)
		var value := float(effect.get("value", 0.0))
		var sign := "+" if value >= 0.0 else "-"
		var value_text := _format_effect_value(stat_id, absf(value))
		return "%s%s%s" % [display_name, sign, value_text]
	var effect_type := str(effect.get("effect", ""))
	if effect_type == "tagged_damage_percent":
		var target_text := _format_target_tags(effect.get("target_tags", []))
		var value := absf(float(effect.get("value", 0.0)))
		return "\u5bf9 %s \u4f24\u5bb3+%s" % [target_text, _format_percent(value)]
	return "\u7279\u6b8a\u6548\u679c"


static func _format_effect_value(stat_id: String, value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.2f" % value


static func _format_percent(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d%%" % roundi(value)
	return "%.2f%%" % value


static func _format_target_tags(tags: Variant) -> String:
	var names: Array[String] = []
	if tags is Array:
		for tag in tags:
			names.append(str(SPECIAL_TAG_NAMES.get(str(tag), str(tag))))
	return "\u3001".join(names)
