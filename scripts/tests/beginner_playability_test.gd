extends Node
## Real GameRoot simulation: normal mobile movement, combat, pickups and free rewards.
## No player buffs, invulnerability, forced kills or altered combat clock.
var failures := 0
var capture_dir := ""
var stationary := false
var wave_count := 1
var results: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func frames(count: int = 4) -> void:
	for n in count: await get_tree().process_frame

func _run() -> void:
	CampProgression.begin_transient_session()
	var difficulties: Array[String] = BattleDifficulty.IDS.duplicate()
	var seeds: Array[int] = [101, 202, 303]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--difficulty="): difficulties = [BattleDifficulty.normalize(arg.trim_prefix("--difficulty="))]
		if arg.begins_with("--seed="): seeds = [int(arg.trim_prefix("--seed="))]
		if arg.begins_with("--waves="): wave_count = int(arg.trim_prefix("--waves="))
		if arg == "--stationary": stationary = true
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for id in difficulties:
		for rng_seed in seeds:
			await _play(id, rng_seed)
	var beginner := results.filter(func(r): return r.difficulty == "1")
	if results.size() != difficulties.size() * seeds.size(): failures += 1
	if not stationary and not beginner.is_empty():
		var survived := beginner.filter(func(r): return r.completed_waves == wave_count).size()
		if survived < ceili(beginner.size() * 0.66): failures += 1
	print("PLAYABILITY_COMPLETE failures=", failures, " results=", JSON.stringify(results))
	get_tree().quit(1 if failures else 0)

func _play(id: String, rng_seed: int) -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	var menu := game.find_child("MainMenuUIController", true, false) as MainMenuUIController
	menu._on_start_battle_pressed()
	await frames(8)
	menu._on_difficulty_selected(id)
	if not capture_dir.is_empty():
		await get_tree().create_timer(0.6).timeout
		for tier in BattleDifficulty.IDS:
			menu._on_difficulty_selected(tier)
			await frames(3)
			await capture("difficulty_selection" if tier == "1" else "difficulty_" + tier)
		menu._on_difficulty_selected(id)
		await frames(3)
	seed(rng_seed)
	menu.character_confirm_button.pressed.emit()
	await frames(4)
	var manager := flow._bound_wave_manager
	var player := flow.get_bound_player()
	manager._elite_quota_rng.seed = rng_seed
	var loadout := flow.get_bound_loadout()
	if player.current_hp != 5 or manager.player_level != 1 or not CampProgression.get_outgame_modifiers().is_empty():
		failures += 1
		push_error("Playtest must begin with five HP, level one and no talents")
	var stats := {"spawned": 0, "killed": 0, "damage_taken": 0, "free_choices": 0, "paid_choices": 0, "completed_waves": 0}
	manager.enemy_root.child_entered_tree.connect(func(node):
		if node is EnemyController:
			stats.spawned += 1
			node.died.connect(func(_enemy, _table, _pos): stats.killed += 1))
	manager.wave_finished.connect(func(_wave): stats.completed_waves += 1)
	var elapsed := 0.0
	var reaction_clock := 0.0
	var previous_hp := player.current_hp
	var captured := false
	var timed_out := true
	for frame in 18000:
		if player.current_hp < previous_hp: stats.damage_taken += previous_hp - player.current_hp
		previous_hp = player.current_hp
		if not player.is_alive() or stats.completed_waves >= wave_count:
			timed_out = false
			break
		var state := flow.current_state
		if state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
			# Prefer an offered upgrade or weapon, then the first valid reward.
			var offers := flow._active_shop_offers.values()
			offers.sort_custom(func(a, b): return reward_priority(a) > reward_priority(b))
			for offer in offers:
				if flow.submit_shop_purchase(offer, "free").get("success", false):
					stats.free_choices += 1
					break
		elif state == MainFlowCoordinator.STATE_FINANCE_POPUP:
			# Spend only earned gold on offered weapons/upgrades, as a normal run would.
			var bought := false
			for offer in flow._active_shop_offers.values():
				if reward_priority(offer) < 2: continue
				if flow.submit_shop_purchase(offer, "shop").get("success", false):
					stats.paid_choices += 1
					bought = true
					break
			if not bought: flow.close_finance_popup()
		elif state == MainFlowCoordinator.STATE_SHOP_POPUP:
			flow.close_shop_popup()
		elif state == MainFlowCoordinator.STATE_INTEREST_SETTLEMENT:
			flow.close_interest_settlement()
		elif state == MainFlowCoordinator.STATE_WAVE_COMBAT:
			var delta := get_process_delta_time()
			elapsed += delta
			reaction_clock -= delta
			if reaction_clock <= 0.0:
				reaction_clock = 0.25
				player.set_mobile_move_direction(Vector2.ZERO if stationary else movement(player, elapsed))
			if not captured and manager.wave_time_left < 10.0 and not capture_dir.is_empty():
				captured = true
				await capture("beginner_combat")
		await get_tree().process_frame
	if timed_out: failures += 1
	var result := {"difficulty": id, "seed": rng_seed, "stationary": stationary, "completed_waves": stats.completed_waves,
		"alive": player.is_alive(), "hp": player.current_hp, "max_hp": player.get_stat("max_hp"), "level": manager.player_level,
		"spawned": stats.spawned, "killed": stats.killed, "damage_taken": stats.damage_taken,
		"free_choices": stats.free_choices, "paid_choices": stats.paid_choices, "weapons": loadout.get_weapon_instances().size(), "combat_seconds": snappedf(elapsed, 0.01)}
	results.append(result)
	print("PLAYABILITY_RUN ", JSON.stringify(result))
	flow.enter_start_page()
	await frames(8)
	game.queue_free()
	await frames(12)

func reward_priority(offer: Dictionary) -> int:
	if offer.get("offer_type") == "weapon_upgrade": return 3
	if offer.get("offer_type") == "new_weapon": return 2
	return 1

func movement(player: PlayerController, elapsed: float) -> Vector2:
	# A broad circle plus a simple local escape; no spawn foresight or stat access.
	var target := Vector2.RIGHT.rotated(elapsed * 0.55) * 260.0
	var direction := (target - player.global_position).normalized()
	var avoidance := Vector2.ZERO
	for enemy in EnemyRegistry.get_registered_enemies():
		if not enemy.is_alive(): continue
		var away: Vector2 = player.global_position - enemy.global_position
		var distance := away.length()
		if distance < 120.0 and distance > 0.0:
			avoidance += away.normalized() * (1.0 - distance / 120.0)
	return (direction + avoidance * 3.0).normalized()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))
