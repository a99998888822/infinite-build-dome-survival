extends Node
## Minimal mobile layout capture: boot the production battle, clear the opening
## rewards, start a wave and save one frame per interesting surface.
## Usage: --capture-dir=<absolute path> [--window=2400x1080] [--mobile-ui]

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
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.size = window_size
	await frames(3)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(4)
	if not flow.confirm_character_selection():
		await _save("00_select_failed")
		get_tree().quit(2)
		return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	await frames(6)
	# Two camp opening rewards precede the first wave.
	var guard := 0
	while flow.get_current_state() == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and guard < 4:
		guard += 1
		flow.close_shared_reward_shop_popup()
		await frames(4)
	await _save("00_opening_done")
	flow.request_next_wave()
	await frames(150)
	await _save("01_combat_hud")
	var hud := battle.get_node_or_null("HUD")
	if hud != null and hud.has_method("_set_drawer_open"):
		hud._set_drawer_open(true, false)
		await frames(14)
		await _save("02_stats_drawer")
		hud._set_drawer_open(false, false)
		await frames(6)
	# The bank modal is the densest screen; capture it before quitting.
	if flow.has_method("_request_wave_end_finance") and flow._request_wave_end_finance():
		await frames(30)
		await _save("03_bank")
		_dump_region(Vector2(300, 60), Vector2(420, 160), "bank_top_left")
		_dump_text("金", "bank_money")
		_dump_text("本金", "bank_principal")
	print("CAPTURE_DONE dir=%s window=%s mobile=%s" % [capture_dir, window_size, MobileProfile.is_mobile()])
	get_tree().quit(0)


func _dump_region(origin: Vector2, extent: Vector2, tag: String) -> void:
	## Lists every visible control whose rect touches the probe, for layout triage.
	var probe := Rect2(origin, extent)
	var found: Array[String] = []
	for node in get_tree().root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not probe.intersects(control.get_global_rect()):
			continue
		var text := ""
		if control is Label:
			text = (control as Label).text
		elif control is RichTextLabel:
			text = (control as RichTextLabel).text
		elif control is Button:
			text = (control as Button).text
		if text.is_empty():
			continue
		found.append("%s(%s) rect=%s text=%s" % [control.name, control.get_class(), control.get_global_rect(), text.left(40)])
	print("DUMP %s probe=%s hits=%d" % [tag, probe, found.size()])
	for line in found:
		print("DUMP   " + line)


func _dump_text(needle: String, tag: String) -> void:
	## Reports every label whose text contains needle, with the width it needs.
	for node in get_tree().root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var text := ""
		if control is Label:
			text = (control as Label).text
		elif control is RichTextLabel:
			text = (control as RichTextLabel).text
		if text.is_empty() or not text.contains(needle):
			continue
		print("DUMP %s %s rect=%s min=%s parent=%s(%s) parent_rect=%s text=%s" % [
			tag, control.name, control.get_global_rect(), control.get_combined_minimum_size(),
			control.get_parent().name, control.get_parent().get_class(),
			(control.get_parent() as Control).get_global_rect() if control.get_parent() is Control else Rect2(),
			text.left(24)])


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := capture_dir.path_join(name + ".png")
	if image.save_png(path) != OK:
		push_error("CAPTURE failed to save " + path)
	else:
		print("CAPTURE_SAVED " + path)
