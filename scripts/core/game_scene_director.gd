extends Node
class_name GameSceneDirector

const BATTLE_ROOT_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const CAMP_SCENE: PackedScene = preload("res://scenes/camp/camp_root.tscn")
const MAX_BIND_ATTEMPTS: int = 30

var _main_flow_coordinator: MainFlowCoordinator = null
var battle_root: Node = null
var camp_root: CampRoot = null
var _bind_attempts: int = 0
var _bind_failure_reported: bool = false


func _ready() -> void:
	call_deferred("_bind_to_main_flow")


func _bind_to_main_flow() -> void:
	var coordinator := _find_main_flow_coordinator()
	if coordinator == null:
		_bind_attempts += 1
		if _bind_attempts < MAX_BIND_ATTEMPTS:
			call_deferred("_bind_to_main_flow")
		elif not _bind_failure_reported:
			_bind_failure_reported = true
			push_error("[GameSceneDirector] main flow coordinator unavailable after %d attempts." % MAX_BIND_ATTEMPTS)
		return
	_bind_attempts = 0
	_bind_failure_reported = false
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
	if _main_flow_coordinator == null:
		return
	if battle_root != null:
		if is_instance_valid(battle_root):
			return
		battle_root = null
	var game_root := _get_game_root()
	if game_root == null:
		return
	battle_root = BATTLE_ROOT_SCENE.instantiate()
	if not game_root.add_to_world(battle_root):
		push_error("[GameSceneDirector] failed to attach battle root to world.")
		battle_root.queue_free()
		battle_root = null


func _compose_camp() -> void:
	if _main_flow_coordinator == null:
		return
	if camp_root != null:
		if is_instance_valid(camp_root):
			return
		camp_root = null
	var game_root := _get_game_root()
	if game_root == null:
		return
	camp_root = CAMP_SCENE.instantiate() as CampRoot
	if camp_root == null or not game_root.add_to_world(camp_root):
		push_error("[GameSceneDirector] failed to attach camp root to world.")
		if camp_root != null:
			camp_root.queue_free()
		camp_root = null
		return
	_main_flow_coordinator.bind_camp_context(camp_root)


func _teardown_battle() -> void:
	if battle_root == null:
		return
	if is_instance_valid(battle_root):
		if battle_root.has_method("restore_world_nodes"):
			battle_root.restore_world_nodes()
		battle_root.queue_free()
	battle_root = null


func _teardown_camp() -> void:
	if camp_root == null:
		return
	if is_instance_valid(camp_root):
		camp_root.queue_free()
	camp_root = null
