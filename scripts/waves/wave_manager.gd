extends Node
class_name WaveManager

signal wave_started(wave_id: String, duration_seconds: int)
signal wave_finished(wave_id: String)
signal exp_changed(current_exp: int, required_exp: int, level: int)
signal gold_changed(current_gold: int)
signal finance_changed(snapshot: Dictionary)
signal interest_settled(result: Dictionary)
signal shared_reward_shop_requested(level: int)
# 兼容旧入口，后续可逐步迁移到 shared_reward_shop_requested。
signal free_shop_requested(level: int)

const DEFAULT_PLAYER_LEVEL: int = 1
const SPAWN_MIN_DISTANCE: float = 1000.0
const SPAWN_MAX_DISTANCE: float = 1500.0
const DROP_REWARD_SYSTEM_SCRIPT: Script = preload("res://scripts/rewards/drop_reward_system.gd")
const BATTLE_FINANCE_SYSTEM_SCRIPT: Script = preload("res://scripts/rewards/battle_finance_system.gd")

@export var auto_start: bool = false
@export var enemy_root_path: NodePath
@export var pickup_root_path: NodePath
@export var summon_root_path: NodePath

var player: PlayerController = null
var current_wave_index: int = -1
var current_wave: Dictionary = {}
var wave_time_left: float = 0.0
var spawn_timers_ms: Array[float] = []
var running: bool = false
var player_level: int = DEFAULT_PLAYER_LEVEL
var current_exp: int = 0
var current_gold: int = 0
var collected_exp_this_wave: int = 0
var collected_gold_this_wave: int = 0

var reward_snapshot: RewardSnapshot = RewardSnapshot.new()
var drop_reward_system: DropRewardSystem = DROP_REWARD_SYSTEM_SCRIPT.new()
var finance_system: BattleFinanceSystem = BATTLE_FINANCE_SYSTEM_SCRIPT.new()
var enemy_scene_cache: Dictionary = {}

@onready var enemy_root: Node = _get_optional_node(enemy_root_path)
@onready var pickup_root: Node = _get_optional_node(pickup_root_path)
@onready var summon_root: SummonRoot = _get_optional_node(summon_root_path) as SummonRoot


func _ready() -> void:
	if enemy_root == null:
		enemy_root = get_node_or_null("EnemyRoot")
	if pickup_root == null:
		pickup_root = get_node_or_null("PickupRoot")
	if enemy_root == null:
		enemy_root = self
	if pickup_root == null:
		pickup_root = self
	_ensure_summon_root()
	if auto_start:
		start_next_wave()


func _process(delta: float) -> void:
	if not running:
		return
	wave_time_left -= delta
	_process_spawn_timers(delta)
	if finance_system != null:
		finance_system.tick(delta)
	if wave_time_left <= 0.0:
		finish_current_wave()


func initialize(target_player: PlayerController) -> void:
	player = target_player
	current_wave_index = -1
	running = false
	player_level = DEFAULT_PLAYER_LEVEL
	current_exp = 0
	current_gold = 0
	collected_exp_this_wave = 0
	collected_gold_this_wave = 0
	if finance_system != null:
		finance_system.initialize(player, Callable(self, "get_current_gold"), Callable(self, "apply_gold_delta"))
		_connect_finance_system()
	_connect_player_relic_signal()
	reward_snapshot.reset()
	clear_battle_entities()
	if summon_root != null:
		summon_root.initialize(player)


func _get_optional_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)


func start_next_wave() -> bool:
	var waves := DataRegistry.get_table("waves")
	if current_wave_index + 1 >= waves.size():
		return false
	current_wave_index += 1
	current_wave = waves[current_wave_index]
	reward_snapshot.reset(str(current_wave.get("id", "")))
	wave_time_left = float(current_wave.get("duration_seconds", 0))
	spawn_timers_ms.clear()
	var spawn_groups: Array = current_wave.get("spawn_groups", [])
	for group in spawn_groups:
		spawn_timers_ms.append(0.0)
	if finance_system != null and int(finance_system.get_state_snapshot().get("current_wave_number", 0)) < current_wave_index + 1:
		finance_system.begin_wave(current_wave_index + 1)
	running = true
	wave_started.emit(str(current_wave.get("id", "")), int(current_wave.get("duration_seconds", 0)))
	return true


func finish_current_wave() -> void:
	if not running:
		return
	running = false
	collect_all_exp_orbs()
	clear_battle_entities()
	if finance_system != null:
		finance_system.process_wave_end_settlements()
	wave_finished.emit(str(current_wave.get("id", "")))


func spawn_enemy(enemy_id: String, position: Vector2 = Vector2.ZERO) -> EnemyController:
	var enemy_data := DataRegistry.get_record("enemies", enemy_id)
	if enemy_data.is_empty():
		return null
	var enemy_scene := _load_enemy_scene(enemy_data)
	if enemy_scene == null:
		return null
	var enemy := enemy_scene.instantiate() as EnemyController
	if enemy == null:
		return null
	enemy.auto_initialize_on_ready = false
	enemy_root.add_child(enemy)
	enemy.global_position = position
	var zone_modifiers := ZoneProgression.build_enemy_pressure_modifiers()
	enemy.initialize(enemy_id, player, zone_modifiers)
	enemy.died.connect(_on_enemy_died)
	return enemy


