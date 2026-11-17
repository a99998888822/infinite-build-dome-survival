extends Node
## Phone capture of the unequipped-enchantment reminder shown by "next wave".
## Usage: --scene res://scenes/tests/mobile_enchant_notice_capture.tscn --
##        --capture-dir=<abs> [--window=WxH] [--mobile-ui]
## The scene drives the production battle, leaves one spare enchantment scroll
## and no free slot use, then presses the real next-wave button once.

var capture_dir := ""
var window_size := Vector2i(2400, 1080)
var failures := 0
var flow: MainFlowCoordinator
var popup: FinancePopup
var manager: WaveManager


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()
	get_tree().create_timer(150).timeout.connect(func(): get_tree().quit(99))


func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)


func frames(count := 6) -> void:
	for i in count:
		await get_tree().process_frame


func physical_ratio() -> Vector2:
	# Logical layout pixels to real framebuffer pixels; the phone canvas scales
	# by the profile factor, the desktop canvas stays 1:1.
	var visible := get_tree().root.get_visible_rect().size
	return Vector2(window_size) / visible


func click(logical_point: Vector2) -> void:
	# Window input is addressed in framebuffer pixels, layout rects are logical.
	var point := (logical_point * physical_ratio()).round()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_window().push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_window().push_input(event)
		await frames(3)


func capture(id: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	image.save_png(capture_dir.path_join(id + ".png"))
	print("CAPTURE_SAVED ", capture_dir.path_join(id + ".png"), " ", image.get_size())


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	seed(20102026)
	var root := get_tree().root
	root.borderless = true
	root.size = window_size
	if MobileProfile.is_mobile():
		root.content_scale_factor = MobileProfile.ui_scale
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(14)
	root.size = window_size
	await frames(4)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(10)
	check(flow.confirm_character_selection(), "production battle starts")
	await frames(14)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	# Enter the bank the way the production wave-end does.
	var opened := flow._request_wave_end_finance()
	print("FINANCE_REQUESTED ", opened, " state=", flow.get_current_state())
	if not opened:
		flow.finish_current_wave()
	await frames(24)
	# GPU startup is slower than headless: settle any modal the run queued first.
	var guard := 0
	while flow.get_current_state() != MainFlowCoordinator.STATE_FINANCE_POPUP and guard < 8:
		guard += 1
		print("WAITING_FOR_FINANCE state=", flow.get_current_state())
		if flow.get_current_state() == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
			flow.close_shared_reward_shop_popup()
		elif flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_CHALLENGE:
			flow.decide_wave_challenge(str(manager.wave_challenges.offer.token), false)
		else:
			flow._request_wave_end_finance()
		await frames(24)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	print("POPUP_FOUND ", popup != null, " visible=", popup != null and popup.visible)
	check(popup != null and popup.visible, "finance popup opens at wave end")
	if popup == null:
		get_tree().quit(2)
		return
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("notice_capture")
	manager.wave_challenges.pressure = {"comfortable": true}
	var inventory := manager.player.item_inventory
	var weapon := flow.get_bound_loadout().get_weapon_instances()[0]
	for item in weapon.get_attached_item_instances():
		flow.submit_enchantment_operation("detach", weapon.weapon_id, str(item.item_instance_id))
	inventory.clear()
	inventory.add_item_from_base("scroll_water", "notice_capture")
	popup.workbench.refresh()
	await frames(8)
	check(weapon.has_available_attachment_slot() and not inventory.get_available_items().is_empty(), "fixture has a free slot plus a spare scroll")
	check(popup._has_unused_enchantments(), "unused enchantment detected before the press")
	var button := popup.start_button.get_global_rect()
	print("START_BUTTON ", button)
	await click(button.get_center())
	await frames(6)
	check(popup._enchantment_notice.visible, "next wave shows the reminder")
	await frames(6)
	_report()
	await capture(_shot_name("01_notice"))
	# Second press leaves finance, as the production flow does.
	await click(popup.start_button.get_global_rect().get_center())
	await frames(10)
	print("FINANCE_ENCHANT_NOTICE_CAPTURE failures=", failures)
	get_tree().quit(1 if failures else 0)


func _shot_name(base: String) -> String:
	return ("%s_%dx%d" % [base, window_size.x, window_size.y])


func _report() -> void:
	var root := get_tree().root
	var visible := root.get_visible_rect()
	var ratio := physical_ratio()
	var notice := popup._enchantment_notice
	var body := notice.get_child(0) as VBoxContainer
	var message := body.get_child(0) as Label
	var hint := body.get_child(1) as Label
	var notice_rect := Rect2(notice.global_position, notice.size)
	var button_rect := popup.start_button.get_global_rect()
	var payload := {
		"mobile": MobileProfile.is_mobile(),
		"window": str(window_size),
		"logical_viewport": str(visible.size),
		"physical_ratio": str(ratio),
		"ui_scale": snappedf(MobileProfile.ui_scale, 0.001),
		"content_scale_factor": snappedf(root.content_scale_factor, 0.001),
		"content_scale_size": str(root.content_scale_size),
		"content_scale_aspect": root.content_scale_aspect,
		"scene_wide": popup._scene_wide,
		"main_panel": str(Rect2(popup.main_panel.global_position, popup.main_panel.size)),
		"notice_logical": str(notice_rect),
		"notice_physical": str(Rect2(notice_rect.position * ratio.x, notice_rect.size * ratio.x)),
		"notice_min": str(notice.get_combined_minimum_size()),
		"notice_screen_share": "%.1f%% x %.1f%%" % [notice_rect.size.x / visible.size.x * 100.0, notice_rect.size.y / visible.size.y * 100.0],
		"button_logical": str(button_rect),
		"message_font": message.get_theme_font_size("font_size"),
		"hint_font": hint.get_theme_font_size("font_size"),
		"message_lines": message.get_line_count(),
		"message_size": str(message.size),
	}
	print("NOTICE_METRICS ", JSON.stringify(payload))
