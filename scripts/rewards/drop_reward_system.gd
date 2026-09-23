extends RefCounted
class_name DropRewardSystem
signal relic_choice_collected(reward_id: String)

const EXP_ORB_SCENE: PackedScene = preload("res://scenes/pickups/exp_orb.tscn")
const HEALTH_PACK_SCENE: PackedScene = preload("res://scenes/pickups/health_pack.tscn")
const AUGMENTATION_PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/augmentation_pickup.tscn")
const RELIC_PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/relic_pickup.tscn")
const VALID_DROP_TYPES: Array[String] = ["exp_orb", "health_pack", "relic", "augmentation"]
const DEFAULT_ELITE_RELIC_DECAY_FACTOR: float = 0.5

var _elite_relics_dropped_this_wave: int = 0
var _reward_generation: int = 0
var _next_elite_reward_id: int = 0
var _resolved_elite_rewards: Dictionary = {}
var _choice_tokens: Dictionary = {}
var _next_choice_id: int = 0


func begin_wave() -> void:
	_elite_relics_dropped_this_wave = 0
	_reward_generation += 1
	_next_elite_reward_id = 0
	_resolved_elite_rewards.clear()
	_choice_tokens.clear()


func get_elite_relics_dropped_this_wave() -> int:
	return _elite_relics_dropped_this_wave


func get_elite_relic_drop_chance(chance_before_decay: float, decay_factor: float = DEFAULT_ELITE_RELIC_DECAY_FACTOR) -> float:
	# Cap the fully modified chance first, so high bonuses cannot cancel the decay.
	return clampf(chance_before_decay, 0.0, 100.0) * pow(clampf(decay_factor, 0.0, 1.0), _elite_relics_dropped_this_wave)


func _roll_drop_chance(chance_percent: float) -> bool:
	return chance_percent >= 100.0 or (chance_percent > 0.0 and randf() * 100.0 < chance_percent)


func _resolve_elite_relic_roll(action: Dictionary) -> bool:
	# Resolve immediately before spawning. Uncollected drops already count.
	if int(action.get("reward_generation", -1)) != _reward_generation:
		return false
	var reward_id := int(action.get("elite_reward_id", -1))
	if reward_id < 0 or _resolved_elite_rewards.has(reward_id):
		return false
	_resolved_elite_rewards[reward_id] = true
	var chance := get_elite_relic_drop_chance(float(action.get("chance_before_elite_decay", 0.0)), float(action.get("elite_relic_decay_factor", DEFAULT_ELITE_RELIC_DECAY_FACTOR)))
	action["adjusted_chance_percent"] = chance
	return _roll_drop_chance(chance)


func build_drop_actions(drop_table_id: String, player: PlayerController = null) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var drop_table := DataRegistry.get_record("drop_tables", drop_table_id)
	if drop_table.is_empty():
		push_warning("[DropRewardSystem] missing drop table: %s" % drop_table_id)
		return actions

	var drop_rate_bonus := _get_player_stat(player, "drop_rate_percent")
	var is_elite_table := (drop_table.get("tags", []) as Array).has("elite")
	for entry in drop_table.get("entries", []):
		if not (entry is Dictionary):
			continue
		var drop_type := str(entry.get("type", ""))
		if drop_type.is_empty():
			continue
		if not VALID_DROP_TYPES.has(drop_type):
			push_warning("[DropRewardSystem] unsupported drop type: %s" % drop_type)
			continue

		var base_chance := clampf(float(entry.get("chance_percent", 100.0)), 0.0, 100.0)
		var adjusted_chance := clampf(base_chance * (1.0 + drop_rate_bonus / 100.0), 0.0, 100.0)
		var is_elite_relic := is_elite_table and drop_type == "relic"
		if adjusted_chance <= 0.0 or (not is_elite_relic and not _roll_drop_chance(adjusted_chance)):
			continue

		var amount := maxi(0, int(entry.get("amount", 0)))
		if amount <= 0 and drop_type != "relic":
			continue
		if amount <= 0 and drop_type == "relic":
			amount = 1

		var action := {
			"type": drop_type,
			"amount": amount,
			"chance_percent": base_chance,
			"adjusted_chance_percent": adjusted_chance,
			"entry": entry.duplicate(true),
		}
		if drop_type == "relic":
			action["relic_id"] = str(entry.get("relic_id", entry.get("target_id", "")))
		if is_elite_relic:
			# This action is a pending chance, not a guaranteed relic reward.
			action["elite_relic_reward"] = true
			action["reward_generation"] = _reward_generation
			action["elite_reward_id"] = _next_elite_reward_id
			action["chance_before_elite_decay"] = adjusted_chance
			action["elite_relic_decay_factor"] = float(drop_table.get("elite_relic_decay_percent", DEFAULT_ELITE_RELIC_DECAY_FACTOR * 100.0)) / 100.0
			_next_elite_reward_id += 1
		actions.append(action)
	return actions


func spawn_drop_actions(
	actions: Array[Dictionary],
	position: Vector2,
	pickup_root: Node,
	player: PlayerController,
	snapshot: RewardSnapshot = null,
	on_exp_collected: Callable = Callable(),
	on_health_collected: Callable = Callable()
) -> Array[Node]:
	var spawned_nodes: Array[Node] = []
	for action in actions:
		if not (action is Dictionary):
			continue
		var spawned := spawn_action(action, position, pickup_root, player, snapshot, on_exp_collected, on_health_collected)
		if spawned != null:
			spawned_nodes.append(spawned)
	return spawned_nodes


