extends Node
## Exercise both reward entrances on the native canvas and resized windows.

var failures: Array[String] = []
var checks := 0
var output := ""
var baseline := false
var game: GameRoot
var battle: BattleRoot
var popup: ShopPopup


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg == "--baseline": baseline = true
	_run.call_deferred()


func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "save " + label)


func click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)


func verify_layout(label: String) -> void:
	var viewport := get_viewport().get_visible_rect()
	var hud := battle.hud as BattleHud
	var panel := popup.main_panel.get_global_rect()
	var safe := hud.get_modal_safe_rect()
	check(popup.visible and popup._offer_cards.size() >= 3, label + " shows reward choices")
	check(viewport.encloses(panel), label + " panel fits canvas")
	check(safe.grow(1).encloses(panel), label + " panel clears stats drawer")
	check(panel.size.x >= safe.size.x * 0.85, label + " panel uses the native reward area")
	check(absf(panel.get_center().x - safe.get_center().x) <= 1, label + " panel centered beside drawer")
	check(popup.weapon_strip.get_global_rect().end.y < panel.position.y, label + " loadout stays above rewards")
	check(panel.encloses(popup.skip_button.get_global_rect()), label + " skip stays in panel")
	check(panel.encloses(popup.refresh_button.get_global_rect()), label + " reroll stays in panel")
	var columns := 4
	var rows := 2
	var gap := popup.offer_grid.get_theme_constant("v_separation")
	var card_height := (popup.offer_scroll.size.y - gap * (rows - 1)) / rows
	check(popup.offer_grid.columns == columns, label + " fixed four columns even with three choices")
	check(popup.center_container.scale == Vector2.ONE and popup.weapon_strip.scale == Vector2.ONE, label + " native layout has no presentation scaling")
	check(panel.size == Vector2(1312, 896), label + " native panel uses explicit pixel dimensions")
	check(not popup.offer_scroll.get_v_scroll_bar().visible, label + " up to eight cards need no scrolling")
	var column_gap := popup.offer_grid.get_theme_constant("h_separation")
	var card_width := (popup.offer_scroll.size.x - column_gap * (columns - 1)) / columns
	for index in popup._offer_cards.size():
		var card := popup._offer_cards[index]
		var card_rect := card.get_global_rect()
		check(panel.encloses(card_rect), label + " card fits panel: " + str(card.offer_data.target_id))
		check(card_rect.encloses(card.select_button.get_global_rect()), label + " selection stays inside card")
		check(absf(card.size.y - card_height) <= 1, label + " cards fit the settled container height")
		check(absf(card.size.x - card_width) <= 1, label + " fixed cell width independent of reward count")
		var cell_origin := popup.offer_scroll.global_position + Vector2((index % columns) * (floorf(card_width) + column_gap), floorf(float(index) / columns) * (floorf(card_height) + gap))
		check(card_rect.position.distance_to(cell_origin) <= 1, label + " row-major fixed cell position")
		check(popup.offer_scroll.get_global_rect().grow(1).encloses(card_rect), label + " card stays inside reward area")
		var font_scale := card.get_global_transform_with_canvas().get_scale().y
		check(is_equal_approx(font_scale, 1.0), label + " card renders directly on native canvas")
		check(card.name_label.get_theme_font_size("font_size") >= 18, label + " native title font size")
	print("REWARD_LAYOUT ", label, " safe=", safe, " panel=", panel, " scroll=", popup.offer_scroll.get_global_rect())


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	seed(19102026)
	get_tree().root.size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "production battle starts")
	await frames(16)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	while flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
		flow.close_shared_reward_shop_popup()
	if flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	battle.set_process(false)
	battle.wave_manager.current_gold = 1000
	popup = game.find_child("ShopPopup", true, false) as ShopPopup
	flow.request_shared_reward_shop_popup(4)
	await get_tree().create_timer(1.0).timeout
	verify_layout("level_1920")
	await capture("level_1920")
	var weapon_button := popup.weapon_strip._weapon_buttons[0]
	var motion := InputEventMouseMotion.new()
	motion.position = weapon_button.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	await frames()
	var tooltip := popup.weapon_strip.weapon_tooltip
	check(tooltip.visible, "native weapon strip accepts pointer hover")
	check(tooltip.global_position.y >= weapon_button.get_global_rect().end.y - 3, "weapon tooltip clears the native icon")
	var old_ids := flow._active_shop_offer_ids.duplicate()
	await click(popup.refresh_button)
	await get_tree().create_timer(0.8).timeout
	check(flow._active_shop_offer_ids != old_ids, "native reroll accepts pointer")
	for dimensions in [Vector2i(1184, 666), Vector2i(1280, 720), Vector2i(2560, 1440)]:
		get_tree().root.size = dimensions
		await frames(12)
		check(get_viewport().get_visible_rect().size.is_equal_approx(Vector2(1920, 1080)), "stable logical canvas at " + str(dimensions))
		verify_layout("level_" + str(dimensions.x))
	get_tree().root.size = Vector2i(1920, 1080)
	L10n.set_locale("en", false)
	battle.player.modifier_stack.set_base_stat("shop_offer_count_bonus", 5)
	check(bool(flow.request_shop_refresh().get("success", false)), "refresh expanded reward choices")
	await get_tree().create_timer(1.0).timeout
	check(popup._offer_cards.size() == 8, "bonus produces eight reward choices")
	verify_layout("eight_choices_en")
	await capture("eight_choices_en")
	battle.player.modifier_stack.set_base_stat("shop_offer_count_bonus", 0)
	L10n.set_locale("zh_CN", false)
	await click(popup.skip_button)
	check(not popup.visible, "skip accepts pointer and closes level reward")
	battle.wave_manager._on_relic_choice_collected("layout_miniboss")
	await get_tree().create_timer(1.0).timeout
	verify_layout("miniboss_1920")
	check(popup.payload.get("choice_id", "") == "layout_miniboss", "miniboss uses its own reward payload")
	for card in popup._offer_cards:
		check(card.offer_data.offer_type == "relic", "miniboss offers relics")
	await capture("miniboss_1920")
	var relics_before := battle.player.relic_system.get_total_relic_count()
	await click(popup._offer_cards[0].select_button)
	check(battle.player.relic_system.get_total_relic_count() == relics_before + 1, "native selection grants exactly one relic")
	check(not popup.visible, "selection closes miniboss reward")
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("REWARD_POPUP_LAYOUT_COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if baseline or failures.is_empty() else 1)
