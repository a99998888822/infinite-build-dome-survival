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


func _ready() -> void:
	_prepare_layers()
	call_deferred("_bind_to_main_flow")


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
