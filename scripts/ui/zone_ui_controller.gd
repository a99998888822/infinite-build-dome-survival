extends Node
class_name ZoneUIController

const ZONE_SELECT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_select_popup.tscn")
const ZONE_HARVEST_RESULT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/zones/zone_harvest_result_popup.tscn")

@onready var hud_layer: CanvasLayer = get_node_or_null("HUDLayer")
@onready var popup_layer: CanvasLayer = get_node_or_null("PopupLayer")
@onready var fade_layer: CanvasLayer = get_node_or_null("FadeLayer")
@onready var zone_select_popup: ZoneSelectPopup = get_node_or_null("PopupLayer/ZoneSelectPopup")
@onready var zone_harvest_result_popup: ZoneHarvestResultPopup = get_node_or_null("PopupLayer/ZoneHarvestResultPopup")

var _main_flow_coordinator: MainFlowCoordinator = null
var _applied_safe_rect: Rect2 = Rect2()


func _ready() -> void:
	_prepare_layers()
	if get_viewport() != null:
		var viewport_callable := Callable(self, "_on_viewport_size_changed")
		if not get_viewport().size_changed.is_connected(viewport_callable):
			get_viewport().size_changed.connect(viewport_callable)
	call_deferred("_bind_to_main_flow")


func _process(_delta: float) -> void:
	if _main_flow_coordinator == null:
		return
	var current_state := _main_flow_coordinator.get_current_state()
	if current_state == MainFlowCoordinator.STATE_ZONE_SELECT:
		# Reconcile the visible modal with the flow state in case the state
		# changed before this controller finished binding its signal.
		if zone_select_popup != null and not zone_select_popup.visible:
			var payload := _main_flow_coordinator.get_zone_selection_payload()
			if not payload.is_empty():
				_show_zone_select(payload)
		if zone_select_popup != null and zone_select_popup.visible:
			_apply_zone_safe_rect()
	elif zone_select_popup != null and zone_select_popup.visible:
		zone_select_popup.hide_popup()


func _prepare_layers() -> void:
	if zone_select_popup == null and popup_layer != null:
		zone_select_popup = ZONE_SELECT_POPUP_SCENE.instantiate() as ZoneSelectPopup
		if zone_select_popup != null:
			zone_select_popup.name = "ZoneSelectPopup"
			popup_layer.add_child(zone_select_popup)
	if zone_harvest_result_popup == null and popup_layer != null:
		zone_harvest_result_popup = ZONE_HARVEST_RESULT_POPUP_SCENE.instantiate() as ZoneHarvestResultPopup
		if zone_harvest_result_popup != null:
			zone_harvest_result_popup.name = "ZoneHarvestResultPopup"
			popup_layer.add_child(zone_harvest_result_popup)


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
	_reconcile_modal_state()


func _reconcile_modal_state() -> void:
	if _main_flow_coordinator == null:
		return
	match _main_flow_coordinator.get_current_state():
		MainFlowCoordinator.STATE_ZONE_SELECT:
			var payload := _main_flow_coordinator.get_zone_selection_payload()
			if not payload.is_empty():
				_show_zone_select(payload)
		_:
			return


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
			var game_root := current as GameRoot
			return game_root.get_main_flow_coordinator()
		current = current.get_parent()
	if get_tree() != null and get_tree().current_scene is GameRoot:
		return (get_tree().current_scene as GameRoot).get_main_flow_coordinator()
	return null


func _on_modal_requested(modal_state: String, payload: Dictionary) -> void:
	match modal_state:
		MainFlowCoordinator.STATE_ZONE_SELECT:
			_show_zone_select(payload)
		MainFlowCoordinator.STATE_ZONE_HARVEST_RESULT:
			_show_zone_harvest_result(payload)
		_:
			return


func _on_modal_closed(modal_state: String) -> void:
	match modal_state:
		MainFlowCoordinator.STATE_ZONE_SELECT:
			if zone_select_popup != null:
				zone_select_popup.hide_popup()
		MainFlowCoordinator.STATE_ZONE_HARVEST_RESULT:
			if zone_harvest_result_popup != null:
				zone_harvest_result_popup.hide_popup()
		_:
			return


func _show_zone_select(payload: Dictionary) -> void:
	if zone_select_popup == null:
		return
	if zone_harvest_result_popup != null:
		zone_harvest_result_popup.hide_popup()
	_apply_zone_safe_rect(true)
	zone_select_popup.configure(payload)
	var zone_selected_callable := Callable(self, "_on_zone_selected")
	if not zone_select_popup.zone_selected.is_connected(zone_selected_callable):
		zone_select_popup.zone_selected.connect(zone_selected_callable)
	zone_select_popup.show_popup()
	if GameGlobal != null:
		GameGlobal.log_debug("zone select popup shown")


func _show_zone_harvest_result(payload: Dictionary) -> void:
	if zone_harvest_result_popup == null:
		return
	if zone_select_popup != null:
		zone_select_popup.hide_popup()
	zone_harvest_result_popup.configure(payload)
	var harvest_confirmed_callable := Callable(self, "_on_zone_harvest_confirmed")
	if not zone_harvest_result_popup.confirmed.is_connected(harvest_confirmed_callable):
		zone_harvest_result_popup.confirmed.connect(harvest_confirmed_callable)
	zone_harvest_result_popup.show_popup()
	if GameGlobal != null:
		GameGlobal.log_debug("zone harvest popup shown")


func _on_zone_selected(zone_id: String) -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.confirm_zone_selection(zone_id)


func _on_zone_harvest_confirmed() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.close_zone_harvest_result_popup()


func _on_viewport_size_changed() -> void:
	_apply_zone_safe_rect(true)


func _apply_zone_safe_rect(force: bool = false) -> void:
	if zone_select_popup == null:
		return
	var next_rect := _get_zone_safe_rect()
	if not force and next_rect == _applied_safe_rect:
		return
	_applied_safe_rect = next_rect
	zone_select_popup.set_safe_rect(next_rect)


func _get_zone_safe_rect() -> Rect2:
	var battle_hud := _find_battle_hud()
	if battle_hud != null and battle_hud.has_method("get_modal_safe_rect"):
		return battle_hud.get_modal_safe_rect()
	var viewport := get_viewport()
	var viewport_size := Vector2(viewport.size) if viewport != null else Vector2(1280, 720)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var safe_left := 16.0
	var safe_right := minf(336.0, viewport_size.x * 0.30)
	var safe_top := 16.0
	var safe_bottom := 16.0
	return Rect2(
		Vector2(safe_left, safe_top),
		Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - safe_bottom, 0.0))
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
