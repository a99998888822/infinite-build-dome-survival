extends Control
class_name ZoneSelectPopup

const ZONE_SELECT_CARD_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_select_card.tscn")

signal zone_selected(zone_id: String)

var selection_payload: Dictionary = {}

@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var zone_card_grid: GridContainer = get_node_or_null("CenterContainer/MainPanel/Content/ZoneCardGrid")
@onready var hint_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/HintLabel")


func _ready() -> void:
	_prepare_layout()
	hide_popup()
	_refresh_visual()


func configure(payload: Dictionary) -> void:
	selection_payload = payload.duplicate(true)
	_refresh_visual()


func show_popup() -> void:
	show()


func hide_popup() -> void:
	hide()


func _prepare_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if center_container != null:
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	if main_panel != null:
		main_panel.custom_minimum_size = Vector2(1040, 620)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if zone_card_grid != null:
		zone_card_grid.columns = 3


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
	for zone_entry in zones:
		if zone_entry is Dictionary:
			zone_card_grid.add_child(_create_zone_card(zone_entry))


func _create_zone_card(zone_entry: Dictionary) -> Control:
	var card := ZONE_SELECT_CARD_SCENE.instantiate() as ZoneSelectCard
	if card == null:
		var fallback := Label.new()
		fallback.text = "区域卡加载失败"
		return fallback
	card.configure(zone_entry)
	var selected_callable := Callable(self, "_on_zone_card_pressed")
	if not card.selected.is_connected(selected_callable):
		card.selected.connect(selected_callable)
	return card


func _build_summary_text() -> String:
	var current_zone_name := str(selection_payload.get("current_zone_name", ""))
	var streak_count := int(selection_payload.get("streak_count", 0))
	var fortune_storage := int(selection_payload.get("fortune_storage", 0))
	var pending_harvest := bool(selection_payload.get("pending_harvest", false))
	return "当前驻守：%s\n连驻层数：%d\n福缘储备：%d\n待收割：%s" % [current_zone_name, streak_count, fortune_storage, str(pending_harvest)]


func _build_hint_text() -> String:
	return "同一区域会继续积累福缘；切换区域会触发收割。"


func _on_zone_card_pressed(zone_id: String) -> void:
	zone_selected.emit(zone_id)
