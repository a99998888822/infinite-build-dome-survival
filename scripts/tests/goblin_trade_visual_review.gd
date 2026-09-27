extends Node
## Review harness only. Sample offers originate here, not in the game flow.

var capture_dir := ""
var small := false
var capture := false
var reject_demo := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
			capture = true
		if arg == "--small": small = true
		if arg == "--reject-demo": reject_demo = true
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	seed(9262026)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(640, 360) if small else Vector2i(1152, 768)
	window.content_scale_size = window.size
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(2)
		return
	await frames(6)
	var manager := flow._bound_wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(420, "review_fixture")
	manager.finance_system.deposit(200, true)
	flow.finish_current_wave()
	await frames(12)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	var initial_gold := manager.get_current_gold()
	var initial_principal := manager.finance_system.principal
	var original_bank_rect := popup._bank.get_rect()
	# This copy comes from the user's earlier example and is not a new offer design.
	var copy := "存入 200 本金\n强力刷新 ×1" if small else "存入 200 本金\n获得 1 次强力刷新"
	popup.present_trade("再存一点，\n我给你看看真正的好东西。", copy, "本次刷新 · 幸运 +100")
	var presentation := popup.trade_presentation
	if not capture and DisplayServer.get_name() != "headless": return
	presentation.set_process(false)
	presentation.sound_enabled = false
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	for index in 160:
		presentation.seek(float(index) / 20.0)
		if reject_demo and index == 96:
			presentation._no.pressed.emit()
		popup.portrait._elapsed = float(index) / 20.0
		popup.portrait.expression = 3 if index in range(8, 70) else 0
		popup.portrait._reaction_left = 0.0
		popup.portrait.set_process(false)
		popup.portrait.queue_redraw()
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
			var error := window.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(3)
				return
	var unchanged := initial_gold == manager.get_current_gold() and initial_principal == manager.finance_system.principal
	var restored := not reject_demo or (not presentation.is_active() and popup._bank.get_rect() == original_bank_rect)
	print("TRADE_VISUAL_REVIEW small=", small, " frames=160 economy_unchanged=", unchanged, " layout_restored=", restored)
	CampProgression.end_transient_session()
	game.queue_free()
	await frames(3)
	get_tree().quit(0 if unchanged and restored else 1)
