extends Node
## Uses the production game, resources, layouts and controllers. Poses are held
## for repeatable art comparison; no textures, filters or colors are overridden.
var output := ""
var game: GameRoot
var player: PlayerController
var battle: BattleRoot
var shots: Array = []
var enemies: Array[EnemyController] = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame

func capture(name: String, subjects: Array = []) -> void:
	var row := {"name":name,"viewport":[get_tree().root.size.x,get_tree().root.size.y],"subjects":[]}
	for subject: Sprite2D in subjects:
		var rect: Rect2 = subject.get_global_transform_with_canvas()*subject.get_rect()
		row.subjects.append({"name":str(subject.get_parent().name),"texture":subject.texture.resource_path,
			"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"frame":subject.frame,
			"scale":[subject.global_scale.x,subject.global_scale.y]})
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)
	shots.append(row)

func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	var flow := game.get_main_flow_coordinator()
	for character in ["void_hunter","capitalist"]:
		get_tree().root.size = Vector2i(1280,720)
		get_tree().root.content_scale_size = Vector2i(1280,720)
		flow.enter_battle_selection("character_"+character,[])
		await frames()
		assert(flow.confirm_character_selection())
		await frames(12)
		battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
		if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
			battle.combat_guide.skip_button.pressed.emit()
			await frames()
		player = battle.player
		battle.wave_manager.set_process(false)
		battle.wave_manager.clear_enemies()
		player.set_physics_process(false)
		player.position = Vector2.ZERO
		player._sync_camera()
		player.camera_2d.force_update_scroll()
		await frames()
		if character == "void_hunter":
			var ids := ["enemy_mutated_grub","enemy_echo_bat","enemy_elite_rusher","enemy_underworld_wolf"]
			var points := [Vector2(-230,85),Vector2(-80,105),Vector2(95,110),Vector2(280,110)]
			for index in ids.size():
				var actor := battle.wave_manager.spawn_enemy(ids[index],points[index]) as EnemyController
				assert(actor != null)
				actor.set_physics_process(false)
				actor.set_process(false)
				enemies.append(actor)
			await frames()
			# Complete their real spawn-warning state before holding the poses.
			(enemies[2] as EliteRusher)._process_special_behavior(1.0)
			(enemies[3] as UnderworldWolf)._process_special_behavior(1.0)
			assert(enemies[2].sprite.visible and enemies[3].sprite.visible)
			(enemies[1] as EchoBat).skill_state = "move"
			(enemies[1] as EchoBat)._flap_time = 0
			(enemies[1] as EchoBat)._animate(0)
			(enemies[3] as UnderworldWolf).set_animation(&"move")
			for viewport in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1536,864)]:
				get_tree().root.size = viewport
				get_tree().root.content_scale_size = viewport
				await frames(8)
				await capture("battle_%d"%viewport.x,[player.sprite,enemies[0].sprite,enemies[1].sprite,enemies[2].sprite,enemies[3].sprite])
			get_tree().root.size = Vector2i(1280,720)
			get_tree().root.content_scale_size = Vector2i(1280,720)
			await frames(8)
			for index in 21:
				enemies[0]._set_movement_visual(true,1.0/14)
				(enemies[1] as EchoBat)._animate(1.0/14)
				(enemies[3] as UnderworldWolf).animate(1.0/10)
				await frames(2)
				await capture("enemies_%02d"%index,[enemies[0].sprite,enemies[1].sprite,enemies[2].sprite,enemies[3].sprite])
			var knight := enemies[2] as EliteRusher
			for action in [&"move",&"windup",&"dash",&"recover"]:
				knight._set_animation(action)
				for index in EliteRusher.FRAMES.get_frame_count(action):
					knight._animation_time = (float(index)+0.1)/EliteRusher.FRAMES.get_animation_speed(action)
					knight._state_time = (float(index)+0.1)/EliteRusher.FRAMES.get_frame_count(action)*float(knight._profile.get(str(action)+"_ms",400))/1000.0
					knight._animate(0)
					await frames(2)
					await capture("knight_%s_%02d"%[action,index],[knight.sprite])
			var wolf := enemies[3] as UnderworldWolf
			for action in [&"breath_charge",&"breath",&"leap_charge",&"leap",&"land"]:
				wolf.set_animation(action)
				for index in UnderworldWolf.FRAMES.get_frame_count(action):
					wolf.animation_time = (float(index)+0.1)/UnderworldWolf.FRAMES.get_animation_speed(action)
					wolf.animate(0)
					await frames(2)
					await capture("wolf_%s_%02d"%[action,index],[wolf.sprite])
			var bat := enemies[1] as EchoBat
			for index in 9:
				bat.skill_state = "charge" if index<3 else ("warning" if index<8 else "release")
				bat.state_time = (float(index)+0.1)/3*.2 if index<3 else (float(index-3)+0.1)/5*.5
				bat._animate(0)
				await frames(2)
				await capture("bat_attack_%02d"%index,[bat.sprite])
		for index in player.walk_frame_count:
			player._walk_animation_time = float(index)/player.walk_animation_fps
			player._update_walk_animation(Vector2.RIGHT,0)
			await frames(2)
			await capture(character+"_walk_%02d"%index,[player.sprite])
		player._set_facing(false)
		await frames(2)
		await capture(character+"_left",[player.sprite])
		player._set_facing(true)
		player._apply_idle_visual()
		if character == "void_hunter":
			battle.wave_manager.clear_enemies()
			enemies.clear()
			var ground := get_tree().get_first_node_in_group("battle_cavern") as CavernBattleBackdrop
			var locations: Dictionary = {}
			for nodes: Array in ground.cells.values():
				for node: Sprite2D in nodes:
					var entry: Dictionary = node.get_meta("scenery")
					if entry.kind == "prop" and not locations.has(entry.source_id):
						locations[entry.source_id] = node.global_position
			# Query deterministic production placements beyond the opening view.
			# The camera then streams those real cells before each capture.
			for y in range(-6,7):
				for x in range(-6,7):
					for entry: Dictionary in ground._plan_cell(Vector2i(x,y)):
						if entry.kind == "prop" and not locations.has(entry.source_id):
							locations[entry.source_id] = entry.point
			assert(locations.size() == ground.config.props.size())
			for id: String in locations:
				var found := false
				player.position = locations[id]-Vector2(170,40)
				player._sync_camera()
				player.camera_2d.force_update_scroll()
				await frames(8)
				for nodes: Array in ground.cells.values():
					for node: Sprite2D in nodes:
						if node.texture.resource_path.get_file().get_basename()==id and node.global_position.distance_to(locations[id])<1:
							await capture("stone_"+id,[node])
							found = true
				assert(found,"Configured stone was not captured: "+id)
			flow.finish_current_wave()
			await frames(25)
			var popup := game.find_child("FinancePopup",true,false) as FinancePopup
			assert(popup != null and popup.visible)
			popup.interest_arrival.skip()
			if popup.trade_presentation != null and popup.trade_presentation.is_active():
				popup.trade_presentation._no.pressed.emit()
			await frames(8)
			for viewport in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1536,864),Vector2i(960,540)]:
				get_tree().root.size = viewport
				get_tree().root.content_scale_size = viewport
				await frames(12)
				popup.portrait.set_process(false)
				popup.portrait._elapsed = 0
				popup.portrait.expression = 0
				popup.portrait.queue_redraw()
				await frames(2)
				await capture("finance_%d"%viewport.x)
			get_tree().root.size = Vector2i(1280,720)
			get_tree().root.content_scale_size = Vector2i(1280,720)
			await frames(8)
			for state in 5:
				popup.portrait.expression = state
				popup.portrait.queue_redraw()
				await frames(2)
				await capture("goblin_%d"%state)
		flow.enter_start_page()
		await frames(12)
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("capture_metadata.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"production_scene":true,"held_poses":true,"shots":shots},"\t"))
	print("SPRITE_EDGE_REVIEW_OK shots=",shots.size())
	get_tree().quit()
