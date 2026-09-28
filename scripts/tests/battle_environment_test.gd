extends Node
## Exercise the production scene and stream decoration across camera cells.
var game: GameRoot
var battle: BattleRoot
var capture_dir := ""
var baseline := ""
var failures := 0
var snapshots: Dictionary = {}
const SCENERY = preload("res://scripts/battle/battle_scenery_catalog.gd")


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--baseline="): baseline = arg.trim_prefix("--baseline=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(60).timeout
	push_error("BATTLE_ENVIRONMENT_TIMEOUT")
	get_tree().quit(99)


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)


func _run() -> void:
	CampProgression.begin_transient_session()
	_check_catalog()
	seed(9282026)
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152,648)
	get_tree().root.content_scale_size = Vector2i(1152,648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start production battle")
	await frames(10)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	var ground := get_tree().get_first_node_in_group("battle_wetland") as WetlandBackdrop
	var camera := battle.player.get_viewport().get_camera_2d()
	var locations := {"01_center": Vector2.ZERO, "02_wetland": Vector2(480,280), "03_outskirts": Vector2(-850,-300), "04_return": Vector2.ZERO}
	for label in locations:
		battle.player.global_position = locations[label]
		battle.player._sync_camera()
		camera.reset_smoothing()
		camera.force_update_scroll()
		await frames(12)
		var points: Array[String] = []
		var density_ok := true
		var placement_ok := true
		for cell in ground._cells.values():
			density_ok = density_ok and cell.get_child_count() <= 3
			for decal in cell.get_children():
				points.append("%d,%d" % [roundi(decal.position.x),roundi(decal.position.y)])
				placement_ok = placement_ok and ground.is_wet_at(decal.global_position)
				placement_ok = placement_ok and is_equal_approx(decal.scale.x,decal.scale.y)
				placement_ok = placement_ok and decal.texture is AtlasTexture and decal.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		points.sort()
		check(density_ok, "all cells keep density <= 3 at " + label)
		check(placement_ok, "cropped nearest-neighbor art keeps aspect ratio and stays off central floor " + label)
		snapshots[label] = points
		check(ground._cells.size() == ground._cell_rect.size.x * ground._cell_rect.size.y, "streamed cells reclaimed " + label)
		await capture(label)
	check(snapshots["01_center"] == snapshots["04_return"], "decoration positions stable after leaving and returning")
	if not baseline.is_empty():
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline))
		check(snapshots == original, "same decoration count and positions as original scene at all four locations")
	if not capture_dir.is_empty():
		var report := FileAccess.open(capture_dir.path_join("placements.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify(snapshots,"  "))
	var clock := ground.get_environment_time()
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await frames(8)
	check(is_equal_approx(clock,ground.get_environment_time()), "environment pauses with battle")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	await frames(8)
	check(ground.get_environment_time() > clock, "environment resumes")
	var ripple_index := ground._ripple_cursor
	ground.spawn_ripple(Vector2(480,300),0.9)
	ground._update_ripples(1.0)
	var ripple := ground._ripples[ripple_index]
	check(ripple.visible and ripple.texture is AtlasTexture and ripple.texture.get_width() * ripple.scale.x <= 53.0, "ripple keeps original physical size despite 128px canvas")
	ground._update_ripples(2.0)
	check(not ripple.visible, "ripple pool expires normally")
	get_tree().root.size = Vector2i(640,360)
	get_tree().root.content_scale_size = Vector2i(640,360)
	await frames(12)
	var ruins: Node2D = battle.get_node("BattleSky/DistantRuins")
	var horizon_ok := true
	for placement: Dictionary in ruins.get_placements():
		var rect: Rect2 = placement.rect
		horizon_ok = horizon_ok and rect.position.y >= 59.0 and rect.size.y > 0.0
		horizon_ok = horizon_ok and is_equal_approx(rect.end.y,float(placement.waterline))
	check(horizon_ok, "small-window ruins remain below HUD and share reflection waterline")
	await capture("05_small_window")
	get_tree().root.size = Vector2i(1152,648)
	get_tree().root.content_scale_size = Vector2i(1152,648)
	battle.player.global_position = Vector2(480,280)
	battle.player._sync_camera()
	battle.player.set_physics_process(true)
	battle.wave_manager.set_process(true)
	await frames(240)
	check(battle.player.alive and battle.wave_manager.wave_time_left < 29.0, "normal battle runs with new scenery")
	await capture("06_live_combat")
	flow.enter_start_page()
	await frames(60)
	check(get_tree().get_nodes_in_group("battle_wetland").is_empty(), "normal return to menu releases streamed environment")
	game.queue_free()
	await frames(8)
	check(get_tree().get_nodes_in_group("battle_wetland").is_empty(), "environment released with battle")
	CampProgression.end_transient_session()
	print("BATTLE_ENVIRONMENT_COMPLETE failures=", failures)
	get_tree().quit(1 if failures else 0)


func _check_catalog() -> void:
	var config := SCENERY.get_config()
	check(config.assets.size() == 30, "all thirty approved assets registered")
	var valid := true
	for asset_id: String in config.assets:
		var definition: Dictionary = config.assets[asset_id]
		var texture := SCENERY.get_texture(asset_id)
		valid = valid and texture.atlas.get_size() == Vector2(128,128)
		valid = valid and Rect2(Vector2.ZERO,Vector2(128,128)).encloses(texture.region)
		valid = valid and FileAccess.get_sha256(str(definition.texture)) == str(definition.sha256)
	check(valid, "copied PNG hashes and content bounds match approved package")
	var max_moss := 0.0
	for asset_id: String in config.groups.moss:
		max_moss = maxf(max_moss,float(config.assets[asset_id].world_extent)*1.08)
	check(max_moss < float(config.assets.decal_single_brick.world_extent)*0.9, "moss remains smaller than single brick including size variation")
	check(SCENERY.get_depth_scale(0.25,0.2) < SCENERY.get_depth_scale(0.9,0.2), "same asset smaller in distance")
