extends PanelContainer
class_name ZoneSelectCard

signal selected(zone_id: String)

const GOLD := Color("#d3a637")
const GOLD_BRIGHT := Color("#ffe18a")
const TEXT := Color("#d9d0af")
const MUTED := Color("#827a61")
const PANEL := Color("#0d1c14")
const PANEL_HOVER := Color("#182b1b")
const PANEL_SELECTED := Color("#2c2817")

var zone_data: Dictionary = {}
var _hovered := false
var _selected := false
var _interaction_locked := false
var _tween: Tween = null
var _pulse_time := 0.0
var _status_label: Label = null

@onready var content: VBoxContainer = get_node_or_null("Content")
@onready var top_tint_line: ColorRect = get_node_or_null("Content/TopTintLine")
@onready var type_label: Label = get_node_or_null("Content/TypeLabel")
@onready var title_label: Label = get_node_or_null("Content/TitleLabel")
@onready var description_label: Label = get_node_or_null("Content/DescriptionLabel")
@onready var detail_label: Label = get_node_or_null("Content/DetailLabel")
@onready var preview_label: Label = get_node_or_null("Content/PreviewLabel")
@onready var bottom_tint_line: ColorRect = get_node_or_null("Content/BottomTintLine")
@onready var select_button: Button = get_node_or_null("Content/SelectButton")


func _process(delta: float) -> void:
	if str(zone_data.get("choice_mode", "")) == "stay" and not _hovered:
		_pulse_time += delta
		if top_tint_line != null:
			top_tint_line.modulate.a = 0.76 + 0.24 * (sin(_pulse_time * 2.2) + 1.0) * 0.5
	else:
		if top_tint_line != null:
			top_tint_line.modulate.a = 1.0


func _ready() -> void:
	_prepare_layout()
	if select_button != null:
		if not select_button.pressed.is_connected(_on_select_button_pressed):
			select_button.pressed.connect(_on_select_button_pressed)
		if not select_button.mouse_entered.is_connected(_on_mouse_entered):
			select_button.mouse_entered.connect(_on_mouse_entered)
		if not select_button.mouse_exited.is_connected(_on_mouse_exited):
			select_button.mouse_exited.connect(_on_mouse_exited)
	_refresh_visual()


func configure(zone_entry: Dictionary) -> void:
	zone_data = zone_entry.duplicate(true)
	_refresh_visual()


func animate_in(index: int = 0) -> void:
	pivot_offset = size * 0.5 if size.length() > 0.0 else custom_minimum_size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.24).set_delay(index * 0.07)
	tween.tween_property(self, "scale", Vector2.ONE, 0.30).set_delay(index * 0.07)


func set_selected(selected_value: bool) -> void:
	_selected = selected_value
	_update_panel_style(_get_zone_tint())
	if _selected:
		_animate_scale(Vector2(1.035, 1.035), 0.14)
	else:
		_animate_scale(Vector2.ONE, 0.14)


func set_interaction_locked(locked: bool) -> void:
	_interaction_locked = locked
	if select_button != null:
		select_button.disabled = locked


func _prepare_layout() -> void:
	custom_minimum_size = Vector2(184, 262)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if content != null:
		content.custom_minimum_size = Vector2(184, 262)
		content.add_theme_constant_override("separation", 6)
	if _status_label == null and content != null:
		_status_label = Label.new()
		_status_label.name = "StatusLabel"
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_label.add_theme_font_size_override("font_size", 10)
		content.add_child(_status_label)
		content.move_child(_status_label, 2)


func _refresh_visual() -> void:
	var zone_tint := _get_zone_tint()
	_update_panel_style(zone_tint)
	_update_button_style(zone_tint)
	_update_tint_lines(zone_tint)
	if _status_label != null:
		_status_label.text = _build_status_text()
		_status_label.add_theme_color_override("font_color", zone_tint.lightened(0.12))
	if type_label != null:
		type_label.text = _build_type_text()
		type_label.add_theme_color_override("font_color", zone_tint)
	if title_label != null:
		title_label.text = _build_card_title()
		title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	if description_label != null:
		description_label.text = str(zone_data.get("description", ""))
		description_label.add_theme_color_override("font_color", TEXT)
	if detail_label != null:
		detail_label.text = _build_detail_text()
		detail_label.add_theme_color_override("font_color", MUTED)
	if preview_label != null:
		preview_label.text = _build_preview_text()
		preview_label.add_theme_color_override("font_color", GOLD)
	if select_button != null:
		select_button.text = _build_card_button_text()