func spawn_summon(summon_data: Dictionary, position: Vector2 = Vector2.ZERO, use_position: bool = false) -> SummonController:
	_ensure_summon_root()
	return summon_root.spawn_summon(summon_data, position, use_position) if summon_root != null else null


func spawn_summons(summon_data: Dictionary, base_count: int = 1) -> Array[SummonController]:
	_ensure_summon_root()
	if summon_root == null:
		var empty_result: Array[SummonController] = []
		return empty_result
	return summon_root.spawn_summons(summon_data, base_count)


func spawn_default_summon(base_count: int = 1) -> SummonController:
	_ensure_summon_root()
	return summon_root.spawn_default_summon(base_count) if summon_root != null else null


func spawn_default_summons(base_count: int = 1) -> Array[SummonController]:
	_ensure_summon_root()
	if summon_root == null:
		var empty_result: Array[SummonController] = []
		return empty_result
	return summon_root.spawn_default_summons(base_count)


func spawn_exp_orb(amount: int, position: Vector2) -> ExpOrb:
	return drop_reward_system.spawn_exp_orb(amount, position, pickup_root, player, reward_snapshot, Callable(self, "_on_exp_orb_collected"))


func spawn_health_pack(amount: int, position: Vector2) -> HealthPack:
	return drop_reward_system.spawn_health_pack(amount, position, pickup_root, player, reward_snapshot, Callable(self, "_on_health_pack_collected"))


func collect_all_exp_orbs() -> void:
	collect_exp_orbs_in_root(pickup_root)


func collect_all_reward_pickups() -> void:
	# 兼容旧调用；当前仅收集经验球。
	collect_all_exp_orbs()


func clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyController and enemy.is_inside_tree():
			enemy.queue_free()


func clear_summons() -> void:
	if summon_root != null:
		summon_root.clear_summons()


func clear_battle_entities() -> void:
	_clear_non_exp_reward_pickups()
	clear_enemies()
	clear_summons()


func _collect_exp_orbs_recursive(node: Node, result: Array[ExpOrb]) -> void:
	if node is ExpOrb:
		result.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_exp_orbs_recursive(child, result)


func collect_exp_orbs_in_root(root: Node) -> void:
	var exp_orbs: Array[ExpOrb] = []
	if root != null:
		_collect_exp_orbs_recursive(root, exp_orbs)
	for orb in exp_orbs:
		if is_instance_valid(orb) and orb.is_inside_tree():
			orb.collect()


func _clear_non_exp_reward_pickups() -> void:
	var pickups: Array[Node] = []
	if pickup_root != null:
		_collect_reward_pickups_recursive(pickup_root, pickups)
	for pickup in pickups:
		if pickup is ExpOrb:
			continue
		if is_instance_valid(pickup) and pickup.is_inside_tree():
			pickup.queue_free()


func _collect_reward_pickups_recursive(node: Node, result: Array[Node]) -> void:
	if node.is_in_group("reward_pickups"):
		result.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_reward_pickups_recursive(child, result)


func calculate_wave_duration(wave_index: int) -> int:
	return mini(15 + 5 * wave_index, 50)


func get_required_exp_for_next_level() -> int:
	return 5 + (player_level - 1) * 5


func add_exp_and_gold(exp_amount: int, gold_amount: int) -> void:
	var final_exp := _apply_percent_bonus(exp_amount, "exp_gain_percent")
	var final_gold := _apply_percent_bonus(gold_amount, "currency_gain_percent")
	current_exp += final_exp
	current_gold += final_gold
	collected_exp_this_wave += final_exp
	collected_gold_this_wave += final_gold
	_process_level_ups()
	exp_changed.emit(current_exp, get_required_exp_for_next_level(), player_level)
	gold_changed.emit(current_gold)


func get_current_gold() -> int:
	return current_gold


func apply_gold_delta(delta: int, reason: String = "") -> bool:
	var next_gold := current_gold + delta
	if next_gold < 0:
		return false
	current_gold = next_gold
	gold_changed.emit(current_gold)
	return true


func deposit_finance(amount: int, free_principal: bool = false, reason: String = "manual") -> Dictionary:
	if finance_system == null:
		return {"success": false, "reason": "finance_system_missing"}
	return finance_system.deposit(amount, free_principal, reason)


func withdraw_finance(amount: int) -> Dictionary:
	if finance_system == null:
		return {"success": false, "reason": "finance_system_missing"}
	return finance_system.withdraw(amount)


func apply_finance_operation(action: String, amount: int) -> Dictionary:
	if finance_system == null:
		return {"success": false, "reason": "finance_system_missing"}
	return finance_system.apply_finance_operation(action, amount)


