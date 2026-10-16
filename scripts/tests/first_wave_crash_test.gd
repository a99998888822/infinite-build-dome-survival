extends Node
## Drive the real menu and battle, including rendering, streaming and rewards.
## Run GPU checks with scripts/tools/run_godot_background.py.

var failures := 0
var repeats := 1
var wave_count := 1
var rng_seed := 202
var character := "character_void_hunter"
var difficulty := "1"
var attacks := true
var invulnerable := false
var probe := ""
var captures := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var player: PlayerController
var backdrop: CavernPopulationBackdrop
var stats: Dictionary
var spawned_ids: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--repeats="): repeats = int(arg.trim_prefix("--repeats="))
		if arg.begins_with("--waves="): wave_count = int(arg.trim_prefix("--waves="))
		if arg.begins_with("--seed="): rng_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--character="): character = arg.trim_prefix("--character=")
		if arg.begins_with("--difficulty="): difficulty = arg.trim_prefix("--difficulty=")
		if arg.begins_with("--probe="): probe = arg.trim_prefix("--probe=")
		if arg.begins_with("--capture-dir="): captures = arg.trim_prefix("--capture-dir=")
		if arg == "--no-attacks": attacks = false
		if arg == "--invulnerable": invulnerable = true
	_run.call_deferred()


func frames(count := 4) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FIRST_WAVE_CHECK " + message)


func mark(stage: String) -> void:
	var row := stats.duplicate()
	row.stage = stage
	row.ticks_ms = Time.get_ticks_msec()
	row.frame = Engine.get_process_frames()
	row.memory_mb = snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)
	if is_instance_valid(manager):
		row.wave = manager.current_wave_index + 1
		row.remaining = snappedf(manager.wave_time_left, 0.01)
		row.living = manager.get_living_enemy_count()
	if is_instance_valid(player):
		row.position = str(player.global_position)
		row.hp = player.current_hp
	if is_instance_valid(backdrop):
		row.cells = backdrop.cells.size()
		row.grass_draw_max = 0
		row.grass_band_max = 0
		for group: Dictionary in backdrop.grass_cells.values():
			for band: Dictionary in group.bands:
				row.grass_band_max = maxi(row.grass_band_max,band.blades.size())
				row.grass_draw_max = maxi(row.grass_draw_max,band.back.multimesh.instance_count)
	print("FIRST_WAVE_TRACE ", JSON.stringify(row))


func _run() -> void:
	CampProgression.begin_transient_session()
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(attacks)
	# This regression does not consume or persist the player's onboarding state.
	CombatSettings.combat_guide_seen = true
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	for index in repeats:
		await _play(index)
		if failures: break
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("FIRST_WAVE_COMPLETE failures=%d repeats=%d waves=%d character=%s attacks=%s invulnerable=%s probe=%s renderer=%s" % [failures, repeats, wave_count, character, attacks, invulnerable, probe, DisplayServer.get_name()])
	get_tree().quit(1 if failures else 0)


