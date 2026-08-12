extends Node
class_name FinanceUIController

const FINANCE_POPUP_SCENE: PackedScene = preload("res://scenes/ui/finance/finance_popup.tscn")

@onready var popup_layer: CanvasLayer = get_node_or_null("PopupLayer")
@onready var finance_popup: FinancePopup = get_node_or_null("PopupLayer/FinancePopup")

var _main_flow_coordinator: MainFlowCoordinator = null


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
	if modal_state != MainFlowCoordinator.STATE_FINANCE_POPUP:
		return
	_show_finance_popup(payload)


func _on_modal_closed(modal_state: String) -> void:
	if modal_state != MainFlowCoordinator.STATE_FINANCE_POPUP:
		return
	if finance_popup != null:
		finance_popup.hide_popup()


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
