extends Node
class_name FinanceUIController

@onready var finance_popup: FinancePopup = $PopupLayer/FinancePopup
var _flow: MainFlowCoordinator
var _hud: BattleHud
var _attempts := 0
var _last_rect := Rect2()
var _suspended_for_inspection := false
var challenge_popup: WaveChallengePopup


func _ready() -> void:
	challenge_popup = WaveChallengePopup.new()
	challenge_popup.name = "WaveChallengePopup"
	var challenge_layer := CanvasLayer.new()
	challenge_layer.name = "ChallengeLayer"
	challenge_layer.layer = 30 # Above the HUD drawer (29); suspended when settings open.
	add_child(challenge_layer)
	challenge_layer.add_child(challenge_popup)
	_bind.call_deferred()


func _bind() -> void:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			_flow = current.get_main_flow_coordinator()
			break
		current = current.get_parent()
	if _flow == null:
		_attempts += 1
		if _attempts < 30: _bind.call_deferred()
		return
	_flow.modal_requested.connect(_on_modal_requested)
	_flow.modal_closed.connect(_on_modal_closed)
	_flow.preparation_changed.connect(_on_preparation_changed)
	_flow.state_changed.connect(_on_flow_state_changed)
	_flow.flow_reset.connect(_on_flow_reset)
	finance_popup.bind_flow(_flow)
	challenge_popup.flow = _flow


func _on_modal_requested(state: String, payload: Dictionary) -> void:
	if state == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
		challenge_popup.present(payload)
		return
	if state != MainFlowCoordinator.STATE_FINANCE_POPUP: return
	_suspended_for_inspection = false
	_apply_safe_rect(true)
	finance_popup.configure(payload)
	finance_popup.show_popup()


func _on_preparation_changed(payload: Dictionary) -> void:
	if finance_popup.visible: finance_popup.configure(payload)


func _on_modal_closed(state: String) -> void:
	if state == MainFlowCoordinator.STATE_WAVE_CHALLENGE: challenge_popup.dismiss()
	if state == MainFlowCoordinator.STATE_FINANCE_POPUP:
		_suspended_for_inspection = false
		finance_popup.hide_popup()


func _on_flow_state_changed(previous: String, current: String) -> void:
	if current == MainFlowCoordinator.STATE_BATTLE_RESULT: challenge_popup.dismiss()
	if previous == MainFlowCoordinator.STATE_WAVE_CHALLENGE and current == MainFlowCoordinator.STATE_BATTLE_UTILITY:
		challenge_popup.hide()
	elif previous == MainFlowCoordinator.STATE_BATTLE_UTILITY and current == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
		challenge_popup.show()
	if previous == MainFlowCoordinator.STATE_FINANCE_POPUP and current == MainFlowCoordinator.STATE_ESC_OVERLAY:
		_suspended_for_inspection = true
		# Preserve the existing widgets and scroll state while the list is open.
		finance_popup.hide()
	elif _suspended_for_inspection and current == MainFlowCoordinator.STATE_FINANCE_POPUP:
		_suspended_for_inspection = false
		_apply_safe_rect(true)
		finance_popup.show()


func _on_flow_reset() -> void:
	challenge_popup.dismiss()
	_suspended_for_inspection = false
	finance_popup.hide_popup()
	finance_popup.reset_interest_arrival()


func _process(_delta: float) -> void:
	if finance_popup.visible: _apply_safe_rect()


func _apply_safe_rect(force: bool = false) -> void:
	if not is_instance_valid(_hud):
		var game := get_tree().current_scene
		if game != null: _hud = game.find_child("HUD", true, false) as BattleHud
	var viewport := get_viewport().get_visible_rect().size
	finance_popup.main_panel.visible = viewport.x >= 1000 or _hud == null or not _hud.is_stats_drawer_open()
	var safe := _hud.get_modal_safe_rect() if _hud != null else Rect2(16, 72, viewport.x - 352, viewport.y - 128)
	if FinanceSceneLayout.supports(viewport):
		var right := viewport.x - 36
		if _hud != null and _hud.is_stats_drawer_open():
			right = minf(right, _hud.stats_drawer.global_position.x - 14)
		safe = Rect2(0, 0, right, viewport.y)
		if force or safe != _last_rect:
			_last_rect = safe
			finance_popup.set_safe_rect(safe)
		return
	var top := minf(72, viewport.y * 0.18)
	var bottom := minf(56, viewport.y * 0.14)
	if viewport.y < 480:
		top = 60
		bottom = 8
	safe.position.y = top
	safe.size.y = maxf(180, viewport.y - top - bottom)
	if viewport.x < 1000:
		safe.position.x = 12
		safe.size.x = viewport.x - 56
	if force or safe != _last_rect:
		_last_rect = safe
		finance_popup.set_safe_rect(safe)