func trigger_finance_interest(source: String = "manual") -> Dictionary:
	if finance_system == null:
		return {"success": false, "reason": "finance_system_missing"}
	return finance_system.trigger_manual_interest(source)


func get_finance_popup_payload(source: String = "wave_start") -> Dictionary:
	if finance_system == null:
		return {}
	return finance_system.build_finance_popup_payload(source)


func get_finance_snapshot() -> Dictionary:
	if finance_system == null:
		return {}
	return finance_system.get_state_snapshot()


func prepare_finance_for_wave(wave_number: int) -> Dictionary:
	if finance_system == null:
		return {}
	return finance_system.begin_wave(wave_number)


func add_relic(relic_id: String) -> bool:
	return player != null and player.add_relic(relic_id)


func _connect_player_relic_signal() -> void:
	if player == null:
		return
	var relic_added_callable := Callable(self, "_on_player_relic_added")
	if not player.relic_added.is_connected(relic_added_callable):
		player.relic_added.connect(relic_added_callable)


func _on_player_relic_added(relic_id: String) -> void:
	if finance_system != null:
		finance_system.on_relic_added(relic_id)


func _connect_finance_system() -> void:
	if finance_system == null:
		return
	var changed_callable := Callable(self, "_on_finance_changed")
	var settled_callable := Callable(self, "_on_interest_settled")
	if not finance_system.finance_changed.is_connected(changed_callable):
		finance_system.finance_changed.connect(changed_callable)
	if not finance_system.interest_settled.is_connected(settled_callable):
		finance_system.interest_settled.connect(settled_callable)


func _on_finance_changed(snapshot: Dictionary) -> void:
	finance_changed.emit(snapshot.duplicate(true))


func _on_interest_settled(result: Dictionary) -> void:
	interest_settled.emit(result.duplicate(true))


func _process_spawn_timers(delta: float) -> void:
	var spawn_groups: Array = current_wave.get("spawn_groups", [])
	for index in range(spawn_groups.size()):
		var group: Dictionary = spawn_groups[index]
		spawn_timers_ms[index] -= delta * 1000.0
		if spawn_timers_ms[index] > 0.0:
			continue
		spawn_timers_ms[index] = float(group.get("spawn_interval_ms", 1000))
		for count_index in range(int(group.get("count_per_spawn", 1))):
			spawn_enemy(str(group.get("enemy_id", "")), get_random_spawn_position())


func get_random_spawn_position() -> Vector2:
	var origin := player.global_position if player != null else Vector2.ZERO
	var angle := randf() * TAU
	var distance := randf_range(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
	return origin + Vector2.RIGHT.rotated(angle) * distance


func _ensure_summon_root() -> void:
	if summon_root != null and is_instance_valid(summon_root):
		return
	summon_root = _get_optional_node(summon_root_path) as SummonRoot
	if summon_root != null:
		return
	summon_root = get_node_or_null("SummonRoot") as SummonRoot
	if summon_root != null:
		return
	summon_root = SummonRoot.new()
	summon_root.name = "SummonRoot"
	add_child(summon_root)


func _on_enemy_died(enemy: EnemyController, drop_table_id: String, death_position: Vector2) -> void:
	var actions := drop_reward_system.build_drop_actions(drop_table_id, player)
	for action in actions:
		drop_reward_system.spawn_action(
			action,
			death_position,
			pickup_root,
			player,
			reward_snapshot,
			Callable(self, "_on_exp_orb_collected"),
			Callable(self, "_on_health_pack_collected")
		)


func _on_exp_orb_collected(orb: ExpOrb, exp_amount: int, gold_amount: int) -> void:
	add_exp_and_gold(exp_amount, gold_amount)
	reward_snapshot.record_exp_collection(exp_amount, gold_amount)


func _on_health_pack_collected(_pickup: HealthPack, heal_amount: int) -> void:
	reward_snapshot.record_health_collection(heal_amount)


func _apply_percent_bonus(base_amount: int, stat_id: String) -> int:
	var bonus := player.get_stat(stat_id) if player != null else StatDefinitions.get_default_value(stat_id)
	return maxi(0, int(roundi(float(base_amount) * (1.0 + bonus / 100.0))))


func _process_level_ups() -> void:
	while current_exp >= get_required_exp_for_next_level():
		current_exp -= get_required_exp_for_next_level()
		player_level += 1
		shared_reward_shop_requested.emit(player_level)
		free_shop_requested.emit(player_level)


func _load_enemy_scene(enemy_data: Dictionary) -> PackedScene:
	var scene_path := str(enemy_data.get("scene", ""))
	if scene_path.is_empty():
		return null
	if enemy_scene_cache.has(scene_path):
		return enemy_scene_cache[scene_path]
	var loaded_scene := load(scene_path) as PackedScene
	if loaded_scene != null:
		enemy_scene_cache[scene_path] = loaded_scene
	return loaded_scene


func get_reward_snapshot() -> Dictionary:
	return reward_snapshot.to_dictionary()
