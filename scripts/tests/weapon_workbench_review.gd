extends Node

var output := ""
var failures := 0
var checks := 0
var measurements: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "real battle starts")
	await frames()
	var loadout := flow.get_bound_loadout()
	for id in ["weapon_copper_lamp", "weapon_mutant_tentacle", "weapon_earth_hammer", "weapon_camp_dagger"]:
		check(loadout.equip_weapon(id), "fixture equips " + id)
	flow.get_bound_player().set_physics_process(false)
	flow._bound_wave_manager.set_process(false)
	flow._bound_wave_manager.clear_enemies()
	flow.finish_current_wave()
	await frames(30)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.stop()
	popup.cancel_trade("workbench_review")
	popup._select_tab("enchant")
	var bench := popup.workbench
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1152,768), Vector2i(1024,576)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = dimensions
		await frames(15)
		bench._weapon_scroll.scroll_horizontal = 0
		await frames()
		var bar := bench._weapon_scroll.get_h_scroll_bar()
		var cards := bench._weapon_row.get_global_rect()
		var track := bar.get_global_rect()
		var heading := bench._sell_weapon.get_global_rect()
		var card_gap := track.position.y - cards.end.y
		var sale_gap := heading.position.y - track.end.y
		check(bar.visible and track.size.y <= 10, "thin scrollbar appears for overflowing weapons")
		check(card_gap >= 16 and sale_gap >= 18, "scrollbar has requested padding above and below")
		check(bench._weapon_scroll.size.x <= popup._enchant_scroll.size.x, "weapon overflow stays inside its viewport")
		measurements.append({"viewport":[dimensions.x,dimensions.y],"track_height":track.size.y,"card_gap":card_gap,"sale_gap":sale_gap})
		await capture("workbench_%dx%d" % [dimensions.x,dimensions.y])
		bar.value = bar.max_value
		await frames()
		var last := bench._weapon_row.get_child(4) as Button
		check(bench._weapon_scroll.get_global_rect().encloses(last.get_global_rect()), "last weapon remains reachable by horizontal scroll")
		last.pressed.emit()
		await frames()
		check(bench.selected_weapon_id == "weapon_camp_dagger", "scrolled weapon can be selected")
		await capture("workbench_end_%dx%d" % [dimensions.x,dimensions.y])
	for id in ["weapon_copper_lamp", "weapon_mutant_tentacle", "weapon_earth_hammer", "weapon_camp_dagger"]:
		loadout.remove_weapon(id)
	bench.refresh()
	await frames()
	check(not bench._weapon_scroll.get_h_scroll_bar().visible, "scrollbar disappears when one weapon fits")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(measurements,"\t"))
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("WEAPON_WORKBENCH_TEST checks=",checks," failures=",failures," layout=",JSON.stringify(measurements))
	get_tree().quit(0 if failures == 0 else 1)


func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK,"save real UI capture")
