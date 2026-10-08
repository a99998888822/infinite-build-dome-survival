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
	CampProgression.begin_transient_session()
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	CombatSettings.set_option("show_hints", true, false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
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
	await _test_review_layout()
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
	check(menu._settings_panel is GameSettingsPanel and menu._settings_panel.basic_settings.visible, "main menu shares reviewed settings and opens basic page")
	await capture("07_main_menu_settings")
	await click(menu._settings_panel.tabs[1])
	check(menu._settings_panel.combat_settings.visible and CombatSettings.keyboard_movement and CombatSettings.quick_cast, "main menu combat page retains settings changed in battle")
	check(menu._settings_panel.find_child("WheelchairMode", true, false) == null, "main menu has no retired automation switch")
	await capture("12_main_menu_combat")
	await escape()
	await get_tree().create_timer(0.3).timeout
	check(not menu._settings_overlay.visible, "Escape closes main menu settings")
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 100)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("BATTLE_SETTINGS_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_review_layout() -> void:
	await click(hud.settings_button)
	var view := overlay._settings_view
	check(view.size == Vector2(952, 562) and view.basic_settings.visible, "production panel matches approved 952 by 562 layout")
	await capture("08_review_basic")
	await click(view.tabs[1])
	check(view.combat_settings.visible and view.mode_buttons.size() == 2, "combat settings use two movement cards")
	check(view.mode_buttons[0].button_pressed and view.mode_checks[0].visible and not view.quick_cast.button_pressed, "mouse card selected and quick cast off by default")
	check(view.quick_cast.get_parent() == view._key_descriptions[1].get_parent(), "quick cast remains on the left mouse row")
	check(view.find_child("WheelchairMode", true, false) == null, "battle settings has no retired automation switch")
	await capture("09_review_mouse")
	await click(view.mode_buttons[1])
	await click(view.quick_cast)
	await click(view.show_hints)
	check(CombatSettings.keyboard_movement and CombatSettings.quick_cast and not CombatSettings.show_hints, "review-style controls update live saved settings")
	await click(view.tabs[0])
	await click(view.tabs[1])
	check(view.mode_buttons[1].button_pressed and view.mode_checks[1].visible and view.quick_cast.button_pressed and not view.show_hints.button_pressed, "tab changes preserve choices and selected indicators")
	check(not CombatSettings.prefers_auto_cast("weapon_void_blade", false), "movement and quick-cast changes preserve per-skill preferences")
	await capture("10_review_keyboard_quick")
	for viewport_size in [Vector2i(1024, 576), Vector2i(960, 540)]:
		get_tree().root.size = viewport_size
		get_tree().root.content_scale_size = viewport_size
		await frames(10)
		check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(view.get_global_rect()), "settings panel stays inside small viewport")
		check(view.get_global_rect().encloses(view.return_button.get_global_rect()) and view.get_global_rect().encloses(view.menu_button.get_global_rect()), "both return buttons remain accessible")
		view.content_scroll.scroll_vertical = 1000
		await frames(5)
		check(view.content_scroll.get_global_rect().encloses(view._key_descriptions.back().get_global_rect()), "scroll reaches final operation row at small resolution")
		await capture("11_review_%d" % viewport_size.x)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(8)
	CombatSettings.set_option("show_hints", true, false)
	await escape()
