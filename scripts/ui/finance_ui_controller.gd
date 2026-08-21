extends Node
class_name FinanceUIController

const FINANCE_POPUP_SCENE: PackedScene = preload("res://scenes/ui/finance/finance_popup.tscn")
const INTEREST_SETTLEMENT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/finance/interest_settlement_popup.tscn")
const WEAPON_STRIP_SCENE: PackedScene = preload("res://scenes/ui/common/weapon_strip.tscn")
const INTEREST_NOTICE_DURATION: float = 2.5
const NUMERIC_FONT: Font = preload("res://assets/font/VT323-Regular.ttf")

@onready var popup_layer: CanvasLayer = get_node_or_null("PopupLayer")
@onready var finance_popup: FinancePopup = get_node_or_null("PopupLayer/FinancePopup")

var _finance_weapon_strip: WeaponStrip = null
var _interest_popup: InterestSettlementPopup = null
var _interest_popup_token: int = 0

var _main_flow_coordinator: MainFlowCoordinator = null
var _interest_notice_panel: PanelContainer = null
var _interest_notice_label: Label = null
var _interest_notice_token: int = 0
var _interest_notice_tween: Tween = null

const INTEREST_NOTICE_VISIBLE_ALPHA: float = 0.82
const INTEREST_NOTICE_ANIMATION_SECONDS: float = 0.45


func _ready() -> void:
	_prepare_layers()
	if get_viewport() != null:
		var viewport_callable := Callable(self, "_on_viewport_size_changed")
		if not get_viewport().size_changed.is_connected(viewport_callable):
			get_viewport().size_changed.connect(viewport_callable)
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
	_ensure_finance_weapon_strip()
	_ensure_interest_popup()


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
			if _finance_weapon_strip != null:
				_finance_weapon_strip.visible = false
		MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
			_interest_popup_token += 1
			if _interest_popup != null:
				_interest_popup.hide_popup()
			_hide_interest_notice()
		_:
			return


func _show_interest_settlement(payload: Dictionary) -> void:
	_ensure_interest_popup()
	if _interest_popup == null:
		return
	_interest_popup_token += 1
	var token := _interest_popup_token
	_interest_popup.configure(payload)
	var confirmed_callable := Callable(self, "_on_interest_popup_confirmed")
	if not _interest_popup.confirmed.is_connected(confirmed_callable):
		_interest_popup.confirmed.connect(confirmed_callable)
	_interest_popup.show_popup()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if token != _interest_popup_token:
			return
		if is_instance_valid(_interest_popup) and _interest_popup.visible:
			_interest_popup.hide_popup()
		if _main_flow_coordinator != null and _main_flow_coordinator.get_current_state() == MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
			_main_flow_coordinator.close_interest_settlement()
	)


func _on_interest_popup_confirmed() -> void:
	_interest_popup_token += 1
	if _interest_popup != null:
		_interest_popup.hide_popup()
	if _main_flow_coordinator != null and _main_flow_coordinator.get_current_state() == MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
		_main_flow_coordinator.close_interest_settlement()


func _show_finance_popup(payload: Dictionary) -> void:
	if finance_popup == null:
		return
	_ensure_finance_weapon_strip()
	if _finance_weapon_strip != null:
		_finance_weapon_strip.visible = true
		_finance_weapon_strip.set_loadout(_main_flow_coordinator.get_bound_loadout() if _main_flow_coordinator != null else null)
		_layout_finance_weapon_strip()
	finance_popup.set_safe_rect(_get_finance_safe_rect())
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


func _on_viewport_size_changed() -> void:
	var safe_rect := _get_finance_safe_rect()
	if finance_popup != null and finance_popup.visible:
		finance_popup.set_safe_rect(safe_rect)
	_layout_finance_weapon_strip()
	if _interest_notice_panel != null and _interest_notice_panel.visible:
		_position_interest_notice()


func _ensure_finance_weapon_strip() -> void:
	if _finance_weapon_strip != null and is_instance_valid(_finance_weapon_strip):
		return
	if popup_layer == null:
		return
	_finance_weapon_strip = WEAPON_STRIP_SCENE.instantiate() as WeaponStrip
	if _finance_weapon_strip == null:
		return
	_finance_weapon_strip.name = "FinanceWeaponStrip"
	_finance_weapon_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finance_weapon_strip.visible = false
	popup_layer.add_child(_finance_weapon_strip)