func _update_panel_style(zone_tint: Color) -> void:
	var background := PANEL_SELECTED if _selected else (PANEL_HOVER if _hovered else PANEL)
	var border := GOLD_BRIGHT if _selected else zone_tint
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2 if _selected else 1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 6 if _hovered or _selected else 3
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)


func _update_button_style(zone_tint: Color) -> void:
	if select_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(zone_tint.r * 0.25, zone_tint.g * 0.25, zone_tint.b * 0.25, 1.0)
	normal.border_color = zone_tint
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(zone_tint.r * 0.42, zone_tint.g * 0.42, zone_tint.b * 0.42, 1.0)
	hover.border_color = GOLD_BRIGHT
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(zone_tint.r * 0.55, zone_tint.g * 0.55, zone_tint.b * 0.55, 1.0)
	select_button.add_theme_stylebox_override("normal", normal)
	select_button.add_theme_stylebox_override("hover", hover)
	select_button.add_theme_stylebox_override("pressed", pressed)
	select_button.add_theme_stylebox_override("disabled", normal)
	select_button.add_theme_color_override("font_color", TEXT)
	select_button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	select_button.add_theme_font_size_override("font_size", 11)


func _update_tint_lines(zone_tint: Color) -> void:
	if top_tint_line != null:
		top_tint_line.color = zone_tint
	if bottom_tint_line != null:
		bottom_tint_line.color = zone_tint


func _animate_scale(target: Vector2, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target, duration)


func _on_mouse_entered() -> void:
	if _interaction_locked:
		return
	_hovered = true
	_update_panel_style(_get_zone_tint())
	_animate_scale(Vector2(1.02, 1.02) if not _selected else Vector2(1.045, 1.045), 0.12)


func _on_mouse_exited() -> void:
	_hovered = false
	_update_panel_style(_get_zone_tint())
	_animate_scale(Vector2(1.035, 1.035) if _selected else Vector2.ONE, 0.12)


func _build_status_text() -> String:
	var choice_mode := str(zone_data.get("choice_mode", ""))
	if choice_mode == "stay":
		return "当前驻守"
	if choice_mode == "switch":
		return "切换后将收割"
	if choice_mode == "initial":
		return "首次驻守"
	return "可选择区域"


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
	var enemy_pressure: Variant = zone_data.get("enemy_pressure", {})
	var player_pressure: Variant = zone_data.get("player_pressure", {})
	return "连驻层数：%d\n敌方压力：%s\n玩家压力：%s" % [streak_count, _format_dictionary(enemy_pressure), _format_dictionary(player_pressure)]


func _build_preview_text() -> String:
	var expected_fortune_gain := int(zone_data.get("expected_fortune_gain", 0))
	var harvest_preview: Variant = zone_data.get("harvest_preview", {})
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
	var label_overrides := {
		"max_hp_percent": "生命",
		"armor_flat": "护甲",
		"spawn_interval_percent": "刷怪频率",
		"damage_taken_percent": "承伤",
	}
	var parts: Array[String] = []
	var keys: Array = (value_data as Dictionary).keys()
	keys.sort()
	for key_variant in keys:
		var stat_id := str(key_variant)
		var amount := int((value_data as Dictionary)[key_variant])
		var label := str(label_overrides.get(stat_id, StatDefinitions.get_display_name(stat_id)))
		var sign := "+" if amount > 0 else ""
		parts.append("%s %s%d" % [label, sign, amount])
	return ", ".join(parts)


func _on_select_button_pressed() -> void:
	if _interaction_locked:
		return
	selected.emit(str(zone_data.get("zone_id", "")))
