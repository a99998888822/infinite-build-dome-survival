extends Control
class_name InterestSettlementPopup

const GOLD := Color("#d3a637")
const GOLD_BRIGHT := Color("#ffe18a")
const PANEL_GREEN := Color("#0d1c14")
const TEXT := Color("#d9d0af")
const MUTED := Color("#827a61")
const GREEN := Color("#70bf7d")
const RED := Color("#bd6a62")

signal confirmed

var payload: Dictionary = {}
var _backdrop: ColorRect = null
var _show_tween: Tween = null
var _counter_tween: Tween = null
var _result_label: Label = null
var _detail_column: VBoxContainer = null
var _detail_line_nodes: Array[Label] = []
var _displayed_gain := 0
var _presentation_token := 0

@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var details_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/DetailsLabel")
@onready var confirm_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ConfirmButton")


func _ready() -> void:
	_prepare_layout()
	_ensure_backdrop()
	_ensure_dynamic_content()
	if confirm_button != null and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	hide_popup()


func configure(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)
	_refresh_visual()


func show_popup() -> void:
	_prepare_layout()
	_ensure_dynamic_content()
	_presentation_token += 1
	var token := _presentation_token
	visible = true
	_refresh_visual()
	if main_panel == null:
		return
	main_panel.pivot_offset = main_panel.size * 0.5
	main_panel.modulate.a = 0.0
	main_panel.scale = Vector2(0.95, 0.95)
	if confirm_button != null:
		confirm_button.disabled = true
	if _backdrop != null:
		_backdrop.modulate.a = 0.0
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _backdrop != null:
		_show_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.20)
	_show_tween.parallel().tween_property(main_panel, "modulate:a", 1.0, 0.26)
	_show_tween.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.34)
	_show_tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.22).set_delay(0.08)
	_show_tween.parallel().tween_property(summary_label, "modulate:a", 1.0, 0.22).set_delay(0.16)
	_show_tween.parallel().tween_property(_result_label, "modulate:a", 1.0, 0.22).set_delay(0.24)
	_start_gain_counter(token)
	_start_detail_lines(token)
	if AudioManager != null:
		AudioManager.play_ui_sfx("interest_reveal")


func hide_popup() -> void:
	_presentation_token += 1
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	if _counter_tween != null and _counter_tween.is_valid():
		_counter_tween.kill()
	visible = false
	if main_panel != null:
		main_panel.modulate.a = 1.0
		main_panel.scale = Vector2.ONE
	if _backdrop != null:
		_backdrop.modulate.a = 1.0


func _prepare_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if center_container != null:
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_container.offset_right = -320.0
		center_container.offset_top = 24.0
		center_container.offset_bottom = -24.0
	if main_panel != null:
		main_panel.custom_minimum_size = Vector2(620, 440)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		main_panel.add_theme_stylebox_override("panel", _make_panel_style())
	if content != null:
		content.add_theme_constant_override("separation", 11)
	if title_label != null:
		title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		title_label.add_theme_font_size_override("font_size", 24)
	if summary_label != null:
		summary_label.add_theme_color_override("font_color", TEXT)
		summary_label.add_theme_font_size_override("font_size", 13)
	if confirm_button != null:
		_style_confirm_button()


func _ensure_backdrop() -> void:
	if _backdrop != null:
		return
	_backdrop = ColorRect.new()
	_backdrop.name = "InterestBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.01, 0.02, 0.015, 0.84)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = -5
	add_child(_backdrop)
	move_child(_backdrop, 0)


func _ensure_dynamic_content() -> void:
	if content == null:
		return
	if _result_label == null:
		_result_label = Label.new()
		_result_label.name = "InterestGainLabel"
		_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_result_label.add_theme_font_size_override("font_size", 26)
		_result_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		content.add_child(_result_label)
		content.move_child(_result_label, 2)
	if _detail_column == null:
		_detail_column = VBoxContainer.new()
		_detail_column.name = "SettlementDetails"
		_detail_column.add_theme_constant_override("separation", 5)
		content.add_child(_detail_column)
		content.move_child(_detail_column, max(content.get_child_count() - 2, 0))
	if details_label != null:
		details_label.visible = false


func _refresh_visual() -> void:
	_ensure_dynamic_content()
	if title_label != null:
		title_label.text = "利息结算"
	if summary_label != null:
		summary_label.text = "本金：%d    ·    当前利率：%.1f%%" % [int(payload.get("principal", 0)), float(payload.get("interest_rate", 0.0))]
	if _result_label != null:
		_result_label.text = "+%d 利息" % _displayed_gain
		_result_label.add_theme_color_override("font_color", GREEN if _get_total_gain() > 0 else MUTED)
	if _detail_column != null:
		_rebuild_detail_lines()


