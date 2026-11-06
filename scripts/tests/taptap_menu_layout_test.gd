extends Node
## Render the real menu with Android's account entry enabled on the test host.

var checks := 0
var failures := 0
var capture_dir := ""
var resolution := Vector2i(1920, 1080)
var account_requests := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			resolution = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + note)


func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	get_tree().root.borderless = true
	get_tree().root.size = resolution
	var game: Node = load("res://scenes/core/game_root.tscn").instantiate()
	add_child(game)
	await frames(24)
	var menu: Node = game.get_node("UiRoot/MainMenuUIController")
	TapTapSession._required = true
	menu._create_taptap_entry()
	TapTapSession._required = false
	TapTapSession.login_required.connect(func(): account_requests += 1)
	var actions: Control = menu.start_page.get_node("TopRightActions")
	var account_button: Button = actions.get_node("TapTapAccountButton")
	var language_row: Control = actions.get_node("LanguageSelector")
	var language_option: OptionButton = language_row.get_node("LanguageOption")
	var original_locale: String = L10n.locale
	for locale in ["zh_CN", "en"]:
		L10n.set_locale(locale)
		await frames()
		var account_rect := account_button.get_global_rect()
		var language_rect := language_row.get_global_rect()
		check(not account_rect.intersects(language_rect), "account and language never overlap: " + locale)
		check(language_rect.position.x - account_rect.end.x >= 23, "account and language keep touch spacing: " + locale)
		check(get_viewport().get_visible_rect().encloses(actions.get_global_rect()), "top actions fit phone: " + locale)
		if DisplayServer.get_name() != "headless":
			var before := account_requests
			await tap(account_button)
			check(account_requests == before + 1, "account responds to touch: " + locale)
			await tap(language_option)
			check(language_option.get_popup().visible, "language selector responds to touch: " + locale)
			language_option.get_popup().hide()
			await frames()
			if not capture_dir.is_empty():
				DirAccess.make_dir_recursive_absolute(capture_dir)
				await RenderingServer.frame_post_draw
				check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("menu-" + locale + ".png")) == OK, "capture " + locale)
	L10n.set_locale(original_locale)
	game.queue_free()
	await frames()
	print("TAPTAP_MENU_LAYOUT_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func tap(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var event := InputEventScreenTouch.new()
	event.index = 15
	event.position = get_viewport().get_screen_transform() * point
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
