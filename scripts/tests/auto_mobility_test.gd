extends "res://scripts/tests/mobility_weapon_integration_test.gd"
## Production movement, casts, settings and GUI; no user preferences are written.

func _run() -> void:
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	CombatSettings.load_config(ConfigFile.new())
	check(not CombatSettings.build_config().has_section_key("combat", "wheelchair_mode"), "new config has no automation master switch")
	check(CombatSettings.prefers_auto_cast("weapon_void_blade", false) and not CombatSettings.prefers_auto_cast(IDS[0], true), "attack and mobility defaults differ")
	CombatSettings.set_weapon_auto_cast(IDS[0], true, false)
	CombatSettings.set_weapon_auto_cast("weapon_copper_lamp", false, false)
	var encoded := CombatSettings.build_config().encode_to_text()
	var saved := ConfigFile.new()
	check(saved.parse(encoded) == OK, "per-weapon settings serialize")
	CombatSettings.load_config(saved)
	check(CombatSettings.prefers_auto_cast(IDS[0], true) and not CombatSettings.prefers_auto_cast("weapon_copper_lamp", false), "choices survive config reload")
	var legacy := ConfigFile.new()
	legacy.set_value("combat", "wheelchair_mode", false)
	legacy.set_value("combat", "keyboard_movement", true)
	legacy.set_value("combat", "quick_cast", true)
	legacy.set_value("combat", "show_hints", false)
	legacy.set_value("weapon_auto_cast", IDS[0], true)
	CombatSettings.load_config(legacy)
	check(DataRegistry.get_table("weapons").all(func(record): return not CombatSettings.prefers_auto_cast(str(record.id), false)), "legacy disabled master migrates every equipped or unequipped skill to manual")
	check(CombatSettings.keyboard_movement and CombatSettings.quick_cast and not CombatSettings.show_hints, "migration preserves movement quick cast and hints")
	CombatSettings.set_weapon_auto_cast(IDS[0], true, false)
	var migrated := CombatSettings.build_config()
	check(not migrated.has_section_key("combat", "wheelchair_mode"), "migration drops legacy key on save")
	CombatSettings.load_config(migrated)
	check(CombatSettings.prefers_auto_cast(IDS[0], true), "subsequent edits survive reload without repeating migration")
	legacy.set_value("combat", "wheelchair_mode", true)
	legacy.set_value("weapon_auto_cast", "weapon_void_blade", false)
	CombatSettings.load_config(legacy)
	check(CombatSettings.prefers_auto_cast(IDS[0], true) and not CombatSettings.prefers_auto_cast("weapon_void_blade", false) and CombatSettings.prefers_auto_cast("weapon_copper_lamp", false), "legacy enabled master retains mixed choices and defaults")
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [IDS[0]])
	await frames()
	check(flow.confirm_character_selection(), "real battle boots")
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
	for keyboard in [false, true]:
		for index in 3:
			await _pursuit_and_escape(index, keyboard)
	await _boundaries()
	await _during_motion_input()
	await _manual_and_settings()
	await _performance()
	await reset()
	flow.enter_start_page()
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("AUTO_MOBILITY_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func fixture(index: int = 0, keyboard: bool = true) -> WeaponInstance:
	await reset()
	CombatSettings.reset_weapon_auto_cast(false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(true)
	CombatSettings.set_option("keyboard_movement", keyboard, false)
	CombatSettings.set_option("quick_cast", false, false)
	CombatSettings.set_weapon_auto_cast(IDS[index], true, false)
	loadout.active_casting.mobility_planner = AutoMobilityPlanner.new()
	for weapon in loadout.weapon_instances: weapon.volley_index = 0
	return loadout.get_weapon_instance(IDS[index])

func move(direction: Vector2) -> void:
	player._clear_move_input()
	if player.keyboard_movement:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_D if direction.x > 0 else KEY_A if direction.x < 0 else KEY_W
		event.pressed = true
		player.accept_move_key(event)
	else:
		player.request_move(origin + direction * 400.0)

func decide(seconds: float = 0.8) -> void:
	for i in ceili(seconds / 0.05):
		loadout.tick(0.05)
		freeze_effects()

func crowd(behind: bool = true) -> void:
	var side := -1.0 if behind else 1.0
	for offset in [Vector2(100, 0), Vector2(110, 50), Vector2(110, -50)]: enemy(offset * Vector2(side, 1))

func _pursuit_and_escape(index: int, keyboard: bool) -> void:
	var weapon := await fixture(index, keyboard)
	enemy(Vector2(150, 0))
	enemy(Vector2(180, 65))
	move(Vector2.RIGHT)
	decide()
	var label: String = IDS[index] + " keyboard=" + str(keyboard)
	check(weapon.volley_index == (0 if index == 1 else 1), "pursuit respects movement and recoil " + label)
	if weapon.volley_index > 0:
		var body: MobilityWeaponRuntime = weapon.mobility_runtime.get_ref()
		check(player.movement_intent().dot(Vector2.RIGHT) > 0.99, "pursuit preserves movement command " + label)
		if index == 2:
			check(not body.return_ready and body.anchor == null and not weapon.is_return_ready(), "automatic blink has no return mark")
			var landing := player.global_position
			decide()
			check(player.global_position == landing and weapon.volley_index == 1, "automatic blink does not immediately return")
	weapon = await fixture(index, keyboard)
	crowd()
	move(Vector2.RIGHT)
	var destination := player.move_destination
	decide()
	check(weapon.volley_index == 1, "high-pressure retreat releases " + label)
	check(keyboard and bool(player._held_move_keys.get(KEY_D, false)) or not keyboard and player.has_move_destination and player.move_destination == destination, "retreat retains keyboard or click command " + label)
	await step(0.05, 7)
	check(player.global_position.x > origin.x + 40, "actual movement travels away from crowd " + label)
	if index == 1:
		var gun: MobilityWeaponRuntime = weapon.mobility_runtime.get_ref()
		check(gun.heading.dot(Vector2.LEFT) > 0.86, "recoil follows retreat while shot faces pursuers")
	if keyboard:
		var release := InputEventKey.new()
		release.physical_keycode = KEY_D
		release.pressed = false
		player.accept_move_key(release)
		check(player.movement_intent().is_zero_approx(), "release during/after displacement never restores stale keys")
	else:
		player.request_move(origin + Vector2(0, -200))
		check(player.move_destination == origin + Vector2(0, -200), "new click replaces retained destination")

func _boundaries() -> void:
	var weapon := await fixture()
	crowd()
	decide(2.0)
	check(weapon.volley_index == 0, "standing still never auto-dashes")
	move(Vector2.UP)
	decide()
	check(weapon.volley_index == 0, "lateral motion does not count as pursuit or retreat")
	await fixture()
	enemy(Vector2(-140, 0))
	move(Vector2.RIGHT)
	decide()
	check(weapon.volley_index == 0, "retreat without significant pressure preserves skill")
	await fixture()
	crowd()
	move(Vector2.RIGHT)
	decide(0.15)
	check(weapon.volley_index == 0, "brief input does not trigger displacement")
	move(Vector2.LEFT)
	decide(0.15)
	check(weapon.volley_index == 0, "direction change restarts intent stability")
	await fixture()
	crowd()
	wall(Vector2(60, 0))
	await get_tree().physics_frame
	move(Vector2.RIGHT)
	decide()
	check(weapon.volley_index == 0, "terrain-blocked retreat waits without cooldown")
	await fixture()
	crowd()
	enemy(Vector2(110, 0))
	move(Vector2.RIGHT)
	decide()
	check(weapon.volley_index == 0, "retreat into another enemy is rejected")
	await fixture(0, false)
	crowd()
	player.request_move(origin + Vector2(30, 0))
	decide()
	check(weapon.volley_index == 0, "nearby click destination cannot be overshot")
	await fixture()
	crowd()
	move(Vector2.RIGHT)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	decide(1.0)
	check(weapon.volley_index == 0, "pause blocks planner")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_FINANCE_POPUP)
	decide(1.0)
	check(weapon.volley_index == 0, "non-combat phase blocks planner")
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_WAVE_COMBAT)
	player.alive = false
	decide(1.0)
	check(weapon.volley_index == 0, "death blocks planner")
	await fixture()
	crowd()
	for id in IDS: CombatSettings.set_weapon_auto_cast(id, true, false)
	move(Vector2.RIGHT)
	decide()
	var total := 0
	for source in loadout.weapon_instances: total += source.volley_index
	check(total == 1, "simultaneously ready mobility skills choose only one cast")
	await step(0.05, 7)
	decide(0.7)
	var later := 0
	for source in loadout.weapon_instances: later += source.volley_index
	check(later == 1, "shared cooldown prevents chained displacement")
	var planner := loadout.active_casting.mobility_planner
	var context := {"threats": [], "hazards": [{"start": origin + Vector2(60, 0), "end": origin + Vector2(60, 0), "radius": 30.0}]}
	check(not planner.safe_path(origin, origin + Vector2(100, 0), true, false, context), "visible hazard rejects a crossing dash")
	check(not planner.safe_path(origin, origin + Vector2(60, 0), true, true, context), "visible hazard rejects a blink landing")

