extends "res://scripts/tests/seven_weapon_performance.gd"
## Real map and HUD. Wave twelve, real HP/deaths/rewards and normal spawn cap.
var simulated := 0.0
var measuring := false

func _physics_process(delta: float) -> void:
	if measuring: simulated += delta

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" and not "--background-capture" in args:
		get_tree().quit(2)
		return
	output = "res://artifacts/reports/screenshot_loadout/result.json"
	var seconds := 30.0
	for arg in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seed="): random_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	for i in 12: await get_tree().process_frame
	var menu := game.find_child("MainMenuUIController", true, false) as MainMenuUIController
	menu._on_start_battle_pressed()
	for i in 4: await get_tree().process_frame
	for button in menu.difficulty_list.get_children():
		if button is Button and str(button.get_meta("difficulty_id", "")) == "3": button.pressed.emit()
	menu.character_confirm_button.pressed.emit()
	await menu.dungeon_loading.finished
	var flow := game.get_main_flow_coordinator()
	var manager := flow._bound_wave_manager
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	manager.set_process(false)
	manager.clear_battle_entities()
	manager.running = false
	# Choice popups pause combat; preserve reward processing but disconnect dialogs.
	for pair in [[manager.shared_reward_shop_requested, "_on_shared_reward_shop_requested"], [manager.relic_choice_requested, "_on_relic_choice_requested"]]:
		var callback := Callable(flow, pair[1])
		if pair[0].is_connected(callback): pair[0].disconnect(callback)
	player.modifier_stack.set_base_stat("load_capacity", 1000)
	for existing in loadout.weapon_instances.duplicate():
		if existing.weapon_id != BOW: loadout.remove_weapon(existing.weapon_id)
	for id in [HAMMER, DAGGER, LAMP, PLASMA, SPEAR, COIN]: check(loadout.equip_weapon(id), "equip " + id)
	var targets := {"max_hp": 199.0, "hp_regen": 5.5, "armor": 2097.0, "shield_regen": 4.2,
		"move_speed": 271.0, "damage_percent": 183.0, "melee_damage": 79.0, "ranged_damage": 57.0,
		"element_damage": 64.0, "attack_speed": 39.0, "crit_chance": 100.0, "crit_damage": 590.0,
		"projectile_count": 7.0, "area_size": 227.0, "damage_area_size": 230.0, "control_power": 76.0,
		"divinity": 200.0, "enemy_spawn_rate_percent": 100.0}
	for stat in targets:
		player.modifier_stack.set_base_stat(stat, player.modifier_stack.get_base_stat(stat) + targets[stat] - player.get_stat(stat))
	var receipts: Array = []
	for w: WeaponInstance in loadout.weapon_instances:
		while w.level < 5: loadout.upgrade_weapon(w.weapon_id)
		while not w._attached_item_instances.is_empty(): w.detach_item_instance()
		var spell_set: Array = STRESS_SPELLS.get(w.weapon_id, ["scroll_split", "scroll_fire", "scroll_lightning"])
		for item_id in spell_set:
			var item := player.item_inventory.add_item_from_base(item_id, "screenshot_perf")
			check(loadout.attach_item_to_weapon(w.weapon_id, str(item.item_instance_id)), "attach " + w.weapon_id + " " + item_id)
		weapon = w
		for stat in ["damage_percent", "melee_damage", "ranged_damage", "element_damage", "attack_speed", "crit_chance", "crit_damage", "projectile_count", "area_size", "damage_area_size", "control_power"]:
			total(stat, targets[stat])
		CombatSettings.set_weapon_auto_cast(w.weapon_id, true, false)
		receipts.append({"id": w.weapon_id, "level": w.level, "projectiles": w.get_stat("projectile_count"), "spells": spell_set})
	player._invincibility_timer = 100000.0
	player.active_controls = false
	seed(random_seed)
	manager._elite_quota_rng.seed = random_seed
	manager.current_wave_index = 10
	check(manager.start_next_wave(), "wave twelve started")
	check(manager.get_enemy_erosion_snapshot().erosion == 200.0, "erosion 200 applied")
	check(player.get_stat("enemy_spawn_rate_percent") == 100.0, "spawn bonus 100 applied")
	var positions: Array[Vector2] = []
	for i in BattleDifficulty.ENEMY_LIMIT:
		manager.spawn_enemy(manager._select_spawn_variant("enemy_mutated_grub"), manager._get_batch_spawn_position(positions))
	manager.set_process(true)
	Engine.max_fps = 60
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var wall: Array[float] = []
	var draws: Array[float] = []
	var population: Array[float] = []
	var tiers := {}
	var seen := {}
	var started := Time.get_ticks_usec()
	var previous := started
	while float(Time.get_ticks_usec() - started) / 1000000.0 < seconds + 5.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if now - started >= 5000000:
			measuring = true
			wall.append(float(now - previous) / 1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			population.append(float(manager.get_living_enemy_count()))
			var key := str(PerformanceBudget.tier())
			tiers[key] = int(tiers.get(key, 0)) + 1
			for enemy in EnemyRegistry.get_registered_enemies(): seen[enemy.get_instance_id()] = true
		previous = now
	measuring = false
	var sorted := wall.duplicate()
	sorted.sort()
	var n := maxi(1, ceili(sorted.size() * 0.01))
	var slow := 0.0
	for i in n: slow += sorted[sorted.size() - 1 - i]
	var report := {"seed": random_seed, "mobile_profile": MobileProfile.is_mobile(), "actual_mobile_device": MobileProfile.is_device(),
		"gpu": RenderingServer.get_video_adapter_name(), "window": [get_window().size.x, get_window().size.y],
		"physics_hz": Engine.physics_ticks_per_second, "seconds": seconds, "warmup_seconds": 5,
		"simulation_seconds": simulated, "stationary_invulnerable_player": true, "reward_dialogs_disabled": true,
		"wave": 12, "difficulty": manager.difficulty_id, "enemy_cap": BattleDifficulty.ENEMY_LIMIT,
		"erosion": manager.get_enemy_erosion_snapshot(), "spawn_count_base9": manager.calculate_enemy_spawn_count(9),
		"targets": targets, "weapons": receipts, "fps": 1000.0 / _stats(wall).mean,
		"one_percent_low_fps": 1000.0 / (slow / n), "wall_ms": _stats(wall), "draw_calls": _stats(draws),
		"population": _stats(population), "unique_enemies_seen": seen.size(), "budget_frames": tiers,
		"pending_spawns": manager.pending_spawn_count(), "weapon_damage": manager.weapon_damage_this_wave.duplicate(true), "failures": failures}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	if DisplayServer.get_name() != "headless": get_viewport().get_texture().get_image().save_png(output.get_basename() + ".png")
	print("SCREENSHOT_PERF fps=", report.fps, " failures=", failures)
	CampProgression.end_transient_session()
	get_tree().quit(1 if failures else 0)
