extends Node
class_name WaveManager

signal wave_started(wave_id: String, duration_seconds: int)
signal wave_finished(wave_id: String)
signal exp_changed(current_exp: int, required_exp: int, level: int)
signal gold_changed(current_gold: int)
signal finance_changed(snapshot: Dictionary)
signal interest_settled(result: Dictionary)
signal shared_reward_shop_requested(level: int)
signal wave_end_absorb_started(wave_id: String)

const DEFAULT_PLAYER_LEVEL: int = 1
const SPAWN_MIN_DISTANCE: float = 300.0
const SPAWN_MAX_DISTANCE: float = 600.0
const SPAWN_SEPARATION_DISTANCE: float = 96.0
const SPAWN_POSITION_ATTEMPTS: int = 10
const WAVE_HP_GROWTH_RATE: float = 0.207
const WAVE_DAMAGE_GROWTH_PERCENT: float = 7.0
const WAVE_SPAWN_COUNT_GROWTH_PERCENT: float = 8.0
const WAVE_SPAWN_INTERVAL_GROWTH_PERCENT: float = 6.0
const WAVE_ARMOR_GROWTH: float = 2.0
const ZONE_SPAWN_COUNT_GROWTH_PERCENT: float = 6.0
const MIN_SPAWN_INTERVAL_MS: float = 300.0
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
var _pending_wave_end_absorb_count: int = 0
var _finishing_wave_id: String = ""

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
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
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
	if CampProgression != null and CampProgression.has_method("has_unlock") and CampProgression.has_unlock("run_start_double_level"):
		player_level += 2
	current_exp = 0
	current_gold = 0
	collected_exp_this_wave = 0
	collected_gold_this_wave = 0
	_pending_wave_end_absorb_count = 0
	_finishing_wave_id = ""
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
	if player != null and player.is_alive():
		player.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_START)
	if player != null and player.is_alive():
		player.heal(int(player.get_stat("max_hp")))
	running = true
	wave_started.emit(str(current_wave.get("id", "")), int(current_wave.get("duration_seconds", 0)))
	return true


func finish_current_wave() -> void:
	if not running:
		return
	running = false
	_finishing_wave_id = str(current_wave.get("id", ""))
	wave_end_absorb_started.emit(_finishing_wave_id)
	clear_battle_entities()
	_start_wave_end_exp_absorb()


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
	var runtime_modifiers := ZoneProgression.build_enemy_pressure_modifiers()
	runtime_modifiers.append_array(_build_wave_enemy_modifiers())
	enemy.initialize(enemy_id, player, runtime_modifiers)
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
			enemy.fade_out_and_free()


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


func _start_wave_end_exp_absorb() -> void:
	var exp_orbs: Array[ExpOrb] = []
	if pickup_root != null:
		_collect_exp_orbs_recursive(pickup_root, exp_orbs)
	_pending_wave_end_absorb_count = 0
	for orb in exp_orbs:
		if not is_instance_valid(orb) or not orb.is_inside_tree():
			continue
		_pending_wave_end_absorb_count += 1
		var absorbed_callable := Callable(self, "_on_wave_end_exp_orb_absorbed")
		if not orb.collected.is_connected(absorbed_callable):
			orb.collected.connect(absorbed_callable)
		orb.start_wave_end_collection(player)
	if _pending_wave_end_absorb_count <= 0:
		_complete_wave_end_absorb()


func _on_wave_end_exp_orb_absorbed(_orb: ExpOrb, _exp_amount: int, _gold_amount: int) -> void:
	if _pending_wave_end_absorb_count <= 0:
		return
	_pending_wave_end_absorb_count -= 1
	if _pending_wave_end_absorb_count <= 0:
		_complete_wave_end_absorb()


func _complete_wave_end_absorb() -> void:
	_pending_wave_end_absorb_count = 0
	process_wave_end_settlements()
	var finished_wave_id := _finishing_wave_id
	_finishing_wave_id = ""
	wave_finished.emit(finished_wave_id)


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
	return mini(30 + 5 * wave_index, 60)


func get_required_exp_for_next_level() -> int:
	return ceili(0.45 * pow(float(player_level) + 1.8, 2.9))


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


func process_wave_end_settlements() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if finance_system != null:
		results = finance_system.process_wave_end_settlements()
	if player != null and player.is_alive():
		player.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	return results


func tick_finance(delta: float) -> void:
	if finance_system != null:
		finance_system.tick(delta)


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
		spawn_timers_ms[index] = calculate_spawn_interval(float(group.get("spawn_interval_ms", 1000)))
		var spawn_count := calculate_enemy_spawn_count(int(group.get("count_per_spawn", 1)))
		for count_index in range(spawn_count):
			spawn_enemy(str(group.get("enemy_id", "")), get_random_spawn_position())


