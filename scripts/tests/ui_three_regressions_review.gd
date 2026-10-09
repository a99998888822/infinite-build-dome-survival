extends Node
## Production UI and GPU evidence for marker lifetime, breathing, and shop bounds.

var output := ""
var baseline := false
var failures: Array[String] = []
var checks := 0
var samples: Dictionary = {}
var game: GameRoot
var flow: MainFlowCoordinator
var menu: MainMenuUIController
var battle: BattleRoot
var popup: FinancePopup


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg == "--baseline": baseline = true
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(100).timeout
	push_error("UI_THREE_REGRESSIONS_TIMEOUT")
	get_tree().quit(99)


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func shot(clip: String, index: int) -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	var directory := output.path_join(clip)
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().root.get_texture().get_image().save_png(directory.path_join("frame_%04d.png" % index))


func rendered_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw


func pointer(point: Vector2, button := 0, pressed := false) -> void:
	if button == 0:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		get_tree().root.push_input(motion)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		if DisplayServer.get_name() == "headless" and battle != null:
			battle.active_controller._input(event)
			battle.active_controller._unhandled_input(event)
		else:
			get_tree().root.push_input(event)


func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.set_option("keyboard_movement", false, false)
	L10n.set_locale("zh_CN", false)
	seed(9102026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	await frames(16)
	flow = game.get_main_flow_coordinator()
	menu = game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu._on_start_battle_pressed()
	pointer(Vector2(20, 20))
	await frames(12)
	await _breathing("character_void_hunter", "breathing_hunter")
	await _breathing("character_capitalist", "breathing_capitalist")
	menu.show_start_page()
	var weapons: Array[String] = ["weapon_void_blade"]
	flow.enter_battle_selection("character_void_hunter", weapons)
	await frames()
	check(flow.confirm_character_selection(), "production battle starts")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set("_invincibility_timer", 1000.0)
	battle.player.modifier_stack.set_base_stat("move_speed", 65)
	await _movement()
	await _shop()
	game.queue_free()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	CampProgression.end_transient_session()
	await frames(6)
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"baseline": baseline, "checks": checks, "failures": failures, "samples": samples, "fps": 30, "production": true}, "\t"))
	print("UI_THREE_REGRESSIONS_DONE checks=%d failures=%d baseline=%s" % [checks, failures.size(), baseline])
	get_tree().quit(0 if baseline or failures.is_empty() else 1)


func _breathing(id: String, clip: String) -> void:
	menu._on_character_selected(id)
	var view := menu.character_view
	view.reset_animation()
	await frames(3)
	var mask := SubViewport.new()
	mask.size = Vector2i(256, 256)
	mask.transparent_bg = true
	mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mask)
	var sprite := TextureRect.new()
	sprite.texture = view.character_icon.texture
	sprite.material = view.character_icon.material
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.size = Vector2(256, 256)
	mask.add_child(sprite)
	var bounds: Array = []
	for i in 90:
		await rendered_frame()
		shot(clip, i)
		if DisplayServer.get_name() != "headless":
			var used := mask.get_texture().get_image().get_used_rect()
			bounds.append([used.position.y, used.end.y, used.size.y])
	if not bounds.is_empty():
		var feet: Array = bounds.map(func(row): return row[1])
		var heights: Array = bounds.map(func(row): return row[2])
		check(int(feet.max()) - int(feet.min()) <= 1, id + " rendered feet stay grounded")
		check(int(heights.max()) - int(heights.min()) >= 4, id + " rendered height changes with breathing")
	samples[clip] = bounds
	mask.queue_free()
	view.hover_target.grab_focus()
	await frames(8)
	check(view.walking and view.walk_frame > 0, id + " hover/focus walking still animates")
	check(is_zero_approx(float(view._breath_material.get_shader_parameter("breath_amount"))), id + " walking resets breathing")
	view.hover_target.release_focus()
	view.reset_animation()


