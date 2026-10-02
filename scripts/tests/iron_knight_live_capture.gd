extends Node

var capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _run() -> void:
	if capture_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		get_tree().quit(2)
		return
	seed(270927)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	print("KNIGHT_CAPTURE_STAGE game_loaded")
	await frames(12)
	print("KNIGHT_CAPTURE_STAGE menu_ready")
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	print("KNIGHT_CAPTURE_STAGE selection")
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	print("KNIGHT_CAPTURE_STAGE battle_ready")
	battle.set_process(false)
	var manager: WaveManager = battle.wave_manager
	manager.set_process(false)
	var player: PlayerController = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 100
	player.add_runtime_modifier({"id": "capture_pickup", "source_id": "capture", "source_type": "test", "stat": "pickup_radius", "operation": "override", "value": 0, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		enemy.free()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		runtime.queue_free()
	await frames(2)
	var origin := player.global_position
	DirAccess.make_dir_recursive_absolute(capture_dir)
	if OS.get_cmdline_user_args().has("--include-sprites"):
		# Real battle viewport and production animation code, with scripted input.
		var small := manager.spawn_enemy("enemy_mutated_grub", origin + Vector2(-110, 0))
		small.set_physics_process(false)
		for index in 144:
			player._set_facing(index < 72)
			player._update_walk_animation(Vector2.RIGHT if index < 72 else Vector2.LEFT, 1.0 / 60.0)
			small._set_movement_visual(true, 1.0 / 60.0)
			small.sprite.flip_h = index >= 72
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("sprites_%04d.png" % index))
		player._update_walk_animation(Vector2.ZERO, 0.0)
		player._set_facing(true)
		small.free()
	var knight := manager.spawn_enemy("enemy_elite_rusher", origin + Vector2(-380, 0)) as EliteRusher
	var records: Array[Dictionary] = []
	var states: Dictionary = {}
	var dodging := false
	var loot_seen := false
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for index in 420:
		if index % 60 == 0:
			print("KNIGHT_CAPTURE_FRAME ", index)
		if is_instance_valid(knight):
			states[knight.skill_state] = true
			if knight.skill_state == "windup" and knight._state_time >= 0.3:
				dodging = true
			if dodging:
				player._update_walk_animation(Vector2.UP if player.global_position.y > origin.y - 85 else Vector2.ZERO, 1.0 / 60.0)
				player.global_position.y = move_toward(player.global_position.y, origin.y - 85, 260.0 / 60.0)
			if knight.skill_state == "chase" and dodging:
				knight.set_target_player(null)
			if index == 335:
				knight.take_damage(100000, "iron_knight_capture")
			records.append({"frame": index, "state": knight.skill_state, "state_time": knight._state_time,
				"distance": knight.global_position.distance_to(player.global_position),
				"position": [knight.global_position.x, knight.global_position.y], "animation": str(knight._animation),
				"texture_size": [knight.sprite.texture.get_width(), knight.sprite.texture.get_height()],
				"atlas_region": str((knight.sprite.texture as AtlasTexture).region)})
		manager._flush_pending_reward_batches()
		loot_seen = loot_seen or not get_tree().get_nodes_in_group("relic_pickups").is_empty()
		await RenderingServer.frame_post_draw
		var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
		if error != OK:
			get_tree().quit(4)
			return
	var valid := states.has("spawn") and states.has("chase") and states.has("windup") and states.has("dash") and states.has("recover") and states.has("dead") and loot_seen
	var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"production": true, "valid": valid, "fps": 60, "frames": 420,
		"states": states.keys(), "loot_seen": loot_seen, "origin": [origin.x, origin.y],
		"sprite_frames": EliteRusher.FRAMES.resource_path, "samples": records}, "\t"))
	print("IRON_KNIGHT_LIVE_CAPTURE valid=", valid, " states=", states.keys(), " loot=", loot_seen)
	get_tree().quit(0 if valid else 1)
