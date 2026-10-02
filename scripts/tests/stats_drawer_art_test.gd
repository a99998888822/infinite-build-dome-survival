extends Node
## Exercises the installed art in the real HUD, including native GPU captures.
var output := ""
var failures := 0
var game: GameRoot
var hud: BattleHud
var skin: Control
var handle: TextureRect
var records: Array[Dictionary] = []
@onready var root: Window = get_tree().root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(90).timeout
	push_error("STATS_ART_TEST_TIMEOUT")
	get_tree().quit(99)


func frames(count: int = 8) -> void:
	for _i in count: await get_tree().process_frame


func check(value: bool, note: String) -> void:
	print("PASS " if value else "FAIL ", note)
	if not value: failures += 1


func _run() -> void:
	seed(20260929)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	root.unfocusable = true
	root.always_on_top = false
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	await frames()
	var flow := game.get_main_flow_coordinator()
	var starting: Array[String] = ["weapon_void_blade"]
	flow.enter_battle_selection("character_void_hunter", starting)
	await frames()
	check(flow.confirm_character_selection(), "entered real battle")
	await frames(12)
	hud = game.find_child("HUD", true, false) as BattleHud
	var manager := hud._wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	flow.get_bound_player().set_physics_process(false)
	flow.get_bound_player().set("_invincibility_timer", 1000.0)
	flow.get_bound_loadout().set_process(false)
	manager.apply_gold_delta(500, "art_test")
	skin = hud.find_child("WoodAndChainSkin", true, false) as Control
	handle = hud.find_child("LeatherPullHandle", true, false) as TextureRect
	check(skin.get_script().resource_path == "res://scripts/ui/stats_drawer_skin.gd", "uses production skin")
	check(handle.texture.resource_path == "res://assets/ui/stats_drawer/stats_leather_handle.png", "uses production handle")
	check(handle.texture.get_size() == Vector2(44, 40), "installed handle is 44x40")
	check(hud.stats_drawer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest pixel filtering")
	for viewport_size in [Vector2i(1152, 648), Vector2i(1024, 576), Vector2i(1920, 1080)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await frames(12)
		hud._set_drawer_open(true, false)
		await frames(3)
		var origin := skin.global_position + Vector2(floorf((skin.size.x - 288.0) / 2.0), 0)
		var rivet := handle.get_global_transform() * Vector2(32, 19) - origin
		check(is_equal_approx(rivet.x, 11.0), "rivet on metal at " + str(viewport_size))
		check(handle.size == Vector2(44, 40), "native handle size at " + str(viewport_size))
		await capture("battle_%dx%d" % [viewport_size.x, viewport_size.y])
		hud._set_drawer_open(false, false)
		await frames(4)
		var exposed := handle.get_global_rect().intersection(root.get_visible_rect())
		var click_area := hud.drawer_toggle_button.get_global_rect().intersection(root.get_visible_rect())
		check(exposed.size.x >= 12.0 and click_area.size.x >= 12.0, "closed handle remains visible and clickable")
		await capture("closed_%dx%d" % [viewport_size.x, viewport_size.y])
		# Route a real mouse click through Control hit testing, rather than emitting pressed.
		var point := click_area.get_center()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
			await frames(2)
		check(hud.is_stats_drawer_open(), "mouse click reopens drawer")
		hud._set_drawer_open(true, false)
		hud.stats_scroll.scroll_vertical = 100000
		await frames(3)
		var bar := hud.stats_scroll.get_v_scroll_bar()
		check(is_equal_approx(bar.value, maxf(0, bar.max_value - bar.page)), "last attribute remains reachable")
		hud.stats_scroll.scroll_vertical = 0
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	await frames(10)
	hud._set_drawer_open(true, false)
	flow.finish_current_wave()
	await frames(25)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.stop()
	popup.portrait.set_process(false)
	popup.portrait._elapsed = 0.0
	popup.portrait.queue_redraw()
	popup.cancel_trade("art_test")
	popup._select_tab("shop")
	check(popup.visible and hud.is_stats_drawer_open(), "finance locks stats open")
	check(popup.start_button.get_theme_stylebox("normal") is StyleBoxFlat, "original finance buttons")
	check(popup._tab_buttons.shop.get_theme_stylebox("normal") is StyleBoxFlat, "original finance tabs")
	check(not hud.stats_drawer.get_global_rect().intersects(popup.main_panel.get_global_rect()), "finance and stats do not overlap")
	await frames(10)
	await capture("finance_1152x648")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("capture_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"failures": failures, "records": records}, "\t") + "\n")
	print("STATS_ART_TEST_DONE failures=", failures)
	game.queue_free()
	await frames(3)
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(failures)


func capture(label: String) -> void:
	await frames(3)
	var record := {"name": label, "window": str(root.size), "skin": str(skin.get_global_rect()), "godot_focus": root.has_focus(), "always_on_top": root.always_on_top}
	if DisplayServer.get_name() != "headless" and not output.is_empty():
		await RenderingServer.frame_post_draw
		var im := root.get_texture().get_image()
		check(im.get_size() == root.size, "native screenshot " + label)
		# Godot may retain focus on its private desktop. The external launcher
		# verifies the actual desktop and zero foreground samples on the user's desktop.
		check(not root.always_on_top, "window is not topmost " + label)
		im.save_png(output.path_join(label + ".png"))
	records.append(record)
