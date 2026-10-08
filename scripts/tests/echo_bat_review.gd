extends Node
## Real battle, real candidate AI and swept damage. Only player input is staged.
class MixWaveManager extends WaveManager:
	var rolls := 0
	func _spawn_variant_roll() -> float:
		var value := (float(rolls % 10) + 0.5) / 10.0
		rolls += 1
		return value

var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var bat: EchoBat
var checks := 0
var failures := 0
var captures := ""
var title: Label
var caption: Label
var status: Label
var shot_count := 0
var seen_frames: Dictionary = {}
var sample_log: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): captures = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(220).timeout
	push_error("ECHO_BAT_REVIEW_TIMEOUT")
	get_tree().quit(99)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count: int = 3) -> void:
	for i in count: await get_tree().process_frame


func freeze_waves() -> void:
	for wave in get_tree().get_nodes_in_group("echo_bat_projectiles"):
		wave.set_physics_process(false)


func step(count: int = 1, movement: Vector2 = Vector2.ZERO) -> void:
	for i in count:
		await get_tree().physics_frame
		player.move_and_collide(movement / 60.0)
		player._update_walk_animation(movement, 1.0 / 60.0)
		if not is_zero_approx(movement.x):
			player.facing_right = movement.x > 0
			player.visual_anchor.scale.x = absf(player.visual_anchor.scale.x) * (1 if player.facing_right else -1)
		player._invincibility_timer = maxf(0, player._invincibility_timer - 1.0 / 60.0)
		bat._physics_process(1.0 / 60.0)
		seen_frames[str(bat.sprite.texture.resource_path.get_file()) + ":" + str(bat.sprite.frame)] = true
		for wave in get_tree().get_nodes_in_group("echo_bat_projectiles"):
			if not wave.is_queued_for_deletion(): wave._physics_process(1.0 / 60.0)
		freeze_waves()
		await get_tree().process_frame


func reset(bat_position: Vector2, player_position: Vector2, delay: float) -> void:
	if is_instance_valid(bat): bat.free()
	player.global_position = player_position
	player.alive = true
	player.current_hp = int(player.get_stat("max_hp"))
	player.current_shield = 0
	player._invincibility_timer = 0
	player.sprite.modulate = Color.WHITE
	bat = load("res://scenes/enemy/echo_bat.tscn").instantiate()
	bat.auto_initialize_on_ready = false
	player.get_parent().add_child(bat)
	bat.initialize("enemy_echo_bat", player)
	bat.global_position = bat_position
	bat.cooldown = delay
	bat.set_physics_process(false)
	bat.sonic_fired.connect(func(_wave: Node2D):
		shot_count += 1
		freeze_waves())
	shot_count = 0
	await frames()