func _during_motion_input() -> void:
	var weapon := await fixture(0, true)
	crowd()
	move(Vector2.RIGHT)
	decide()
	await step(0.05)
	check(player.is_mobility_moving(), "input update fixture is mid-dash")
	var release := InputEventKey.new()
	release.physical_keycode = KEY_D
	release.pressed = false
	player._input(release)
	await step(0.05, 6)
	check(player.movement_intent().is_zero_approx() and player.velocity.is_zero_approx(), "mid-dash key release is respected after the motion ends")
	weapon = await fixture(0, false)
	crowd()
	move(Vector2.RIGHT)
	decide()
	await step(0.05)
	var revised := origin + Vector2(160, -160)
	player.request_move(revised)
	await step(0.05, 6)
	check(player.has_move_destination and player.move_destination == revised, "mid-dash right-click updates survive completion")
	await fixture(0, false)
	crowd()
	move(Vector2.RIGHT)
	decide()
	battle.active_controller.stop_movement()
	await step(0.05, 7)
	decide(3.0)
	check(not player.has_move_destination and player.movement_intent().is_zero_approx() and weapon.volley_index == 1, "stop cancels retained command and prevents automatic re-engagement")
	# Check actual enemy-state adapters, not only synthetic hazard geometry.
	await fixture()
	var wolf := battle.wave_manager.spawn_enemy("enemy_underworld_wolf", origin + Vector2(300, 0)) as UnderworldWolf
	wolf.set_physics_process(false)
	wolf.state = "leap_charge"
	wolf.locked_point = origin + Vector2(100, 0)
	var planner := loadout.active_casting.mobility_planner
	var context := planner.snapshot(player)
	check(not planner.safe_path(origin, wolf.locked_point, false, true, context), "live wolf leap warning blocks an automatic blink landing")

