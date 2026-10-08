extends Node
## Real GameRoot + production casts, deterministically stepped for collision/timing QA.
const IDS := ["weapon_dash_blade", "weapon_hand_cannon", "weapon_star_tome"]
var checks := 0
var failures := 0
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var capture_dir := ""
var origin := Vector2.ZERO
var walls: Array[Node] = []
var timings: Array[float] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(150).timeout
	push_error("MOBILITY_TEST_TIMEOUT")
	get_tree().quit(99)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int = 3) -> void:
	for i in count: await get_tree().process_frame
	await get_tree().create_timer(0.03).timeout

func freeze_effects() -> void:
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		node.set_physics_process(false)

func step(delta: float, count: int = 1) -> void:
	for i in count:
		var started := Time.get_ticks_usec()
		player._physics_process(delta)
		for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"):
			if is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.has_method("_physics_process"):
				effect._physics_process(delta)
		freeze_effects()
		loadout.active_casting.tick(delta)
		timings.append((Time.get_ticks_usec() - started) / 1000.0)
		await get_tree().process_frame

func reset() -> void:
	for weapon in loadout.weapon_instances: loadout._clear_weapon_runtime(weapon)
	await frames()
	loadout.active_casting.states.clear()
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for wall in walls:
		if is_instance_valid(wall): wall.free()
	walls.clear()
	player.alive = true
	player.global_position = origin
	player._clear_move_input()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()

func enemy(offset: Vector2) -> EnemyController:
	var body := battle.wave_manager.spawn_enemy("enemy_mutated_grub", origin + offset)
	body.set_physics_process(false)
	body.current_hp = 10000
	return body

func wall(offset: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12,240)
	shape.shape = rectangle
	body.add_child(shape)
	player.get_parent().add_child(body)
	body.global_position = origin + offset
	walls.append(body)
	return body

func cast(index: int, offset: Vector2) -> MobilityWeaponRuntime:
	var weapon := loadout.get_weapon_instance(IDS[index])
	check(loadout.cast_weapon(weapon, origin + offset), "cast " + IDS[index])
	freeze_effects()
	return weapon.mobility_runtime.get_ref() as MobilityWeaponRuntime

func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "GPU " + label)