func _run() -> void:
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(4)
	check(flow.confirm_character_selection(), "real battle scene opened")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.hud.set_process(false)
	battle.hud.hide()
	player = battle.player
	player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()
	await validate_behavior()
	if not captures.is_empty() and DisplayServer.get_name() != "headless" and failures == 0:
		DirAccess.make_dir_recursive_absolute(captures)
		make_overlay()
		await capture_storyboard()
		var file := FileAccess.open(captures.path_join("samples.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(sample_log, "\t"))
	print("ECHO_BAT_REVIEW checks=%d failures=%d captures=%d" % [checks, failures, sample_log.size()])
	get_tree().quit(1 if failures else 0)


func validate_behavior() -> void:
	await reset(Vector2(-400, 0), Vector2.ZERO, 99)
	await step(60)
	check(bat.global_position.x > -330, "outside 0.9 range approaches player")
	await reset(Vector2(-45, 0), Vector2.ZERO, 99)
	await step(60)
	check(bat.global_position.x < -90, "inside 0.3 range retreats")
	await reset(Vector2(-180, 0), Vector2.ZERO, 99)
	await step(20)
	check(bat.global_position.is_equal_approx(Vector2(-180, 0)), "holds position inside preferred range")
	check(seen_frames.size() >= 6, "hover and move animate all six source frames")
	var visible_width := EchoBat.MOVE.get_image().get_region(Rect2i(0, 0, 128, 128)).get_used_rect().size.x * bat.sprite.scale.x
	check(visible_width > 71.0 and visible_width < 74.0, "pixel art preserves the approved 80 percent world size")
	check(is_equal_approx((bat.get_node("CollisionShape2D").shape as CircleShape2D).radius, 9.6), "bat collision shrinks with body")
	var mouth_right := bat.mouth_position() - bat.global_position
	check(absf(mouth_right.x - 11.2) < 0.5 and absf(mouth_right.y + 12) < 0.5, "new lip socket remains aligned to smaller bat")
	bat.sprite.flip_h = true
	check((bat.mouth_position() - bat.global_position).is_equal_approx(Vector2(-mouth_right.x, mouth_right.y)), "lip socket mirrors with left-facing artwork")
	bat.sprite.flip_h = false
	check(EchoBat.MOVE.get_size() == Vector2(768, 128) and EchoBat.ATTACK.get_size() == Vector2(1152, 128), "production atlases contain 6 and 9 full 128px frames")
	check(bat.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel art uses nearest texture sampling")
	check(is_equal_approx(float(bat.profile.path_width), 20.0), "warning width 20 versus miniboss 71.68")
	bat.cooldown = 0
	check(bat.begin_attack(), "begins charge")
	await step(11)
	check(bat.skill_state == "charge" and not bat.warning.visible and shot_count == 0, "no warning or damage before 0.2s")
	await step()
	check(bat.skill_state == "warning" and bat.warning.visible and shot_count == 0, "0.2s opens warning")
	var locked := bat.aim_direction
	player.global_position.y = -100
	await step(29)
	check(bat.warning.visible and shot_count == 0, "warning persists for 0.5s before firing")
	await step()
	check(not bat.warning.visible and shot_count == 1, "warning disappears on projectile release")
	check(bat.aim_direction.is_equal_approx(locked), "warning and wave direction locked while player dodges")
	var wave := get_tree().get_nodes_in_group("echo_bat_projectiles")[0] as EchoBatSonic
	var start_distance := wave.travelled
	await step(12)
	check(is_equal_approx(wave.travelled - start_distance, 60.0), "doubled sonic speed travels 60 units in 0.2s")
	check(wave.visual.hframes == 8, "pixel spiral uses eight baked animation frames")
	bat.cooldown = 99
	var before := player.current_hp
	await step(140)
	var all_attack_frames := true
	for index in 9:
		all_attack_frames = all_attack_frames and seen_frames.has("attack.png:" + str(index))
	check(all_attack_frames, "real charge warning release and recovery display all nine attack frames")
	check(player.current_hp == before, "sidestep avoids the real swept projectile")
	check(get_tree().get_nodes_in_group("echo_bat_projectiles").is_empty(), "wave expires at maximum distance")
	await reset(Vector2(-180, 0), Vector2.ZERO, 0)
	before = player.current_hp
	await step(42)
	check(player.current_hp == before, "warning does not inflict damage")
	await step(65)
	check(player.current_hp == before - 7, "sonic hit deals one configured damage event")
	bat.cooldown = 99
	await step(35)
	check(player.current_hp == before - 7, "one wave cannot hit twice")
	await reset(Vector2(-180, 0), Vector2.ZERO, 0)
	await step(20)
	var paused_time := bat.state_time
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await step(20)
	check(is_equal_approx(bat.state_time, paused_time) and shot_count == 0, "pause freezes charge and warning")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	bat._on_control_interrupted()
	check(not bat.warning.visible and not bat.charge.visible, "control interruption removes warning")
	await reset(Vector2(16, 0), Vector2.ZERO, 99)
	before = player.current_hp
	bat._process_contact_damage()
	check(player.current_hp == before - 1, "body contact inflicts only one damage")
	await reset(Vector2(-180, 0), Vector2.ZERO, 0)
	await step(46)
	check(get_tree().get_nodes_in_group("echo_bat_projectiles").size() == 1, "flying wave created")
	bat.free()
	await frames()
	check(get_tree().get_nodes_in_group("echo_bat_projectiles").is_empty(), "owner cleanup frees warning and projectiles")
	await validate_spawn_mix()


func validate_spawn_mix() -> void:
	var manager := MixWaveManager.new()
	player.get_parent().add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	manager._difficulty.spawn_count = 1.0
	manager.current_wave_index = 0
	manager.current_wave = {"id": "mix_review", "duration_seconds": 30, "spawn_groups": [
		{"enemy_id": "enemy_mutated_grub", "spawn_interval_ms": 1200, "count_per_spawn": 6},
		{"enemy_id": "enemy_mutated_grub", "spawn_interval_ms": 1800, "count_per_spawn": 4}]}
	manager.wave_time_left = 30
	manager.spawn_timers_ms.assign([0.0, 0.0])
	manager._process_spawn_timers(0.0)
	var bats := 0
	var grubs := 0
	for enemy in EnemyRegistry.get_registered_enemies():
		if manager.is_ancestor_of(enemy):
			enemy.set_physics_process(false)
			if enemy is EchoBat: bats += 1
			elif enemy.enemy_id == "enemy_mutated_grub": grubs += 1
	check(bats == 3 and grubs == 7, "real ordinary spawn timers apply 30:70 weights across groups")
	check(manager._select_spawn_variant("enemy_elite_rusher") == "enemy_elite_rusher", "miniboss identity is never mixed")
	var sample := manager.spawn_enemy("enemy_mutated_grub", Vector2(900, 0))
	check(sample != null and sample.enemy_id == "enemy_mutated_grub", "explicit spawn preserves caller enemy type")
	var all_waves_use_pool := true
	for record: Dictionary in DataRegistry.get_table("waves"):
		for group: Dictionary in record.spawn_groups:
			all_waves_use_pool = all_waves_use_pool and group.enemy_id == "enemy_mutated_grub"
	check(all_waves_use_pool, "all twenty waves resolve the configured normal mix")
	manager.free()
	await frames()


func make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	game.add_child(layer)
	var top := ColorRect.new()
	top.position = Vector2(20, 18)
	top.size = Vector2(1240, 80)
	top.color = Color(0.055, 0.07, 0.11, 0.94)
	layer.add_child(top)
	title = Label.new()
	title.position = Vector2(42, 26)
	title.add_theme_font_size_override("font_size", 25)
	title.text = "回声蝙蝠 · 128 像素描线版实机"
	layer.add_child(title)
	var detail := Label.new()
	detail.position = Vector2(43, 63)
	detail.add_theme_font_size_override("font_size", 15)
	detail.modulate = Color("b6bad2")
	detail.text = "体型 80%    ·    像素螺旋音波 300 速度    ·    普通小怪：蝙蝠 30% / 天外幼体 70%"
	layer.add_child(detail)
	var bottom := ColorRect.new()
	bottom.position = Vector2(20, 610)
	bottom.size = Vector2(1240, 90)
	bottom.color = top.color
	layer.add_child(bottom)
	caption = Label.new()
	caption.position = Vector2(42, 620)
	caption.add_theme_font_size_override("font_size", 23)
	layer.add_child(caption)
	status = Label.new()
	status.position = Vector2(43, 658)
	status.add_theme_font_size_override("font_size", 17)
	status.modulate = Color("c3bddf")
	layer.add_child(status)


func capture_storyboard() -> void:
	for chapter in 4:
		if chapter == 0:
			await reset(Vector2(-240, 0), Vector2(160, 0), 99)
			caption.text = "01 / 保持距离：太远靠近，贴近退开"
		elif chapter < 3:
			await reset(Vector2(-155, 0), Vector2(95, 0), 0.7)
			caption.text = "02 / 预警锁定方向后，侧移躲开音波" if chapter == 1 else "03 / 留在攻击路径上，音波命中后扣血"
		else:
			await reset(Vector2(155, 0), Vector2(-95, 0), 0.7)
			caption.text = "04 / 朝左喷吐：嘴部、预警和音波同步翻转"
		for frame in 86:
			var time := frame * 0.05
			var movement := Vector2.ZERO
			if chapter == 0 and time >= 1.6 and time < 3.4: movement = Vector2(-130, 0)
			if chapter == 1 and time >= 1.02 and time < 1.9: movement = Vector2(0, -110)
			await step(3, movement)
			if chapter > 0 and time > 1.5: bat.cooldown = 99
			player.camera_2d.global_position = Vector2(0, -15)
			player.camera_2d.offset = Vector2.ZERO
			player.camera_2d.zoom = Vector2.ONE * 1.8
			player.camera_2d.reset_smoothing()
			player.camera_2d.force_update_scroll()
			var state_names := {"move": "振翅移动 / 悬停", "charge": "蓄力", "warning": "路径预警", "release": "喷吐音波", "recover": "收招"}
			var ratio := bat.global_position.distance_to(player.global_position) / bat.attack_range()
			status.text = "%s    ·    距离 / 射程 %.2f    ·    玩家生命 %d" % [state_names.get(bat.skill_state, ""), ratio, player.current_hp]
			# HUD signal callbacks may refresh after the staged hit. Hide only UI,
			# preserving the real battlefield's background and ambience layers.
			for path in ["HUD", "BattleTopBar", "BattleTopBarBackground"]:
				var ui := battle.get_node_or_null(path) as CanvasLayer
				if ui != null: ui.hide()
			battle.hud._economy_log_layer.hide()
			battle.active_controller._cursor_layer.hide()
			await RenderingServer.frame_post_draw
			var index := chapter * 86 + frame
			var filename := "frame_%03d.png" % index
			var picture := get_tree().root.get_texture().get_image()
			if picture.save_png(captures.path_join(filename)) != OK:
				check(false, "save engine screenshot")
			if (chapter == 0 and frame == 25) or (chapter == 1 and frame == 23) or (chapter >= 2 and frame == 30):
				picture.save_png(captures.get_base_dir().path_join("chapter_%d.png" % chapter))
			sample_log.append({"file": filename, "chapter": chapter, "time": time, "state": bat.skill_state, "ratio": ratio, "hp": player.current_hp, "bat": [bat.position.x, bat.position.y], "sprite_frame": bat.sprite.frame})