func spawn_drop_table(
	drop_table_id: String,
	position: Vector2,
	pickup_root: Node,
	player: PlayerController,
	snapshot: RewardSnapshot = null,
	on_exp_collected: Callable = Callable(),
	on_health_collected: Callable = Callable()
) -> Array[Node]:
	return spawn_drop_actions(build_drop_actions(drop_table_id, player), position, pickup_root, player, snapshot, on_exp_collected, on_health_collected)


func spawn_action(
	action: Dictionary,
	position: Vector2,
	pickup_root: Node,
	player: PlayerController,
	snapshot: RewardSnapshot = null,
	on_exp_collected: Callable = Callable(),
	on_health_collected: Callable = Callable()
) -> Node:
	if action.is_empty():
		return null
	var drop_type := str(action.get("type", ""))
	var amount := maxi(0, int(action.get("amount", 0)))
	match drop_type:
		"exp_orb":
			return spawn_exp_orb(amount, position, pickup_root, player, snapshot, on_exp_collected)
		"health_pack":
			return spawn_health_pack(amount, position, pickup_root, player, snapshot, on_health_collected)
		"augmentation":
			var entry: Dictionary = action.get("entry", {})
			var augmentation_id := str(action.get("item_id", entry.get("item_id", entry.get("augmentation_id", ""))))
			return spawn_augmentation(augmentation_id, amount, position, pickup_root, player, snapshot)
		"relic":
			if not is_instance_valid(pickup_root) or not is_instance_valid(player):
				return null
			var is_elite_relic := bool(action.get("elite_relic_reward", false))
			if is_elite_relic and not _resolve_elite_relic_roll(action):
				return null
			var token := "relic_choice_%d_%d" % [_reward_generation, _next_choice_id]
			_next_choice_id += 1
			_choice_tokens[token] = false
			var pickup := RELIC_PICKUP_SCENE.instantiate() as RelicPickup
			pickup.initialize_choice(player, _claim_relic_choice.bind(token), snapshot)
			pickup_root.add_child(pickup)
			pickup.global_position = position
			if is_elite_relic:
				_elite_relics_dropped_this_wave += 1
			if snapshot != null:
				snapshot.record_spawned_drop("relic", 1)
			return pickup
		_:
			if snapshot != null:
				snapshot.record_spawned_drop("unknown", 1)
			push_warning("[DropRewardSystem] unknown reward type: %s" % drop_type)
			return null


func _claim_relic_choice(token: String) -> bool:
	if not _choice_tokens.has(token) or bool(_choice_tokens[token]):
		return false
	_choice_tokens[token] = true
	relic_choice_collected.emit(token)
	return true


func spawn_exp_orb(
	amount: int,
	position: Vector2,
	pickup_root: Node,
	player: PlayerController,
	snapshot: RewardSnapshot = null,
	on_collected: Callable = Callable()
) -> ExpOrb:
	if pickup_root == null or player == null:
		return null
	var orb := EXP_ORB_SCENE.instantiate() as ExpOrb
	if orb == null:
		return null
	pickup_root.add_child(orb)
	orb.global_position = position
	orb.initialize(amount)
	orb.set_target_player(player)
	if snapshot != null:
		snapshot.record_spawned_drop("exp_orb", 1)
	if on_collected.is_valid():
		orb.collected.connect(on_collected)
	return orb


func spawn_health_pack(
	amount: int,
	position: Vector2,
	pickup_root: Node,
	player: PlayerController,
	snapshot: RewardSnapshot = null,
	on_collected: Callable = Callable()
) -> HealthPack:
	if pickup_root == null or player == null:
		return null
	var pack := HEALTH_PACK_SCENE.instantiate() as HealthPack
	if pack == null:
		return null
	pickup_root.add_child(pack)
	pack.global_position = position
	pack.initialize(amount)
	pack.set_target_player(player)
	if snapshot != null:
		snapshot.record_spawned_drop("health_pack", 1)
	if on_collected.is_valid():
		pack.collected.connect(on_collected)
	return pack


func spawn_augmentation(
	augmentation_id: String,
	amount: int,
	position: Vector2,
	pickup_root: Node,
	player: PlayerController,
	snapshot: RewardSnapshot = null
) -> AugmentationPickup:
	if pickup_root == null or player == null or augmentation_id.is_empty():
		return null
	var pickup := AUGMENTATION_PICKUP_SCENE.instantiate() as AugmentationPickup
	if pickup == null:
		return null
	pickup_root.add_child(pickup)
	pickup.global_position = position
	pickup.initialize(augmentation_id, maxi(amount, 1))
	pickup.set_target_player(player)
	if snapshot != null:
		snapshot.record_spawned_drop("augmentation", 1)
	return pickup


func collect_reward_pickups(root: Node) -> void:
	if root == null:
		return
	var pickups: Array[Node] = []
	_collect_reward_pickups_recursive(root, pickups)
	for pickup in pickups:
		if is_instance_valid(pickup) and pickup.is_inside_tree() and pickup.has_method("collect"):
			pickup.call("collect")


func _collect_reward_pickups_recursive(node: Node, result: Array[Node]) -> void:
	if node.is_in_group("reward_pickups"):
		result.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_reward_pickups_recursive(child, result)


func _get_player_stat(player: PlayerController, stat_id: String) -> float:
	if player == null:
		return 0.0
	return player.get_stat(stat_id)
