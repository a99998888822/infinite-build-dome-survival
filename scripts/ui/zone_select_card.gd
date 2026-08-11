extends PanelContainer
class_name ZoneSelectCard

signal selected(zone_id: String)

var zone_data: Dictionary = {}

@onready var top_tint_line: ColorRect = get_node_or_null("Content/TopTintLine")
@onready var type_label: Label = get_node_or_null("Content/TypeLabel")
@onready var title_label: Label = get_node_or_null("Content/TitleLabel")
@onready var description_label: Label = get_node_or_null("Content/DescriptionLabel")
@onready var detail_label: Label = get_node_or_null("Content/DetailLabel")
@onready var preview_label: Label = get_node_or_null("Content/PreviewLabel")
@onready var bottom_tint_line: ColorRect = get_node_or_null("Content/BottomTintLine")
@onready var select_button: Button = get_node_or_null("Content/SelectButton")


func _ready() -> void:
	_prepare_layout()
	if select_button != null and not select_button.pressed.is_connected(_on_select_button_pressed):
		select_button.pressed.connect(_on_select_button_pressed)
	_refresh_visual()


func configure(zone_entry: Dictionary) -> void:
	zone_data = zone_entry.duplicate(true)
	_refresh_visual()


func _prepare_layout() -> void:
	custom_minimum_size = Vector2(300, 280)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _refresh_visual() -> void:
	var zone_tint := _get_zone_tint()
	_update_panel_style(zone_tint)
	_update_tint_lines(zone_tint)

	if type_label != null:
		type_label.text = _build_type_text()
		type_label.add_theme_color_override("font_color", zone_tint)
	if title_label != null:
		title_label.text = _build_card_title()
	if description_label != null:
		description_label.text = str(zone_data.get("description", ""))
	if detail_label != null:
		detail_label.text = _build_detail_text()
	if preview_label != null:
		preview_label.text = _build_preview_text()
	if select_button != null:
		select_button.text = _build_card_button_text()


func _update_panel_style(zone_tint: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.10, 0.95)
	style.border_color = zone_tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)


func _update_tint_lines(zone_tint: Color) -> void:
	if top_tint_line != null:
		top_tint_line.color = zone_tint
	if bottom_tint_line != null:
		bottom_tint_line.color = zone_tint


func _build_type_text() -> String:
	var choice_mode := str(zone_data.get("choice_mode", ""))
	if choice_mode == "initial":
		return "首次驻守"
	if choice_mode == "stay":
		return "继续驻守"
	if choice_mode == "switch":
		return "切换驻守"
	return "区域"


func _build_card_title() -> String:
	var display_name := str(zone_data.get("display_name", zone_data.get("zone_id", "")))
	var choice_mode := str(zone_data.get("choice_mode", ""))
	if choice_mode == "initial":
		return "%s / 首次驻守" % display_name
	if choice_mode == "stay":
		return "%s / 继续驻守" % display_name
	return "%s / 切换驻守" % display_name


func _build_detail_text() -> String:
	var streak_count := int(zone_data.get("next_streak_count", 0))
	var enemy_pressure := zone_data.get("enemy_pressure", {})
	var player_pressure := zone_data.get("player_pressure", {})
	return "连驻层数：%d\n敌方压力：%s\n玩家压力：%s" % [streak_count, _format_dictionary(enemy_pressure), _format_dictionary(player_pressure)]


func _build_preview_text() -> String:
	var expected_fortune_gain := int(zone_data.get("expected_fortune_gain", 0))
	var harvest_preview := zone_data.get("harvest_preview", {})
	if harvest_preview is Dictionary and not (harvest_preview as Dictionary).is_empty():
		var harvest_text := harvest_preview as Dictionary
		return "预估福缘：%d\n换区收割：金币 %d / 候选 +%d" % [expected_fortune_gain, int(harvest_text.get("gold_gain", 0)), int(harvest_text.get("extra_offer_count", 0))]
	return "预估福缘：%d" % expected_fortune_gain


func _build_card_button_text() -> String:
	var choice_mode := str(zone_data.get("choice_mode", ""))
	if choice_mode == "stay":
		return "继续驻守"
	if choice_mode == "switch":
		return "切换到此区域"
	return "选择此区域"


func _get_zone_tint() -> Color:
	var tags: Variant = zone_data.get("tendency_tags", [])
	if tags is Array:
		var tag_list := tags as Array
		if tag_list.has("melee"):
			return Color(0.90, 0.38, 0.38, 1.0)
		if tag_list.has("ranged"):
			return Color(0.42, 0.74, 1.0, 1.0)
		if tag_list.has("elect"):
			return Color(0.68, 0.48, 1.0, 1.0)
		if tag_list.has("humanity"):
			return Color(0.52, 0.86, 0.58, 1.0)
		if tag_list.has("divinity"):
			return Color(0.98, 0.72, 0.38, 1.0)
	return Color(0.76, 0.76, 0.76, 1.0)


func _format_dictionary(value_data: Variant) -> String:
	if not (value_data is Dictionary) or (value_data as Dictionary).is_empty():
		return "无"
	var parts: Array[String] = []
	for key_variant in (value_data as Dictionary).keys():
		parts.append("%s %s" % [str(key_variant), str((value_data as Dictionary)[key_variant])])
	return ", ".join(parts)


func _on_select_button_pressed() -> void:
	selected.emit(str(zone_data.get("zone_id", "")))
