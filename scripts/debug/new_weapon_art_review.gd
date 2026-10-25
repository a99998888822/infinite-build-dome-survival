extends Node
## Art direction review: controlled poses and reactions on the real battlefield.
## No new weapon gameplay, automatic damage, equipment or balance is installed.
const ART = preload("res://scripts/effects/candidate_weapon_art.gd")
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const FPS := 60
const CLIP_FRAMES := 180
const JUMP_START_FRAME := 28
const SPECS := [
	["furnace_single", "刚焰炉", "单圈 · 受击爆发", 1, false],
	["furnace_multi", "刚焰炉", "三圈 · 连续喷发", 3, false],
	["furnace_split", "刚焰炉", "三圈 + 分裂 · 外沿小火簇", 3, true],
	["saber_single", "斩马刀", "单刀 · 闪现穿线斩", 1, false],
	["saber_multi", "斩马刀", "五刀 · 围绕中心小角度旋转", 5, false],
	["saber_diagonal", "斩马刀", "五刀 · 斜向闪现", 5, false],
]
var output_dir := ""
var session: RecordingSession
var battle: BattleRoot
var camera: Camera2D
var title: Label
var subtitle: Label
var enemies: Array[EnemyController] = []
var positions: Array[Vector2] = []
var effects: Array[Dictionary] = []
var afterimages: Array[Sprite2D] = []
var report := {"revision": 4, "review_only": true, "gameplay_integrated": false, "fps": FPS, "clips": [], "baked": []}
var only := ""
var bake_only := false
var graphical := false


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--bake-only": bake_only = true
	graphical = DisplayServer.get_name() != "headless"
	if output_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		get_tree().quit(2)
		return
	if graphical and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("Use run_godot_background.py for art review")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run.call_deferred()


func _run() -> void:
	seed(10252026)
	CampProgression.begin_transient_session()
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	AudioServer.set_bus_mute(0, true)
	if bake_only:
		if graphical: await _bake()
		await _finish()
		return
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_weapon_auto_cast("weapon_dash_blade", false, false)
	CombatSettings.set_option("show_hints", false, false)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"countdown": 0, "hud": false, "wave": 3, "relics": [],
		"weapons": [{"id": "weapon_dash_blade", "level": 1, "attachments": []}]}, true)
	var error := await session.prepare(config)
	if not error.is_empty() or not session.begin():
		push_error("ART_REVIEW_SETUP: " + error)
		get_tree().quit(3)
		return
	battle = session.battle
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.set_process(false)
	battle.active_controller.set_process_input(false)
	battle.active_controller.set_process_unhandled_input(false)
	battle.loadout.set_process(false)
	battle.player.set_physics_process(false)
	battle.player._clear_move_input()
	battle.player.global_position = Vector2.ZERO
	camera = Camera2D.new()
	battle.player.get_parent().add_child(camera)
	camera.zoom = Vector2(2.4, 2.4)
	camera.make_current()
	_make_titles()
	for i in 12: await get_tree().process_frame
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	# Warm both candidate shaders before capture, away from the camera.
	ART.ring(battle.player.get_parent(), Vector2(10000, 0))
	ART.cut(battle.player.get_parent(), Vector2(10000, 0), Vector2(10280, 0))
	for i in 4: await get_tree().process_frame
	for spec in SPECS:
		if not only.is_empty() and spec[0] != only: continue
		await _clip(spec)
	await _finish()


func _make_titles() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.035, 0.045, 0.047, 1.0)
	back.size = Vector2(1920, 116)
	layer.add_child(back)
	title = Label.new()
	title.position = Vector2(40, 16)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 30)
	layer.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(40, 62)
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color("babfba")
	layer.add_child(subtitle)
	var note := Label.new()
	note.text = "美术预览  ·  真实战场背景 / 演示动作"
	note.position = Vector2(1330, 40)
	note.add_theme_font_override("font", FONT)
	note.add_theme_font_size_override("font_size", 16)
	note.modulate = Color("99a6a2")
	layer.add_child(note)


