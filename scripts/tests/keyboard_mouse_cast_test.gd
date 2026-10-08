extends "res://scripts/tests/active_combat_integration_test.gd"
## Headless checks controller semantics; GPU also exercises the real GUI input route.

const POINTER := Vector2(860, 370)
var gpu := false

func press_mouse(button: int = MOUSE_BUTTON_LEFT, point: Vector2 = POINTER) -> void:
	if gpu:
		await mouse(point, button)
		await mouse(point, button, false)
	else:
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = button
			event.pressed = down
			controller._input(event)
			controller._unhandled_input(event)
		await frames()

func press_key(code: int) -> void:
	if gpu:
		await key(code)
		await key(code, false)
	else:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		controller._unhandled_input(event)
		await frames()

func fixture(ids: Array[String]) -> void:
	for source in loadout.weapon_instances.duplicate():
		loadout.remove_weapon(source.weapon_id)
	manager.clear_battle_entities()
	await frames()
	for id in ids:
		check(loadout.equip_weapon(id), "equip " + id)
	await frames()

func _run() -> void:
	CampProgression.begin_transient_session()
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	CombatSettings.set_option("keyboard_movement", true, false)
	CombatSettings.set_option("quick_cast", false, false)
	gpu = DisplayServer.get_name() != "headless"
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(12)
	await boot()
	battle.set_process(false)
	await fixture(["weapon_void_blade", "weapon_camp_dagger", "weapon_plasma_cannon"])
	await _normal_casting()
	await _quick_casting()
	await _special_weapons()
	await _mode_boundaries()
	await _mixed_skills()
	await _loadout_changes()
	flow.enter_start_page()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await frames(6)
	print("KEYBOARD_MOUSE_CAST_COMPLETE checks=%d failures=%d gpu=%s" % [checks, failures, gpu])
	get_tree().quit(1 if failures else 0)

func _normal_casting() -> void:
	var bow := loadout.weapon_instances[0]
	var dagger := loadout.weapon_instances[1]
	var plasma := loadout.weapon_instances[2]
	await mouse(POINTER)
	controller._pointer_position = POINTER
	controller._has_pointer_position = true
	await frames()
	check(controller.current_weapon == bow and controller.selected_weapon == null, "first weapon selected without aiming or firing")
	check(controller.cursor_icon.visible and controller.cursor_icon.weapon == bow, "current weapon icon visible beside battlefield pointer")
	check(controller.cursor_icon.position.x > POINTER.x and controller.cursor_icon.position.y < POINTER.y, "icon placed above and right of pointer")
	await press_key(KEY_2)
	check(controller.current_weapon == dagger and controller.selected_weapon == dagger and dagger.volley_index == 0, "WASD supports number-key manual aiming")
	await press_key(KEY_1)
	controller.cancel_aim()
	await press_mouse()
	check(controller.selected_weapon == bow and controller.indicator.visible and bow.volley_index == 0, "first left click only aims")
	if gpu:
		var before := player.global_position
		await key(KEY_D)
		await get_tree().create_timer(0.2).timeout
		await key(KEY_D, false)
		check(player.global_position.x > before.x + 5 and controller.selected_weapon == bow, "WASD moves while aiming")
		check(controller.indicator.global_position.distance_to(player.global_position) < 2, "indicator follows moving player")
	await press_mouse()
	check(bow.volley_index == 1 and controller.selected_weapon == null and not controller.indicator.visible, "second left click casts once and exits aim")
	check(controller.current_weapon == bow and controller.cursor_icon.visible, "current weapon persists after cast")
	await press_mouse()
	await press_mouse()
	check(bow.volley_index == 1 and controller.selected_weapon == bow, "executing weapon rejects repeated clicks without queue")
	loadout.active_casting.interrupt(bow)
	await press_mouse()
	check(bow.volley_index == 1 and controller.indicator.visible and not controller.indicator.available, "cooling weapon retains unavailable aim and does not fire")
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	check(controller.current_weapon == dagger and controller.selected_weapon == dagger and dagger.volley_index == 0, "wheel while aiming changes weapon and indicator without firing")
	check(controller.cursor_icon.weapon == dagger, "wheel updates pointer icon")
	await press_mouse()
	check(dagger.volley_index == 1 and controller.selected_weapon == null, "next left click casts newly aimed weapon")
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	check(controller.current_weapon == plasma and controller.selected_weapon == null and plasma.volley_index == 0, "idle wheel selects only")
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	check(controller.current_weapon == bow, "wheel down wraps last to first")
	await press_mouse(MOUSE_BUTTON_WHEEL_UP)
	check(controller.current_weapon == plasma, "wheel up wraps first to last")
	await press_mouse()
	await press_mouse(MOUSE_BUTTON_RIGHT)
	check(controller.selected_weapon == null and not player.has_move_destination, "right click cancels aim without moving in keyboard mode")
	if gpu:
		await press_mouse()
		await press_key(KEY_ESCAPE)
		check(controller.selected_weapon == null and flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "Escape first cancels aiming")
		await press_key(KEY_ESCAPE)
		check(flow.current_state == MainFlowCoordinator.STATE_ESC_OVERLAY and not controller.cursor_icon.visible, "second Escape opens inventory and hides cursor icon")
		await press_key(KEY_ESCAPE)
		await get_tree().create_timer(0.4).timeout
		await press_mouse()
		var hud := battle.hud as BattleHud
		await click(hud.combat_bar.cast_mode_icons[0])
		check(plasma.volley_index == 0 and controller.selected_weapon == plasma, "weapon bar intercepts left click")
		var point := hud.combat_bar.cards[0].get_global_rect().get_center()
		await press_mouse(MOUSE_BUTTON_WHEEL_DOWN, point)
		check(controller.current_weapon == plasma and not controller.cursor_icon.visible, "UI scroll cannot switch weapon; pointer icon hides over UI")
		await mouse(POINTER)
		await click(hud.settings_button)
		check(not controller.cursor_icon.visible and controller.selected_weapon == null, "settings clears aim and hides cursor icon")
		var settings: GameSettingsPanel = battle.utility_overlay._settings_view
		await click(settings.tabs[1])
		check(L10n.source(settings._key_labels[0].text) == L10n.text("ui.settings.controls.number_keys") and settings._key_labels[4].is_visible_in_tree() and L10n.source(settings._key_descriptions[1].text) == L10n.text("ui.settings.controls.click_aim_hint"), "settings explains number keys and additional WASD wheel controls")
		await capture("keyboard_settings_normal")
		await press_key(KEY_ESCAPE)
		await get_tree().create_timer(0.4).timeout

