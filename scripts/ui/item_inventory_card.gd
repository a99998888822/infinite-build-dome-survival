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
const RARITY_LABELS: Dictionary = {
	"common": "普通",
	"uncommon": "优秀",
	"rare": "稀有",
	"epic": "史诗",
	"mythic": "神话",
	"legendary": "传说",
}
const RARITY_COLOR_CODES: Dictionary = {
	"common": "#B3BDC7",
	"uncommon": "#59EB73",
	"rare": "#599EFF",
	"epic": "#B86BFF",
	"mythic": "#FF9438",
	"legendary": "#FF5C54",
}
const CATEGORY_LABELS: Dictionary = {
	"enchantment_scroll": "附魔卷轴",
	"wizard_scroll": "术士卷轴",
}
const EFFECT_LABELS: Dictionary = {
	"fire": "火焰",
	"explosion": "爆炸",
	"lightning": "闪电",
	"electric_spark": "电火花",
	"split": "分裂",
	"pierce": "穿透",
}
const EFFECT_COLOR_CODES: Dictionary = {
	"fire": "#FFAA61",
	"explosion": "#FFD89E",
	"lightning": "#BFE8FF",
	"electric_spark": "#FFD15C",
	"split": "#FF9ED7",
	"pierce": "#9EDBFF",
}
const MODIFIER_LABELS: Dictionary = {
	"damage": "伤害",
	"burn_duration": "燃烧时间",
	"glow_multiplier": "辉光强度",
	"particle_rate": "粒子发射",
	"count_multiplier": "粒子数量",
	"radius": "爆炸范围",
	"patch_duration": "火焰池持续时间",
	"chain_count": "连续传递",
	"jump_radius": "连锁范围",
	"detonate_burning": "燃烧引爆",
	"child_count": "分裂数量",
	"spread_angle": "分裂角度",
	"extra_target_hits": "额外命中",
}

signal item_tooltip_requested(anchor_card: ItemInventoryCard, bbcode_text: String)
signal item_tooltip_hidden

var item_instance: Dictionary = {}
var drag_enabled: bool = true


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(next_item: Dictionary, allow_drag: bool = true) -> void:
	item_instance = next_item.duplicate(true)
	drag_enabled = allow_drag
	custom_minimum_size = Vector2(128.0, 58.0)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if drag_enabled else Control.CURSOR_ARROW
	flat = false
	var item_name := str(item_instance.get("display_name", "物品"))
	var equipped_weapon_id := str(item_instance.get("equipped_weapon_id", ""))
	text = "%s\n%s" % [item_name, "已装填" if not equipped_weapon_id.is_empty() else "可装填"]
	tooltip_text = ""
	var rarity_color: Color = RARITY_COLORS.get(str(item_instance.get("rarity", "common")), Color.WHITE)
	add_theme_color_override("font_color", rarity_color)
	add_theme_color_override("font_hover_color", rarity_color.lightened(0.16))
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
		lines.append("[color=#F5D76E]连续传递：[/color][color=#7FD88F]%d 次[/color]" % int(rolled_parameters["chain_count"]))
	if rolled_parameters.has("chain_interval"):
		lines.append("[color=#F5D76E]传递间隔：[/color][color=#7FD88F]%.2f 秒[/color]" % float(rolled_parameters["chain_interval"]))
	if rolled_parameters.has("stun_duration"):
		lines.append("[color=#F5D76E]麻痹时间：[/color][color=#7FD88F]%.2f 秒[/color]" % float(rolled_parameters["stun_duration"]))
	if rolled_parameters.has("child_count"):
		lines.append("[color=#F5D76E]分裂子箭：[/color][color=#7FD88F]%d 支[/color]" % int(rolled_parameters["child_count"]))
	if rolled_parameters.has("spread_angle"):
		lines.append("[color=#F5D76E]分裂角度：[/color][color=#7FD88F]%d°[/color]" % int(rolled_parameters["spread_angle"]))
	if rolled_parameters.has("extra_target_hits"):
		lines.append("[color=#F5D76E]额外命中：[/color][color=#7FD88F]%d 个目标[/color]" % int(rolled_parameters["extra_target_hits"]))