func _manual_and_settings() -> void:
	await fixture()
	move(Vector2.RIGHT)
	var weapon := loadout.get_weapon_instance(IDS[0])
	CombatSettings.set_weapon_auto_cast(IDS[0], false, false)
	check(player.movement_intent() == Vector2.RIGHT, "changing per-skill settings does not stop movement")
	crowd()
	decide()
	check(weapon.volley_index == 0, "individual mobility opt-out prevents automation")
	battle.active_controller.select_slot(0)
	check(battle.active_controller.selected_weapon == weapon, "manual mobility remains available")
	CombatSettings.set_weapon_auto_cast(IDS[0], true, false)
	battle.active_controller.select_slot(0)
	decide()
	check(weapon.volley_index == 0, "manual aim takes priority over auto movement")
	battle.active_controller.cancel_aim()
	loadout.equip_weapon("weapon_void_blade")
	var bow := loadout.get_weapon_instance("weapon_void_blade")
	CombatSettings.set_weapon_auto_cast(bow.weapon_id, false, false)
	battle.active_controller.select_slot(loadout.weapon_instances.find(bow))
	check(battle.active_controller.selected_weapon == bow, "manual attack can be selected alongside automatic skills")
	battle.hud._refresh_active_combat()
	var flow := game.get_main_flow_coordinator()
	flow.request_esc_overlay()
	await frames(12)
	var strip := battle.esc_overlay.weapon_strip
	var bar: ActiveCombatWeaponBar = battle.hud.combat_bar
	check(strip._cast_mode_buttons.size() == loadout.weapon_instances.size(), "Esc has one cast-mode icon under every equipped weapon")
	var toggle := strip._cast_mode_buttons[0]
	check(toggle.automatic and not strip._cast_mode_buttons[1].automatic, "Esc shows independent saved choices")
	check(is_equal_approx(strip.size.y, 62) and is_equal_approx(toggle.get_global_rect().get_center().y, strip.get_node("StripPanel").get_global_rect().end.y - 1), "original Esc frame height is preserved with mode icon centers on its bottom border")
	check(toggle.get_theme_constant("icon_max_width") == 14 and bar.cast_mode_icons[0].size == Vector2(14, 14), "both mode glyphs use 70 percent of their original size")
	check(is_equal_approx(bar.cast_mode_icons[0].get_global_rect().get_center().y, bar.cards[0].get_global_rect().end.y - 1), "battle mode icon center sits on the original frame bottom border")
	await click_mode_control(toggle)
	check(not CombatSettings.prefers_auto_cast(IDS[0], true) and not bar.cast_mode_icons[0].automatic, "Esc icon click updates policy and battle icon together")
	check(weapon.volley_index == 0 and battle.active_controller.selected_weapon == null, "mode click does not cast or select a weapon")
	check(not strip._attachment_editing_enabled, "Esc mode editing does not enable attachment editing")
	await capture("esc_cast_mode_icons")
	await click_mode_control(strip._cast_mode_buttons[3])
	check(CombatSettings.is_weapon_automatic(bow), "attack icon can opt back into automatic casting")
	(battle.hud as BattleHud)._on_settings_pressed()
	await frames()
	var panel: GameSettingsPanel = battle.utility_overlay._settings_view
	panel.select_page(1)
	await frames()
	check(panel.is_visible_in_tree() and panel.tabs.size() == 2 and panel.find_child("SkillAutomation", true, false) == null, "settings only has general and combat pages")
	check(panel.find_child("WheelchairMode", true, false) == null, "combat settings no longer includes an automation master switch")
	check(CombatSettings.is_weapon_automatic(bow) and not CombatSettings.is_weapon_automatic(weapon), "each icon directly determines actual casting policy")
	await capture("settings_two_pages")
	battle.utility_overlay._close()
	await frames(8)
	toggle = strip._cast_mode_buttons[0]
	await click_mode_control(toggle)
	check(toggle.automatic and CombatSettings.is_weapon_automatic(weapon), "Esc enables automation without any other switch")
	# Rebuild/reopen must retain choices and avoid duplicate child controls.
	flow.close_esc_overlay()
	await frames()
	flow.request_esc_overlay()
	await frames(12)
	check(strip._cast_mode_buttons[0].automatic and strip.weapon_list.get_child_count() == loadout.weapon_instances.size(), "reopening inventory retains preference without duplicate slots")
	for record: Dictionary in DataRegistry.get_table("weapons"):
		if loadout.weapon_instances.size() < 11 and loadout.get_weapon_instance(str(record.id)) == null:
			loadout.equip_weapon(str(record.id))
	flow.close_esc_overlay()
	battle.hud._refresh_active_combat()
	flow.request_esc_overlay()
	await frames(8)
	for viewport_size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		get_tree().root.size = viewport_size
		get_tree().root.content_scale_size = viewport_size
		await frames(8)
		var scroll := strip.weapon_list.get_parent() as ScrollContainer
		scroll.ensure_control_visible(strip._weapon_buttons[-1])
		await frames()
		check(strip._cast_mode_layer.get_global_rect().encloses(strip._cast_mode_buttons[-1].get_global_rect()), "detached last toggle follows horizontal scrolling without clipping " + str(viewport_size))
		check(strip._cast_mode_layer.get_global_rect().end.y <= battle.esc_overlay.center_container.global_position.y, "icons fit between the original weapon and inventory frames " + str(viewport_size))
		check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(bar.get_global_rect()), "battle icons stay inside viewport " + str(viewport_size))
		check(bar.get_global_rect().end.y + 4 <= battle.hud.exp_bar.get_global_rect().position.y, "battle icons clear the experience bar " + str(viewport_size))
		await capture("esc_cast_mode_%d" % viewport_size.x)
	flow.close_esc_overlay()
	await frames()
	check(bar.cast_mode_icons[0].automatic and CombatSettings.is_weapon_automatic(weapon), "battle icon matches effective automatic policy")
	if DisplayServer.get_name() != "headless":
		await click_mode_control(bar.cast_mode_icons[0])
		check(CombatSettings.prefers_auto_cast(IDS[0], true) and battle.active_controller.selected_weapon == null, "battle mode icon is display-only and does not cast")
		await click_mode_control(bar.cards[0])
		check(battle.active_controller.selected_weapon == weapon, "weapon square retains manual selection")
	battle.active_controller.cancel_aim()
	for extra in loadout.weapon_instances.duplicate():
		if not extra.weapon_id in IDS: loadout.remove_weapon(extra.weapon_id)

func click_mode_control(toggle: Control) -> void:
	if DisplayServer.get_name() == "headless":
		if toggle is CheckBox: toggle.set_pressed(not toggle.button_pressed)
		else: toggle.pressed.emit()
		return
	var point := toggle.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames()

func _performance() -> void:
	await fixture()
	for i in 160:
		enemy(Vector2(100 + (i % 10) * 5, (i / 10) * 3))
	move(Vector2.RIGHT)
	var planner := loadout.active_casting.mobility_planner
	var started := Time.get_ticks_usec()
	for i in 600: loadout.tick(1.0 / 60.0)
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	check(planner.evaluations <= 40 and planner.candidates_checked == 0, "dense crowd is budgeted and conservatively skips unsafe truncated analysis")
	check(loadout.weapon_instances[0].volley_index == 0, "crowd budget exhaustion never grants an unsafe cast")
	print("AUTO_MOBILITY_BUDGET frames=600 enemies=160 evaluations=%d candidates=%d cpu_ms=%.3f" % [planner.evaluations, planner.candidates_checked, elapsed])
