extends Node
## Production loadout, damage signal, colliders, animation, shop and enchantments.
var checks := 0
var failures := 0
var session: RecordingSession
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var furnace: WeaponInstance
var saber: WeaponInstance
var walls: Array[Node] = []
var fired := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame

func freeze() -> void:
	for body in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		body.set_physics_process(false)

func step(n: int) -> void:
	for i in n:
		player._physics_process(1.0 / 60.0)
		for body in get_tree().get_nodes_in_group("weapon_runtime_effects"):
			if not body.is_queued_for_deletion() and body.has_method("_physics_process"):
				body._physics_process(1.0 / 60.0)
		freeze()
		loadout.active_casting.tick(1.0 / 60.0)
		await get_tree().process_frame

func reset() -> void:
	for weapon in loadout.weapon_instances:
		loadout._clear_weapon_runtime(weapon)
		for item in weapon.get_attached_item_instances(): weapon.detach_item_instance(str(item.item_instance_id))
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for wall in walls:
		if is_instance_valid(wall): wall.free()
	walls.clear()
	await frames()
	loadout.active_casting.states.clear()
	furnace.initialize("weapon_furnace", player)
	saber.initialize("weapon_saber", player)
	furnace.use_active_range_rules = true
	saber.use_active_range_rules = true
	furnace.runtime_stats.crit_chance = 0
	saber.runtime_stats.crit_chance = 0
	player.alive = true
	player.current_hp = 1000
	player.current_shield = 0
	player._invincibility_timer = 0.0
	player.global_position = Vector2.ZERO
	player._clear_move_input()
	player.action_animator.reset()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	fired = 0
	await frames()

func enemy(at: Vector2) -> EnemyController:
	var body := battle.wave_manager.spawn_enemy("enemy_mutated_grub", at)
	body.set_physics_process(false)
	body.current_hp = 10000
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var collision := body.get_node("CollisionShape2D") as CollisionShape2D
	collision.position = Vector2.ZERO
	collision.shape = shape
	body.target_player = null
	return body

func wall(at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 200)
	collision.shape = shape
	body.add_child(collision)
	player.get_parent().add_child(body)
	body.global_position = at
	walls.append(body)

func damage() -> FurnaceRuntime:
	player._invincibility_timer = 0.0
	player.take_damage(1, "integration_enemy")
	freeze()
	var list := get_tree().get_nodes_in_group("furnace_runtimes")
	return list.back() as FurnaceRuntime if not list.is_empty() else null

