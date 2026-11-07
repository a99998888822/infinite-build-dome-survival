extends Node
## Layout capture for review: boots the production game and saves one frame per
## surface. Usage: --capture-dir=<absolute path> [--window=WxH] [--mobile-ui]

var capture_dir := ""
var window_size := Vector2i(1920, 1080)
var game: GameRoot
var battle: BattleRoot


func _ready() -> void:
	_go.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _go() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(int(parts[0]), int(parts[1]))
	if capture_dir.is_empty():
		push_error("CAPTURE missing --capture-dir")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	CampProgression.begin_transient_session()
	seed(20261105)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(14)
	_apply_window_size()
	await frames(6)
	await _save("00_main_menu")
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(10)
	await _save("01_character_select")
	if not flow.confirm_character_selection():
		push_error("CAPTURE could not enter the battle")
		get_tree().quit(2)
		return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	await frames(8)
	var guard := 0
	while flow.get_current_state() == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and guard < 4:
		guard += 1
		await _save("02_opening_rewards_%d" % guard)
		flow.close_shared_reward_shop_popup()
		await frames(6)
	flow.request_next_wave()
	await frames(150)
	await _save("03_combat_hud")
	var hud := battle.get_node_or_null("HUD")
	if hud != null and hud.has_method("_set_drawer_open"):
		hud._set_drawer_open(true, false)
		await frames(14)
		await _save("04_stats_drawer")
		hud._set_drawer_open(false, false)
		await frames(6)
	flow.request_esc_overlay()
	# The drawer animates open over ~0.36s; capture only after it settles.
	await frames(45)
	await _save("05_esc_overlay")
	flow.close_esc_overlay()
	await frames(10)
	if flow.has_method("_request_wave_end_finance") and flow._request_wave_end_finance():
		await frames(30)
		await _save("06_bank_shop")
		var popup := game.find_child("FinancePopup", true, false) as FinancePopup
		if popup != null and popup.has_method("_select_tab"):
			popup._select_tab("enchant")
			await frames(14)
			await _save("07_enchant_tab")
	print("CAPTURE_DONE dir=%s window=%s mobile=%s" % [capture_dir, window_size, MobileProfile.is_mobile()])
	get_tree().quit(0)


func _apply_window_size() -> void:
	# A decorated window is clamped to the desktop work area, which would turn a
	# 2400x1080 phone capture into 1904x1071 on a 1920x1080 monitor. Borderless
	# keeps the requested framebuffer size and does not appear in the image.
	var root := get_tree().root
	root.borderless = true
	if root.size != window_size:
		root.size = window_size
	if MobileProfile.is_mobile():
		# GameRoot enters with KEEP after MobileProfile's ready; on a phone
		# WindowSettings runs at startup and re-applies the phone presentation,
		# but it skips that under --background-capture. Restore it here so the
		# 20:9 frame shows the extra battlefield instead of letterboxing.
		root.content_scale_factor = MobileProfile.ui_scale
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _save(name: String) -> void:
	# Re-assert the framebuffer before every frame: startup code in other
	# systems can still touch the window size after the first resize.
	_apply_window_size()
	await frames(2)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	print("CAPTURE_SIZE %s image=%s vis=%s aspect=%d factor=%.2f" % [
		name,
		str(image.get_size()),
		str(get_viewport().get_visible_rect().size),
		get_tree().root.content_scale_aspect,
		get_tree().root.content_scale_factor,
	])
	var path := capture_dir.path_join(name + ".png")
	if image.save_png(path) != OK:
		push_error("CAPTURE failed to save " + path)
	else:
		print("CAPTURE_SAVED %s %s" % [path, str(image.get_size())])
