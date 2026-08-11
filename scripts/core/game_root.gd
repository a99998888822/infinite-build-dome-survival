extends Node
class_name GameRoot

const MAIN_FLOW_COORDINATOR_SCENE: PackedScene = preload("res://scenes/core/main_flow_coordinator.tscn")

var core_root: Node = null
var world_root: Node2D = null
var ui_root: CanvasLayer = null
var debug_root: Node = null
var _main_flow_coordinator: MainFlowCoordinator = null


func _ready() -> void:
	# 根场景只负责准备通用容器，不写具体玩法规则。
	core_root = _ensure_child("CoreRoot", Node.new())
	world_root = _ensure_child("WorldRoot", Node2D.new()) as Node2D
	ui_root = _ensure_child("UiRoot", CanvasLayer.new()) as CanvasLayer
	debug_root = _ensure_child("DebugRoot", Node.new())
	_ensure_main_flow_coordinator()
	GameGlobal.set_game_mode("game")
	GameGlobal.set_runtime_flag("game_root_ready", true)
	GameGlobal.log_debug("game root ready")


func get_main_flow_coordinator() -> MainFlowCoordinator:
	return _ensure_main_flow_coordinator()


func get_core_root() -> Node:
	return core_root


func get_world_root() -> Node2D:
	return world_root


func get_ui_root() -> CanvasLayer:
	return ui_root


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
