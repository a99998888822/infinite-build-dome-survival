extends Control
class_name ZoneSelectPopup

const ZONE_SELECT_CARD_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_select_card.tscn")
const STATS_DRAWER_RESERVED_WIDTH: float = 336.0
const GOLD := Color("#d3a637")
const GOLD_BRIGHT := Color("#ffe18a")
const PANEL_GREEN := Color("#0d1c14")
const PANEL_GREEN_DARK := Color("#0a110c")
const TEXT := Color("#d9d0af")
const MUTED := Color("#827a61")
const CYAN := Color("#8dbda0")

signal zone_selected(zone_id: String)

var selection_payload: Dictionary = {}
var _backdrop: ColorRect = null
var _accent_line: ColorRect = null
var _show_tween: Tween = null
var _selection_locked := false

@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var zone_card_grid: HBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content/ZoneCardGrid")
@onready var hint_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/HintLabel")


func _ready() -> void:
	_prepare_layout()
	_ensure_visual_layers()
	hide_popup()
	_refresh_visual()


func configure(payload: Dictionary) -> void:
	selection_payload = payload.duplicate(true)
	_selection_locked = false
	_refresh_visual()


func show_popup() -> void:
	_prepare_layout()
	_selection_locked = false
	visible = true
	_refresh_visual()
	if main_panel == null:
		return
	main_panel.pivot_offset = main_panel.size * 0.5
	main_panel.modulate.a = 0.0
	main_panel.scale = Vector2(0.96, 0.96)
	if _backdrop != null:
		_backdrop.modulate.a = 0.0
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _backdrop != null:
		_show_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.20)
	_show_tween.parallel().tween_property(main_panel, "modulate:a", 1.0, 0.24)
	_show_tween.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.32)
	if AudioManager != null:
		AudioManager.play_ui_sfx("modal_open")


func hide_popup() -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	visible = false
	_selection_locked = false
	if main_panel != null:
		main_panel.modulate.a = 1.0
		main_panel.scale = Vector2.ONE
	if _backdrop != null:
		_backdrop.modulate.a = 1.0


func _prepare_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	if center_container != null:
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_container.offset_top = 18.0
		center_container.offset_bottom = -18.0
		center_container.offset_right = -STATS_DRAWER_RESERVED_WIDTH
		center_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		center_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	if main_panel != null:
		main_panel.custom_minimum_size = Vector2(800, 520)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		main_panel.add_theme_stylebox_override("panel", _make_panel_style())
	if content != null:
		content.add_theme_constant_override("separation", 12)
	if title_label != null:
		title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		title_label.add_theme_font_size_override("font_size", 24)
	if summary_label != null:
		summary_label.add_theme_color_override("font_color", TEXT)
		summary_label.add_theme_font_size_override("font_size", 13)
	if hint_label != null:
		hint_label.add_theme_color_override("font_color", CYAN)
		hint_label.add_theme_font_size_override("font_size", 12)


func _ensure_visual_layers() -> void:
	if _backdrop == null:
		_backdrop = ColorRect.new()
		_backdrop.name = "ZoneSelectBackdrop"
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop.color = Color(0.01, 0.02, 0.015, 0.82)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backdrop.z_index = -5
		add_child(_backdrop)
		move_child(_backdrop, 0)
	if _accent_line == null and content != null:
		_accent_line = ColorRect.new()
		_accent_line.name = "HeaderAccentLine"
		_accent_line.custom_minimum_size = Vector2(0.0, 2.0)
		_accent_line.color = GOLD
		content.add_child(_accent_line)
		content.move_child(_accent_line, 1)


func _refresh_visual() -> void:
	if title_label != null:
		title_label.text = "区域选择"
	if summary_label != null:
		summary_label.text = _build_summary_text()
	if hint_label != null:
		hint_label.text = _build_hint_text()
	_rebuild_cards()


func _rebuild_cards() -> void:
	if zone_card_grid == null:
		return
	for child in zone_card_grid.get_children():
		child.queue_free()
	var zones: Variant = selection_payload.get("zones", [])
	if not (zones is Array):
		return
	var index := 0
	for zone_entry in zones:
		if zone_entry is Dictionary:
			var card := _create_zone_card(zone_entry)
			if card == null:
				continue
			zone_card_grid.add_child(card)
			card.set_selected(str(zone_entry.get("choice_mode", "")) == "stay")
			card.animate_in(index)
			index += 1


func _create_zone_card(zone_entry: Dictionary) -> ZoneSelectCard:
	var card := ZONE_SELECT_CARD_SCENE.instantiate() as ZoneSelectCard
	if card == null:
		return null
	card.configure(zone_entry)
	var selected_callable := Callable(self, "_on_zone_card_pressed")
	if not card.selected.is_connected(selected_callable):
		card.selected.connect(selected_callable)
	return card


func _on_zone_card_pressed(zone_id: String) -> void:
	if _selection_locked or zone_id.is_empty():
		return
	_selection_locked = true
	for child in zone_card_grid.get_children():
		var card := child as ZoneSelectCard
		if card == null:
			continue
		var is_selected := str(card.zone_data.get("zone_id", "")) == zone_id
		card.set_selected(is_selected)
		card.set_interaction_locked(true)
	if AudioManager != null:
		AudioManager.play_ui_sfx("zone_select")
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if visible:
			zone_selected.emit(zone_id)
	)


func _build_summary_text() -> String:
	var current_zone_name := str(selection_payload.get("current_zone_name", ""))
	var streak_count := int(selection_payload.get("streak_count", 0))
	var fortune_storage := int(selection_payload.get("fortune_storage", 0))
	var pending_harvest := bool(selection_payload.get("pending_harvest", false))
	return "当前驻守：%s    连驻层数：%d    福缘储备：%d    待收割：%s" % [current_zone_name if not current_zone_name.is_empty() else "无", streak_count, fortune_storage, "是" if pending_harvest else "否"]


func _build_hint_text() -> String:
	return "同一区域会继续积累福缘；切换区域会触发收割。"


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_GREEN
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_top = 16
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	return style