func _clip(spec: Array) -> void:
	for effect in get_tree().get_nodes_in_group("candidate_weapon_art"): effect.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	for ghost in afterimages:
		if is_instance_valid(ghost): ghost.queue_free()
	enemies.clear()
	positions.clear()
	effects.clear()
	afterimages.clear()
	var furnace: bool = str(spec[0]).begins_with("furnace")
	var diagonal: bool = spec[0] == "saber_diagonal"
	var from := Vector2.ZERO if furnace else Vector2(-150, 65 if diagonal else 0)
	var to := Vector2(150, -55 if diagonal else 0)
	battle.player.global_position = from
	battle.player.sprite.modulate = Color.WHITE
	battle.player._set_facing(true)
	battle.player.action_animator.reset()
	camera.global_position = Vector2(0, -20)
	camera.reset_smoothing()
	title.text = str(spec[1])
	title.modulate = Color("ffdc7a") if furnace else Color("a4e0dc")
	subtitle.text = str(spec[2])
	if furnace:
		for i in 7:
			var a := TAU * i / 7.0 + 0.23
			positions.append(Vector2(cos(a), sin(a) * 0.659091) * (104.0 if i % 2 else 125.0))
	else:
		for ratio in [0.22, 0.49, 0.78]: positions.append(from.lerp(to, ratio) + Vector2(0, 4))
	for point in positions:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", point)
		enemy.current_hp = 10000
		enemy.target_player = null
		enemy.challenge_target = null
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await get_tree().process_frame
	var start := Engine.get_frames_drawn()
	var jump_frames := {}
	var jump_before := {}
	var jump_after := {}
	var jump_timeline: Array[Dictionary] = []
	var clip: Dictionary = battle.player.action_animator._clips["jump_forward"]
	var durations: Array = clip.get("frame_durations", [])
	var half_seconds := 0.0
	for index in 3:
		half_seconds += float(durations[index]) if durations.size() == 6 else 1.0 / float(clip.fps)
	var blink_frame := JUMP_START_FRAME + ceili(half_seconds * FPS)
	var rotations: Array[float] = []
	for frame in CLIP_FRAMES:
		battle.hud.battle_top_bar.hide()
		var seconds := float(frame) / FPS
		if furnace:
			if frame == 30: battle.player.sprite.modulate = Color("ffae8b")
			if frame == 36: battle.player.sprite.modulate = Color.WHITE
			for pulse in int(spec[3]):
				if frame == 30 + pulse * 11:
					_add_effect(ART.ring(battle.player.get_parent(), from, 160.0, false, pulse * 0.23), seconds)
				if bool(spec[4]) and frame == 61 + pulse * 11:
					_add_effect(ART.ring(battle.player.get_parent(), from, 160.0, true, pulse * 0.31), seconds)
			for i in enemies.size():
				var push := smoothstep(0.50, 0.76, seconds) * 31.0
				enemies[i].global_position = positions[i] + positions[i].normalized() * push
				if frame == 48:
					enemies[i].apply_burning(1.6, 0.0, "art_review")
				if frame == 144: enemies[i].clear_burning()
		else:
			if frame == JUMP_START_FRAME:
				battle.player.play_mobility_action("weapon_dash_blade", to - from)
			if frame == blink_frame:
				_make_afterimages(from, to)
				battle.player.blink_to(to)
				camera.make_current()
			for index in int(spec[3]):
				if frame == blink_frame + index * 4:
					var step := (index + 1) / 2
					var angle := float(step) * (3.0 if index % 2 == 1 else -3.0)
					rotations.append(angle)
					var cut := ART.cut(battle.player.get_parent(), from, to, angle)
					assert(cut.global_position.is_equal_approx((from + to) * 0.5), "Cuts must rotate around their shared midpoint")
					_add_effect(cut, seconds)
			# Player motion is held by this fixture; advance the real animation explicitly.
			# Keep frame zero at t=0; the first sample of frame three is at the destination.
			if frame != JUMP_START_FRAME:
				battle.player.action_animator.tick(1.0 / FPS, false)
			if battle.player.action_animator.current_clip == "jump_forward":
				var pose := battle.player.action_animator.current_frame
				jump_frames[pose] = true
				var samples: Dictionary = jump_before if frame < blink_frame else jump_after
				if not samples.has(pose):
					jump_timeline.append({"video_frame": frame, "pose": pose, "side": "origin" if frame < blink_frame else "destination"})
				samples[pose] = true
				assert(battle.player.global_position.is_equal_approx(from if frame < blink_frame else to), "Jump pose must be on the expected side of the blink")
			for i in enemies.size():
				var flash := frame >= blink_frame and frame < blink_frame + int(spec[3]) * 4 and (frame - blink_frame) % 4 < 2
				enemies[i].sprite.modulate = Color("d8fff1") if flash else Color.WHITE
			for i in afterimages.size():
				afterimages[i].modulate.a = maxf(0.0, 0.34 - (seconds - float(blink_frame) / FPS) * 1.4 - float(i) * 0.02)
		for item in effects:
			var effect: Node2D = item.node
			effect.sample(seconds - float(item.start))
		if graphical:
			await RenderingServer.frame_post_draw
			if frame in [0, 35, 40, 47, 49, 50, 59, 61, 65, 70, 78]:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("%s_%03d.png" % [spec[0], frame]))
		await get_tree().process_frame
	if not furnace:
		assert(jump_frames.size() == 6, "Review must show all six jump frames")
		assert(jump_before.keys() == [0, 1, 2] and jump_after.keys() == [3, 4, 5], "Exactly half the jump must play on each side of the blink")
	report.clips.append({"id": spec[0], "start_frame": start, "frames": CLIP_FRAMES,
		"effect_instances": effects.size(), "projectiles": spec[3], "split": spec[4],
		"jump_frames": jump_frames.keys(), "jump_before": jump_before.keys(), "jump_after": jump_after.keys(),
		"jump_timeline": jump_timeline, "blink_frame": blink_frame, "half_jump_seconds": half_seconds,
		"cut_angles_degrees": rotations})
	print("ART_REVIEW_CLIP ", spec[0], " effects=", effects.size())


