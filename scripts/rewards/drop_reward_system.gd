extends RefCounted
class_name DropRewardSystem

const EXP_ORB_SCENE: PackedScene = preload("res://scenes/pickups/exp_orb.tscn")
const HEALTH_PACK_SCENE: PackedScene = preload("res://scenes/pickups/health_pack.tscn")
const VALID_DROP_TYPES: Array[String] = ["exp_orb", "health_pack", "relic"]


func build_drop_actions(drop_table_id: String, player: PlayerController = null) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var drop_table := DataRegistry.get_record("drop_tables", drop_table_id)
	if drop_table.is_empty():
		push_warning("[DropRewardSystem] missing drop table: %s" % drop_table_id)
		return actions

	var drop_rate_bonus := _get_player_stat(player, "drop_rate_percent")
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
		if adjusted_chance <= 0.0 or randf() * 100.0 > adjusted_chance:
			continue

		var amount := maxi(0, int(entry.get("amount", 0)))
		if amount <= 0 and drop_type != "relic":
			continue
		if amount <= 0 and drop_type == "relic":
			amount = 1

		actions.append({
			"type": drop_type,
			"amount": amount,
			"chance_percent": base_chance,
			"adjusted_chance_percent": adjusted_chance,
			"entry": entry.duplicate(true),
		})
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
		"relic":
			if snapshot != null:
				snapshot.record_spawned_drop("relic", 1)
			push_warning("[DropRewardSystem] relic reward requested, but relic pickup scene is not implemented yet.")
			return null
		_:
			if snapshot != null:
				snapshot.record_spawned_drop("unknown", 1)
			push_warning("[DropRewardSystem] unknown reward type: %s" % drop_type)
			return null


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
