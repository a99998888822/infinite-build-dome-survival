extends Node

# Review candidates or verify actual installed art through the real player controller.
# --installed checks loaded resources without injecting textures or animation settings.
var candidate_dir := ""
var installed := false
var output := ""
var kind := "void_hunter"
var checks := 0
var failures := 0
var samples: Array = []
var captures: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--installed": installed = true
		if arg.begins_with("--candidate-dir="): candidate_dir = arg.trim_prefix("--candidate-dir=")
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--character="): kind = arg.trim_prefix("--character=")
	_run.call_deferred()


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func visible_pixels_match(actual: Image, expected: Image) -> bool:
	if actual == null or actual.get_size() != expected.get_size(): return false
	# Godot's alpha-border import may fill RGB under fully transparent pixels.
	for y in expected.get_height():
		for x in expected.get_width():
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			if not is_equal_approx(a.a, b.a) or (b.a > 0 and not a.is_equal_approx(b)): return false
	return true


func _run() -> void:
	if candidate_dir.is_empty() or kind not in ["void_hunter", "capitalist"]:
		push_error("Pass --candidate-dir and --character=void_hunter|capitalist")
		get_tree().quit(2)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(candidate_dir.path_join("integration_manifest.json")))
	var contract: Dictionary = {}
	for entry: Dictionary in manifest.characters:
		if str(entry.key) == kind: contract = entry
	var idle := Image.load_from_file(candidate_dir.path_join(str(contract.idle)))
	var walk := Image.load_from_file(candidate_dir.path_join(str(contract.walk)))
	check(idle != null and walk != null, "candidate images load")
	if idle == null or walk == null:
		get_tree().quit(3)
		return
	var count := int(contract.walk_frames)
	check(idle.get_size() == Vector2i(64, 64) and walk.get_size() == Vector2i(count * 64, 64), "complete 64px frame layout")
	check(idle.get_data() == walk.get_region(Rect2i(0, 0, 64, 64)).get_data(), "first walk frame equals idle")
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_" + kind, [])
	await frames(4)
	check(flow.confirm_character_selection(), "real character selection enters battle")
	await frames(8)
	var battle: BattleRoot = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	var player := battle.player
	player.set_physics_process(false)
	var original_scale := player.visual_anchor.scale.abs()
	var original_position := player.sprite.position
	var body := player.get_node("CollisionShape2D") as CollisionShape2D
	var shape := body.shape
	var weapon_anchor := (player.get_node("WeaponAnchor") as Node2D).position
	if installed:
		check(player._idle_texture.resource_path == "res://" + str(contract.future_targets.idle), "idle comes from formal assets")
		check(player._walk_texture.resource_path == "res://" + str(contract.future_targets.walk), "walk comes from formal assets")
		check(player.walk_frame_count == count and player.walk_animation_fps == float(contract.walk_fps), "formal configuration matches approved animation")
		check(visible_pixels_match(player._idle_texture.get_image(), idle), "imported idle pixels match approved outline")
		check(visible_pixels_match(player._walk_texture.get_image(), walk), "imported walk pixels match approved outline")
	else:
		player._idle_texture = ImageTexture.create_from_image(idle)
		player._walk_texture = ImageTexture.create_from_image(walk)
		player.walk_frame_count = count
		player.walk_animation_fps = float(contract.walk_fps)
	player._update_walk_animation(Vector2.ZERO, 0)
	check(player.sprite.texture == player._idle_texture and player.sprite.hframes == 1, "idle texture is active")
	for i in count:
		player._walk_animation_time = (float(i) + 0.05) / player.walk_animation_fps
		player._update_walk_animation(Vector2.RIGHT, 0)
		check(player.sprite.frame == i and player.sprite.hframes == count, "walk frame " + str(i) + " selected without cropping")
	player._walk_animation_time = (float(count) + 0.05) / player.walk_animation_fps
	player._update_walk_animation(Vector2.RIGHT, 0)
	check(player.sprite.frame == 0, "full frame sequence loops")
	player._update_walk_animation(Vector2.ZERO, 0)
	check(player.sprite.texture == player._idle_texture and player.sprite.frame == 0, "stop restores exact first frame")
	check(player.sprite.position == original_position and player.visual_anchor.scale.abs() == original_scale, "world scale and visual offset preserved")
	check(body.shape == shape and (player.get_node("WeaponAnchor") as Node2D).position == weapon_anchor, "collision and weapon anchor preserved")
	check(player.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest-neighbor sprite filtering")
	var overlay := CanvasLayer.new()
	game.add_child(overlay)
	var label := Label.new()
	overlay.add_child(label)
	label.position = Vector2(450, 68)
	label.add_theme_font_size_override("font_size", 16)
	label.text = ("初心者" if kind == "void_hunter" else "资本家") + (" · 描边版正式资源实机" if installed else " · 像素候选稿实机预览")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var graphical := DisplayServer.get_name() != "headless"
	var right_frames := {}
	var left_frames := {}
	var start := player.global_position
	var farthest_right := start.x
	var farthest_left := start.x
	player.set_physics_process(true)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for i in 120:
		var direction := Vector2.ZERO if i < 15 or i >= 105 else (Vector2.RIGHT if i < 60 else Vector2.LEFT)
		player.set_mobile_move_direction(direction)
		await get_tree().process_frame
		await get_tree().physics_frame
		farthest_right = maxf(farthest_right, player.global_position.x)
		if i >= 60: farthest_left = minf(farthest_left, player.global_position.x)
		if direction.x > 0 and player.sprite.hframes == count: right_frames[player.sprite.frame] = true
		if direction.x < 0 and player.sprite.hframes == count: left_frames[player.sprite.frame] = true
		if i == 50: check(player.facing_right and player.visual_anchor.scale.x > 0, "right movement uses right-facing sprite")
		if i == 95: check(not player.facing_right and player.visual_anchor.scale.x < 0, "left movement mirrors the character")
		if i % 2 == 0 and graphical:
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			var image := get_tree().root.get_texture().get_image()
			var filename := "frame_%03d.png" % int(i / 2)
			check(image.save_png(output.path_join(filename)) == OK, "save gameplay frame")
			captures.append({"file":filename,"process_frame":Engine.get_process_frames(),"step":i,
			 "position":[player.global_position.x,player.global_position.y],
			 "sprite_frame":player.sprite.frame,"hframes":player.sprite.hframes,"facing_right":player.facing_right})
		if i % 10 == 0:
			samples.append({"step":i,"sprite_frame":player.sprite.frame,"hframes":player.sprite.hframes,
			 "position":[player.global_position.x,player.global_position.y],"facing_right":player.facing_right})
	player.set_mobile_move_direction(Vector2.ZERO)
	await frames(3)
	check(right_frames.size() == count and left_frames.size() == count, "actual movement visits every frame in both directions")
	check(farthest_right > start.x + 100 and player.global_position.x < farthest_right - 100, "real movement travels right and returns left")
	check(player.sprite.hframes == 1 and player.sprite.texture == player._idle_texture, "actual movement stops in idle")
	var report := {"character":kind,"checks":checks,"failures":failures,"candidate_only":not installed,"installed":installed,
	 "loaded_idle_path":player._idle_texture.resource_path,"loaded_walk_path":player._walk_texture.resource_path,
	 "frame_size":[64,64],"walk_frames":count,"walk_fps":player.walk_animation_fps,"samples":samples,
	 "right_frames":right_frames.keys(),"left_frames":left_frames.keys(),"captured_pngs":60 if graphical else 0,
	 "resolution":[1152,768],"fixed_fps":30,"captures":captures,
	 "capture_note":"Rendered real GameRoot using installed art without texture overrides." if installed else "Rendered real GameRoot; external candidate textures override only this transient player instance."}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("verification.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	game.queue_free()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for audio in AudioManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.25).timeout
	# Fixed-FPS headless runs finish faster than the audio mixer thread.
	OS.delay_msec(100)
	CampProgression.end_transient_session()
	print("PLAYER_ART_REVIEW character=",kind," checks=",checks," failures=",failures)
	get_tree().quit.call_deferred(0 if failures == 0 else 1)
