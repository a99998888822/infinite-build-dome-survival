extends Node
class_name ShopUIController

const SHOP_POPUP_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_popup.tscn")
const SHOP_POPUP_LAYER: int = 23
const MAX_BIND_ATTEMPTS: int = 30

@onready var popup_layer: CanvasLayer = get_node_or_null("PopupLayer")
@onready var shop_popup: ShopPopup = get_node_or_null("PopupLayer/ShopPopup")

var _main_flow_coordinator: MainFlowCoordinator = null
var _viewport_size_callable: Callable = Callable()
var _applied_safe_rect: Rect2 = Rect2()
var _bind_attempts: int = 0
var _bind_failure_reported: bool = false


func _ready() -> void:
	_prepare_layers()
	_viewport_size_callable = Callable(self, "_on_viewport_size_changed")
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_viewport_size_callable):
		viewport.size_changed.connect(_viewport_size_callable)
	_on_viewport_size_changed()
	call_deferred("_bind_to_main_flow")


func _process(_delta: float) -> void:
	if shop_popup != null and shop_popup.visible:
		_apply_shop_safe_rect()


func _prepare_layers() -> void:
	if popup_layer == null:
		popup_layer = CanvasLayer.new()
		popup_layer.name = "PopupLayer"
		add_child(popup_layer)
	if popup_layer != null:
		popup_layer.layer = SHOP_POPUP_LAYER
	if shop_popup == null and popup_layer != null:
		shop_popup = SHOP_POPUP_SCENE.instantiate() as ShopPopup
		if shop_popup != null:
			shop_popup.name = "ShopPopup"
			popup_layer.add_child(shop_popup)


func _bind_to_main_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		_bind_attempts += 1
		if _bind_attempts < MAX_BIND_ATTEMPTS:
			call_deferred("_bind_to_main_flow")
		elif not _bind_failure_reported:
			_bind_failure_reported = true
			push_error("[ShopUIController] main flow coordinator unavailable after %d attempts." % MAX_BIND_ATTEMPTS)
		return
	_bind_attempts = 0
	_bind_failure_reported = false
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
	_apply_shop_safe_rect(true)
	shop_popup.configure(payload)
	var selected_callable := Callable(self, "_on_offer_selected")
	var skipped_callable := Callable(self, "_on_skipped")
	var refresh_requested_callable := Callable(self, "_on_refresh_requested")
	if not shop_popup.offer_selected.is_connected(selected_callable):
		shop_popup.offer_selected.connect(selected_callable)
	if not shop_popup.skipped.is_connected(skipped_callable):
		shop_popup.skipped.connect(skipped_callable)
	if not shop_popup.refresh_requested.is_connected(refresh_requested_callable):
		shop_popup.refresh_requested.connect(refresh_requested_callable)
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
	if shop_popup == null:
		return
	if not bool(result.get("success", false)):
		shop_popup.show_error(str(result.get("reason", "unknown")))
		shop_popup.reset_submission()
		return
	shop_popup.reset_submission()
	if mode == ShopPopup.ENTRY_SHOP:
		shop_popup.remove_offer(str(result.get("offer_id", "")))
		shop_popup.refresh_gold(_main_flow_coordinator.get_current_gold())


func _on_stat_preview_requested(offer: Dictionary) -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.set_stat_preview_from_offer(offer)


func _on_stat_preview_cleared() -> void:
	if _main_flow_coordinator != null:
		_main_flow_coordinator.clear_stat_preview()


func _on_viewport_size_changed() -> void:
	_apply_shop_safe_rect(true)


func _apply_shop_safe_rect(force: bool = false) -> void:
	if shop_popup == null:
		return
	var next_rect := _get_shop_safe_rect()
	if not force and next_rect == _applied_safe_rect:
		return
	_applied_safe_rect = next_rect
	shop_popup.set_safe_rect(next_rect)


func _get_shop_safe_rect() -> Rect2:
	var battle_hud := _find_battle_hud()
	if battle_hud != null and battle_hud.has_method("get_modal_safe_rect"):
		return battle_hud.get_modal_safe_rect()
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport != null else Vector2(1280, 720)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := 16.0
	var right := minf(336.0, viewport_size.x * 0.30)
	var top := 16.0
	var bottom := 16.0
	var safe_left := clampf(left, 0.0, viewport_size.x)
	var safe_top := clampf(top, 0.0, viewport_size.y)
	var safe_right := clampf(right, 0.0, viewport_size.x - safe_left)
	return Rect2(Vector2(safe_left, safe_top), Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - bottom, 0.0)))


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


func _on_refresh_requested() -> void:
	if _main_flow_coordinator == null:
		return
	var result := _main_flow_coordinator.request_shop_refresh()
	if shop_popup == null:
		return
	if not bool(result.get("success", false)):
		shop_popup.show_error(str(result.get("reason", "unknown")))


func _on_skipped() -> void:
	if _main_flow_coordinator == null:
		return
	var mode := shop_popup.get_mode() if shop_popup != null else ShopPopup.ENTRY_FREE
	if mode == ShopPopup.ENTRY_SHOP:
		_main_flow_coordinator.close_shop_popup()
	else:
		_main_flow_coordinator.close_shared_reward_shop_popup()