func _build_tooltip() -> String:
	var lines: Array[String] = []
	var rarity := str(item_instance.get("rarity", "common"))
	var rarity_color := str(RARITY_COLOR_CODES.get(rarity, "#FFFFFF"))
	lines.append("[color=%s][b]%s[/b][/color]" % [rarity_color, str(item_instance.get("display_name", "物品"))])
	lines.append("[color=#C7D3E4]类型：%s　稀有度：%s[/color]" % [
		str(CATEGORY_LABELS.get(str(item_instance.get("category", "")), "特殊物品")),
		str(RARITY_LABELS.get(rarity, "未知")),
	])
	var description := str(item_instance.get("description", ""))
	if not description.is_empty():
		lines.append("[color=#FFFFFF]%s[/color]" % description)
	var effect_names := _get_effect_names()
	if not effect_names.is_empty():
		lines.append("[color=#F5D76E]附加效果：[/color][color=#BFD8FF]%s[/color]" % effect_names)
	var equipped_weapon_id := str(item_instance.get("equipped_weapon_id", ""))
	lines.append("[color=#F5D76E]装备状态：[/color][color=%s]%s[/color]" % [
		"#7FD88F" if not equipped_weapon_id.is_empty() else "#C7D3E4",
		"已装填" if not equipped_weapon_id.is_empty() else "未装填",
	])
	_append_rolled_parameter_lines(lines)
	for modifier in item_instance.get("modifiers", []):
		if modifier is Dictionary:
			lines.append(_format_modifier(modifier))
	return "\n".join(lines)


func _on_mouse_entered() -> void:
	if not item_instance.is_empty():
		item_tooltip_requested.emit(self, _build_tooltip())


func _on_mouse_exited() -> void:
	item_tooltip_hidden.emit()


func _get_effect_names() -> String:
	var names: Array[String] = []
	var effect_ids: Variant = item_instance.get("effect_ids", [])
	if effect_ids is Array:
		for effect_id in effect_ids:
			names.append(str(EFFECT_LABELS.get(str(effect_id), "附魔效果")))
	return "、".join(names)


func _format_modifier(modifier: Dictionary) -> String:
	var channel := str(modifier.get("channel", ""))
	var operation := str(modifier.get("operation", ""))
	var effect_id := str(modifier.get("effect_id", ""))
	if channel == "visual.color":
		return "[color=#F5D76E]粒子颜色：[/color][color=%s]%s[/color]" % [
			str(EFFECT_COLOR_CODES.get(effect_id, "#BFD8FF")),
			_get_visual_color_name(effect_id),
		]
	if channel == "detonate_burning":
		return "[color=#F5D76E]燃烧引爆：[/color][color=#7FD88F]已启用[/color]"
	var label := str(MODIFIER_LABELS.get(channel, "效果强化"))
	var value: Variant = modifier.get("value", 0.0)
	if not (value is int or value is float):
		return "[color=#F5D76E]%s：[/color][color=#7FD88F]已生效[/color]" % label
	var number := float(value)
	if operation == "multiply":
		var percent := (number - 1.0) * 100.0
		return _format_colored_value(label, _format_signed_number(percent) + "%", percent)
	if operation == "add_flat":
		var suffix := " 秒" if channel == "burn_duration" else " 次" if channel in ["chain_count", "child_count", "extra_target_hits"] else "°" if channel == "spread_angle" else ""
		return _format_colored_value(label, _format_signed_number(number) + suffix, number)
	if operation == "override":
		return "[color=#F5D76E]%s：[/color][color=#7FD88F]%.2f[/color]" % [label, number]
	return "[color=#F5D76E]%s：[/color][color=#7FD88F]已生效[/color]" % label


func _format_colored_value(label: String, value_text: String, number: float) -> String:
	var color := "#7FD88F" if number >= 0.0 else "#FF827A"
	return "[color=#F5D76E]%s：[/color][color=%s]%s[/color]" % [label, color, value_text]


func _format_signed_number(number: float) -> String:
	var sign := "+" if number >= 0.0 else ""
	if is_equal_approx(number, roundf(number)):
		return "%s%d" % [sign, roundi(number)]
	return "%s%.2f" % [sign, number]


func _get_visual_color_name(effect_id: String) -> String:
	match effect_id:
		"fire":
			return "火焰橙"
		"explosion":
			return "暖金色"
		"lightning":
			return "冰蓝色"
		"electric_spark":
			return "电光黄色"
		"split":
			return "粉白色"
		"pierce":
			return "浅蓝色"
		_:
			return "自定义色彩"
