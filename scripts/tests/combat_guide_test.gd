extends "res://scripts/tests/active_combat_integration_test.gd"
## The opt-in flag exercises the real first-visit gate without writing a save.
var guide: CombatGuideOverlay


func _enter() -> void:
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "character selection accepted")
	await frames(6)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	player = battle.player
	loadout = battle.loadout
	manager = battle.wave_manager
	controller = battle.active_controller
	guide = battle.combat_guide


func _press(button: Button) -> void:
	if DisplayServer.get_name() == "headless": button.pressed.emit()
	else: await click(button)
	await frames(5)


func _layout_check(label: String) -> void:
	var viewport := get_viewport().get_visible_rect()
	check(viewport.encloses(guide.card.get_global_rect()), label + " card within viewport")
	check(viewport.encloses(guide.spotlight.focus_rect), label + " highlight within viewport")
	check(not guide.card.get_global_rect().intersects(guide.spotlight.focus_rect), label + " instructions do not cover highlighted controls")


func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.load_config(ConfigFile.new())
	check(CombatSettings.should_show_combat_guide(), "explicit test opt-in enables first visit")
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(12)
	flow = game.get_main_flow_coordinator()
	await _enter()
	check(flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE and guide.visible and guide.step == 0, "first visit shows movement guide")
	check(flow.current_wave_index == -1 and not manager.running, "first wave has not started")
	check(not flow.request_next_wave(), "next-wave requests cannot bypass guide")
	check(EnemyRegistry.get_registered_enemies().is_empty(), "no enemies spawned before guide")
	var position_before := player.global_position
	var time_before := manager.wave_time_left
	var config_before := CombatSettings.build_config().encode_to_text()
	await mouse(guide.spotlight.destination, MOUSE_BUTTON_RIGHT)
	await mouse(guide.spotlight.destination, MOUSE_BUTTON_RIGHT, false)
	await key(KEY_1)
	await key(KEY_1, false)
	await key(KEY_W)
	await key(KEY_W, false)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE, false)
	manager._process(10)
	check(player.global_position == position_before and not player.has_move_destination and not controller.can_control(), "demo blocks movement and casting")
	check(loadout.weapon_instances[0].volley_index == 0, "demo input does not execute a weapon")
	check(manager.wave_time_left == time_before and flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE, "guide blocks Escape and freezes wave clock")
	_layout_check("movement 1280")
	await capture("01_right_click")
	await _press(guide.next_button)
	check(guide.step == 1 and guide.preview_esc.visible, "next shows production Esc inventory")
	check(guide._legend.visible and guide._legend.get_child_count() == 2, "both cast icons explained with one starting weapon")
	if DisplayServer.get_name() != "headless":
		await click(guide.preview_esc.weapon_strip._cast_mode_buttons[0])
	check(CombatSettings.build_config().encode_to_text() == config_before, "spotlight blocks auto/manual edits")
	_layout_check("inventory 1280")
	await capture("02_auto_manual")
	await _press(guide.next_button)
	check(guide.step == 2 and guide.preview_settings.combat_settings.visible, "next opens combat settings tab")
	if DisplayServer.get_name() != "headless": await click(guide.preview_settings.mode_buttons[1])
	check(CombatSettings.build_config().encode_to_text() == config_before, "spotlight blocks movement setting changes")
	_layout_check("settings 1280")
	await capture("03_wasd_settings")
	await _press(guide.previous_button)
	check(guide.step == 1, "previous returns to inventory")
	await _press(guide.next_button)
	await _press(guide.next_button)
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and manager.running and flow.current_wave_index == 0, "finish starts exactly the first wave")
	flow.finish_combat_guide()
	check(flow.current_wave_index == 0, "duplicate finish cannot start another wave")
	check(CombatSettings.combat_guide_seen and not CombatSettings.should_show_combat_guide(), "completion suppresses automatic repeat")
	var saved := CombatSettings.build_config()
	CombatSettings.load_config(saved)
	check(CombatSettings.combat_guide_seen, "completion round-trips config")
	manager.set_process(false)
	await _replay(MainFlowCoordinator.STATE_WAVE_COMBAT)
	flow.request_esc_overlay()
	await frames()
	await _replay(MainFlowCoordinator.STATE_ESC_OVERLAY)
	flow.close_esc_overlay()
	flow.request_shared_reward_shop_popup(2)
	await frames()
	var offers := flow._active_shop_offers.duplicate(true)
	await _replay(MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP)
	check(flow._active_shop_offers == offers and flow._active_level_up_level == 2, "replay preserves pending reward offers")
	flow.close_shared_reward_shop_popup()
	flow.enter_start_page()
	await frames(8)
	await _enter()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and not guide.visible, "second run starts without guide")
	flow.enter_start_page()
	await frames(8)
	# Opening camp rewards precede the first guide, without spawning a wave.
	CombatSettings.combat_guide_seen = false
	for record: Dictionary in CampProgression.get_building_records():
		for level: String in record.get("levels", {}):
			for effect: Dictionary in record.levels[level]:
				if effect.get("unlock", "") == "run_start_double_level":
					CampProgression.state.building_levels[record.id] = int(level)
	check(CampProgression.has_unlock("run_start_double_level"), "camp opening reward enabled")
	await _enter()
	check(flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and not guide.visible and not manager.running, "opening rewards shown before guide and wave")
	flow.request_battle_utility("settings")
	await frames()
	check(battle.utility_overlay._settings_view.guide_button.disabled and not flow.request_combat_guide_replay(), "replay cannot bypass unfinished opening rewards")
	flow.close_battle_utility()
	check(flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and not manager.running, "opening reward context remains intact")
	flow.close_shared_reward_shop_popup()
	check(flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and flow._active_level_up_level == 3, "second opening reward remains queued")
	flow.close_shared_reward_shop_popup()
	await frames(5)
	check(guide.visible and guide.step == 0 and not manager.running, "guide starts after final opening reward")
	await _press(guide.skip_button)
	check(manager.running and flow.current_wave_index == 0 and manager.player_level == 3, "skip starts first wave and retains both starting levels")
	check(CombatSettings.combat_guide_seen, "skip also marks guide seen")
	flow.enter_start_page()
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("COMBAT_GUIDE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _replay(source: String) -> void:
	var time_before := manager.wave_time_left
	var pause_before := bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	var resume_before := flow._resume_state_after_modal
	CombatSettings.set_option("keyboard_movement", true, false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", false, false)
	var before := CombatSettings.build_config().encode_to_text()
	flow.request_battle_utility("settings")
	await frames()
	battle.utility_overlay._settings_view.select_page(1)
	var replay := battle.utility_overlay._settings_view.guide_button
	await frames(8)
	battle.utility_overlay._settings_view.content_scroll.ensure_control_visible(replay)
	await frames(6)
	check(replay.is_visible_in_tree(), "replay button exists inside combat settings")
	check(battle.utility_overlay._settings_view.content_scroll.get_global_rect().encloses(replay.get_global_rect()), "replay button scrolled into view")
	if source == MainFlowCoordinator.STATE_WAVE_COMBAT: await capture("04_replay_entry")
	await _press(replay)
	check(guide.visible and flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE, "replay opens from " + source)
	if source == MainFlowCoordinator.STATE_WAVE_COMBAT:
		get_tree().root.size = Vector2i(960, 540)
		get_tree().root.content_scale_size = Vector2i(960, 540)
		await frames(8)
		for index in 3:
			guide._show_step(index)
			await frames(8)
			_layout_check("compact step %d" % index)
			await capture("compact_%d" % index)
		get_tree().root.size = Vector2i(1280, 720)
		get_tree().root.content_scale_size = Vector2i(1280, 720)
		await frames(8)
		L10n.set_locale("en", false)
		await frames(8)
		for index in 3:
			guide._show_step(index)
			await frames(8)
			_layout_check("English step %d" % index)
		L10n.set_locale("zh_CN", false)
		await frames(8)
	await _press(guide.skip_button)
	check(flow.current_state == MainFlowCoordinator.STATE_BATTLE_UTILITY and battle.utility_overlay._settings_view.combat_settings.visible, "replay returns to combat settings")
	check(CombatSettings.build_config().encode_to_text() == before, "replay preserves nondefault preferences")
	flow.close_battle_utility()
	await frames(6)
	check(flow.current_state == source and bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) == pause_before, "replay restores source pause state")
	check(flow._resume_state_after_modal == resume_before and manager.wave_time_left == time_before, "replay preserves nested return state and wave time")
	if source == MainFlowCoordinator.STATE_ESC_OVERLAY: check(battle.esc_overlay.visible, "original inventory restored after replay")
