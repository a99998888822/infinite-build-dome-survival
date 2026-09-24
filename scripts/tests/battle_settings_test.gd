extends Node

var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var battle: BattleRoot
var hud: BattleHud
var overlay: BattleUtilityOverlay
var manager: WaveManager

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(90).timeout
	push_error("BATTLE_SETTINGS_TEST_TIMEOUT")
	get_tree().quit(99)

func frames(count: int = 4) -> void:
	for index in count:
		await get_tree().process_frame

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", label)

func click(control: Control) -> void:
	var position := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)

func escape() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)

func round_trip(name: String, use_escape: bool = false) -> void:
	var source := flow.current_state
	var original_pause := bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	var reward_resume := flow._resume_state_after_modal
	var offers := flow._active_shop_offers.duplicate(true)
	var choice := flow._active_relic_choice
	var hp := flow.get_bound_player().current_hp
	var time_left := manager.wave_time_left
	await frames()
	check(not hud.settings_button.disabled, name + " wrench enabled")
	await click(hud.settings_button)
	check(flow.current_state == MainFlowCoordinator.STATE_BATTLE_UTILITY and overlay.visible and overlay._settings.visible, name + " real wrench click opens settings")
	check(flow.get_battle_display_state() == source and flow._resume_state_after_modal == reward_resume, name + " underlying state preserved")
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)), name + " pauses runtime")
	check(overlay._menu_button.visible and overlay._return_button.visible, name + " both return actions visible")
	manager._process(1.0)
	check(manager.wave_time_left == time_left, name + " wave clock frozen")
	await capture(name)
	if use_escape:
		await escape()
	else:
		await click(overlay._return_button)
	check(flow.current_state == source and not overlay.visible, name + " returns to source screen")
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) == original_pause, name + " restores previous pause state")
	check(flow._active_shop_offers == offers and flow._active_relic_choice == choice and flow.get_bound_player().current_hp == hp, name + " no reroll grant or healing")

func _run() -> void:
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start real battle")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	hud = battle.hud as BattleHud
	overlay = battle.utility_overlay
	manager = battle.wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	flow.get_bound_player().set_physics_process(false)
	flow.get_bound_player().add_relic("relic_finance_manager")
	manager.apply_gold_delta(500, "test")
	await round_trip("01_combat_settings", true)
	flow.request_esc_overlay()
	await frames(12)
	await round_trip("02_esc_settings")
	check(battle.esc_overlay.visible, "ESC inventory remains visible after settings")
	await escape()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "ESC still returns to combat")
	flow.request_shared_reward_shop_popup(2)
	await frames(15)
	await round_trip("03_upgrade_settings", true)
	check((game.find_child("ShopPopup", true, false) as ShopPopup).visible, "upgrade cards remain visible")
	flow.close_shared_reward_shop_popup()
	manager._on_relic_choice_collected("settings_test_choice")
	await frames(15)
	await round_trip("04_relic_settings")
	check(flow._active_relic_choice == "settings_test_choice", "relic choice identity survives settings")
	flow.close_shared_reward_shop_popup()
	flow.finish_current_wave()
	await frames(20)
	var finance := game.find_child("FinancePopup", true, false) as FinancePopup
	check(finance.visible and flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "finance page ready")
	finance.amount_input.text = "123"
	await round_trip("05_finance_settings", true)
	check(finance.visible and finance.amount_input.text == "123", "finance form survives settings")
	await click(hud.settings_button)
	var music: HSlider = overlay._volume_controls.bgm_volume.slider
	music.value = 37
	check(CampProgression.get_volume_setting("bgm_volume", 100) == 37, "settings reuse saved audio controls")
	await click(overlay._menu_button)
	await frames(12)
	check(flow.current_state == MainFlowCoordinator.STATE_START_PAGE and flow.current_mode == MainFlowCoordinator.MODE_BOOT, "main menu action resets flow")
	check((game.get_node("SceneDirector") as GameSceneDirector).battle_root == null and flow.get_bound_player() == null, "battle scene and context released")
	check(not finance.visible and not (game.find_child("ShopPopup", true, false) as ShopPopup).visible, "battle dialogs closed on main menu")
	check(flow._active_shop_offers.is_empty() and flow._pending_relic_choices.is_empty(), "abandoned run rewards cleared")
	var menu := game.find_child("MainMenuUIController", true, false) as MainMenuUIController
	check(menu.start_page.visible, "main menu visible")
	await capture("06_returned_main_menu")
	await click(menu.settings_button)
	await frames(15)
	check(menu._settings_overlay.visible and menu._music_slider.value == 37, "main menu settings share persisted audio")
	await capture("07_main_menu_settings")
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 100)
	print("BATTLE_SETTINGS_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
