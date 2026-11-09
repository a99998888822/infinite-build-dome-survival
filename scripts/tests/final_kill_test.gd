extends "res://scripts/tests/night_evacuation_test.gd"
## Exercises the real battle, final-hit damage path, payout gate and teardown.

func run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	output = "res://artifacts/previews/final_kill"
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.size = Vector2i(1280, 720)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	await boot()
	# Ordinary waves retain their existing extraction behavior.
	manager.wave_time_left = 0.0
	manager._process(0.01)
	check(evacuation.active, "ordinary waves still enter extraction")
	evacuation.reset()
	manager.cleanup_active = false
	manager.current_wave_index = DataRegistry.get_table("waves").size() - 1
	manager.current_wave = DataRegistry.get_table("waves").back()
	flow.current_wave_index = manager.current_wave_index
	manager.wave_time_left = 1.0
	var enemy := manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(95, 0))
	enemy.set_physics_process(false)
	enemy.current_hp = 500
	enemy.take_damage(1, "test_before_countdown")
	check(enemy.alive and not manager.final_kill_sequence.active, "no execution before final countdown ends")
	manager.wave_time_left = 0.0
	manager._process(0.01)
	check(not evacuation.is_active() and manager.cleanup_active, "final countdown enters cleanup instead of extraction")
	check(manager.spawn_enemy("enemy_mutated_grub") == null, "final cleanup rejects new spawns")
	manager._process(30.0)
	check(manager.running and enemy.alive, "final cleanup never times out or deletes survivors")
	await film(enemy, "normal")
	check(not manager.final_kill_sequence.active and Engine.time_scale == 1.0, "normal execution restores time")
	manager._process(0.01)
	await frames(120)
	check(not manager.running, "wave finishes only after the presentation")
	# A fresh real battle supplies the boss case and resets rewards.
	await boot()
	manager.current_wave_index = DataRegistry.get_table("waves").size() - 1
	manager.current_wave = DataRegistry.get_table("waves").back()
	flow.current_wave_index = manager.current_wave_index
	manager.wave_time_left = 1.0
	var boss := manager.spawn_enemy("enemy_elite_rusher", player.global_position + Vector2(110, 0))
	var other := manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(-100, 0))
	boss._process_special_behavior(0.8) # Complete its authored spawn invulnerability.
	boss.set_physics_process(false)
	other.set_physics_process(false)
	other.current_hp = 500
	manager.wave_time_left = 0.0
	manager._process(0.01)
	other.take_damage(1, "test_multiple")
	check(other.alive and not manager.final_kill_sequence.active, "multiple survivors cannot trigger an execution")
	other.take_damage(9999, "test_remove_other")
	await frames(3)
	boss.current_hp = 100 + maxi(1, roundi(boss.get_stat("damage_taken_percent", 100.0) / 100.0))
	boss.take_damage(1, "test_boss_boundary")
	check(boss.current_hp == 100 and boss.alive and not manager.final_kill_sequence.active, "boss at exactly 100 is not executed")
	await film(boss, "boss")
	check(Engine.time_scale == 1.0 and not manager.final_kill_sequence.active, "boss execution restores time")
	# Cancellation also restores a non-default scale instead of overwriting it.
	await boot()
	manager.current_wave_index = DataRegistry.get_table("waves").size() - 1
	manager.current_wave = DataRegistry.get_table("waves").back()
	flow.current_wave_index = manager.current_wave_index
	manager.wave_time_left = 1.0
	var last := manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(80, 0))
	if last == null:
		check(false, "cancellation fixture spawns")
		get_tree().quit(1)
		return
	last.set_physics_process(false)
	manager.wave_time_left = 0.0
	Engine.time_scale = 0.75
	last.take_damage(1, "test_cancel")
	check(manager.final_kill_sequence.active, "execution starts before cancellation")
	flow.enter_start_page()
	await frames(8)
	check(Engine.time_scale == 0.75, "leaving battle restores previous time scale")
	Engine.time_scale = 1.0
	CampProgression.end_transient_session()
	print("FINAL_KILL_TEST checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func film(enemy: EnemyController, label: String) -> void:
	var directory := output.path_join(label)
	DirAccess.make_dir_recursive_absolute(directory)
	var capture_gpu := DisplayServer.get_name() != "headless"
	var previous_kills: int = manager.run_statistics.snapshot().get("kills", 0)
	var capture_times: Array[int] = []
	var capture_images: Array[Image] = []
	var original_camera := player.get_viewport().get_camera_2d()
	var started := Time.get_ticks_msec()
	var struck := false
	while Time.get_ticks_msec() - started < 3500:
		if not struck and Time.get_ticks_msec() - started >= 600:
			struck = true
			enemy.take_damage(1, "weapon_void_blade", true, Vector2.RIGHT)
			check(not enemy.alive and manager.final_kill_sequence.active and Engine.time_scale == 0.2, label + " threshold is the final attack")
			manager._process(0.01)
			check(manager.running and flow.current_state == flow.STATE_WAVE_COMBAT, label + " settlement waits for cinematic")
			check(manager.run_statistics.snapshot().get("kills", 0) == previous_kills + 1, label + " records exactly one kill")
		if capture_gpu:
			await RenderingServer.frame_post_draw
			capture_times.append(Time.get_ticks_msec())
			capture_images.append(get_tree().root.get_texture().get_image())
		await get_tree().create_timer(0.05, true, false, true).timeout
	check(player.get_viewport().get_camera_2d() == original_camera, label + " restores gameplay camera")
	if capture_gpu:
		for old in DirAccess.get_files_at(directory):
			if old.begins_with("frame_") and old.ends_with(".png"): DirAccess.remove_absolute(directory.path_join(old))
		for i in capture_images.size():
			capture_images[i].save_png(directory.path_join("frame_%03d.png" % i))
		FileAccess.open(directory.path_join("timing.json"), FileAccess.WRITE).store_string(JSON.stringify(capture_times))
