extends Node2D
class_name SummonRoot

signal summon_spawned(summon: SummonController, summon_id: String)
signal summon_died(summon_id: String, reason: String)

const SUMMON_UNIT_SCENE: PackedScene = preload("res://scenes/summons/summon_unit.tscn")
const DEFAULT_HARD_CAP: int = 12

@export var hard_cap: int = DEFAULT_HARD_CAP
@export var auto_clear_on_runtime_reset: bool = true

var owner_player: PlayerController = null
var active_summons: Array[SummonController] = []

@onready var targeting_service: TargetingService = get_node_or_null("TargetingService") as TargetingService


static func get_default_summon_data() -> Dictionary:
	return {
		"id": "summon_kinling",
		"display_name": "眷族幼体",
		"tags": ["summon", "kin"],
		"base_stats": {
			"max_hp": 20,
			"move_speed": 240,
			"summon_damage": 4,
		},
		"attack_interval_ms": 700,
		"attack_radius": 72,
		"follow_distance": 96,
		"chase_radius": 320,
		"leash_distance": 420,
		"lifetime_seconds": -1,
		"use_cooldown_reduction_only": false,
	}


func _ready() -> void:
	_ensure_targeting_service()
	if auto_clear_on_runtime_reset:
		var reset_callable := Callable(self, "_on_runtime_state_reset")
		if not GameGlobal.runtime_state_reset.is_connected(reset_callable):
			GameGlobal.runtime_state_reset.connect(reset_callable)


func _exit_tree() -> void:
	var reset_callable := Callable(self, "_on_runtime_state_reset")
	if GameGlobal.runtime_state_reset.is_connected(reset_callable):
		GameGlobal.runtime_state_reset.disconnect(reset_callable)


func initialize(player: PlayerController) -> void:
	# 新一局或重新绑定玩家时清空旧召唤物，避免运行态串局。
	owner_player = player
	clear_summons()
	_ensure_targeting_service()


func spawn_default_summon(base_count: int = 1) -> SummonController:
	var spawned := spawn_default_summons(base_count)
	return spawned[0] if not spawned.is_empty() else null


func spawn_default_summons(base_count: int = 1) -> Array[SummonController]:
	return spawn_summons(get_default_summon_data(), base_count)


func spawn_summons(summon_data: Dictionary, base_count: int = 1) -> Array[SummonController]:
	_compact_summons()
	var result: Array[SummonController] = []
	var count := _calculate_spawn_count(base_count)
	for _index in range(count):
		var summon := spawn_summon(summon_data)
		if summon != null:
			result.append(summon)
	return result


func spawn_summon(summon_data: Dictionary, spawn_position: Vector2 = Vector2.ZERO, use_spawn_position: bool = false) -> SummonController:
	_compact_summons()
	if active_summons.size() >= hard_cap:
		return null
	_ensure_targeting_service()
	var summon := SUMMON_UNIT_SCENE.instantiate() as SummonController
	if summon == null:
		push_error("[SummonRoot] failed to instantiate summon unit.")
		return null

	var spawn_index := active_summons.size()
	var runtime_data := summon_data.duplicate(true)
	runtime_data["formation_index"] = spawn_index
	runtime_data["formation_count"] = hard_cap
	add_child(summon)
	summon.global_position = spawn_position if use_spawn_position else _get_spawn_position(spawn_index)
	var runtime_modifiers: Array = []
	var raw_runtime_modifiers := runtime_data.get("runtime_modifiers", [])
	if raw_runtime_modifiers is Array:
		runtime_modifiers = raw_runtime_modifiers
	if not summon.initialize(owner_player, targeting_service, runtime_data, runtime_modifiers):
		summon.queue_free()
		return null
	var died_callable := Callable(self, "_on_summon_died")
	if not summon.died.is_connected(died_callable):
		summon.died.connect(died_callable)
	active_summons.append(summon)
	summon_spawned.emit(summon, summon.summon_id)
	return summon


func clear_summons() -> void:
	_compact_summons()
	for summon in active_summons:
		if is_instance_valid(summon) and summon.is_inside_tree():
			summon.queue_free()
	active_summons.clear()


func get_active_summons() -> Array[SummonController]:
	_compact_summons()
	var result: Array[SummonController] = []
	for summon in active_summons:
		result.append(summon)
	return result


func get_active_summon_count() -> int:
	_compact_summons()
	return active_summons.size()


func _calculate_spawn_count(base_count: int) -> int:
	if base_count <= 0:
		return 0
	var owner_bonus := int(owner_player.get_stat("summon_count")) if owner_player != null else 0
	var desired_count := maxi(0, base_count + owner_bonus)
	return mini(desired_count, maxi(hard_cap - active_summons.size(), 0))


func _get_spawn_position(spawn_index: int) -> Vector2:
	var origin := owner_player.global_position if owner_player != null else global_position
	var count := maxi(hard_cap, 1)
	var angle := TAU * float(spawn_index % count) / float(count)
	return origin + Vector2.RIGHT.rotated(angle) * 96.0


func _ensure_targeting_service() -> void:
	if targeting_service != null and is_instance_valid(targeting_service):
		return
	targeting_service = get_node_or_null("TargetingService") as TargetingService
	if targeting_service != null:
		return
	targeting_service = TargetingService.new()
	targeting_service.name = "TargetingService"
	add_child(targeting_service)


func _compact_summons() -> void:
	for index in range(active_summons.size() - 1, -1, -1):
		var summon := active_summons[index]
		if summon == null or not is_instance_valid(summon) or not summon.is_inside_tree():
			active_summons.remove_at(index)


func _on_summon_died(summon: SummonController, reason: String) -> void:
	if summon != null:
		active_summons.erase(summon)
		summon_died.emit(summon.summon_id, reason)


func _on_runtime_state_reset() -> void:
	clear_summons()
	owner_player = null