func _quick_casting() -> void:
	await fixture(["weapon_void_blade", "weapon_plasma_cannon"])
	CombatSettings.set_option("quick_cast", true, false)
	var bow := controller.current_weapon
	var plasma := loadout.weapon_instances[1]
	await press_mouse()
	check(bow.volley_index == 1 and controller.selected_weapon == null and not controller.indicator.visible, "quick cast fires on first left click without indicator")
	await press_mouse()
	check(bow.volley_index == 1, "quick repeated click cannot bypass execution")
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	check(controller.current_weapon == plasma and plasma.volley_index == 0, "quick wheel only switches")
	await press_mouse()
	check(plasma.volley_index == 1 and bow.volley_index == 1 and controller.selected_weapon == null, "quick current weapon fires independently")
	if gpu:
		await click((battle.hud as BattleHud).settings_button)
		var settings: GameSettingsPanel = battle.utility_overlay._settings_view
		await click(settings.tabs[1])
		check(L10n.source(settings._key_descriptions[1].text) == L10n.text("ui.settings.controls.click_quick_cast_hint"), "settings explains single-click quick cast")
		await capture("keyboard_settings_quick")
		await press_key(KEY_ESCAPE)
		await get_tree().create_timer(0.4).timeout

func _special_weapons() -> void:
	CombatSettings.set_option("quick_cast", false, false)
	for id in ["weapon_copper_lamp", "weapon_kunyu_ritual_tome"]:
		await fixture([id])
		player.last_move_direction = Vector2.UP
		var source := controller.current_weapon
		var target: EnemyController
		if source.is_copper_lamp():
			target = manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(-60, 0))
			target.set_physics_process(false)
			target.modifier_stack.set_base_stat("max_hp", 100000)
			target.current_hp = 100000
		await press_mouse()
		check(controller.selected_weapon == source and controller.indicator.visible and source.volley_index == 0, "keyboard first click previews " + id)
		if source.is_copper_lamp():
			check(controller.indicator.target_offset.normalized().is_equal_approx(Vector2.LEFT), "lamp preview points to nearest enemy instead of movement or pointer")
		await press_mouse()
		check(source.volley_index == 1 and controller.selected_weapon == null, "keyboard second click casts " + id)
		var body: Node2D = loadout.active_casting.state_for(source).body.get_ref()
		if body is CopperLamp:
			body.set_physics_process(false)
			body._physics_process(0.01)
			check(not body.manual_control and body.target == target and body.heading.is_equal_approx(Vector2.LEFT), "manual lamp click still targets nearest enemy instead of movement or pointer")
		if body is RitualDomain:
			check(body.global_position.is_equal_approx(player.global_position), "ritual starts centered on player")
			body.set_physics_process(false)
			player.global_position += Vector2(400, 100)
			body._physics_process(0.01)
			check(body.global_position.is_equal_approx(player.global_position), "keyboard-cast ritual follows player movement")

