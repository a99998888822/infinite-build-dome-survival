extends Node
class_name GameSceneDirector

const BATTLE_ROOT_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const CAMP_SCENE: PackedScene = preload("res://scenes/camp/camp_root.tscn")

var _main_flow_coordinator: MainFlowCoordinator = null
var battle_root: Node = null
var camp_root: CampRoot = null


func _ready() -> void:
	call_deferred("_bind_to_main_flow")


func _bind_to_main_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		call_deferred("_bind_to_main_flow")
		return
	if _main_flow_coordinator == coordinator:
		return
	_unbind_main_flow()
	_main_flow_coordinator = coordinator
	if not _main_flow_coordinator.mode_changed.is_connected(_on_mode_changed):
		_main_flow_coordinator.mode_changed.connect(_on_mode_changed)


func _unbind_main_flow() -> void:
	if _main_flow_coordinator != null and _main_flow_coordinator.mode_changed.is_connected(_on_mode_changed):
		_main_flow_coordinator.mode_changed.disconnect(_on_mode_changed)
	_main_flow_coordinator = null


func _find_main_flow_coordinator() -> MainFlowCoordinator:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return (current as GameRoot).get_main_flow_coordinator()
		current = current.get_parent()
	return null


func _get_game_root() -> GameRoot:
	var current: Node = self
	while current != null:
		if current is GameRoot:
			return current as GameRoot
		current = current.get_parent()
	return null


func _on_mode_changed(previous_mode: String, current_mode: String) -> void:
	match current_mode:
		MainFlowCoordinator.MODE_BATTLE:
			_teardown_camp()
			_compose_battle()
		MainFlowCoordinator.MODE_CAMP:
			_teardown_battle()
			_compose_camp()
		MainFlowCoordinator.MODE_TALENTS:
			_teardown_battle()
			_teardown_camp()
		MainFlowCoordinator.MODE_BOOT:
			_teardown_battle()
			_teardown_camp()


func _compose_battle() -> void:
	if battle_root != null or _main_flow_coordinator == null:
		return
	var game_root := _get_game_root()
	if game_root == null:
		return
	battle_root = BATTLE_ROOT_SCENE.instantiate()
	game_root.add_to_world(battle_root)


func _compose_camp() -> void:
	if camp_root != null or _main_flow_coordinator == null:
		return
	var game_root := _get_game_root()
	if game_root == null:
		return
	camp_root = CAMP_SCENE.instantiate() as CampRoot
	game_root.add_to_world(camp_root)
	_main_flow_coordinator.bind_camp_context(camp_root)


func _teardown_battle() -> void:
	if battle_root == null:
		return
	if is_instance_valid(battle_root):
		battle_root.queue_free()
	battle_root = null


func _teardown_camp() -> void:
	if camp_root == null:
		return
	if is_instance_valid(camp_root):
		camp_root.queue_free()
	camp_root = null
