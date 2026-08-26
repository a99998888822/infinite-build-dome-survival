extends Button
class_name ItemInventoryCard

const RARITY_COLORS: Dictionary = {
	"common": Color(0.70, 0.74, 0.78, 1.0),
	"uncommon": Color(0.35, 0.92, 0.45, 1.0),
	"rare": Color(0.35, 0.62, 1.0, 1.0),
	"epic": Color(0.72, 0.42, 1.0, 1.0),
	"mythic": Color(1.0, 0.58, 0.22, 1.0),
	"legendary": Color(1.0, 0.24, 0.22, 1.0),
}

var item_instance: Dictionary = {}
var drag_enabled: bool = true


func configure(next_item: Dictionary, allow_drag: bool = true) -> void:
	item_instance = next_item.duplicate(true)
	drag_enabled = allow_drag
	custom_minimum_size = Vector2(128.0, 58.0)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if drag_enabled else Control.CURSOR_ARROW
	flat = false
	var item_name := str(item_instance.get("display_name", item_instance.get("base_item_id", "item")))
	var equipped_weapon_id := str(item_instance.get("equipped_weapon_id", ""))
	var equipped_mark := " *" if not equipped_weapon_id.is_empty() else ""
	text = "%s%s\n#%s" % [item_name, equipped_mark, str(item_instance.get("item_instance_id", ""))]
	tooltip_text = _build_tooltip()
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.02, 0.95))
	add_theme_constant_override("outline_size", 3)


func _get_drag_data(_position: Vector2) -> Variant:
	if not drag_enabled or item_instance.is_empty():
		return null
	var preview := Label.new()
	preview.text = str(item_instance.get("display_name", "物品"))
	preview.add_theme_color_override("font_color", RARITY_COLORS.get(str(item_instance.get("rarity", "common")), Color.WHITE))
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 3)
	set_drag_preview(preview)
	return {
		"type": "augmentation_item",
		"item_instance_id": str(item_instance.get("item_instance_id", "")),
	}


func _append_rolled_parameter_lines(lines: Array[String]) -> void:
	var rolled_parameters: Variant = item_instance.get("rolled_parameters", {})
	if not (rolled_parameters is Dictionary) or rolled_parameters.is_empty():
		rolled_parameters = item_instance.get("effect_parameters", {})
	if not (rolled_parameters is Dictionary):
		return
	if rolled_parameters.has("chain_count"):
		lines.append("连续传递：%d 次" % int(rolled_parameters["chain_count"]))
	if rolled_parameters.has("chain_interval"):
		lines.append("传递间隔：%.2f 秒" % float(rolled_parameters["chain_interval"]))
	if rolled_parameters.has("stun_duration"):
		lines.append("麻痹时间：%.2f 秒" % float(rolled_parameters["stun_duration"]))


func _build_tooltip() -> String:
	var lines: Array[String] = []
	lines.append(str(item_instance.get("display_name", item_instance.get("base_item_id", "物品"))))
	lines.append("实例 %s" % str(item_instance.get("item_instance_id", "")))
	var description := str(item_instance.get("description", ""))
	if not description.is_empty():
		lines.append(description)
	var equipped_weapon_id := str(item_instance.get("equipped_weapon_id", ""))
	if not equipped_weapon_id.is_empty():
		lines.append("Equipped weapon: %s" % equipped_weapon_id)
	_append_rolled_parameter_lines(lines)
	for modifier in item_instance.get("modifiers", []):
		if modifier is Dictionary:
			lines.append("%s %s %s" % [str(modifier.get("channel", "")), str(modifier.get("operation", "")), str(modifier.get("value", ""))])
	return "\n".join(lines)
