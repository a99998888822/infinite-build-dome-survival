extends Node
# Headless/transient runs must pass -- --show-combat-guide to exercise the
# first-visit guide; CombatSettings deliberately suppresses it otherwise.
var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var menu: MainMenuUIController
var flow: MainFlowCoordinator

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	menu = game.get_node("UiRoot/MainMenuUIController")
	flow = game.get_main_flow_coordinator()
	menu._on_start_battle_pressed()
	await frames()
	var loading := menu.dungeon_loading
	var began := Time.get_ticks_usec()
	menu._on_character_confirm_pressed()
	check(Time.get_ticks_usec() - began < 100000, "confirm returns before expensive scene creation")
	check(loading.active and loading.visible and loading.curtain.modulate.a == 1.0, "black loading screen appears immediately")
	check(flow.get_bound_player() == null, "battle creation waits for loading frame")
	var ticket := loading._ticket
	menu._on_character_confirm_pressed()
	check(loading._ticket == ticket, "double click cannot start a second run")
	check(L10n.text(loading.caption.text) == "正在进入地下城", "loading caption is localized")
	await capture("loading_black")
	if not capture_dir.is_empty():
		await frames(8)
		await capture("loading_dots")
	var count := 0
	var frozen := true
	while loading.active and count < 1200:
		frozen = frozen and bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
		var player := flow.get_bound_player()
		if player != null:
			frozen = frozen and player.global_position == Vector2.ZERO
			if flow._bound_wave_manager.running:
				frozen = frozen and is_equal_approx(flow._bound_wave_manager.wave_time_left, float(flow.current_wave_duration_seconds))
		await frames(1)
		count += 1
	check(not loading.active, "loading completes within frame budget")
	check(frozen, "player and wave clock remain frozen throughout preparation and fade")
	check(not loading.visible and not bool(GameGlobal.get_runtime_flag("battle_loading", true)), "loading barrier releases on success")
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", true)), "combat starts and resumes after reveal")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	var backdrop := battle.loadout._get_visual_root().get_node("Backdrop") as CavernBattleBackdrop
	check(backdrop.is_initial_stream_ready(), "all initial scenery cells are present before reveal")
	var cached := true
	for layout: Dictionary in battle.player.get_combat_frame_layouts():
		cached = cached and backdrop.foot_bounds_cache.get(layout.texture, {}).has(layout.grid)
	check(cached, "all action alpha bounds are cached before first movement and attack")
	check(battle.loadout._get_visual_root().get_node_or_null("EntryRenderWarmup") == null, "render samples leave no live effects behind")
	check(battle.loadout._projectile_sequence == 0 and battle.loadout.weapon_instances[0].volley_index == 0, "warmup does not fire weapons or consume cooldowns")
	await capture("battle_revealed")
	flow.enter_start_page()
	await frames(8)
	menu._on_start_battle_pressed()
	menu._on_character_confirm_pressed()
	await frames(3)
	flow.enter_start_page()
	await frames(8)
	check(not loading.active and not loading.visible and not bool(GameGlobal.get_runtime_flag("battle_loading", true)), "reset cancels an in-progress load and clears the barrier")
	check((game.get_node("SceneDirector") as GameSceneDirector).battle_root == null, "cancelled load cannot attach a stale battle later")
	loading.begin(flow, "invalid_character", [], "1")
	await loading.finished
	await frames(4)
	check(flow.current_mode == MainFlowCoordinator.MODE_BOOT and not loading.active and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", true)), "failed initialization returns to menu without a stuck pause")
	CombatSettings.combat_guide_seen = false
	menu._on_start_battle_pressed()
	menu._on_character_confirm_pressed()
	await loading.finished
	check(flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE and bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)), "first-time guide remains paused after the fade")
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.combat_guide.skip_button.pressed.emit()
	await frames()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", true)), "guide dismissal starts the wave normally")
	flow.enter_start_page()
	await frames(8)
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("BATTLE_LOADING checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
