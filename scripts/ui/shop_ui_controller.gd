extends Node
class_name ShopUIController

const SHOP_POPUP_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_popup.tscn")

@onready var popup_layer: CanvasLayer = get_node_or_null("PopupLayer")
@onready var shop_popup: ShopPopup = get_node_or_null("PopupLayer/ShopPopup")

var _main_flow_coordinator: MainFlowCoordinator = null


func _ready() -> void:
	_prepare_layers()
	call_deferred("_bind_to_main_flow")


func _prepare_layers() -> void:
	if popup_layer == null:
		popup_layer = CanvasLayer.new()
		popup_layer.name = "PopupLayer"
		popup_layer.layer = 26
		add_child(popup_layer)
	if shop_popup == null and popup_layer != null:
		shop_popup = SHOP_POPUP_SCENE.instantiate() as ShopPopup
		if shop_popup != null:
			shop_popup.name = "ShopPopup"
			popup_layer.add_child(shop_popup)


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
		MainFlowCoordinator.STATE_SHOP_POPUP, MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
			_show_shop_popup(payload)
		_:
			return


func _on_modal_closed(modal_state: String) -> void:
	match modal_state:
		MainFlowCoordinator.STATE_SHOP_POPUP, MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
			if shop_popup != null:
				shop_popup.hide_popup()
		_:
			return


func _show_shop_popup(payload: Dictionary) -> void:
	if shop_popup == null:
		return
	if _main_flow_coordinator != null:
		shop_popup.set_loadout(_main_flow_coordinator.get_bound_loadout())
	if _main_flow_coordinator != null:
		shop_popup.set_bond_player(_main_flow_coordinator.get_bound_player())
	shop_popup.configure(payload)
	var selected_callable := Callable(self, "_on_offer_selected")
	var skipped_callable := Callable(self, "_on_skipped")
	if not shop_popup.offer_selected.is_connected(selected_callable):
		shop_popup.offer_selected.connect(selected_callable)
	if not shop_popup.skipped.is_connected(skipped_callable):
		shop_popup.skipped.connect(skipped_callable)
	var preview_requested_callable := Callable(self, "_on_stat_preview_requested")
	var preview_cleared_callable := Callable(self, "_on_stat_preview_cleared")
	if not shop_popup.stat_preview_requested.is_connected(preview_requested_callable):
		shop_popup.stat_preview_requested.connect(preview_requested_callable)
	if not shop_popup.stat_preview_cleared.is_connected(preview_cleared_callable):
		shop_popup.stat_preview_cleared.connect(preview_cleared_callable)
	shop_popup.show_popup()


func _on_offer_selected(offer: Dictionary) -> void:
	if _main_flow_coordinator == null:
		return
	var mode := shop_popup.get_mode() if shop_popup != null else ShopPopup.ENTRY_FREE
	var result := _main_flow_coordinator.submit_shop_purchase(offer, mode)
	if shop_popup != null and not bool(result.get("success", false)):
		shop_popup.show_error(str(result.get("reason", "unknown")))
		shop_popup.reset_submission()


func _on_stat_preview_requested(offer: Dictionary) -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.set_stat_preview_from_offer(offer)


func _on_stat_preview_cleared() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.clear_stat_preview()


func _on_skipped() -> void:
	if _main_flow_coordinator == null:
		return
	var mode := shop_popup.get_mode() if shop_popup != null else ShopPopup.ENTRY_FREE
	if mode == ShopPopup.ENTRY_SHOP:
		_main_flow_coordinator.close_shop_popup()
	else:
		_main_flow_coordinator.close_shared_reward_shop_popup()