func _layout_finance_weapon_strip() -> void:
	if _finance_weapon_strip == null or not is_instance_valid(_finance_weapon_strip) or get_viewport() == null:
		return
	var safe := _get_finance_safe_rect()
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return
	var strip_width := minf(560.0, maxf(safe.size.x - 32.0, 0.0))
	_finance_weapon_strip.position = Vector2(safe.position.x + (safe.size.x - strip_width) * 0.5, safe.position.y + 18.0)
	_finance_weapon_strip.size = Vector2(strip_width, 62.0)

func _get_finance_safe_rect() -> Rect2:
	var battle_hud := _find_battle_hud()
	if battle_hud != null and battle_hud.has_method("get_modal_safe_rect"):
		return battle_hud.get_modal_safe_rect()
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := minf(220.0, viewport_size.x * 0.18)
	var right := minf(336.0, viewport_size.x * 0.30)
	var top := minf(112.0, viewport_size.y * 0.18)
	var bottom := 16.0
	var safe_left := clampf(left, 0.0, viewport_size.x)
	var safe_top := clampf(top, 0.0, viewport_size.y)
	var safe_right := clampf(right, 0.0, viewport_size.x - safe_left)
	return Rect2(
		Vector2(safe_left, safe_top),
		Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - bottom, 0.0))
	)


func _find_battle_hud() -> BattleHud:
	var current: Node = self
	var game_root: GameRoot = null
	while current != null:
		if current is GameRoot:
			game_root = current as GameRoot
			break
		current = current.get_parent()
	if game_root == null:
		return null
	var scene_director := game_root.get_node_or_null("SceneDirector") as GameSceneDirector
	if scene_director == null or scene_director.battle_root == null:
		return null
	return scene_director.battle_root.get_node_or_null("HUD") as BattleHud


func _ensure_interest_popup() -> void:
	if _interest_popup != null and is_instance_valid(_interest_popup):
		return
	if popup_layer == null:
		return
	_interest_popup = popup_layer.get_node_or_null("InterestSettlementPopup") as InterestSettlementPopup
	if _interest_popup != null:
		return
	_interest_popup = INTEREST_SETTLEMENT_POPUP_SCENE.instantiate() as InterestSettlementPopup
	if _interest_popup == null:
		return
	_interest_popup.name = "InterestSettlementPopup"
	popup_layer.add_child(_interest_popup)


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
	_interest_notice_label.add_theme_font_override("font", NUMERIC_FONT)
	_interest_notice_label.add_theme_font_size_override("font_size", 22)
	_interest_notice_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_interest_notice_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	_interest_notice_label.add_theme_constant_override("outline_size", 3)
	notice_content.add_child(_interest_notice_label)

	var bottom_line := ColorRect.new()
	bottom_line.name = "BottomLine"
	bottom_line.custom_minimum_size = Vector2(0.0, 2.0)
	bottom_line.color = Color(1.0, 1.0, 1.0, 0.94)
	notice_content.add_child(bottom_line)


func _position_interest_notice(vertical_ratio: float = 0.78) -> void:
	if _interest_notice_panel == null or get_viewport() == null:
		return
	var safe_rect := _get_finance_safe_rect()
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return
	var text_width := _get_interest_notice_text_width()
	var desired_width := clampf(ceil(text_width + 72.0), 240.0, 540.0)
	var width := minf(desired_width, safe_rect.size.x)
	var notice_height := minf(56.0, safe_rect.size.y)
	var target_x := safe_rect.position.x + maxf((safe_rect.size.x - width) * 0.5, 0.0)
	var target_y := safe_rect.position.y + safe_rect.size.y * clampf(vertical_ratio, 0.25, 0.90) - notice_height * 0.5
	target_y = clampf(target_y, safe_rect.position.y, safe_rect.end.y - notice_height)
	_interest_notice_panel.anchor_left = 0.0
	_interest_notice_panel.anchor_top = 0.0
	_interest_notice_panel.anchor_right = 0.0
	_interest_notice_panel.anchor_bottom = 0.0
	_interest_notice_panel.offset_left = target_x
	_interest_notice_panel.offset_top = target_y
	_interest_notice_panel.offset_right = target_x + width
	_interest_notice_panel.offset_bottom = target_y + notice_height


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
