extends RefCounted
class_name DropRewardSystem

const EXP_ORB_SCENE: PackedScene = preload("res://scenes/pickups/exp_orb.tscn")
const HEALTH_PACK_SCENE: PackedScene = preload("res://scenes/pickups/health_pack.tscn")
const AUGMENTATION_PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/augmentation_pickup.tscn")
const VALID_DROP_TYPES: Array[String] = ["exp_orb", "health_pack", "relic", "augmentation"]


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

		var action := {
			"type": drop_type,
			"amount": amount,
			"chance_percent": base_chance,
			"adjusted_chance_percent": adjusted_chance,
			"entry": entry.duplicate(true),
		}
		if drop_type == "relic":
			action["relic_id"] = str(entry.get("relic_id", entry.get("target_id", "")))
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
			if snapshot != null:
				snapshot.record_spawned_drop("relic", 1)
			var entry: Dictionary = action.get("entry", {})
			var relic_id := str(action.get("relic_id", action.get("target_id", entry.get("relic_id", entry.get("target_id", "")))))
			if relic_id.is_empty():
				relic_id = _pick_random_available_relic(player)
			if relic_id.is_empty() or player == null or not player.has_method("add_relic") or not player.add_relic(relic_id):
				push_warning("[DropRewardSystem] relic reward failed: %s" % relic_id)
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


func _pick_random_available_relic(player: PlayerController) -> String:
	var candidates: Array[String] = []
	for relic_data in DataRegistry.get_table("relics"):
		if not (relic_data is Dictionary):
			continue
		var relic_record: Dictionary = relic_data
		var relic_id := str(relic_record.get("id", ""))
		if relic_id.is_empty():
			continue
		if player != null and player.has_method("can_add_relic") and not player.can_add_relic(relic_id):
			continue
		candidates.append(relic_id)
	if candidates.is_empty():
		return ""
	return candidates[randi_range(0, candidates.size() - 1)]


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
