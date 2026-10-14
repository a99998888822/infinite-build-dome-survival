extends Node
## Review capture only. Current production and the user's older attached layout
## are photographed separately. No source art or production scene is rewritten.
var output := ""
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var ground: CavernBattleBackdrop
var shots: Array = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame

func move_to(point: Vector2) -> void:
	player.position = point
	player._sync_camera()
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	await frames()

func capture(name: String, data: Dictionary = {}) -> void:
	data["name"] = name
	data["viewport"] = [1280,720]
	data["player"] = [player.position.x,player.position.y]
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)
	shots.append(data)

func rect_array(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func photograph_items(mode: String) -> void:
	var locations: Dictionary = {}
	for y in range(-10,11):
		for x in range(-10,11):
			for entry: Dictionary in ground._plan_cell(Vector2i(x,y)):
				if entry.kind not in ["prop","rubble"]: continue
				var key := "%s_%d" % [entry.kind,entry.index]
				if not locations.has(key) or entry.point.length()<locations[key].point.length():
					locations[key] = entry
	var counts := {"prop":0,"rubble":0}
	for key: String in locations:
		var entry: Dictionary = locations[key]
		await move_to(entry.point-Vector2(180,90))
		var found := false
		for nodes: Array in ground.cells.values():
			for node: Sprite2D in nodes:
				var meta: Dictionary = node.get_meta("scenery")
				if meta.kind != entry.kind or meta.index != entry.index or node.global_position.distance_to(entry.point)>1: continue
				var rect: Rect2 = ground.world_to_ui*node.global_transform*node.get_rect()
				assert(Rect2(0,220,1280,370).encloses(rect),"Subject must remain visible below the darkness and above the HUD")
				await capture(mode+"_"+key,{"mode":mode,"kind":entry.kind,"index":entry.index,
					"texture":node.texture.resource_path,"rect":rect_array(rect),"scale":node.scale.x,
					"flip_h":node.flip_h,"natural_placement":true,"collision":false,"destructible":false})
				counts[entry.kind] += 1
				found = true
		assert(found,"Natural placement not found: "+key)
	assert(counts.prop == (0 if mode=="production" else 2))
	assert(counts.rubble == (7 if mode=="production" else 2))

func _run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",[])
	await frames()
	assert(flow.confirm_character_selection())
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	player = battle.player
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernBattleBackdrop
	assert(ground is CavernMeadowBackdrop)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player.set_physics_process(false)
	await move_to(Vector2.ZERO)
	await capture("production_overview",{"mode":"production"})
	await photograph_items("production")
	# Restore the still-existing older ground/props renderer in this review run.
	# Shared horizon, corner art and HUD keep their current production settings.
	var parent := ground.get_parent()
	var viewport_parent := parent.get_parent()
	ground.detach_player()
	parent.remove_child(ground)
	ground.queue_free()
	# Match the production ready-before-viewport-reparent lifecycle so the
	# renderer resolves its horizon relative to the battle scene.
	parent.reparent(battle,false)
	ground = CavernBattleBackdrop.new()
	ground.name = "Backdrop"
	parent.add_child(ground)
	parent.reparent(viewport_parent,false)
	(battle.get_node("BattleEnvironment") as BattleEnvironment).ground = ground
	ground.set_world_context(player,battle.wave_manager)
	await frames()
	await move_to(Vector2.ZERO)
	await capture("attachment_overview",{"mode":"attachment","restored_ground_only":true})
	await photograph_items("attachment")
	for index in ground.horizon.ruins.size():
		await move_to(Vector2.ZERO)
		var selected: Dictionary = {}
		for entry: Dictionary in ground.horizon.entries:
			if entry.index==index and entry.root.x>100:
				selected = entry.duplicate()
				break
		assert(not selected.is_empty())
		await move_to(Vector2((selected.root.x-720.0)/CavernBattleHorizon.RUIN_SPEED,0))
		for entry: Dictionary in ground.horizon.entries:
			if entry.slot!=selected.slot: continue
			var texture: Texture2D = ground.horizon.ruins[index]
			var size := ground.horizon.ruin_display_size(index)*float(entry.scale)
			var rect := Rect2((entry.root-Vector2(size.x*.5,size.y)).round(),size)
			await capture("far_%d"%index,{"mode":"shared","kind":"far","index":index,
				"texture":texture.resource_path,"rect":rect_array(rect),"scale":entry.scale,
				"natural_placement":true,"collision":false,"destructible":false})
	await move_to(Vector2.ZERO)
	for index in ground.horizon.foreground_root.get_child_count():
		var node := ground.horizon.foreground_root.get_child(index) as Sprite2D
		var rect: Rect2 = node.get_global_transform_with_canvas()*node.get_rect()
		await capture("foreground_%d"%index,{"mode":"shared","kind":"foreground","index":index,
			"texture":node.texture.resource_path,"rect":rect_array(rect),"scale":node.scale.x,
			"collision":false,"destructible":false})
	flow.enter_start_page()
	await frames(15)
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	var file := FileAccess.open(output.path_join("capture_metadata.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"shots":shots,"production_art_unchanged":true,
		"attachment_ground_restored_in_review_only":true,"enemy_spawning_paused":true},"\t"))
	print("OBSTACLE_CATALOG_OK shots=",shots.size())
	get_tree().quit()