func _run() -> void:
	CampProgression.begin_transient_session()
	check(DataRegistry.get_load_errors().is_empty(), "configuration loads")
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"countdown":0, "hud":false, "relics":[], "weapons":[{"id":"weapon_furnace","level":1,"attachments":[]},{"id":"weapon_saber","level":1,"attachments":[]}]}, true)
	var error := await session.prepare(config)
	check(error.is_empty() and session.begin(), "real battle equips both weapons")
	if not error.is_empty(): get_tree().quit(1); return
	battle = session.battle
	battle.set_process(false)
	player = battle.player
	loadout = battle.loadout
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.set_process(false)
	loadout.set_process(false)
	player.set_physics_process(false)
	player.relic_system.clear()
	player.modifier_stack.clear()
	player.modifier_stack.set_base_stats({"max_hp":1000,"move_speed":150,"load_capacity":100,"crit_damage":150})
	furnace = loadout.get_weapon_instance("weapon_furnace")
	saber = loadout.get_weapon_instance("weapon_saber")
	loadout.weapon_fired.connect(func(_id, _count): fired += 1)
	await frames(12)
	AudioManager.stop_bgm()
	AudioServer.set_bus_mute(0, true)
	await reset()
	_test_upgrades()
	await reset()
	await _test_furnace()
	await reset()
	await _test_saber()
	await reset()
	await _test_cleanup()
	await reset()
	await session.dispose()
	session.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("FURNACE_SABER_INTEGRATION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_upgrades() -> void:
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity":100,"current_load":0})
	for weapon: WeaponInstance in [furnace, saber]:
		var base := 3.0 if weapon.is_furnace() else 5.0
		check(pool.any(func(row): return row.offer_type == "new_weapon" and row.target_id == weapon.weapon_id), "shop offers " + weapon.weapon_id)
		check(ResourceLoader.exists(str(weapon.weapon_data.icon)), "production icon exists")
		for index in 5:
			var damages: Array = [24,28,32,36,44] if weapon.is_furnace() else [32,37,42,47,54]
			check(weapon.get_base_attack_damage() == damages[index] and is_equal_approx(weapon.get_active_cooldown_seconds(), base - minf(index, 3) * 0.1), "damage/cooldown level %d %s" % [index+1,weapon.weapon_id])
			check(weapon.get_stat("projectile_count") == (2 if index == 4 else 1) and weapon.get_attachment_slot_count() == [1,2,2,3,3][index], "count/slots level %d" % (index+1))
			if index < 4:
				var copy := weapon.make_cast_copy()
				check(weapon.upgrade() and copy.level == index+1, "upgrade preserves active snapshot")
		check(not weapon.upgrade(), "level five cap")
		weapon.runtime_stats.attack_speed = 100
		check(is_equal_approx(weapon.get_active_cooldown_seconds(), (base-0.3)*0.75), "haste scales final cooldown")
	check(loadout.get_total_load_cost() == 52, "load stays 24 + 28")

func _test_furnace() -> void:
	var target := enemy(Vector2(100,0))
	var outside := enemy(Vector2(240,0))
	await frames()
	check(not loadout.cast_weapon(furnace, Vector2.ZERO), "furnace cannot cast manually")
	loadout.active_casting.auto_attack()
	check(fired == 0, "furnace does not auto fire just because enemies exist")
	player.take_damage(0)
	check(fired == 0, "zero damage cannot trigger")
	player.current_shield = 10
	var runtime := damage()
	check(runtime != null and fired == 1 and player.current_hp == 1000, "shield damage triggers passive")
	player.take_damage(1)
	check(fired == 1, "invulnerability blocks triggers")
	damage()
	check(fired == 1, "cooldown blocks repeated damage")
	await step(48)
	check(target.current_hp == 9976 and outside.current_hp == 10000, "one ring hits once within reach")
	check(target.has_status("burning") and is_equal_approx(target._burn_damage_per_tick, 2.4), "native burn uses 10 percent per half second")
	check(is_equal_approx(float(loadout.active_casting.state_for(furnace).remaining), 2.2), "passive cooldown starts on trigger")
	await step(134)
	damage()
	check(fired == 2, "passive becomes ready after three seconds")
	await reset()
	furnace.runtime_stats.projectile_count = 3
	var duplicate := enemy(Vector2(90,0))
	duplicate.add_child(duplicate.get_node("CollisionShape2D").duplicate())
	await frames()
	runtime = damage()
	check(runtime.knockback_count == 1, "only initial burst knocks back, deduplicated")
	await step(75)
	check(duplicate.current_hp == 9928, "three rings give exactly three hits")
	check(is_equal_approx(duplicate._burn_damage_per_tick, 2.4), "same source burn refreshes without stacking")
	await reset()
	var split := player.item_inventory.add_item_from_base("scroll_split", "integration")
	check(furnace.attach_item_instance(split), "furnace supports split")
	var outer := enemy(Vector2(192,0))
	await frames()
	damage()
	await step(80)
	check(outer.current_hp == 9989 and outer.has_status("burning"), "outer flares deal 45 percent damage once")
	check(is_equal_approx(outer._burn_damage_per_tick, 1.08), "split burning scales once")
	await reset()
	wall(Vector2(60,0))
	var blocked := enemy(Vector2(100,0))
	await frames()
	damage()
	await step(48)
	check(blocked.current_hp == 10000, "furnace does not damage through terrain")

func _test_saber() -> void:
	var target := enemy(Vector2(140,0))
	var miss := enemy(Vector2(140,50))
	await frames()
	check(loadout.cast_weapon(saber, Vector2(300,0)), "saber casts")
	freeze()
	var runtime := saber.mobility_runtime.get_ref() as SaberRuntime
	check(not loadout.cast_weapon(saber, Vector2(-300,0)), "one mobility sequence at a time")
	var before := {}
	var after := {}
	before[player.action_animator.current_frame] = true
	for i in 43:
		await step(1)
		if player.action_animator.current_clip == "jump_forward":
			if runtime.blinked: after[player.action_animator.current_frame] = true
			else: before[player.action_animator.current_frame] = true
		if i == 19: check(player.global_position == Vector2.ZERO and target.current_hp == 10000, "no motion or hit before half jump")
	check(before.keys() == [0,1,2] and after.keys() == [3,4,5], "jump plays three frames on each side")
	check(player.global_position.is_equal_approx(Vector2(300,0)) and target.current_hp == 9968 and miss.current_hp == 10000, "blink lands and path deals one narrow hit")
	await reset()
	saber.runtime_stats.projectile_count = 5
	var victim := enemy(Vector2(150,0))
	victim.add_child(victim.get_node("CollisionShape2D").duplicate())
	var ice := player.item_inventory.add_item_from_base("scroll_ice", "integration")
	check(saber.attach_item_instance(ice), "saber supports impact enchantments")
	check(not saber.attach_item_instance(player.item_inventory.add_item_from_base("scroll_split", "integration")), "unsupported saber split rejected")
	await frames()
	loadout.cast_weapon(saber, Vector2(300,0))
	freeze()
	runtime = saber.mobility_runtime.get_ref()
	await step(40)
	check(runtime.cuts_fired == 5 and runtime.hit_count == 5, "five cuts settle once per enemy per cut")
	check(runtime.cut_angles == [0.0,3.0,-3.0,6.0,-6.0] and runtime.cut_centers.all(func(p): return p.is_equal_approx(Vector2(150,0))), "cuts rotate around shared geometric center")
	check(not get_tree().get_nodes_in_group("ice_fields").is_empty(), "actual saber contacts trigger ice")
	await reset()
	wall(Vector2(150,0))
	var blocked := enemy(Vector2(210,0))
	await frames()
	loadout.cast_weapon(saber, Vector2(300,0))
	freeze()
	await step(44)
	check(player.global_position.x < 140 and blocked.current_hp == 10000, "terrain clamps blink and hit path")
	await reset()
	loadout.cast_weapon(saber, Vector2(300,0))
	freeze()
	await step(10)
	wall(Vector2(110,0))
	await frames()
	await step(34)
	check(player.global_position.x < 100, "new obstacle during windup is rechecked")

func _test_cleanup() -> void:
	loadout.cast_weapon(saber, Vector2(300,0))
	freeze()
	await step(6)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var runtime := saber.mobility_runtime.get_ref() as SaberRuntime
	var saved: float = runtime.age
	await step(30)
	check(runtime.age == saved and player.global_position == Vector2.ZERO, "pause freezes sequence and animation")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	loadout._clear_weapon_runtime(saber)
	await frames()
	check(not player.is_mobility_moving() and saber.mobility_runtime == null, "removal cancels jump and releases motion lock")
	damage()
	player.alive = false
	await step(1)
	check(get_tree().get_nodes_in_group("furnace_runtimes").is_empty(), "death releases furnace visuals")