func _movement() -> void:
	var controller := battle.active_controller
	var marker := controller.marker
	var states: Array = []
	for i in 105:
		if i == 5 or i == 60:
			var point := Vector2(910, 340) if i == 5 else Vector2(680, 200)
			pointer(point)
			pointer(point, MOUSE_BUTTON_RIGHT, true)
			pointer(point, MOUSE_BUTTON_RIGHT, false)
		await rendered_frame()
		shot("movement", i)
		states.append({"frame": i, "active": marker.active, "visible": marker.visible, "elapsed": marker.elapsed, "moving": battle.player.has_move_destination})
		if i == 8 or i == 63: check(marker.active and marker.visible, "fresh right click replays marker at frame %d" % i)
		if i == 35 or i == 95: check(not marker.active and not marker.visible, "completed marker disappears at frame %d" % i)
	samples["movement"] = states
	controller.stop_movement()
	pointer(Vector2(900, 200), MOUSE_BUTTON_RIGHT, true)
	await frames(25)
	samples["held_marker"] = {"held": controller.right_held, "active": marker.active, "elapsed": marker.elapsed}
	check(controller.right_held and not marker.active and not marker.visible, "held right click does not restart an expired cue at the same target")
	pointer(Vector2(820, 240))
	await frames(2)
	check(marker.active and marker.visible, "moving a held pointer starts a new cue")
	pointer(Vector2(900, 200), MOUSE_BUTTON_RIGHT, false)
	controller.stop_movement()
	marker.show_destination(battle.player.global_position)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var before := marker.elapsed
	await frames(5)
	check(is_equal_approx(marker.elapsed, before), "paused marker does not consume lifetime")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	controller.clear_input()
	check(not marker.active and not marker.visible, "clearing input removes marker immediately")


func _shop() -> void:
	L10n.set_locale("en", false)
	battle.wave_manager.apply_gold_delta(500, "review")
	flow.finish_current_wave()
	await frames(15)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	battle.wave_manager.goblin_trades.cancel()
	popup.cancel_trade("review")
	var candidates := ShopOfferGenerator.new().build_shop_candidate_pool(flow._build_shop_context())
	var ordered: Array = []
	for id in ["weapon_rentier_purse", "relic_dividend_check", "weapon_camp_dagger"]:
		for offer in candidates:
			if str(offer.target_id) == id: ordered.append(offer)
	check(ordered.size() == 3, "real generator supplies purse, dividend check, and third card")
	flow._preparation_offers = ordered
	flow._active_shop_offers.clear()
	flow._active_shop_offer_ids.clear()
	for offer in ordered:
		flow._active_shop_offers[str(offer.offer_id)] = offer
		flow._active_shop_offer_ids.append(str(offer.offer_id))
	popup.configure(flow.get_preparation_payload())
	popup.shop_grid.set_offers(ordered, true)
	popup._select_tab("shop")
	pointer(Vector2(20, 20))
	await frames(10)
	for dimensions in [Vector2i(1152, 648), Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(640, 360)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = dimensions
		await frames(12)
		_check_shop_bounds(str(dimensions.x))
		await rendered_frame()
		shot("shop_" + str(dimensions.x), 0)
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	await frames(12)
	for i in 75:
		if i == 30: pointer(popup.shop_grid._pool[0].get_global_rect().get_center())
		if i == 50: pointer(popup.shop_grid._pool[1].get_global_rect().get_center())
		if i == 65: pointer(Vector2(20, 20))
		await rendered_frame()
		shot("shop", i)


func _check_shop_bounds(label: String) -> void:
	var grid := popup.shop_grid
	var width := (maxf(100, grid.size.x - 16) - grid.GAP * float(grid._columns - 1)) / float(grid._columns)
	var rows: Array = []
	for card in grid._pool:
		if not card.visible: continue
		rows.append({"id": card.offer.target_id, "width": card.size.x, "allocated_width": width, "minimum": str(card.get_combined_minimum_size()), "kind": card._kind_label.text})
		check(card.size.x <= width + 1, label + " card stays inside allocated width: " + str(card.offer.target_id))
		check(card.size.y <= grid._card_height + 1, label + " card stays inside allocated height: " + str(card.offer.target_id))
	for i in grid._pool.size():
		for j in range(i + 1, grid._pool.size()):
			var a := grid._pool[i]
			var b := grid._pool[j]
			if a.visible and b.visible: check(not a.get_rect().intersects(b.get_rect()), label + " cards do not overlap %d/%d" % [i, j])
	samples["shop_" + label] = rows
