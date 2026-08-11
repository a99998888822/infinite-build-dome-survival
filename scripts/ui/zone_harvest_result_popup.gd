extends Control
class_name ZoneHarvestResultPopup

signal confirmed

var harvest_payload: Dictionary = {}

@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var reward_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/RewardLabel")
@onready var detail_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/DetailLabel")
@onready var confirm_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ConfirmButton")


func _ready() -> void:
	_prepare_layout()
	hide_popup()
	_refresh_visual()
	if confirm_button != null and not confirm_button.pressed.is_connected(_on_confirm_button_pressed):
		confirm_button.pressed.connect(_on_confirm_button_pressed)


func configure(payload: Dictionary) -> void:
	harvest_payload = payload.duplicate(true)
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
		main_panel.custom_minimum_size = Vector2(900, 460)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh_visual() -> void:
	if title_label != null:
		title_label.text = "福缘收割结果"
	if summary_label != null:
		summary_label.text = _build_summary_text()
	if reward_label != null:
		reward_label.text = _build_reward_text()
	if detail_label != null:
		detail_label.text = _build_detail_text()
	if confirm_button != null:
		confirm_button.text = "继续"


func _build_summary_text() -> String:
	return "来源区域：%s -> %s" % [str(harvest_payload.get("source_zone_name", "")), str(harvest_payload.get("next_zone_name", ""))]


func _build_reward_text() -> String:
	var gold_gain := int(harvest_payload.get("gold_gain", 0))
	var extra_offer_count := int(harvest_payload.get("extra_offer_count", 0))
	return "获得金币：%d\n额外候选：%d" % [gold_gain, extra_offer_count]


func _build_detail_text() -> String:
	var streak_count := int(harvest_payload.get("streak_count", 0))
	var fortune_storage := int(harvest_payload.get("fortune_storage", 0))
	var tendency_tags := _join_strings(harvest_payload.get("tendency_tags", []))
	var target_pools := _join_strings(harvest_payload.get("target_pools", []))
	var tag_weight_bonus := int(harvest_payload.get("tag_weight_bonus", 0))
	var rarity_bonus := int(harvest_payload.get("rarity_bonus", 0))
	return "连驻层数：%d\n福缘储备：%d\n倾向标签：%s\n目标池：%s\n标签权重加成：%d\n稀有度加成：%d" % [streak_count, fortune_storage, tendency_tags, target_pools, tag_weight_bonus, rarity_bonus]


func _join_strings(value_data: Variant) -> String:
	if not (value_data is Array) or (value_data as Array).is_empty():
		return "无"
	var parts: Array[String] = []
	for value in value_data:
		var text := str(value).strip_edges()
		if not text.is_empty():
			parts.append(text)
	if parts.is_empty():
		return "无"
	return ", ".join(parts)


func _on_confirm_button_pressed() -> void:
	confirmed.emit()
