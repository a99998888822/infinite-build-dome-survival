extends Node
## Frame and type audit for the finance bank form, the economy log, the ESC
## weapon strip, the enchantment workbench and the wave challenge card.
## Plates are native 1920x1080 coordinates; no extra UI scaling is applied.

const MIN_DESKTOP_FONT := 18

var game: GameRoot
var flow: MainFlowCoordinator
var popup: FinancePopup
var output := ""
var checks := 0
var failures := 0
var report: Array[Dictionary] = []
var rects: Array[Dictionary] = []
var window_size := Vector2i(1920, 1080)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			window_size = Vector2i(int(parts[0]), int(parts[1]))
	_watchdog.call_deferred()
	_run.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(120).timeout
	push_error("FINANCE_UI_FRAME_REVIEW_TIMEOUT")
	get_tree().quit(99)


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.combat_guide_seen = true
	var root := get_tree().root
	# 1920x1080 is the native 1:1 canvas; other windows exercise fractional scaling.
	root.size = window_size
	root.content_scale_size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	check(flow.confirm_character_selection(), "production battle opened")
	await frames(12)
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		flow.finish_combat_guide()
		await frames(6)
	var manager := flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(520, "frame_review")
	flow.finish_current_wave()
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	for i in 90:
		if popup != null and popup.visible: break
		await frames(2)
	check(popup != null and popup.visible, "finance popup opened")
	if popup == null:
		get_tree().quit(2)
		return
	popup.interest_arrival.skip()
	if popup.trade_presentation != null and popup.trade_presentation.is_active():
		popup.cancel_trade("frame_review")
	await frames(8)
	popup._select_tab("bank")
	popup.economy_log.set_open(true)
	await frames(10)
	await capture("01_bank_log")
	_audit_bank_form()
	_audit_frames(popup.economy_log.panel, "economy log frame")
	popup.economy_log.set_open(false)
	await frames(6)
	await capture("02_bank")
	popup._select_tab("enchant")
	await frames(12)
	await capture("03_enchant")
	_audit_frames(popup.workbench, "enchantment workbench frame")
	popup._select_tab("shop")
	await frames(12)
	await capture("04_shop")
	popup.hide_popup()
	await frames(6)
	flow.request_esc_overlay()
	await frames(18)
	await capture("05_esc_weapon_strip")
	var strip: WeaponStrip = (game.find_child("EscOverlay", true, false) as EscOverlay).weapon_strip
	_audit_weapon_slots(strip)
	flow.close_esc_overlay()
	await frames(8)
	await _capture_challenge()
	_report()
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	print("FINANCE_UI_FRAME_REVIEW checks=%d failures=%d plates=%d" % [checks, failures, report.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _audit_bank_form() -> void:
	var controls: Array[Control] = [popup.amount_input, popup._deposit, popup._withdraw, popup.bank_confirm]
	for control in controls:
		var size := _font_size(control)
		report.append({"area": "bank", "control": control.get_class(), "font": size})
		_rect("bank_" + control.get_class() + "_" + str(controls.find(control)), control.get_global_rect())
		check(size >= MIN_DESKTOP_FONT, "bank control type size: %s %dpx" % [control.get_class(), size])
	for label in [popup._principal_protection, popup._bank_preview, popup._receipt, popup._contract]:
		if not label.visible: continue
		var size := _font_size(label)
		report.append({"area": "bank", "control": "Label", "font": size})
		check(size >= MIN_DESKTOP_FONT, "bank label type size: %dpx" % size)
	for key in popup._tab_buttons:
		var button: Button = popup._tab_buttons[key]
		_rect("tab_" + str(key), button.get_global_rect())
	_rect("log_toggle", popup.economy_log.toggle_button.get_global_rect())
	var heading := popup.economy_log.panel.find_child("LogTitle", true, false) as Label
	if heading != null:
		var log_font := _font_size(heading)
		report.append({"area": "log", "control": "heading", "font": log_font})
		check(log_font >= 15, "economy log heading type size: %dpx" % log_font)
	var body_font := _font_size(popup.economy_log.log_text)
	report.append({"area": "log", "control": "body", "font": body_font})
	check(body_font >= 15, "economy log body type size: %dpx" % body_font)
	var first_card: Control = null
	if popup.workbench._inventory.get_child_count() > 0:
		first_card = popup.workbench._inventory.get_child(0) as Control
	if first_card != null: _rect("enchant_card", first_card.get_global_rect())


func _font_size(control: Control) -> int:
	if control is LineEdit: return control.get_theme_font_size("font_size")
	if control is Button: return control.get_theme_font_size("font_size")
	if control is Label: return control.get_theme_font_size("font_size")
	if control is RichTextLabel: return control.get_theme_font_size("normal_font_size")
	return 0


func _audit_frames(control: Control, label: String) -> void:
	var style := control.get_theme_stylebox("panel")
	check(style != null, label + " has a panel skin")
	var rect := control.get_global_rect()
	report.append({"area": "frame", "control": label, "size": [rect.size.x, rect.size.y],
		"style": style.get_class() if style != null else "none"})
	_rect(label, rect)
	if style is NativeHudTextureStyle:
		var skin := style as NativeHudTextureStyle
		var needed_x: float = skin._native_margins[SIDE_LEFT] + skin._native_margins[SIDE_RIGHT]
		var needed_y: float = skin._native_margins[SIDE_TOP] + skin._native_margins[SIDE_BOTTOM]
		check(rect.size.x > needed_x + 4 and rect.size.y > needed_y + 4,
			"%s keeps room for its skirted border: %dpx x %dpx" % [label, rect.size.x, rect.size.y])


func _rect(name: String, rect: Rect2) -> void:
	rects.append({"name": name, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})


func _audit_weapon_slots(strip: WeaponStrip) -> void:
	for button in strip._weapon_buttons:
		var style := button.get_theme_stylebox("normal")
		var rect := button.get_global_rect()
		report.append({"area": "weapon_slot", "size": [rect.size.x, rect.size.y], "style": style.get_class()})
		_rect("weapon_slot", rect)
		check(style != null and rect.size.x >= 48 and rect.size.y >= 48, "weapon slot keeps a full slot frame")


func _capture_challenge() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	game.add_child(layer)
	var challenge := WaveChallengePopup.new()
	layer.add_child(challenge)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/wave_challenges.json"))
	check(config != null and not config.get("challenges", []).is_empty(), "challenge config loaded")
	for index in mini(2, config.challenges.size()):
		var proposal: Dictionary = config.challenges[index].duplicate(true)
		proposal["wave"] = 5
		proposal["token"] = "frame_review:%d" % index
		challenge.present(proposal)
		challenge.presentation.sound_enabled = false
		challenge.presentation.set_process(false)
		challenge.presentation.seek(20)
		await frames(6)
		for button: Button in [challenge.presentation._yes, challenge.presentation._no]:
			var style := button.get_theme_stylebox("normal")
			var rect := button.get_global_rect()
			report.append({"area": "challenge_button", "text": button.text, "size": [rect.size.x, rect.size.y],
				"style": style.get_class() if style != null else "none"})
			_rect("challenge_" + str(button.text), rect)
			check(style != null and rect.size.y >= 28 and rect.size.x >= 80, "challenge button frame fits: " + button.text)
		await capture("06_challenge_%d" % index)
	challenge.queue_free()
	await frames(4)


func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "GPU " + name)


func _report() -> void:
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"viewport": [1920, 1080], "window": [window_size.x, window_size.y], "min_font": MIN_DESKTOP_FONT,
		"checks": checks, "failures": failures, "controls": report, "rects": rects}, "\t"))
