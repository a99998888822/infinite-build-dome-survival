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
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	var manager: WaveManager = battle.wave_manager
	manager.set_process(false)
	var player: PlayerController = battle.player
	player.set_physics_process(false)
	var origin := player.global_position
	player.global_position = origin + Vector2(0, -84)
	player.add_runtime_modifier({"id": "capture_pickup", "source_id": "capture", "source_type": "test", "stat": "pickup_radius", "operation": "override", "value": 0, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		enemy.free()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		runtime.queue_free()
	await frames(2)
	var drops := manager.drop_reward_system
	drops.spawn_exp_orb(1, origin + Vector2(-176,26), manager.pickup_root, player)
	drops.spawn_health_pack(1, origin + Vector2(-76,26), manager.pickup_root, player)
	drops.spawn_augmentation("scroll_lightning", 1, origin + Vector2(24,26), manager.pickup_root, player)
	var relic := drops.spawn_action({"type": "relic", "amount": 1}, origin + Vector2(164,26), manager.pickup_root, player) as RelicPickup
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for index in 180:
		await RenderingServer.frame_post_draw
		var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
		if error != OK:
			get_tree().quit(4)
			return
	var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"production": true, "fps": 60, "frames": 180,
		"relic_icon_size": RelicPickup.ICON_SIZE, "health_icon_size": 16,
		"augmentation_icon_size": 16, "exp_display_size": 8,
		"alive_at_end": is_instance_valid(relic) and not relic.collected_once}, "\t"))
	file.close()
	print("RELIC_PICKUP_CAPTURE_COMPLETE frames=180 size=", RelicPickup.ICON_SIZE)
	get_tree().quit()