func _rebuild_detail_lines() -> void:
	for child in _detail_column.get_children():
		child.queue_free()
	_detail_line_nodes.clear()
	var line_index := 0
	for line_text in _build_detail_lines():
		var line := Label.new()
		line.text = line_text
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color", _get_detail_line_color(line_index))
		line.modulate.a = 0.0
		_detail_column.add_child(line)
		_detail_line_nodes.append(line)
		line_index += 1


func _get_detail_line_color(index: int) -> Color:
	var results := _get_results()
	if index < 0 or index >= results.size() or not (results[index] is Dictionary):
		return MUTED
	var result := results[index] as Dictionary
	if bool(result.get("blocked", false)):
		return RED
	if bool(result.get("success", false)) and int(result.get("gain", 0)) > 0:
		return GOLD_BRIGHT
	return MUTED


func _start_gain_counter(token: int) -> void:
	_displayed_gain = 0
	if _result_label != null:
		_result_label.text = "+0 利息"
	var target_gain := _get_total_gain()
	_counter_tween = create_tween()
	_counter_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_counter_tween.tween_method(_set_gain_counter.bind(target_gain), 0.0, 1.0, 0.62)
	_counter_tween.tween_callback(func() -> void:
		if token == _presentation_token:
			_displayed_gain = target_gain
			_refresh_visual()
			if summary_label != null:
				summary_label.pivot_offset = summary_label.size * 0.5
				var bump := create_tween()
				bump.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				bump.tween_property(summary_label, "scale", Vector2(1.04, 1.04), 0.12)
				bump.tween_property(summary_label, "scale", Vector2.ONE, 0.18)
	)


func _set_gain_counter(progress: float, target_gain: int) -> void:
	_displayed_gain = int(roundf(lerpf(0.0, float(target_gain), progress)))
	if _result_label != null:
		_result_label.text = "+%d 利息" % _displayed_gain


func _start_detail_lines(token: int) -> void:
	var total_delay := 0.30
	for index in range(_detail_line_nodes.size()):
		var line := _detail_line_nodes[index]
		var tween := create_tween()
		tween.tween_property(line, "modulate:a", 1.0, 0.20).set_delay(total_delay + index * 0.08)
		total_delay += 0.08
	get_tree().create_timer(total_delay + 0.35).timeout.connect(func() -> void:
		if token == _presentation_token and is_instance_valid(confirm_button):
			confirm_button.disabled = false
	)


func _get_results() -> Array:
	var results: Array = payload.get("settlement_results", [])
	if results.is_empty():
		var single_result: Variant = payload.get("last_settlement_result", {})
		if single_result is Dictionary and not (single_result as Dictionary).is_empty():
			results = [single_result]
	return results


func _get_total_gain() -> int:
	var total := 0
	for result in _get_results():
		if result is Dictionary:
			total += int((result as Dictionary).get("gain", 0))
	return total


func _build_detail_lines() -> Array[String]:
	var lines: Array[String] = []
	for result in _get_results():
		if not (result is Dictionary):
			continue
		var result_data := result as Dictionary
		var source_label := _source_label(str(result_data.get("source", "")))
		if bool(result_data.get("blocked", false)):
			lines.append("⛓ %s：未收息（高利契约）" % source_label)
		elif not bool(result_data.get("success", false)):
			lines.append("· %s：未收息（%s）" % [source_label, _reason_label(str(result_data.get("reason", "unknown")))])
		else:
			var gain := int(result_data.get("gain", 0))
			lines.append("✦ %s：+%d 利息（利率 %.1f%%）" % [source_label, gain, float(result_data.get("interest_rate", 0.0))])
	if lines.is_empty():
		lines.append("本波没有利息结算记录。")
	return lines


func _reason_label(reason: String) -> String:
	match reason:
		"no_principal":
			return "无本金"
		"high_yield_requires_wave_start_deposit":
			return "高利契约（未达存入门槛）"
		"zero_interest_gain":
			return "无利息收益"
		_:
			return "未结算"


func _source_label(source: String) -> String:
	match source:
		"wave_end":
			return "波末结算"
		"periodic":
			return "周期分红钟"
		"annuity_extra":
			return "永续年金（追加结算）"
		_:
			return "利息结算"


func _style_confirm_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#3d3217")
	normal.border_color = GOLD
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#5a481d")
	hover.border_color = GOLD_BRIGHT
	confirm_button.add_theme_stylebox_override("normal", normal)
	confirm_button.add_theme_stylebox_override("hover", hover)
	confirm_button.add_theme_stylebox_override("pressed", hover)
	confirm_button.add_theme_color_override("font_color", TEXT)
	confirm_button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_GREEN
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	style.shadow_size = 10
	style.content_margin_left = 20
	style.content_margin_top = 18
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	return style


func _on_confirm_pressed() -> void:
	if confirm_button != null and confirm_button.disabled:
		return
	if AudioManager != null:
		AudioManager.play_ui_sfx("confirm")
	confirmed.emit()
