extends Node
## Exercise the phone's fixed input policy against saved desktop preferences.

var checks := 0
var failures := 0
var capture_dir := ""
var resolution := Vector2i(1920, 1080)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()

func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame

func tap(control: Control, index := 15) -> void:
	# Native touch input also exercises mouse emulation and joystick interception.
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = get_viewport().get_screen_transform() * point
	touch.pressed = true
	Input.parse_input_event(touch)
	await frames(2)
	touch.pressed = false
	Input.parse_input_event(touch)
	await frames(2)

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + note)

func capture(page: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	fit_window()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(image.get_size() == resolution and image.save_png(capture_dir.path_join(page + ".png")) == OK, "capture at requested resolution " + page)

func fit_window() -> void:
	# Allow a 20:9 capture wider than the private desktop's physical monitor.
	get_tree().root.borderless = true
	get_tree().root.size = resolution
	MobileProfile.apply_to_window(get_tree().root)

func check_settings(panel: GameSettingsPanel, context: String) -> void:
	check(panel.basic_settings.is_visible_in_tree() and not panel.combat_settings.visible, context + " opens basic settings only")
	check(not panel.tabs[1].visible, context + " hides combat tab")
	check(not panel.resolution.is_visible_in_tree() and not panel.fullscreen_no.is_visible_in_tree(), context + " has no resolution/fullscreen choices")
	panel.select_page(1)
	check(panel.basic_settings.visible and not panel.combat_settings.visible and not panel.show_hints.visible, context + " cannot enter combat settings programmatically")
	check(not panel.guide_button.visible, context + " hides desktop combat guide")
	check(panel.volume_controls.size() == 2, context + " keeps both audio controls")
	for control in panel.volume_controls.values():
		check(control.label.get_global_rect().end.x <= panel.content_scroll.get_global_rect().end.x - 24, context + " volume percentage clears scrollbar")

func _run() -> void:
	if not MobileProfile.is_mobile():
		print("MOBILE_CONTROLS_TEST skipped: use --mobile-ui")
		get_tree().quit(0)
		return
	CampProgression.begin_transient_session()
	var legacy := ConfigFile.new()
	legacy.set_value("combat", "keyboard_movement", true)
	legacy.set_value("combat", "quick_cast", true)
	legacy.set_value("weapon_auto_cast", "weapon_void_blade", false)
	CombatSettings.load_config(legacy)
	check(CombatSettings.prefers_auto_cast("weapon_void_blade", false), "saved manual preference cannot disable automatic attacks")
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", false, false)
	check(CombatSettings.prefers_auto_cast("weapon_void_blade", false), "manual policy cannot be enabled on phone")
	check(not bool(CombatSettings.build_config().get_value("weapon_auto_cast", "weapon_void_blade")), "phone policy preserves saved desktop preference")
	var display_request := WindowSettings._request_id
	var display_index := WindowSettings.get_resolution_index()
	WindowSettings.set_fullscreen(false)
	WindowSettings.set_resolution_index(0)
	check(WindowSettings.is_fullscreen(), "phone display policy is always fullscreen")
	check(WindowSettings._request_id == display_request and WindowSettings.get_resolution_index() == display_index, "display setters cannot resize or persist phone preferences")
	fit_window()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(24)
	fit_window()
	await frames()
	check(get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "game root retains mobile aspect policy")
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	var flow := game.get_main_flow_coordinator()
	menu._on_settings_pressed()
	await frames(24)
	check_settings(menu._settings_panel, "main menu")
	await capture("01_mobile_settings")
	menu._close_settings()
	await frames(24)
	menu._on_talents_pressed()
	await frames(16)
	var talents := game.find_child("CampBlueprintUIController", true, false) as CampBlueprintUIController
	check(talents._hint.text == L10n.text("ui.talent_tree.navigation_touch"), "talent hint uses touch wording")
	var reset_rect := talents._reset_button.get_global_rect()
	check(talents._summary_panel.get_global_rect().encloses(reset_rect), "reset stays inside summary instead of covering tree")
	check(not reset_rect.intersects(talents._currency_label.get_global_rect()) and not reset_rect.intersects(talents._summary_title.get_global_rect()), "reset clears talent points and summary title")
	# The fixed detail box owns the same purchase button on the phone layout.
	CampProgression.set_camp_currency(10000)
	talents.select_node("camp_upgrade_quick_shop")
	check(talents._detail_panel.visible and talents._detail_purchase.visible and not talents._detail_purchase.disabled, "phone detail shows an affordable purchase button")
	check(talents._detail_panel.get_global_rect().encloses(talents._detail_purchase.get_global_rect()), "phone purchase button fits inside the detail frame")
	check(talents._detail_purchase.position.y >= talents._detail_effect.position.y + 90 and not talents._detail_purchase.get_global_rect().intersects(talents._detail_cost.get_global_rect()) and not talents._detail_purchase.get_global_rect().intersects(talents._detail_next.get_global_rect()), "phone purchase button clears the benefit block, next and cost text")
	await capture("02_mobile_talents")
	check(CampProgression.purchase_upgrade("camp_upgrade_quick_shop"), "unlock quick enchant for actual phone HUD coverage")
	var pan_before := talents._pan
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = Vector2(100, 350)
	touch.pressed = true
	get_viewport().push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = touch.position + Vector2(80, 30)
	drag.relative = Vector2(80, 30)
	get_viewport().push_input(drag, true)
	touch.position = drag.position
	touch.pressed = false
	get_viewport().push_input(touch, true)
	check(talents._pan.is_equal_approx(pan_before + drag.relative * 0.55) and not talents._dragging, "touch drag pans at reduced sensitivity and release stops")
	flow.enter_start_page()
	await frames(12)
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade", "weapon_dash_blade"])
	await frames(12)
	check(flow.confirm_character_selection(), "battle starts with filtered legacy weapon list")
	await frames(24)
	while flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
		flow.close_shared_reward_shop_popup()
		await frames()
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	check(not battle.loadout.has_weapon("weapon_dash_blade"), "pointer-steered weapon never enters phone loadout")
	check(is_equal_approx(float(battle.player.modifier_stack.base_stats.move_speed), 155.0), "phone novice starts with fifteen extra base speed")
	var combat_hud := battle.hud as BattleHud
	combat_hud._set_drawer_open(true, false)
	await frames()
	var quick_rect := combat_hud.quick_shop_button.get_global_rect()
	check(combat_hud.quick_shop_button.is_visible_in_tree(), "unlocked quick enchant sign is visible")
	check(not quick_rect.intersects(combat_hud.stats_drawer.get_node("ParchmentPanelSkin").get_global_rect()), "quick enchant sign clears open parchment")
	check(not quick_rect.intersects(combat_hud.economy_panel.get_global_rect()), "quick enchant sign clears balances")
	check(get_viewport().get_visible_rect().encloses(quick_rect), "quick enchant sign fits phone screen")
	await capture("03a_mobile_quick_enchant_drawer")
	await tap(combat_hud.quick_shop_button)
	check(flow.current_state == MainFlowCoordinator.STATE_QUICK_ENCHANTMENT, "native touch reaches uncovered quick enchant sign")
	flow.close_quick_enchantment()
	combat_hud._set_drawer_open(false, false)
	await frames()
	var weapon := battle.loadout.get_weapon_instance("weapon_void_blade")
	check(weapon != null and CombatSettings.is_weapon_automatic(weapon), "equipped weapon ignores saved manual preference")
	check(not battle.player.keyboard_movement, "desktop movement preference cannot enable keyboard controls")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	check(not battle.player.accept_move_key(key), "keyboard movement is rejected")
	battle.player.request_move(battle.player.global_position + Vector2(200, 0))
	check(battle.player._read_move_input().is_zero_approx(), "click destination cannot move phone player")
	battle.player.set_mobile_move_direction(Vector2(0.6, 0.8))
	check(battle.player._read_move_input().is_equal_approx(Vector2(0.6, 0.8)), "joystick remains the movement source")
	battle.player.set_mobile_move_direction(Vector2.ZERO)
	battle.active_controller.select_slot(0)
	check(battle.active_controller.selected_weapon == null, "weapon bar cannot enter manual aiming")
	var bar := (battle.hud as BattleHud).combat_bar
	check(bar != null and bar.cast_mode_icons.is_empty(), "battle bar has no manual/auto icons")
	check(bar.scale.is_equal_approx(Vector2.ONE * 0.8), "phone combat weapon bar displays at eighty percent")
	var target := battle.wave_manager.spawn_enemy("enemy_mutated_grub", battle.player.global_position + Vector2(100, 0))
	target.set_physics_process(false)
	var volley_before := weapon.volley_index
	battle.loadout.tick(10.0)
	check(weapon.volley_index > volley_before, "real weapon automatically fires at an enemy despite saved manual policy")
	battle.wave_manager.clear_enemies()
	await capture("03_mobile_combat")
	var pause_button := (battle.hud as BattleHud).encyclopedia_button
	check(battle.mobile_joystick._is_touch_blocked(pause_button.get_global_rect().get_center()), "joystick yields to top bar pause hit area")
	await tap((battle.hud as BattleHud).settings_button)
	check(flow.current_state == MainFlowCoordinator.STATE_BATTLE_UTILITY, "native touch opens battle settings")
	if flow.current_state != MainFlowCoordinator.STATE_BATTLE_UTILITY: flow.request_battle_utility("settings")
	await frames(20)
	check_settings(battle.utility_overlay._settings_view, "battle")
	await capture("04_mobile_battle_settings")
	flow.close_battle_utility()
	await frames()
	check(not flow.can_open_battle_utility("encyclopedia"), "phone encyclopedia is unavailable")
	await tap(pause_button)
	check(flow.current_state == MainFlowCoordinator.STATE_ESC_OVERLAY, "native touch on ESC opens inventory on phone")
	check(battle.mobile_joystick._active_touch_index < 0, "tapping ESC never starts a joystick gesture")
	if flow.current_state != MainFlowCoordinator.STATE_ESC_OVERLAY: flow.request_esc_overlay()
	await get_tree().create_timer(0.5).timeout
	await frames(16)
	# Even an explicit editing request cannot recreate mode buttons on a phone.
	var strip := battle.esc_overlay.weapon_strip
	strip.set_loadout(battle.loadout, false, true)
	await frames()
	check(strip._cast_mode_buttons.is_empty() and not strip._cast_mode_layer.visible, "inventory strip cannot show manual/auto icons")
	var hud := battle.hud as BattleHud
	var skin := hud.stats_drawer.get_node("ParchmentPanelSkin") as Control
	var skin_rect := skin.get_global_rect()
	var scroll_rect := hud.stats_scroll.get_global_rect()
	var relic_panel := battle.esc_overlay.center_container.get_node("RelicPanel") as Control
	var relic_rect := relic_panel.get_global_rect()
	var strip_rect := strip.get_global_rect()
	check(is_equal_approx(skin_rect.size.x, 416.0 * 0.85) and is_equal_approx(skin_rect.end.x, get_viewport().get_visible_rect().end.x), "85 percent stats metal frame fits right edge")
	check(is_equal_approx(get_viewport().get_visible_rect().end.y - skin_rect.end.y, 8.0), "stats frame extends to bottom game edge")
	check(scroll_rect.position.x >= skin_rect.position.x + 57.0 and scroll_rect.end.x <= skin_rect.end.x - 52.0 and scroll_rect.size.x >= 220.0, "stats text uses the 90 percent inner area")
	check(is_equal_approx(scroll_rect.position.y - skin_rect.position.y, 123.0), "stats begin below parchment roller with inner breathing room")
	check(is_equal_approx(relic_rect.position.x, strip_rect.position.x) and is_equal_approx(relic_rect.end.x, strip_rect.end.x), "relic and weapon frames share both horizontal edges")
	check(is_equal_approx(strip_rect.position.x, hud.get_modal_safe_rect().position.x) and is_equal_approx(strip_rect.size.x, hud.get_modal_safe_rect().size.x), "inventory fills the safe width from the left edge on wide phones")
	check(is_equal_approx(skin_rect.position.x - strip_rect.end.x, 32.0), "inventory sits close to stats with room for toggle")
	check(not hud._economy_log_layer.visible and not hud._economy_log.toggle_button.is_visible_in_tree(), "ESC hides economy log button")
	check(is_equal_approx(hud.economy_panel.position.x, skin_rect.position.x), "balances align with stats frame left edge")
	check(hud.economy_panel.get_global_rect().end.x <= hud.encyclopedia_button.get_parent().get_global_rect().position.x, "balances clear top right actions")
	await capture("05_mobile_inventory")
	check(not pause_button.disabled, "ESC remains tappable while inventory is open")
	await tap(pause_button)
	await get_tree().create_timer(0.2).timeout
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and not battle.esc_overlay.visible, "second native tap on ESC closes inventory and resumes combat")
	await frames()
	check(hud._economy_log_layer.visible, "closing ESC restores combat log")
	var held_touch := InputEventScreenTouch.new()
	held_touch.index = 0
	held_touch.position = get_viewport().get_screen_transform() * (get_viewport().get_visible_rect().size * Vector2(0.3, 0.65))
	held_touch.pressed = true
	Input.parse_input_event(held_touch)
	await frames(2)
	check(battle.mobile_joystick._active_touch_index == 0, "open battlefield touch still starts joystick")
	await tap(pause_button, 1)
	check(flow.current_state == MainFlowCoordinator.STATE_ESC_OVERLAY, "second finger opens ESC while joystick is held")
	held_touch.pressed = false
	Input.parse_input_event(held_touch)
	flow.close_esc_overlay()
	await frames()
	await check_night_guidance(battle)
	flow.request_shared_reward_shop_popup(4, "device_feedback_review")
	await frames(20)
	var rewards := game.find_child("ShopPopup", true, false) as ShopPopup
	check(rewards != null and rewards.visible and rewards.offer_grid.columns <= 3, "phone rewards use up to three columns")
	check(rewards.title_label.get_theme_font_size("font_size") == 24, "reward heading is smaller on phone")
	for card: RewardOption in rewards._offer_cards:
		check(card.name_label.get_theme_font_size("font_size") >= 20 and card.description_label.get_theme_font_size("normal_font_size") >= 18, "reward text is readable")
		check(card.icon_frame.size.y <= 70 and card.select_button.size.y >= 40, "reward icon shrinks and touch action remains large")
	await get_tree().create_timer(0.6).timeout
	await capture("06_mobile_rewards")
	flow.close_shared_reward_shop_popup()
	await frames()
	flow.present_battle_result(false)
	await frames()
	var result := game.find_child("BattleResultPanel", true, false) as RunSettlementPanel
	result.sound_enabled = false
	var sample := {"run_id": "device-feedback-review", "kills": 1800, "gold": 2500, "waves": 8, "interest": 1600, "has_advice": true, "monsters": {"enemy_mutated_grub": 1400, "enemy_echo_bat": 370, "enemy_elite_rusher": 18, "enemy_underworld_wolf": 12}}
	var preview_report := RunSettlement.build(sample, false)
	preview_report.paid = true
	result.present(preview_report)
	result.skip()
	await frames(16)
	check(result._scroll.get_global_rect().encloses(result._total.get_global_rect()), "entire talent payout fits settlement viewport")
	check(result._scroll.get_global_rect().encloses(result._portrait.get_global_rect()), "entire goblin portrait fits settlement viewport")
	check(result._rows[0].panel.size.y <= 64, "settlement stat strips are shorter")
	await capture("07_mobile_settlement")
	result.queue_free()
	game.queue_free()
	await frames(12)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("MOBILE_CONTROLS_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check_night_guidance(battle: BattleRoot) -> void:
	var phase := battle.wave_manager.evacuation as NightEvacuation
	phase.set_physics_process(false)
	phase.begin()
	check(phase.active, "real night evacuation starts for guidance review")
	var visual := phase.visual
	var bar := (battle.hud as BattleHud).combat_bar
	var hud := battle.hud as BattleHud
	var original_weapons := bar.weapons.duplicate()
	var original_position := battle.player.global_position
	hud.set_process(false)
	for count in [1, 6, 24]:
		var sources: Array[WeaponInstance] = []
		for i in count: sources.append(original_weapons[0])
		bar.setup(sources)
		await frames()
		if count == 24: check(bar.columns < count, "night guidance also covers a two-row weapon bar")
		for offset in [Vector2(0, 1700), Vector2(1700, 1700), Vector2(-1700, 1700), Vector2(0, -1700), Vector2(0, 300)]:
			battle.player.global_position += phase.ring_center - offset - phase.foot_position()
			phase.previous_foot = phase.foot_position()
			battle.player._sync_camera()
			battle.player.camera_2d.force_update_scroll()
			await frames()
			visual.refresh()
			check(not visual.distance_label.get_global_rect().intersects(bar.get_global_rect()), "night caption clears weapon bar: " + str(count) + " " + str(offset))
			if visual.show_arrow:
				var arrow_bounds := Rect2(visual.arrow_position - Vector2.ONE * 45 * visual.guide_scale, Vector2.ONE * 90 * visual.guide_scale)
				check(not arrow_bounds.intersects(bar.get_global_rect()), "night arrow glow clears weapon bar: " + str(count) + " " + str(offset))
				check(get_viewport().get_visible_rect().encloses(arrow_bounds), "night arrow stays inside screen")
			if offset == Vector2(0, 1700) and count == 6: await capture("08_mobile_night_guidance")
	bar.setup(original_weapons)
	hud.set_process(true)
	phase.reset()
	battle.player.global_position = original_position
	battle.player._sync_camera()
	battle.player.camera_2d.force_update_scroll()
	await frames()
