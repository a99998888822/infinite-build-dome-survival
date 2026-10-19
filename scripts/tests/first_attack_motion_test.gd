extends Node
## Sample physics steps and completed GPU frames without texture readbacks.
## --entry=cold bypasses the new loading/prewarm barrier as a controlled comparison.
var entry := "loaded"
var input_mode := "mouse"
var output := "user://first_attack_motion.json"
var game: GameRoot
var battle: BattleRoot
var measuring := false
var first_attack_tick := -1
var first_attack_usec := 0
var movement_started := 0
var last_draw_usec := 0
var last_draw_position := Vector2.ZERO
var last_physics_position := Vector2.ZERO
var physics: Array[Dictionary] = []
var draws: Array[Dictionary] = []
var fires: Array[Dictionary] = []
var blink_count := 0
var enemy: EnemyController
var failures: Array[String] = []

func _ready() -> void:
	process_physics_priority = 10000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--entry="): entry = arg.trim_prefix("--entry=")
		if arg.begins_with("--input="): input_mode = arg.trim_prefix("--input=")
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	RenderingServer.frame_post_draw.connect(sample_draw)
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func _physics_process(delta: float) -> void:
	if not measuring: return
	var player := battle.player
	var position := player.global_position
	var distance := position.distance_to(last_physics_position)
	var allowed := player.get_stat("move_speed") * delta
	physics.append({"tick": Engine.get_physics_frames(), "delta": delta, "distance": distance,
		"allowed": allowed, "position": [position.x, position.y], "mobility": player.is_mobility_moving()})
	if distance > allowed + 0.05 and not player.is_mobility_moving():
		failures.append("ordinary movement exceeded speed * physics delta")
	last_physics_position = position

func sample_draw() -> void:
	if not measuring: return
	var now := Time.get_ticks_usec()
	var player := battle.player
	var position := player.global_position
	var camera := player.camera_2d.global_position
	var screen := player.sprite.get_global_transform_with_canvas().origin
	draws.append({"frame": Engine.get_process_frames(), "tick": Engine.get_physics_frames(),
		"time_ms": float(now - movement_started) / 1000.0,
		"frame_ms": float(now - last_draw_usec) / 1000.0,
		"distance": position.distance_to(last_draw_position), "position": [position.x, position.y],
		"camera": [camera.x, camera.y], "sprite_screen": [screen.x, screen.y],
		"clip": player.action_animator.current_clip, "clip_frame": player.sprite.frame})
	last_draw_usec = now
	last_draw_position = position

func on_fired(id: String, _count: int) -> void:
	if id != "weapon_void_blade": failures.append("unexpected mobility/other weapon fired")
	if first_attack_tick < 0:
		first_attack_tick = Engine.get_physics_frames()
		first_attack_usec = Time.get_ticks_usec()
	fires.append({"weapon": id, "tick": Engine.get_physics_frames(), "time_ms": float(Time.get_ticks_usec() - movement_started) / 1000.0})

func move_input(pressed: bool) -> void:
	if input_mode == "keyboard":
		var key := InputEventKey.new()
		key.keycode = KEY_D
		key.physical_keycode = KEY_D
		key.pressed = pressed
		Input.parse_input_event(key)
	else:
		var point := Vector2(1450, 616)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		Input.parse_input_event(motion)
		var button := InputEventMouseButton.new()
		button.position = point
		button.button_index = MOUSE_BUTTON_RIGHT
		button.pressed = pressed
		Input.parse_input_event(button)

func run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("keyboard_movement", input_mode == "keyboard", false)
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", true, false)
	CombatSettings.set_weapon_auto_cast("weapon_dash_blade", false, false)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu._on_start_battle_pressed()
	await frames(4)
	if entry == "cold":
		flow.enter_battle_selection("character_void_hunter")
		flow.confirm_character_selection()
	else:
		menu._on_character_confirm_pressed()
		await menu.dungeon_loading.finished
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	await frames(12)
	battle.loadout.weapon_fired.connect(on_fired)
	battle.player.blink_completed.connect(func(): blink_count += 1)
	last_draw_position = battle.player.global_position
	last_physics_position = last_draw_position
	movement_started = Time.get_ticks_usec()
	last_draw_usec = movement_started
	measuring = true
	move_input(true)
	await get_tree().create_timer(0.4).timeout
	enemy = battle.wave_manager.spawn_enemy("enemy_mutated_grub", battle.player.global_position + Vector2(110, 65))
	enemy.current_hp = 100000
	enemy.set_physics_process(false)
	await get_tree().create_timer(1.2).timeout
	measuring = false
	move_input(false)
	battle.active_controller.stop_movement()
	if fires.is_empty(): failures.append("first automatic bow attack did not happen")
	if enemy.current_hp >= 100000: failures.append("bow/lightning did not hit the target")
	if blink_count > 0: failures.append("unexpected player blink")
	if battle.player.global_position.x < 80.0: failures.append("real movement input did not move far enough")
	var max_step := 0.0
	var max_draw_step := 0.0
	var max_frame_ms := 0.0
	var max_attack_step := 0.0
	var max_attack_ms := 0.0
	var max_screen_step := 0.0
	var previous_screen := Vector2.ZERO
	for row in physics: max_step = maxf(max_step, row.distance)
	for row in draws:
		max_draw_step = maxf(max_draw_step, row.distance)
		max_frame_ms = maxf(max_frame_ms, row.frame_ms)
		if int(row.tick) >= first_attack_tick:
			max_attack_step = maxf(max_attack_step, row.distance)
			max_attack_ms = maxf(max_attack_ms, row.frame_ms)
		var screen := Vector2(row.sprite_screen[0], row.sprite_screen[1])
		if previous_screen != Vector2.ZERO: max_screen_step = maxf(max_screen_step, screen.distance_to(previous_screen))
		previous_screen = screen
	var summary := {"entry": entry, "input": input_mode, "max_physics_step": max_step,
		"max_draw_step": max_draw_step, "max_frame_ms": max_frame_ms,
		"max_attack_draw_step": max_attack_step, "max_attack_frame_ms": max_attack_ms,
		"max_sprite_screen_step": max_screen_step, "blink_count": blink_count,
		"physics_ticks": physics.size(), "rendered_frames": draws.size(), "fires": fires, "failures": failures}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"summary": summary, "physics": physics, "draws": draws}, "\t"))
	print("FIRST_ATTACK_MOTION ", JSON.stringify(summary))
	flow.enter_start_page()
	await frames(8)
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
