extends "res://scripts/tests/echo_bat_review.gd"
## GPU capture of the formal bat at camera 1x. Reuses the behavior review's
## deterministic stepping; no effect-specific render override or replacement.
const OUTPUT := "res://artifacts/previews/bat_sonic_native/20261021-r01/runtime"
var native_records: Array = []


func _ready() -> void:
	WindowSettings._startup_applied = true
	_run.call_deferred()
	_watchdog.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("show_hints", false, false)
	get_window().unfocusable = true
	get_window().size = Vector2i(1920,1080)
	get_window().content_scale_size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(20)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(6)
	check(flow.confirm_character_selection(), "formal battle opens")
	await frames(30)
	battle = game.get_node("SceneDirector").battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.loadout.set_physics_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	player = battle.player
	player.set_physics_process(false)
	player.camera_2d.position_smoothing_enabled = false
	player.camera_2d.zoom = Vector2.ONE
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await reset(Vector2(-180,0), Vector2.ZERO, 0)
	player.camera_2d.global_position = Vector2(-75,-30)
	player.camera_2d.offset = Vector2.ZERO
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	# Review-only clearing matches the prior body review; keep formal terrain.
	var ground := get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	ground.set_process(false)
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if node is CanvasItem and node.has_meta("scenery"):
				var kind := str(node.get_meta("scenery").get("kind", ""))
				if kind in ["prop","grass","grass_batch","contact","cast_shadow"]: node.hide()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(580,345)
	label.text = "蝙蝠特效 · 正式场景 · 1920×1080 · 相机1倍"
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_constant_override("outline_size",4)
	layer.add_child(label)
	var hp_before := player.current_hp
	for index in 36:
		await step(3)
		if index > 16: bat.cooldown = 99
		for path in ["HUD", "BattleTopBar", "BattleTopBarBackground"]:
			var ui := battle.get_node_or_null(path) as CanvasLayer
			if ui != null: ui.hide()
		battle.hud._economy_log_layer.hide()
		battle.active_controller._cursor_layer.hide()
		var effects: Array = []
		if bat.charge.visible: effects.append(sprite_record("charge", bat.charge))
		if bat.warning.visible: effects.append(sprite_record("warning", bat.warning))
		for wave: EchoBatSonic in get_tree().get_nodes_in_group("echo_bat_projectiles"):
			if not wave.is_queued_for_deletion(): effects.append(sprite_record("hit" if wave.impacted else "wave",wave.visual))
		var file_name := "frame_%02d.png" % index
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(get_window().get_texture().get_image().save_png(OUTPUT.path_join(file_name)) == OK, "save " + file_name)
		native_records.append({"file":file_name,"state":bat.skill_state,"hp":player.current_hp,"effects":effects})
	check(player.current_hp == hp_before-7, "real flight hits once for configured damage")
	for spec: Array in [[EchoBatSonic.WAVE,"wave"],[EchoBat.CHARGE,"charge"],[EchoBatSonic.HIT,"hit"]]:
		check(spec[0].get_image().save_png(OUTPUT.path_join("loaded_"+spec[1]+".png")) == OK, "save actual imported texture")
	var file := FileAccess.open(OUTPUT.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"window":[1920,1080],"camera_zoom":1,"staged_input":true,"review_only_scenery_hidden":true,"records":native_records},"  "))
	file.close()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(6)
	CampProgression.end_transient_session()
	print("BAT_SONIC_NATIVE_REVIEW checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)


func sprite_record(kind: String, sprite: Sprite2D) -> Dictionary:
	var pos := sprite.get_global_transform_with_canvas()*Vector2.ZERO
	var size := sprite.get_rect().size
	return {"kind":kind,"frame":sprite.frame,"size":[size.x,size.y],"scale":[sprite.global_scale.x,sprite.global_scale.y],"screen_center":[pos.x,pos.y],"rotation":sprite.global_rotation,"coarse_material":sprite.material != null}
