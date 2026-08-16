extends Node
class_name FinanceUIController

const FINANCE_POPUP_SCENE: PackedScene = preload("res://scenes/ui/finance/finance_popup.tscn")
const INTEREST_NOTICE_DURATION: float = 2.5

@onready var popup_layer: CanvasLayer = get_node_or_null("PopupLayer")
@onready var finance_popup: FinancePopup = get_node_or_null("PopupLayer/FinancePopup")

var _main_flow_coordinator: MainFlowCoordinator = null
var _interest_notice_panel: PanelContainer = null
var _interest_notice_label: Label = null
var _interest_notice_token: int = 0
var _interest_notice_tween: Tween = null

const INTEREST_NOTICE_VISIBLE_ALPHA: float = 0.82
const INTEREST_NOTICE_ANIMATION_SECONDS: float = 0.45


func _ready() -> void:
	_prepare_layers()
	call_deferred("_bind_to_main_flow")


func _prepare_layers() -> void:
	if popup_layer == null:
		popup_layer = CanvasLayer.new()
		popup_layer.name = "PopupLayer"
		popup_layer.layer = 25
		add_child(popup_layer)
	if finance_popup == null and popup_layer != null:
		finance_popup = FINANCE_POPUP_SCENE.instantiate() as FinancePopup
		if finance_popup != null:
			finance_popup.name = "FinancePopup"
			popup_layer.add_child(finance_popup)
	_ensure_interest_notice()


func _bind_to_main_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		call_deferred("_bind_to_main_flow")
		return
	if _main_flow_coordinator == coordinator:
		return
	_unbind_main_flow()
	_main_flow_coordinator = coordinator
	var requested_callable := Callable(self, "_on_modal_requested")
	var closed_callable := Callable(self, "_on_modal_closed")
	if not _main_flow_coordinator.modal_requested.is_connected(requested_callable):
		_main_flow_coordinator.modal_requested.connect(requested_callable)
	if not _main_flow_coordinator.modal_closed.is_connected(closed_callable):
		_main_flow_coordinator.modal_closed.connect(closed_callable)


func _unbind_main_flow() -> void:
	if _main_flow_coordinator == null:
		return
	var requested_callable := Callable(self, "_on_modal_requested")
	var closed_callable := Callable(self, "_on_modal_closed")
	if _main_flow_coordinator.modal_requested.is_connected(requested_callable):
		_main_flow_coordinator.modal_requested.disconnect(requested_callable)
	if _main_flow_coordinator.modal_closed.is_connected(closed_callable):
		_main_flow_coordinator.modal_closed.disconnect(closed_callable)
	_main_flow_coordinator = null


func _find_main_flow_coordinator() -> MainFlowCoordinator:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return (current as GameRoot).get_main_flow_coordinator()
		current = current.get_parent()
	if get_tree() != null and get_tree().current_scene is GameRoot:
		return (get_tree().current_scene as GameRoot).get_main_flow_coordinator()
	return null


func _on_modal_requested(modal_state: String, payload: Dictionary) -> void:
	match modal_state:
		MainFlowCoordinator.STATE_FINANCE_POPUP:
			_show_finance_popup(payload)
		MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
			_show_interest_settlement(payload)
		_:
			return


func _on_modal_closed(modal_state: String) -> void:
	match modal_state:
		MainFlowCoordinator.STATE_FINANCE_POPUP:
			if finance_popup != null:
				finance_popup.hide_popup()
		MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
			_hide_interest_notice()
		_:
			return


func _show_interest_settlement(payload: Dictionary) -> void:
	_ensure_interest_notice()
	if _interest_notice_panel == null or _interest_notice_label == null:
		return
	_interest_notice_token += 1
	var token := _interest_notice_token
	_interest_notice_label.text = _build_interest_notice_text(payload)
	_position_interest_notice(0.70)
	if _interest_notice_tween != null:
		_interest_notice_tween.kill()
	_interest_notice_panel.visible = true
	_interest_notice_panel.modulate.a = 0.0
	_interest_notice_tween = create_tween()
	_interest_notice_tween.set_trans(Tween.TRANS_CUBIC)
	_interest_notice_tween.set_ease(Tween.EASE_OUT)
	_interest_notice_tween.parallel().tween_property(_interest_notice_panel, "modulate:a", INTEREST_NOTICE_VISIBLE_ALPHA, INTEREST_NOTICE_ANIMATION_SECONDS)
	_interest_notice_tween.parallel().tween_property(_interest_notice_panel, "anchor_top", 0.30, INTEREST_NOTICE_ANIMATION_SECONDS)
	_interest_notice_tween.parallel().tween_property(_interest_notice_panel, "anchor_bottom", 0.30, INTEREST_NOTICE_ANIMATION_SECONDS)
	await get_tree().create_timer(INTEREST_NOTICE_DURATION).timeout
	if token != _interest_notice_token:
		return
	_hide_interest_notice()
	if _main_flow_coordinator != null and _main_flow_coordinator.get_current_state() == MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
		_main_flow_coordinator.close_interest_settlement()


