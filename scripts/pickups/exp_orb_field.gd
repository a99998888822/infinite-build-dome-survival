extends Node
## Keeps only nearby experience orbs in the physics world. Orbs retain their
## node, amount, position and gold state; this manager only toggles collision
## and the per-frame callback, never pickup or values.
##
## A slice scan avoids a 10k iteration spike. ExpOrb keeps normal pickup
## behaviour while its collision is enabled.

const SCAN_SLICE := 1024
const ACTIVE_MARGIN := 96.0
const MERGE_CAP := 1000
const MAX_STACK_CONTRIBUTIONS := 16
const MERGE_LOCAL_RADIUS := 320.0
const MERGE_LOCAL_RADIUS_SQUARED := MERGE_LOCAL_RADIUS * MERGE_LOCAL_RADIUS
var player: PlayerController = null
var orbs: Array[ExpOrb] = []
var cursor := 0


func _enter_tree() -> void:
	# BattleRoot reparents WaveManager into the low-resolution world viewport.
	# Entering again must restore the static lookup used by orbs and drops.
	ExpOrb.field_manager = self
	add_to_group("exp_orb_field")


func register_orb(orb: ExpOrb) -> void:
	if orb == null or orb.collected_once:
		return
	if not orbs.has(orb):
		orbs.append(orb)


func unregister_orb(orb: ExpOrb) -> void:
	orbs.erase(orb)


## Rebuilds the registry for a new run. Orbs that survived the previous run are
## still in the pickup root, so they are re-registered instead of silently
## dropping out of collision culling.
func reset(root: Node) -> void:
	orbs.clear()
	cursor = 0
	if root == null:
		return
	for child in root.get_children():
		if child is ExpOrb:
			register_orb(child as ExpOrb)


## Called before a new exp-only orb is created. Over the cap, add the drop to
## the nearest compatible orb instead. Contributions are kept separately so
## every contribution still goes through the original per-orb rounding path.
func try_merge_exp_orb(amount: int, position: Vector2, multiplier: float) -> ExpOrb:
	if amount <= 0 or orbs.size() < MERGE_CAP:
		return null
	var roomy_local: ExpOrb = null
	var roomy_local_distance := MERGE_LOCAL_RADIUS_SQUARED
	var roomy_farthest: ExpOrb = null
	var roomy_farthest_distance := -1.0
	var full_local: ExpOrb = null
	var full_local_distance := MERGE_LOCAL_RADIUS_SQUARED
	var full_farthest: ExpOrb = null
	var full_farthest_distance := -1.0
	for orb in orbs:
		if not is_instance_valid(orb) or orb.collected_once:
			continue
		if orb.gold_lifetime > 0.0 or orb.gold_expired:
			continue
		if not is_equal_approx(orb.gold_multiplier, multiplier):
			continue
		var distance := orb.global_position.distance_squared_to(position)
		if orb.contributions.size() < MAX_STACK_CONTRIBUTIONS:
			if distance <= roomy_local_distance:
				roomy_local_distance = distance
				roomy_local = orb
			if distance > roomy_farthest_distance:
				roomy_farthest_distance = distance
				roomy_farthest = orb
		else:
			if distance <= full_local_distance:
				full_local_distance = distance
				full_local = orb
			if distance > full_farthest_distance:
				full_farthest_distance = distance
				full_farthest = orb
	var target: ExpOrb = null
	var relocate := false
	if roomy_local != null:
		target = roomy_local
	elif roomy_farthest != null:
		target = roomy_farthest
		relocate = true
	elif full_local != null:
		# Every compatible stack already holds the preferred contribution count;
		# the node cap still wins, so the drop joins an existing stack instead of
		# creating a node past MERGE_CAP.
		target = full_local
	elif full_farthest != null:
		target = full_farthest
		relocate = true
	if target == null:
		return null
	if relocate:
		# A drop in a fresh area relocates the least relevant old stack here.
		# Its accumulated experience moves with it; no value is destroyed.
		target.global_position = position
	target.merge_amount(amount)
	return target


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	if orbs.is_empty():
		return
	var count := orbs.size()
	var step := mini(SCAN_SLICE, count)
	var player_position := player.global_position
	var pickup_radius := maxf(player.get_stat("pickup_radius"), 0.0)
	var pickup_squared := pickup_radius * pickup_radius
	var active_radius := pickup_radius + ACTIVE_MARGIN
	var active_squared := active_radius * active_radius
	for offset in step:
		var index := (cursor + offset) % count
		var orb := orbs[index]
		if not is_instance_valid(orb) or orb.collected_once:
			continue
		var position := orb.global_position
		var distance := position.distance_squared_to(player_position)
		var near := distance <= active_squared
		if orb.field_collidable != near:
			orb.set_field_collision(near)
		if near and distance <= pickup_squared:
			if orb.dormant:
				orb.wake_orb()
		elif not orb.force_collecting and not orb.dormant:
			orb.sleep_orb()
	cursor = (cursor + step) % count
