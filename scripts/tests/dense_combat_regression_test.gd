extends Node2D

const RESOLVER = preload("res://scripts/effects/effect_parameter_resolver.gd")
const BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
class ControlledDrops extends DropRewardSystem:
	var chances: Array[float] = []
	func _roll_drop_chance(chance: float) -> bool:
		chances.append(chance)
		return chance > 0.0

var checks := 0
var failures := 0
var received: Array[int] = []
var player: PlayerController

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.position = Vector2(4000, 4000)
	_test_context()
	_test_terrain_cache()
	await _test_explosions()
	await _test_drops()
	await _test_batches()
	player.queue_free()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await frames()
	CampProgression.end_transient_session()
	print("DENSE_COMBAT_REGRESSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _test_context() -> void:
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", player)
	var first := RESOLVER.build_cached_weapon_context(weapon, "thunder_fire", {"damage": 18.0})
	var second := RESOLVER.build_cached_weapon_context(weapon, "thunder_fire", {"damage": 18.0})
	check(first == second, "unchanged reaction inputs share one context")
	weapon.add_effect_modifier({"effect_id": "thunder_fire", "channel": "damage", "operation": "add_flat", "value": 7.0})
	var changed := RESOLVER.build_cached_weapon_context(weapon, "thunder_fire", {"damage": 18.0})
	check(changed != first and changed.get_resolved_parameter("damage") == 25.0, "same-frame modifier change invalidates context")
	var other := RESOLVER.build_cached_weapon_context(weapon, "thunder_fire", {"damage": 36.0})
	check(other.get_resolved_parameter("damage") == 43.0 and first.get_resolved_parameter("damage") == 18.0, "damage bases and existing contexts stay independent")
	var writable := RESOLVER.build_weapon_context(weapon, "thunder_fire", {"damage": 36.0})
	writable.set_parameter("damage", 100.0)
	check(other.get_resolved_parameter("damage") == 43.0, "ordinary mutable contexts never alias reaction cache")

func _test_terrain_cache() -> void:
	var root := Node.new()
	add_child(root)
	check(ExplosionEffect._find_terrain_cached(root) == null, "terrain cache records an empty scene")
	var terrain := Node.new()
	root.add_child(terrain)
	terrain.name = "DestructibleTestArea"
	check(ExplosionEffect._find_terrain_cached(root) == terrain, "same-frame terrain rename invalidates cached miss")
	terrain.name = "Other"
	check(ExplosionEffect._find_terrain_cached(root) == null, "same-frame removal of terrain name invalidates cached hit")
	terrain.name = "DestructibleTestArea"
	ExplosionEffect._find_terrain_cached(root)
	terrain.free()
	check(ExplosionEffect._find_terrain_cached(root) == null, "terrain destruction invalidates cached node")
	root.free()

func _make_enemy(point: Vector2) -> EnemyController:
	var enemy := EnemyController.new()
	enemy.auto_initialize_on_ready = false
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	enemy.add_child(collision)
	enemy.collision_layer = 2
	enemy.collision_mask = 0
	add_child(enemy)
	enemy.position = point
	enemy.current_hp = 1000
	enemy.alive = true
	enemy.set_physics_process(false)
	enemy.damage_received.connect(func(_source: String, _damage: int): received.append(enemy.get_instance_id()))
	return enemy

func _test_explosions() -> void:
	var enemies: Array[EnemyController] = [_make_enemy(Vector2.ZERO), _make_enemy(Vector2(58, 0)), _make_enemy(Vector2(90, 0))]
	var explosion := ExplosionEffect.new()
	add_child(explosion)
	explosion._damage_event = DamageEvent.create({"damage": 18, "source_weapon_id": "weapon_void_blade"})
	await get_tree().physics_frame
	await frames()
	var shape := CircleShape2D.new()
	shape.radius = 50
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 2
	var reference: Array[int] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		if result.collider is EnemyController: reference.append(result.collider.get_instance_id())
	received.clear()
	explosion._damage_enemies(50, 18, 0.0)
	check(received == reference and received.size() == 2, "explosion preserves physics overlap boundaries and returned hit order")
	check(enemies[0].current_hp == 982 and enemies[1].current_hp == 982 and enemies[2].current_hp == 1000, "overlapping collision shape is hit even with center outside radius")
	enemies[0].apply_light()
	explosion._damage_enemies(50, 18, 0.0)
	explosion._damage_enemies(50, 18, 0.0)
	check(enemies[0].current_hp == 941 and not enemies[0].has_status("light"), "overlapping blasts retain separate damage events and consume light once")
	enemies[0].position = Vector2(200, 0)
	enemies[2].position = Vector2(10, 0)
	var newcomer := _make_enemy(Vector2(20, 0))
	await get_tree().physics_frame
	await frames()
	received.clear()
	explosion._damage_enemies(50, 10, 1.0)
	check(not received.has(enemies[0].get_instance_id()) and received.has(enemies[2].get_instance_id()) and received.has(newcomer.get_instance_id()), "subsequent query sees moved and newly spawned enemies")
	check(enemies[1].current_hp == 945 and enemies[2].current_hp == 992 and newcomer.current_hp == 994, "distance falloff still rounds and clamps each individual hit")
	enemies[1].current_hp = 1
	explosion._damage_enemies(50, 18, 0.0)
	received.clear()
	explosion._damage_enemies(50, 18, 0.0)
	check(not received.has(enemies[1].get_instance_id()), "dead target cannot receive another explosion hit")
	for enemy in enemies: if is_instance_valid(enemy): enemy.queue_free()
	newcomer.queue_free()
	explosion.queue_free()
	await frames()

func _test_drops() -> void:
	var manager := preload("res://scenes/waves/wave_manager.tscn").instantiate() as WaveManager
	manager.auto_start = false
	add_child(manager)
	manager.set_process(false)
	manager.drop_reward_system = ControlledDrops.new()
	manager.initialize(player)
	var drops := manager.drop_reward_system as ControlledDrops
	for i in 40: manager._queue_drop_actions([{"type": "exp_orb", "amount": 2}], Vector2(1000, 1000))
	check(manager.pickup_root.get_child_count() == 0, "death queues recipes without creating live pickup nodes")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	manager._process_pending_rewards(1.0)
	check(manager.pickup_root.get_child_count() == 0 and manager._reward_clock == 0.0, "pause freezes both queue and pending gold expiry")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	manager._process_pending_rewards(0.1)
	check(manager.pickup_root.get_child_count() > 0 and manager.pickup_root.get_child_count() <= 12, "normal drain respects per-frame pickup count budget")
	manager._flush_pending_reward_batches()
	check(manager.pickup_root.get_child_count() == 40 and manager.reward_snapshot.spawned_exp_orbs == 40, "wave-end drain preserves every pending drop")
	var orb := manager.pickup_root.get_child(0) as ExpOrb
	var orb_id := orb.get_instance_id()
	var original_color: Color = orb.get_node("Sprite2D").modulate
	orb.configure_gold({"multiplier": 3.0, "lifetime": 0.1})
	orb.advance_gold_clock(0.2)
	orb.rotation = 1.5
	orb.start_wave_end_collection(player)
	orb.collect()
	orb.collect()
	check(manager.reward_snapshot.collected_exp_orbs == 1 and not orb.is_in_group("reward_pickups"), "recycled orb collects once and leaves active pickup groups immediately")
	await frames()
	var reused := manager.spawn_exp_orb(7, Vector2(900, 900))
	check(reused.get_instance_id() == orb_id, "collected orb node is reused")
	check(reused.amount == 7 and not reused.force_collecting and not reused.gold_expired and reused.gold_age == 0.0 and reused.gold_multiplier == 1.0 and reused.rotation == 0.0 and reused.monitoring and reused.visible and reused.get_node("Sprite2D").modulate == original_color, "reuse resets expiry, animation, monitoring, visual tint and amount")
	reused.collect()
	check(manager.reward_snapshot.collected_exp_orbs == 2, "reuse does not retain duplicate collection callbacks")
	drops.gold_terms = {"multiplier": 2.0, "lifetime": 0.05}
	manager._queue_drop_actions([{"type": "exp_orb", "amount": 3}], Vector2(1100, 1100))
	drops.gold_terms.clear()
	manager._process_pending_rewards(0.1)
	var timed := manager.pickup_root.get_child(-1) as ExpOrb
	check(timed.gold_expired and timed.gold_multiplier == 2.0, "queued orb preserves death-time gold terms and unpaused age")
	drops.begin_wave()
	var first := drops.prepare_action({"type": "augmentation", "item_id": "scroll_fire", "amount": 2}, manager.pickup_root, player)
	var second := drops.prepare_action({"type": "augmentation", "item_id": "scroll_water", "amount": 2}, manager.pickup_root, player)
	check(drops.get_augmentation_snapshot().augmentation_drops == 3 and second.amount == 1, "queued scrolls reserve and clip wave quota immediately")
	check(drops.prepare_action({"type": "augmentation", "item_id": "scroll_fire", "amount": 1}, manager.pickup_root, player).is_empty(), "queue cannot overbook augmentation quota")
	check(drops.spawn_action(first, Vector2(500, 500), manager.pickup_root, player) != null and drops.spawn_action(first, Vector2.ZERO, manager.pickup_root, player) == null, "reserved augmentation spawns once even when quota is full")
	drops.begin_wave()
	check(drops.spawn_action(second, Vector2.ZERO, manager.pickup_root, player) == null, "stale prepared recipe cannot leak into a new wave")
	var relics: Array[Dictionary] = []
	for i in 2:
		for action in drops.build_drop_actions("drop_elite_enemy", player):
			if action.type == "relic": relics.append(action)
	drops.chances.clear()
	var relic_first := drops.prepare_action(relics[0], manager.pickup_root, player)
	var relic_second := drops.prepare_action(relics[1], manager.pickup_root, player)
	check(not relic_first.is_empty() and not relic_second.is_empty() and drops.chances == [100.0, 50.0] and drops.get_elite_relics_dropped_this_wave() == 2, "pending elite choices consume decay before any pickup node appears")
	manager._queue_drop_actions([{"type": "exp_orb", "amount": 9}], Vector2.ZERO)
	manager.initialize(player)
	manager._flush_pending_reward_batches()
	check(manager._pending_reward_batches.is_empty() and manager.reward_snapshot.spawned_exp_orbs == 0, "new-run reset discards queued old-run rewards")
	manager.queue_free()
	await frames()
	# Exercise the production completion path with rewards still in the queue.
	manager = preload("res://scenes/waves/wave_manager.tscn").instantiate() as WaveManager
	manager.auto_start = false
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager.start_next_wave()
	manager._queue_drop_actions([{"type": "exp_orb", "amount": 2}, {"type": "augmentation", "item_id": "scroll_fire", "amount": 1}, {"type": "relic", "amount": 1}], Vector2(8000, 8000))
	manager.finish_current_wave()
	check(manager._pending_reward_batches.is_empty() and manager._pending_wave_end_absorb_count == 1 and manager.reward_snapshot.collected_augmentations == 1 and manager._pending_relic_choices.size() == 1, "wave finish drains queued drops before collecting choices and starting exp absorption")
	manager.collect_all_exp_orbs()
	check(manager._pending_wave_end_absorb_count == 0 and manager.run_statistics.completed_waves == 1, "pooled exp collection completes wave settlement exactly once")
	manager.collect_all_exp_orbs()
	check(manager.run_statistics.completed_waves == 1, "repeated collection cannot settle a completed wave twice")
	manager.queue_free()
	await frames()

func _test_batches() -> void:
	var host := Node2D.new()
	add_child(host)
	var first = BURST.spawn(host, Vector2(10, 20), Vector2.RIGHT, 1.0, {})
	var second = BURST.spawn(host, Vector2(30, 40), Vector2.DOWN, 1.0, {})
	check(first == second and first.get_active_particle_count() == 70, "same-frame contacts retain all particles in shared batches")
	first._flush_batches()
	check(first.batches[0].multimesh.visible_instance_count == 10 and first.batches[1].multimesh.visible_instance_count == 60, "one upload contains every contact instance")
	var distinct = BURST.spawn(host, Vector2.ZERO, Vector2.RIGHT, 1.0, {"size_multiplier": 2.0})
	check(distinct != first, "different visual parameters never share a material")
	first._process(2.0)
	var reused = BURST.spawn(host, Vector2(90, 90), Vector2.ZERO, 0.5, {})
	check(reused == first and reused.age == 0.0 and reused.flash_count == 3 and reused.impact_count == 15 and reused.global_position == Vector2(90, 90), "pooled batch resets clock, counts and world position")
	host.queue_free()
	await frames()
	check(get_tree().get_nodes_in_group("lightning_hit_sprite_bursts").is_empty(), "scene teardown frees active and parked batches")