func _add_effect(effect: Node2D, seconds: float) -> void:
	effect.manual_clock = true
	effects.append({"node": effect, "start": seconds})


func _make_afterimages(from: Vector2, to: Vector2) -> void:
	var source := battle.player.sprite
	if source == null or source.texture == null: return
	for i in 3:
		var ghost := Sprite2D.new()
		ghost.texture = source.texture
		ghost.hframes = source.hframes
		ghost.vframes = source.vframes
		ghost.frame = source.frame
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.scale = source.global_scale
		ghost.offset = source.offset
		ghost.flip_h = source.flip_h
		ghost.modulate = Color(0.42, 0.72, 0.71, 0.28)
		battle.player.get_parent().add_child(ghost)
		ghost.global_position = from.lerp(to, float(i) * 0.16) + (source.global_position - from)
		CombatRenderWorld.set_world_layer(ghost, CombatRenderWorld.BACK_Z)
		afterimages.append(ghost)


func _bake() -> void:
	var destination := "res://assets/sprites/weapons/candidates/furnace_saber_v1"
	DirAccess.make_dir_recursive_absolute(destination)
	for row in [["furnace_ring", Vector2i(448, 320), 12, 0.72],
			["furnace_split", Vector2i(512, 352), 12, 0.62],
			["saber_cut", Vector2i(384, 96), 12, 0.30]]:
		var viewport := SubViewport.new()
		viewport.size = row[1]
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var at := Vector2(viewport.size) * 0.5
		var effect: Node2D
		if row[0] == "saber_cut":
			effect = ART.cut(viewport, Vector2(42, 48), Vector2(342, 48))
		else:
			effect = ART.ring(viewport, at, 160.0, row[0] == "furnace_split")
		effect.manual_clock = true
		effect.layered = false
		var sheet := Image.create(viewport.size.x * 4, viewport.size.y * 3, false, Image.FORMAT_RGBA8)
		for index in int(row[2]):
			effect.sample(float(index) / float(row[2]) * float(row[3]))
			await RenderingServer.frame_post_draw
			var frame := viewport.get_texture().get_image()
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(index % 4, index / 4) * viewport.size)
			await get_tree().process_frame
		var path := destination.path_join(str(row[0]) + ".png")
		var result := sheet.save_png(path)
		assert(result == OK, "Candidate atlas must save successfully")
		report.baked.append({"path": path, "frame_size": [viewport.size.x, viewport.size.y],
			"columns": 4, "rows": 3, "frames": row[2], "duration": row[3], "source": "local Godot shader rendering"})
		viewport.queue_free()
		await get_tree().process_frame
	print("ART_REVIEW_BAKED ", report.baked.size())


func _finish() -> void:
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	effects.clear()
	afterimages.clear()
	enemies.clear()
	if is_instance_valid(session):
		await session.dispose()
		session.queue_free()
	for i in 6: await get_tree().process_frame
	battle = null
	camera = null
	session = null
	ART.noise_texture = null
	CampProgression.end_transient_session()
	print("NEW_WEAPON_ART_REVIEW_COMPLETE")
	get_tree().quit()