func _show_finance_popup(payload: Dictionary) -> void:
	if finance_popup == null:
		return
	finance_popup.configure(payload)
	var operation_callable := Callable(self, "_on_finance_operation_submitted")
	var skipped_callable := Callable(self, "_on_finance_skipped")
	if not finance_popup.operation_submitted.is_connected(operation_callable):
		finance_popup.operation_submitted.connect(operation_callable)
	if not finance_popup.skipped.is_connected(skipped_callable):
		finance_popup.skipped.connect(skipped_callable)
	finance_popup.show_popup()


func _on_finance_operation_submitted(action: String, amount: int) -> void:
	if _main_flow_coordinator != null:
		var result := _main_flow_coordinator.submit_finance_operation(action, amount)
		if finance_popup != null and not bool(result.get("success", false)):
			finance_popup.show_error(str(result.get("reason", "unknown")))


func _on_finance_skipped() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.submit_finance_operation("none", 0)


func _ensure_interest_notice() -> void:
	if popup_layer == null:
		return
	_interest_notice_panel = popup_layer.get_node_or_null("InterestNotice") as PanelContainer
	if _interest_notice_panel != null:
		_interest_notice_label = _interest_notice_panel.get_node_or_null("NoticeContent/MessageLabel") as Label
		return
	_interest_notice_panel = PanelContainer.new()
	_interest_notice_panel.name = "InterestNotice"
	_interest_notice_panel.visible = false
	_interest_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_interest_notice_panel.add_theme_stylebox_override("panel", style)
	popup_layer.add_child(_interest_notice_panel)

	var notice_content := VBoxContainer.new()
	notice_content.name = "NoticeContent"
	notice_content.add_theme_constant_override("separation", 7)
	_interest_notice_panel.add_child(notice_content)

	var top_line := ColorRect.new()
	top_line.name = "TopLine"
	top_line.custom_minimum_size = Vector2(0.0, 2.0)
	top_line.color = Color(1.0, 1.0, 1.0, 0.94)
	notice_content.add_child(top_line)

	_interest_notice_label = Label.new()
	_interest_notice_label.name = "MessageLabel"
	_interest_notice_label.custom_minimum_size = Vector2(0.0, 30.0)
	_interest_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_interest_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interest_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interest_notice_label.add_theme_font_size_override("font_size", 18)
	_interest_notice_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_interest_notice_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	_interest_notice_label.add_theme_constant_override("outline_size", 3)
	notice_content.add_child(_interest_notice_label)

	var bottom_line := ColorRect.new()
	bottom_line.name = "BottomLine"
	bottom_line.custom_minimum_size = Vector2(0.0, 2.0)
	bottom_line.color = Color(1.0, 1.0, 1.0, 0.94)
	notice_content.add_child(bottom_line)


func _position_interest_notice(vertical_ratio: float = 0.30) -> void:
	if _interest_notice_panel == null or get_viewport() == null:
		return
	var text_width := _get_interest_notice_text_width()
	var width := clampf(ceil(text_width + 72.0), 240.0, 540.0)
	_interest_notice_panel.anchor_left = 0.0
	_interest_notice_panel.anchor_top = vertical_ratio
	_interest_notice_panel.anchor_right = 0.0
	_interest_notice_panel.anchor_bottom = vertical_ratio
	_interest_notice_panel.offset_left = 32.0
	_interest_notice_panel.offset_top = -26.0
	_interest_notice_panel.offset_right = 32.0 + width
	_interest_notice_panel.offset_bottom = 26.0


func _get_interest_notice_text_width() -> float:
	if _interest_notice_label == null:
		return 0.0
	var font := _interest_notice_label.get_theme_font("font")
	if font == null:
		return _interest_notice_label.get_minimum_size().x
	var font_size := _interest_notice_label.get_theme_font_size("font_size")
	return font.get_string_size(_interest_notice_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x


func _hide_interest_notice() -> void:
	_interest_notice_token += 1
	if _interest_notice_tween != null:
		_interest_notice_tween.kill()
	if _interest_notice_panel == null:
		return
	_interest_notice_tween = create_tween()
	_interest_notice_tween.set_trans(Tween.TRANS_CUBIC)
	_interest_notice_tween.set_ease(Tween.EASE_IN)
	_interest_notice_tween.tween_property(_interest_notice_panel, "modulate:a", 0.0, 0.20)
	_interest_notice_tween.tween_callback(_finish_hide_interest_notice)


func _finish_hide_interest_notice() -> void:
	if _interest_notice_panel != null:
		_interest_notice_panel.visible = false
		_interest_notice_panel.modulate.a = 0.0


func _build_interest_notice_text(payload: Dictionary) -> String:
	var gain := 0
	var ratio := float(payload.get("interest_rate", 0.0))
	var results: Array = payload.get("settlement_results", [])
	if results.is_empty():
		var single_result: Variant = payload.get("last_settlement_result", {})
		if single_result is Dictionary and not (single_result as Dictionary).is_empty():
			results = [single_result]
	for result in results:
		if not (result is Dictionary):
			continue
		var result_data: Dictionary = result
		gain += int(result_data.get("gain", 0))
		if result_data.has("interest_rate_after"):
			ratio = float(result_data.get("interest_rate_after", ratio))
		elif result_data.has("interest_rate"):
			ratio = float(result_data.get("interest_rate", ratio))
	return "当前利率%.1f%%，收获利息%d" % [ratio, gain]
