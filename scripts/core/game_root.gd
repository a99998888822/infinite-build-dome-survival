extends Node
class_name GameRoot

const MAIN_FLOW_COORDINATOR_SCENE: PackedScene = preload("res://scenes/core/main_flow_coordinator.tscn")
const ANDROID_CONTENT_SCALE_SIZE := Vector2i(1280, 720)
const WORLD_RENDER_SIZE := Vector2i(800, 450)

var core_root: Node = null
var world_root: Node2D = null
var ui_root: CanvasLayer = null
var debug_root: Node = null
var _main_flow_coordinator: MainFlowCoordinator = null
var _world_viewport_layer: CanvasLayer = null
var _world_viewport_container: SubViewportContainer = null
var _world_viewport: SubViewport = null
var _world_viewport_root: Node2D = null


func _enter_tree() -> void:
	_configure_android_content_scale()


func _ready() -> void:
	# 根场景只负责准备通用容器，不写具体玩法规则。
	core_root = _ensure_child("CoreRoot", Node.new())
	world_root = _ensure_child("WorldRoot", Node2D.new()) as Node2D
	ui_root = _ensure_child("UiRoot", CanvasLayer.new()) as CanvasLayer
	debug_root = _ensure_child("DebugRoot", Node.new())
	_setup_world_viewport()
	_ensure_main_flow_coordinator()
	GameGlobal.set_game_mode("game")
	GameGlobal.set_runtime_flag("game_root_ready", true)
	GameGlobal.log_debug("game root ready")


func _configure_android_content_scale() -> void:
	if not OS.has_feature("android"):
		return
	var window := get_window()
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = ANDROID_CONTENT_SCALE_SIZE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back_request()


func _handle_android_back_request() -> void:
	var flow := get_main_flow_coordinator()
	if flow == null:
		return
	match flow.get_current_state():
		MainFlowCoordinator.STATE_WAVE_COMBAT, MainFlowCoordinator.STATE_BATTLE_PREPARE:
			flow.request_esc_overlay()
		MainFlowCoordinator.STATE_ESC_OVERLAY:
			flow.close_esc_overlay()
		MainFlowCoordinator.STATE_SHOP_POPUP:
			flow.close_shop_popup()
		MainFlowCoordinator.STATE_FINANCE_POPUP:
			flow.submit_finance_operation("none", 0)
		MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
			flow.close_interest_settlement()
		MainFlowCoordinator.STATE_ZONE_HARVEST_RESULT:
			flow.close_zone_harvest_result_popup()
		MainFlowCoordinator.STATE_CHARACTER_SELECT, MainFlowCoordinator.STATE_CAMP_ENTRY, MainFlowCoordinator.STATE_BATTLE_RESULT:
			flow.enter_start_page()
		MainFlowCoordinator.STATE_START_PAGE:
			get_tree().quit()


func get_main_flow_coordinator() -> MainFlowCoordinator:
	return _ensure_main_flow_coordinator()


func get_core_root() -> Node:
	return core_root


func get_world_root() -> Node2D:
	return world_root


func get_ui_root() -> CanvasLayer:
	return ui_root


func get_world_viewport_root() -> Node2D:
	return _world_viewport_root if _world_viewport_root != null else world_root


func get_debug_root() -> Node:
	return debug_root


func add_to_core(node: Node) -> bool:
	# 供业务模块把全局性节点挂到核心层。
	return _attach_node(node, core_root)


func add_to_world(node: Node) -> bool:
	# 供战斗、营地、关卡等模块把实体挂到世界层。
	return _attach_node(node, world_root)


func add_to_ui(node: Node) -> bool:
	# 供界面模块把界面节点挂到 UI 层。
	return _attach_node(node, ui_root)


func _setup_world_viewport() -> void:
	if _world_viewport_root != null and is_instance_valid(_world_viewport_root):
		return
	_world_viewport_layer = CanvasLayer.new()
	_world_viewport_layer.name = "WorldViewportLayer"
	_world_viewport_layer.layer = -3
	add_child(_world_viewport_layer)
	_world_viewport_container = SubViewportContainer.new()
	_world_viewport_container.name = "WorldViewportContainer"
	_world_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_viewport_container.stretch = true
	_world_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_viewport_layer.add_child(_world_viewport_container)
	_world_viewport = SubViewport.new()
	_world_viewport.name = "WorldViewport"
	_world_viewport.size = WORLD_RENDER_SIZE
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_viewport.transparent_bg = true
	_world_viewport.handle_input_locally = false
	_world_viewport_container.add_child(_world_viewport)
	_world_viewport_root = Node2D.new()
	_world_viewport_root.name = "WorldViewportRoot"
	_world_viewport.add_child(_world_viewport_root)



func _ensure_main_flow_coordinator() -> MainFlowCoordinator:
	# 主流程协调器优先复用场景里已有实例，没有则动态补上。
	if _main_flow_coordinator != null and is_instance_valid(_main_flow_coordinator):
		return _main_flow_coordinator
	if core_root == null:
		return null
	for child in core_root.get_children():
		if child is MainFlowCoordinator:
			_main_flow_coordinator = child
			return _main_flow_coordinator
	var coordinator := MAIN_FLOW_COORDINATOR_SCENE.instantiate() as MainFlowCoordinator
	if coordinator == null:
		push_error("[GameRoot] failed to instantiate main flow coordinator.")
		return null
	core_root.add_child(coordinator)
	_main_flow_coordinator = coordinator
	return _main_flow_coordinator


func _ensure_child(child_name: String, fallback_node: Node) -> Node:
	var existing := get_node_or_null(child_name)
	if existing is Node:
		return existing
	fallback_node.name = child_name
	add_child(fallback_node)
	return fallback_node


func _attach_node(node: Node, target_parent: Node) -> bool:
	if node == null or target_parent == null:
		return false
	if node.get_parent() != null and node.get_parent() != target_parent:
		node.reparent(target_parent)
	elif node.get_parent() == null:
		target_parent.add_child(node)
	return true
