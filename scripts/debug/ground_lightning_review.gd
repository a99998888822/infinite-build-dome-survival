extends Node
## Controlled effect review on the production battlefield, not a gameplay take.
const FPS := 60
const TOTAL := 420
const HAMMER := "weapon_earth_hammer"
var session: RecordingSession
var weapon: WeaponInstance
var enemies: Array[EnemyController] = []
var output_dir := ""
var failures: Array[String] = []
var report := {"fps": FPS, "frames": TOTAL, "review_only": true, "events": []}


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
	if output_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		push_error("Requires --transient-session --capture-dir")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("Use the private desktop capture helper")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run.call_deferred()


func _run() -> void:
	seed(10242026)
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_weapon_auto_cast(HAMMER, false, false)
	CombatSettings.set_option("show_hints", false, false)
	for bus in [AudioManager.BUS_MASTER, AudioManager.BUS_SFX]:
		AudioManager.set_bus_volume(bus, 100, false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), false)
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 0, false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_BGM), true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"countdown": 0, "hud": false,
		"weapons": [{"id": HAMMER, "level": 4, "attachments": ["scroll_electric_spark"]}], "relics": []}, true)
	var error := await session.prepare(config)
	if not error.is_empty() or not session.begin():
		failures.append("Could not prepare review: " + error)
		await _finish()
		return
	var battle := session.battle
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.set_process(false)
	battle.active_controller.set_process_input(false)
	battle.active_controller.set_process_unhandled_input(false)
	battle.player.global_position = Vector2(-160, 90)
	battle.player._clear_move_input()
	battle.player.set_physics_process(false)
	weapon = battle.loadout.get_weapon_instance(HAMMER)
	var camera := Camera2D.new()
	battle.player.get_parent().add_child(camera)
	camera.global_position = Vector2(20, -25)
	camera.zoom = Vector2(2.0, 2.0)
	camera.make_current()
	for point: Vector2 in [Vector2(15, 55), Vector2(110, 110), Vector2(145, -10)]:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", point)
		if enemy == null:
			failures.append("Missing review enemy")
			await _finish()
			return
		# Keep status/damage processing alive, while holding review targets still.
		enemy.target_player = null
		enemy.challenge_target = null
		enemy.knockback_speed = 0.0
		enemy.current_hp = 10000
		enemies.append(enemy)
	for index in 15: await get_tree().process_frame
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	report["start_frame"] = Engine.get_frames_drawn()
	for frame in TOTAL:
		if frame == 30 or frame == 288: _strike(0, frame)
		if frame == 144: _strike(0, frame)
		if frame == 151: _strike(1, frame)
		if frame == 157: _strike(2, frame)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame in [0, 45, 60, 62, 66, 69, 74, 76, 176, 182, 189]:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	for enemy in enemies:
		if enemy.current_hp >= 10000: failures.append("Review target was not hit")
	report["remaining_hp"] = enemies.map(func(enemy): return enemy.current_hp)
	await _finish()


func _strike(index: int, frame: int) -> void:
	var point := enemies[index].global_position
	var event := DamageEvent.create({"damage": 50, "original_damage": 50, "source_weapon_id": HAMMER})
	ElectricSparkEffect.spawn(session.battle.player.get_parent(), point, weapon, event)
	report.events.append({"frame": frame, "target": index, "position": [point.x, point.y]})


func _finish() -> void:
	report["failures"] = failures
	report["audio"] = {"sfx_percent": 100, "bgm_percent": 0,
		"sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),
		"bgm_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")),
		"bgm_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM"))}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("GROUND_LIGHTNING_REVIEW failures=", failures.size())
	CombatHitFeedback.clear()
	weapon = null
	enemies.clear()
	if is_instance_valid(session):
		await session.dispose()
		session.queue_free()
	for index in 8: await get_tree().process_frame
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