func _play(index: int) -> void:
	stats = {"run": index, "seed": rng_seed + index, "spawned": 0, "killed": 0, "rewards": 0, "finished": 0}
	spawned_ids.clear()
	seed(rng_seed + index)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	flow = game.get_main_flow_coordinator()
	var menu := game.find_child("MainMenuUIController", true, false) as MainMenuUIController
	check(menu.start_page.visible, "production main menu is visible")
	mark("main_menu")
	menu.start_battle_button.pressed.emit()
	await frames(8)
	check(menu.character_select_page.visible, "production character selection is visible")
	menu._on_character_selected(character)
	menu._on_difficulty_selected(difficulty)
	mark("character_select")
	menu.character_confirm_button.pressed.emit()
	backdrop = get_tree().get_first_node_in_group("battle_cavern") as CavernPopulationBackdrop
	if backdrop != null: backdrop.population_seed = rng_seed + index
	manager = flow._bound_wave_manager
	player = flow.get_bound_player()
	check(manager != null and player != null, "confirmation creates battle context")
	if manager == null or player == null: return
	# Optional renderer stress only; ordinary regression keeps real damage.
	if invulnerable: player._invincibility_timer = 3600.0
	manager._elite_quota_rng.seed = rng_seed + index
	manager.enemy_root.child_entered_tree.connect(_on_spawn)
	manager.wave_finished.connect(func(_wave): stats.finished += 1; mark("wave_finished"))
	flow.state_changed.connect(func(_previous, current): mark("state:" + current))
	await frames(4)
	check(manager.running, "first wave starts through the confirm button")
	mark("combat_started")
	_apply_probe()
	var elapsed := 0.0
	var movement_clock := 0.0
	var next_mark := 5.0
	var popup_clock := 0.0
	var wall_start := Time.get_ticks_msec()
	while stats.finished < wave_count and player.is_alive() and Time.get_ticks_msec() - wall_start < 150000:
		var delta := get_process_delta_time()
		if flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT:
			elapsed += delta
			movement_clock -= delta
			if movement_clock <= 0:
				movement_clock = 0.25
				player.set_mobile_move_direction(_movement(elapsed))
			if elapsed >= next_mark:
				mark("combat")
				if next_mark == 10.0: await _capture("combat_%d" % index)
				next_mark += 5.0
		else:
			popup_clock += delta
			if popup_clock >= 0.4:
				popup_clock = 0.0
				_advance_popup()
		_apply_probe()
		await get_tree().process_frame
	check(stats.finished >= wave_count, "requested waves complete without death or timeout")
	check(stats.spawned > 0, "real wave spawns enemies")
	if attacks:
		check(stats.killed > 0, "real weapons kill enemies")
		check(stats.rewards > 0, "real pickups open and resolve rewards")
	mark("run_complete")
	flow.enter_start_page()
	await frames(8)
	check(menu.start_page.visible, "returning to the main menu completes")
	game.queue_free()
	await frames(12)
	manager = null
	player = null
	backdrop = null


func _on_spawn(node: Node) -> void:
	# Reparenting the world on menu return re-enters existing children too.
	if node is EnemyController and not spawned_ids.has(node.get_instance_id()):
		spawned_ids[node.get_instance_id()] = true
		stats.spawned += 1
		node.died.connect(func(_enemy, _table, _position): stats.killed += 1)


func _movement(elapsed: float) -> Vector2:
	# A broad orbit avoids repeatedly walking into the same pack as it grows.
	var target := Vector2.RIGHT.rotated(elapsed * 0.2) * 420.0
	var direction := (target - player.global_position).normalized()
	var avoidance := Vector2.ZERO
	for enemy in EnemyRegistry.get_registered_enemies():
		if not enemy.is_alive(): continue
		var away: Vector2 = player.global_position - enemy.global_position
		var distance := away.length()
		if distance < 180.0 and distance > 0:
			avoidance += away.normalized() * (1.0 - distance / 180.0)
	return (direction + avoidance * 3.0).normalized()


func _advance_popup() -> void:
	match flow.current_state:
		MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
			var offers := flow._active_shop_offers.values()
			offers.sort_custom(func(a, b): return _priority(a) > _priority(b))
			for offer in offers:
				if flow.submit_shop_purchase(offer, "free").get("success", false):
					stats.rewards += 1
					break
		MainFlowCoordinator.STATE_FINANCE_POPUP: flow.close_finance_popup()
		MainFlowCoordinator.STATE_WAVE_CHALLENGE: flow.decide_wave_challenge(str(manager.wave_challenges.offer.token), false)
		MainFlowCoordinator.STATE_SHOP_POPUP: flow.close_shop_popup()
		MainFlowCoordinator.STATE_INTEREST_SETTLEMENT: flow.close_interest_settlement()


func _priority(offer: Dictionary) -> int:
	if offer.get("offer_type") == "weapon_upgrade": return 3
	if offer.get("offer_type") == "new_weapon": return 2
	return 1


func _apply_probe() -> void:
	if probe.is_empty() or not is_instance_valid(backdrop): return
	match probe:
		"no-backdrop":
			backdrop.detach_player()
			backdrop.hide()
		"no-update": backdrop.set_process(false)
		"no-ysort": backdrop.roots.y_sort_enabled = false
		"no-grass":
			for group: Dictionary in backdrop.grass_cells.values():
				for band: Dictionary in group.bands:
					band.back.hide()
					band.front.hide()


func _capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(captures.path_join(label + ".png"))