func _mode_boundaries() -> void:
	await fixture(["weapon_void_blade", "weapon_plasma_cannon"])
	controller.select_slot(0)
	var bow := controller.current_weapon
	CombatSettings.set_option("keyboard_movement", false, false)
	await press_mouse()
	check(bow.volley_index == 0 and not controller.cursor_icon.visible, "mouse movement mode hides icon and retains aim-only left click")
	await press_key(KEY_1)
	check(controller.selected_weapon == bow, "mouse movement mode still aims with number keys")
	await press_mouse()
	check(bow.volley_index == 1 and controller.selected_weapon == null, "mouse movement mode still confirms with left click")
	CombatSettings.set_option("keyboard_movement", true, false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(true)
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	await press_key(KEY_2)
	await press_mouse()
	check(controller.current_weapon == null and controller.selected_weapon == null and not controller.cursor_icon.visible and loadout.weapon_instances[1].volley_index == 0, "all-automatic attacks leave no manual wheel or click target")
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	await press_mouse()
	controller._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames()
	check(controller.selected_weapon == null and not controller.cursor_icon.visible and player._held_move_keys.is_empty(), "focus loss clears aim and hides icon")
	controller.cursor_icon.follow_pointer(Vector2(1279, 1), Vector2(1280, 720))
	check(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(controller.cursor_icon.get_global_rect()), "cursor icon stays on-screen at top right")

func _mixed_skills() -> void:
	await fixture(["weapon_void_blade", "weapon_camp_dagger", "weapon_plasma_cannon"])
	CombatSettings.set_option("quick_cast", false, false)
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", true, false)
	var dagger := loadout.weapon_instances[1]
	var plasma := loadout.weapon_instances[2]
	check(controller.current_weapon == dagger, "making current skill automatic selects the next manual skill")
	await press_mouse(MOUSE_BUTTON_WHEEL_UP)
	check(controller.current_weapon == plasma, "wheel wraps across automatic skills without selecting them")
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	check(controller.current_weapon == dagger, "wheel skips automatic skill in the other direction")
	await press_key(KEY_2)
	await press_key(KEY_1)
	check(controller.selected_weapon == dagger, "automatic attack hotkey does not replace manual aim")
	CombatSettings.set_option("quick_cast", true, false)
	await press_key(KEY_3)
	check(plasma.volley_index == 1 and controller.selected_weapon == null, "WASD number hotkey quick-casts the manual skill")
	CombatSettings.set_weapon_auto_cast("weapon_plasma_cannon", true, false)
	check(controller.current_weapon == dagger, "switching skill to auto repairs current manual selection")
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	CombatSettings.set_option("quick_cast", false, false)
	await fixture(["weapon_void_blade", "weapon_star_tome"])
	CombatSettings.set_weapon_auto_cast("weapon_star_tome", true, false)
	var tome := loadout.weapon_instances[1]
	await press_key(KEY_2)
	check(controller.selected_weapon == tome and controller.current_weapon == loadout.weapon_instances[0], "number keys can manually aim automatic mobility without changing the manual wheel target")
	await press_mouse()
	check(tome.volley_index == 1 and tome.is_return_ready() and loadout.weapon_instances[0].volley_index == 0, "left click confirms the aimed mobility skill and retains manual tome return")
	await press_key(KEY_2)
	check(not tome.is_return_ready(), "automatic preference preserves explicit manual tome return")


func _loadout_changes() -> void:
	await fixture(["weapon_void_blade", "weapon_camp_dagger", "weapon_plasma_cannon"])
	controller.select_slot(2)
	var plasma := controller.current_weapon
	loadout.remove_weapon("weapon_void_blade")
	check(controller.current_weapon == plasma and controller.current_slot == 1, "removing earlier slot preserves selected instance")
	loadout.remove_weapon("weapon_plasma_cannon")
	check(controller.current_weapon == loadout.weapon_instances[0] and controller.current_slot == 0, "removing current weapon selects remaining slot")
	loadout.remove_weapon("weapon_camp_dagger")
	await press_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	await press_mouse()
	check(controller.current_weapon == null and controller.selected_weapon == null and not controller.cursor_icon.visible, "empty loadout safely ignores mouse controls")