func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_dash_blade"])
	await frames()
	check(flow.confirm_character_selection(), "production battle starts with mobility weapon")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	player = battle.player
	player.set_physics_process(false)
	loadout = battle.loadout
	player.modifier_stack.set_base_stat("load_capacity", 1000)
	loadout.equip_weapon(IDS[1])
	loadout.equip_weapon(IDS[2])
	origin = player.global_position
	await reset()
	var blade := loadout.get_weapon_instance(IDS[0])
	var cannon := loadout.get_weapon_instance(IDS[1])
	var tome := loadout.get_weapon_instance(IDS[2])
	check(loadout.weapon_instances.size() == 3, "all three config records equip")
	for weapon in loadout.weapon_instances:
		var card := PreparationOfferCard.new()
		add_child(card)
		card.configure({"offer_type":"new_weapon", "target_id":weapon.weapon_id, "display_name":weapon.weapon_data.display_name, "icon":weapon.weapon_data.icon}, "", 1000)
		check(card._description.text == weapon.weapon_data.shop_description, "finance card uses actual short copy " + weapon.weapon_id)
		card.queue_free()
	var base_axes := blade.get_mobility_axes()
	var base_radius := blade.get_hit_radius()
	blade.runtime_stats.area_size = 100
	check(blade.get_mobility_axes().is_equal_approx(base_axes * 1.5) and is_equal_approx(blade.get_hit_radius(), base_radius), "attack distance changes only dash ellipse")
	blade.runtime_stats.area_size = 0
	blade.runtime_stats.damage_area_size = 100
	check(blade.get_mobility_axes().is_equal_approx(base_axes) and is_equal_approx(blade.get_hit_radius(), base_radius * 1.5), "damage area changes only slash radius")
	blade.runtime_stats.damage_area_size = 0
	tome.runtime_stats.area_size = 100
	check(is_equal_approx(tome.get_mobility_axes().x,315) and is_equal_approx(tome.get_hit_radius(),64), "blink range uses attack distance only")
	tome.runtime_stats.area_size = 0
	cannon.runtime_stats.area_size = 100
	cannon.runtime_stats.damage_area_size = 100
	check(is_equal_approx(cannon.get_mobility_landing(Vector2(50,90)).length(),96) and is_equal_approx(cannon.get_attack_range(),225), "cannon retreat fixed while range scales")
	cannon.runtime_stats.area_size = 0
	cannon.runtime_stats.damage_area_size = 0
	check(blade.get_mobility_landing(Vector2(0,1000)).is_equal_approx(Vector2(0,140 * AttackFootprint.ELLIPSE_RATIO)), "vertical dash respects ellipse")
	var path_enemy := enemy(Vector2(45,0))
	var hit_enemy := enemy(Vector2(160,25))
	var outside := enemy(Vector2(210,0))
	await frames()
	battle.active_controller.select_slot(0)
	battle.active_controller.indicator.configure(blade, Vector2(140,0))
	battle.active_controller.indicator.show()
	await capture("dash_indicator")
	battle.active_controller.cancel_aim()
	var dash := cast(0, Vector2(140,0))
	check(not loadout.cast_weapon(cannon, origin + Vector2.RIGHT * 100), "overlapping displacements rejected")
	var speeds: Array[float] = []
	for i in 20:
		var previous := player.global_position
		await step(0.011)
		speeds.append(previous.distance_to(player.global_position) / 0.011)
		if i == 8: check(hit_enemy.current_hp == 10000 and path_enemy.current_hp == 10000, "dash trail has no damage")
	var descending := true
	for i in range(1,speeds.size()): descending = descending and speeds[i] <= speeds[i-1] + 0.1
	check(descending and player.global_position.distance_to(origin + Vector2(140,0)) < 0.01, "dash decelerates to exact destination")
	await step(0.001)
	check(hit_enemy.current_hp < 10000 and path_enemy.current_hp == 10000 and outside.current_hp == 10000, "only arrival circle damages")
	check(dash.hit_count == 1, "native slash hits once")
	await step(0.035)
	await capture("dash_slash")
	await step(0.05,5)
	check(not loadout.active_casting.state_for(blade).executing and loadout.active_casting.state_for(blade).remaining > 0, "slash ends near 0.21s then cooldown begins")
	await reset()
	wall(Vector2(85,0))
	await frames()
	cast(0,Vector2(140,0))
	await step(0.011,21)
	check(player.global_position.x < origin.x + 70 and player.global_position.x > origin.x, "dash capsule stops before terrain")
	await reset()
	var target := enemy(Vector2(52,0))
	var shape := target.get_node("CollisionShape2D") as CollisionShape2D
	var broad := CircleShape2D.new()
	broad.radius = 36
	shape.shape = broad
	await frames()
	var gun := cast(1,Vector2(150,0))
	var projectiles := gun.get_children().filter(func(node): return node is CannonPellet)
	check(projectiles.size() == 5, "five actual PNG shotgun projectiles")
	await step(0.028,2)
	await capture("cannon_fire")
	var last_speed := INF
	var slowing := true
	for i in 8:
		var previous := player.global_position
		await step(0.028)
		var speed := previous.distance_to(player.global_position) / 0.028
		slowing = slowing and speed <= last_speed + 0.01
		last_speed = speed
	check(slowing, "cannon decelerates continuously")
	check(player.global_position.distance_to(origin - Vector2(96,0)) < 0.01, "cannon stops at fixed 96 retreat")
	check(target.current_hp <= 10000 - 5 * 12, "close target receives stacking native pellets")
	await reset()
	var shock_enemy := enemy(Vector2(180,25))
	await frames()
	var star := cast(2,Vector2(170,0))
	var star_state := loadout.active_casting.state_for(tome)
	var bar: ActiveCombatWeaponBar = battle.hud.combat_bar
	check(is_equal_approx(star_state.remaining, tome.get_active_cooldown_seconds()) and tome.is_return_ready(), "first blink immediately starts cooldown and permits return")
	battle.hud._refresh_active_combat()
	check(bar.timers[2].text == "%d s" % ceili(star_state.remaining) and not bar.cooldown_masks[2].visible and bar.icons[2].texture.resource_path.ends_with("star_tome_return.png"), "initial return icon has countdown without grey mask")
	check(player.global_position.is_equal_approx(origin + Vector2(170,0)) and shock_enemy.current_hp < 10000, "blink teleports and damages destination")
	check(shock_enemy._knockback_velocity.dot(shock_enemy.global_position - player.global_position) > 0, "shock knocks outward")
	await step(0.05)
	await capture("star_arrival")
	await step(0.05,8)
	check(tome.is_return_ready() and loadout.active_casting.can_cast(tome), "same skill becomes available to return")
	battle.hud._refresh_active_combat()
	check(bar.timers[2].text == "%d s" % ceili(star_state.remaining) and not bar.cooldown_masks[2].visible and bar.icons[2].texture.resource_path.ends_with("star_tome_return.png"), "return countdown and PNG badge stay synchronized")
	await capture("star_return_ready")
	var before_return := float(star_state.remaining)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await step(1)
	check(is_equal_approx(star_state.remaining, before_return) and tome.is_return_ready() and not loadout.cast_weapon(tome, origin), "pause freezes return window and blocks input")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var before_hp := shock_enemy.current_hp
	battle.active_controller.select_slot(2)
	freeze_effects()
	check(player.global_position.is_equal_approx(origin) and not tome.is_return_ready() and shock_enemy.current_hp == before_hp, "same slot returns with no additional damage")
	battle.hud._refresh_active_combat()
	check(is_equal_approx(star_state.remaining, before_return) and bar.icons[2].texture.resource_path.ends_with("weapon_star_tome.png") and bar.cooldown_masks[2].visible and bar.timers[2].text == "%d s" % ceili(before_return), "early return restores base icon and grey mask without resetting countdown")
	check(is_equal_approx(bar.cooldown_masks[2].material.get_shader_parameter("remaining"), before_return / float(star_state.total)), "early-return mask shows remaining fraction instead of full execution disk")
	check(not loadout.cast_weapon(tome, origin + Vector2(80,0)) and tome.volley_index == 1, "return is single-use and cannot bypass remaining cooldown")
	await step(0.05)
	await capture("star_return")
	await step(0.05,7)
	check(not star_state.executing and is_equal_approx(star_state.remaining, before_return - 0.4), "return animation finishes without starting another cooldown")
	await step(float(star_state.remaining))
	battle.hud._refresh_active_combat()
	check(loadout.active_casting.can_cast(tome) and bar.timers[2].text.is_empty() and not bar.cooldown_masks[2].visible, "remaining cooldown completes normally after early return")
	await reset()
	star = cast(2,Vector2(170,0))
	star_state = loadout.active_casting.state_for(tome)
	await step(float(star_state.remaining) - 0.01)
	check(tome.is_return_ready() and is_instance_valid(star.anchor) and not star.anchor.cancelled, "return available until cooldown deadline")
	var expiry_position := player.global_position
	await step(0.02)
	battle.hud._refresh_active_combat()
	check(not tome.is_return_ready() and (not is_instance_valid(star.anchor) or star.anchor.cancelled) and player.global_position == expiry_position, "expiry removes mark without automatic return")
	check(loadout.active_casting.can_cast(tome) and bar.icons[2].texture.resource_path.ends_with("weapon_star_tome.png") and bar.timers[2].text.is_empty() and not bar.cooldown_masks[2].visible, "expiry restores ready base icon with neither timer nor mask")
	await capture("star_return_expired")
	var next_star := cast(2,Vector2(70,0))
	await step(0.01)
	check(tome.is_return_ready() and tome.mobility_runtime.get_ref() == next_star and next_star.anchor_position == expiry_position, "next cast owns a fresh anchor after expiry")
	await reset()
	var original_cooldown := tome.active_cooldown_ms
	tome.active_cooldown_ms = 150
	cast(2,Vector2(170,0))
	await step(0.2)
	await step(0.3)
	check(not tome.is_return_ready() and loadout.active_casting.can_cast(tome), "short cooldown cannot rearm expired return when arrival animation ends")
	tome.active_cooldown_ms = original_cooldown
	await reset()
	star = cast(2,Vector2(170,0))
	await step(0.05,9)
	wall(Vector2(85,0))
	await frames()
	var blocked_remaining := float(loadout.active_casting.state_for(tome).remaining)
	check(not loadout.cast_weapon(tome, origin) and tome.is_return_ready() and is_equal_approx(loadout.active_casting.state_for(tome).remaining, blocked_remaining), "blocked return retains anchor without resetting countdown")
	await reset()
	dash = cast(0,Vector2(140,0))
	await step(0.02)
	var paused_at := player.global_position
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await step(1)
	check(player.global_position == paused_at and is_equal_approx(dash.age,0.02), "pause freezes movement and effects")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	loadout._clear_weapon_runtime(blade)
	check(not player.is_mobility_moving() and dash.cancelled, "unequip cleanup releases movement lock")
	await reset()
	star = cast(2,Vector2(170,0))
	await step(0.05,9)
	player.alive = false
	await step(0.02)
	check(not tome.is_return_ready() and not player.is_mobility_moving(), "death clears return state")
	await reset()
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(true)
	enemy(Vector2(50,0))
	var before_position := player.global_position
	loadout.active_casting.auto_attack()
	check(player.global_position == before_position and not player.is_mobility_moving(), "automatic mode never drives displacement")
	battle.active_controller.select_slot(0)
	check(battle.active_controller.selected_weapon == blade, "manual mobility remains accessible in automatic mode")
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	await reset()
	var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "mobility_test")
	var split := player.item_inventory.add_item_from_base("scroll_split", "mobility_test")
	check(not blade.get_attachment_incompatibility(pierce).is_empty() and not tome.get_attachment_incompatibility(split).is_empty(), "ineffective attachments rejected explicitly")
	check(cannon.get_attachment_incompatibility(pierce).is_empty() and cannon.get_attachment_incompatibility(split).is_empty(), "cannon accepts pierce and split")
	check(cannon.attach_item_instance(pierce) and cannon.attach_item_instance(split), "cannon equips both attachments")
	var near_target := enemy(Vector2(50,0))
	var far_target := enemy(Vector2(110,0))
	await frames()
	gun = cast(1,Vector2(150,0))
	await step(0.025,12)
	check(near_target.current_hp < 10000 and far_target.current_hp < 10000, "cannon pierce/split reaches additional targets")
	check(int(gun.weapon.attack_context.get("cannon_split_batches",0)) > 0 and int(gun.weapon.attack_context.get("cannon_split_batches",0)) <= 3, "split uses a bounded per-cast budget")
	await reset()
	var bounce := player.item_inventory.add_item_from_base("scroll_bounce", "mobility_test")
	check(blade.attach_item_instance(bounce), "bounce attaches")
	enemy(Vector2(140,0))
	await frames()
	cast(0,Vector2(140,0))
	await step(0.022,11)
	check(player.global_position.distance_to(origin + Vector2(140,0)) < 0.01 and get_tree().get_nodes_in_group("bounce_attacks").size() == 1, "bounce repeats damage without repeating movement")
	await reset()
	# Stress the real cannon broad phase with many irrelevant registered enemies.
	for i in 160: enemy(Vector2(350 + (i % 16) * 30, -210 + (i / 16) * 40))
	await frames()
	var stress_begin := timings.size()
	for repetition in 5:
		loadout.active_casting.states.clear()
		cast(1,Vector2(150,0))
		await step(0.02,36)
	var stress := timings.slice(stress_begin)
	stress.sort()
	check(get_tree().get_nodes_in_group("mobility_weapon_runtimes").is_empty(), "repeated casts release runtime/effect nodes")
	print("MOBILITY_STRESS_CPU_MS p50=%.3f p95=%.3f max=%.3f enemies=160 steps=%d" % [stress[stress.size()/2],stress[int(stress.size()*0.95)],stress[-1],stress.size()])
	await reset()
	# Actual tooltip strings are exported for review, with default base weapon stats.
	if not capture_dir.is_empty():
		var report: Array[Dictionary] = []
		for id in IDS:
			var source := WeaponInstance.new()
			source.initialize(id,player)
			source.use_active_range_rules = true
			report.append({"id": id, "name": source.weapon_data.display_name, "detail": source.build_full_stats_text(), "short": source.weapon_data.shop_description})
		var file := FileAccess.open(capture_dir.path_join("descriptions.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	var total := 0.0
	for timing in timings: total += timing
	print("MOBILITY_STEP_CPU_MS average=%.3f max=%.3f samples=%d (includes native collision + damage + rendering state; not GPU frame time)" % [total / timings.size(), timings.max(), timings.size()])
	flow.enter_start_page()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("MOBILITY_INTEGRATION checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