func calculate_enemy_spawn_count(base_count: int) -> int:
	var spawn_rate_percent := player.get_stat("enemy_spawn_rate_percent") if player != null else 0.0
	var wave_multiplier := 1.0 + WAVE_SPAWN_COUNT_GROWTH_PERCENT * float(maxi(current_wave_index, 0)) / 100.0
	var streak_multiplier := 1.0 + ZONE_SPAWN_COUNT_GROWTH_PERCENT * float(ZoneProgression.get_effective_streak()) / 100.0
	var scaled_count := maxi(0, int(ceil(float(maxi(base_count, 0)) * wave_multiplier * streak_multiplier)))
	return StatDefinitions.calculate_enemy_spawn_count(scaled_count, spawn_rate_percent)


func calculate_spawn_interval(base_interval_ms: float) -> float:
	var wave_growth := WAVE_SPAWN_INTERVAL_GROWTH_PERCENT * float(maxi(current_wave_index, 0)) / 100.0
	var zone_growth := ZoneProgression.get_enemy_pressure_per_streak("spawn_interval_percent") * float(ZoneProgression.get_effective_streak()) / 100.0
	return maxf(MIN_SPAWN_INTERVAL_MS, maxf(base_interval_ms, 0.0) / (1.0 + wave_growth + zone_growth))


func _build_wave_enemy_modifiers() -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	var wave_step := float(maxi(current_wave_index, 0))
	modifiers.append(_build_wave_modifier("max_hp", Modifier.OPERATION_MULTIPLY, pow(1.0 + WAVE_HP_GROWTH_RATE, wave_step)))
	modifiers.append(_build_wave_modifier("melee_damage", Modifier.OPERATION_ADD_PERCENT, WAVE_DAMAGE_GROWTH_PERCENT * wave_step))
	modifiers.append(_build_wave_modifier("armor", Modifier.OPERATION_ADD_FLAT, WAVE_ARMOR_GROWTH * wave_step))
	return modifiers


func _build_wave_modifier(stat_id: String, operation: String, value: float) -> Dictionary:
	return {
		"id": "wave_%d_%s" % [current_wave_index + 1, stat_id],
		"source_type": "wave",
		"source_id": str(current_wave.get("id", "")),
		"target_scope": "enemy",
		"stat": stat_id,
		"operation": operation,
		"value": value,
		"duration": Modifier.PERMANENT_DURATION,
		"stack_rule": Modifier.STACK_RULE_UNIQUE,
	}


func get_random_spawn_position() -> Vector2:
	var origin := player.global_position if player != null else Vector2.ZERO
	var fallback := origin
	for attempt in range(SPAWN_POSITION_ATTEMPTS):
		var angle := randf() * TAU
		var distance := randf_range(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
		var candidate := origin + Vector2.RIGHT.rotated(angle) * distance
		if attempt == 0:
			fallback = candidate
		if _has_spawn_clearance(candidate):
			return candidate
	return fallback


func _has_spawn_clearance(candidate: Vector2) -> bool:
	var min_distance_sq := SPAWN_SEPARATION_DISTANCE * SPAWN_SEPARATION_DISTANCE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.is_inside_tree():
			continue
		if candidate.distance_squared_to(enemy.global_position) < min_distance_sq:
			return false
	return true


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
	if player != null:
		player.heal(int(player.get_stat("on_kill_heal")))
	var actions := drop_reward_system.build_drop_actions(drop_table_id, player)
	if Engine.is_in_physics_frame():
		call_deferred("_spawn_drop_actions", actions, death_position)
	else:
		_spawn_drop_actions(actions, death_position)
	var tip_tray_amount := finance_system.roll_enemy_kill_bonus_drops() if finance_system != null else 0
	if tip_tray_amount > 0:
		if Engine.is_in_physics_frame():
			call_deferred("_spawn_tip_tray_drop", tip_tray_amount, death_position)
		else:
			_spawn_tip_tray_drop(tip_tray_amount, death_position)


func _spawn_tip_tray_drop(amount: int, drop_position: Vector2) -> void:
	if amount <= 0 or pickup_root == null or player == null:
		return
	drop_reward_system.spawn_exp_orb(amount, drop_position, pickup_root, player, reward_snapshot, Callable(self, "_on_exp_orb_collected"))


func _spawn_drop_actions(actions: Array[Dictionary], drop_position: Vector2) -> void:
	if pickup_root == null or player == null:
		return
	for action in actions:
		drop_reward_system.spawn_action(
			action,
			drop_position,
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
