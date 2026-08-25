extends RefCounted
class_name EffectContext

const EFFECT_MODIFIER_SCRIPT = preload("res://scripts/effects/effect_modifier.gd")

var effect_id: String = ""
var source_weapon_id: String = ""
var parameters: Dictionary = {}
var tags: Array[String] = []
var color_override: Color = Color.TRANSPARENT
var modifiers: Array[Dictionary] = []


func set_parameter(channel: String, value: Variant) -> void:
	if channel.is_empty():
		return
	parameters[channel] = value


func set_color_override(color: Color) -> void:
	color_override = color


func get_resolved_parameter(channel: String, fallback: float = 0.0) -> float:
	var value := float(parameters.get(channel, fallback))
	var add_flat := 0.0
	var add_percent := 0.0
	var multiplier := 1.0
	var override_value: Variant = null
	for modifier in modifiers:
		if not EFFECT_MODIFIER_SCRIPT.applies_to(modifier, effect_id, channel):
			continue
		match str(modifier.get("operation", "")):
			EFFECT_MODIFIER_SCRIPT.OP_ADD_FLAT:
				add_flat += float(modifier.get("value", 0.0))
			EFFECT_MODIFIER_SCRIPT.OP_ADD_PERCENT:
				add_percent += float(modifier.get("value", 0.0))
			EFFECT_MODIFIER_SCRIPT.OP_MULTIPLY:
				multiplier *= float(modifier.get("value", 1.0))
			EFFECT_MODIFIER_SCRIPT.OP_OVERRIDE:
				override_value = modifier.get("value", value)
	if override_value != null:
		value = float(override_value)
	value += add_flat
	value *= 1.0 + add_percent / 100.0
	value *= multiplier
	return value


func get_resolved_color(fallback: Color = Color.WHITE) -> Color:
	var color := color_override if color_override.a > 0.0 else fallback
	for modifier in modifiers:
		if not EFFECT_MODIFIER_SCRIPT.applies_to(modifier, effect_id, "visual.color"):
			continue
		var value: Variant = modifier.get("value", Color.TRANSPARENT)
		var color_value := _to_color(value)
		if color_value.a <= 0.0:
			continue
		match str(modifier.get("operation", "")):
			EFFECT_MODIFIER_SCRIPT.OP_OVERRIDE:
				color = color_value
			"tint":
				color = Color(color.r * color_value.r, color.g * color_value.g, color.b * color_value.b, color.a * color_value.a)
	return color


func get_tinted_color(base_color: Color) -> Color:
	var color := base_color
	for modifier in modifiers:
		if not EFFECT_MODIFIER_SCRIPT.applies_to(modifier, effect_id, "visual.color"):
			continue
		var color_value := _to_color(modifier.get("value", Color.TRANSPARENT))
		if color_value.a <= 0.0:
			continue
		match str(modifier.get("operation", "")):
			EFFECT_MODIFIER_SCRIPT.OP_OVERRIDE:
				color = color_value
			"tint":
				color = Color(color.r * color_value.r, color.g * color_value.g, color.b * color_value.b, color.a * color_value.a)
	return color


func _to_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(
			clampf(float(value[0]), 0.0, 1.0),
			clampf(float(value[1]), 0.0, 1.0),
			clampf(float(value[2]), 0.0, 1.0),
			clampf(float(value[3]), 0.0, 1.0) if value.size() > 3 else 1.0
		)
	return Color.TRANSPARENT


func add_modifier(data: Dictionary) -> void:
	var modifier := EFFECT_MODIFIER_SCRIPT.normalize(data)
	if str(modifier.get("channel", "")).is_empty():
		return
	modifiers.append(modifier)


func add_modifiers(data_list: Array) -> void:
	for data in data_list:
		if data is Dictionary:
			add_modifier(data)
