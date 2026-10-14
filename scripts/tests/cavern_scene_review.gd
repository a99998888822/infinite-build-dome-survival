extends Node
## Production scene through character selection, with actual movement input.
## Scenery tour pauses enemy spawning only; no rendering or art overrides.
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var ground: CavernBattleBackdrop
var capture_dir := ""
var checks := 0
var failures: Array[String] = []
var samples: Array = []
var captures: Array = []
var quick := false
var entry_samples: Array = []
var foreground_review := false
var foreground_assets: Array[Dictionary] = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--quick": quick = true
		if arg == "--foreground-review": foreground_review = true
	_run.call_deferred()

func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name)) == OK,"capture "+name)
	captures.append({"file":name,"frame":Engine.get_process_frames()})

func move_to(point: Vector2) -> void:
	player.position = point
	player._sync_camera()
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()

func capture_foreground_details() -> void:
	for node: Node in ground.horizon.foreground_root.get_children():
		var sprite := node as Sprite2D
		check(sprite.texture.get_size()==Vector2(128,128),"installed foreground is 128px")
		check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"foreground uses sharp nearest sampling")
		var image := sprite.texture.get_image()
		if image.is_compressed(): image.decompress()
		var used := image.get_used_rect()
		var bounds: Rect2 = sprite.global_transform*Rect2(used)
		foreground_assets.append({"texture":sprite.texture.resource_path,"size":[128,128],
			"position":[sprite.position.x,sprite.position.y],"scale":[sprite.scale.x,sprite.scale.y],
			"opaque_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
			"filter":sprite.texture_filter})
	# Inspection only: keep the production art/camera unchanged and restore UI.
	var hidden: Array[CanvasLayer] = []
	for node: Node in get_tree().root.find_children("*","CanvasLayer",true,false):
		var layer := node as CanvasLayer
		if layer.layer>=0 and layer.visible:
			hidden.append(layer)
	check(not hidden.is_empty(),"foreground detail capture finds mounted HUD layers")
	# UI layers may be mounted outside GameRoot and their visibility is refreshed
	# every frame. Suppress them immediately before drawing this one screenshot.
	if DisplayServer.get_name()!="headless":
		RenderingServer.frame_pre_draw.connect(func() -> void:
			for layer: CanvasLayer in hidden: layer.hide()
		,CONNECT_ONE_SHOT)
	await capture("foreground_clear.png")
	for layer: CanvasLayer in hidden: layer.show()
	await frames(2)

func _run() -> void:
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
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
	check(flow.confirm_character_selection(),"production character selection")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	check(flow.get_current_state()==MainFlowCoordinator.STATE_WAVE_COMBAT,"guide skipped through its production button")
	player = battle.player
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernBattleBackdrop
	check(ground != null and ground.initialized,"production cave initialized")
	if ground == null:
		get_tree().quit(1)
		return
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player.set_physics_process(false)
	move_to(Vector2.ZERO)
	await frames()
	var initial := ground.layout_signature()
	var ruins := ground.horizon.snapshot()
	var common := 0
	move_to(Vector2(200,0))
	await frames()
	var shifted := ground.horizon.snapshot()
	for key in ruins:
		if not shifted.has(key): continue
		common += 1
		check(is_equal_approx(float(shifted[key].root[0])-float(ruins[key].root[0]),-36.0),"ruin movement is 18 percent")
		check(shifted[key].scale == ruins[key].scale and shifted[key].root[1] == ruins[key].root[1],"ruins keep height and scale")
	check(common>=1,"a sparse ruin landmark remains visible for the parallax measurement")
	move_to(Vector2(200,-1800))
	await frames()
	check(ground.horizon.snapshot()==shifted,"vertical approach never shrinks or removes distant ruins")
	for position in [Vector2(-6200,4700),Vector2(42000,-33000),Vector2.ZERO]:
		move_to(position)
		await frames()
		check(ground.cells.size()==ground.cell_rect.get_area() and ground.cells.size()<120,"streaming stays bounded after long traversal")
		var visible_world: Rect2 = ground.get_viewport().get_canvas_transform().affine_inverse()*ground.get_viewport_rect()
		check(Rect2(ground.ground.position,ground.ground.size).encloses(visible_world),"base ground covers viewport")
	check(ground.layout_signature()==initial,"return restores identical cropped patch layout")
	check(ground.horizon.snapshot()==ruins,"return restores identical distant landmarks")
	seed(515151)
	var expected := randi()
	seed(515151)
	ground._plan_cell(Vector2i(93,-51))
	ground.horizon._update_entries()
	check(randi()==expected,"scenery leaves gameplay RNG untouched")
	if ground is CavernMeadowBackdrop:
		check(ground.ground_textures.is_empty() and ground.detail_textures.is_empty(),"production meadow replaces imported 01 patches")
		check(ground.grass_textures.size()==4 and ground.rubble_textures.size()==9,"approved grass and all B/Q rubble are loaded")
		check(ground.ground_material.get_shader_parameter("surface_texture").resource_path=="res://assets/sprites/background/meadow/meadow-ground.png","ground references the original production texture")
		check(is_equal_approx(ground.ground_material.get_shader_parameter("projection_y"),AttackFootprint.ELLIPSE_RATIO),"surface tilt uses the weapon footprint ratio")
		var scenery_count := 0
		for nodes: Array in ground.cells.values(): scenery_count += nodes.size()
		check(scenery_count<ground.cells.size()*60,"production scenery remains bounded")
	else:
		check(ground.ground_textures.size()==1 and int(ground.config.ground[0].catalog_number)==1,"only catalog 01 is used on the floor")
		check(not ground.grass_textures.is_empty(),"grass cutouts are loaded")
		check(ground.detail_textures.size()==6 and ground.rubble_textures.size()==2,"source-derived cracks and loose stones are loaded")
		var local_detail_count := 0
		for key: Vector2i in ground.cells:
			for node: Node in ground.cells[key]:
				if node.get_meta("scenery").kind=="detail": local_detail_count += 1
		check(local_detail_count>0 and local_detail_count<=ground.cells.size()*2,"small detail groups remain sparse and bounded")
	check(player.visual_anchor.get_parent()==ground.proxy,"player depth proxy preserved")
	check(player.get_parent()==game.get_world_viewport_root(),"player physics ownership preserved")
	player.camera_2d.zoom = Vector2(.75,.75)
	await frames()
	check(is_equal_approx(ground.horizon.camera_scale,.75),"parallax accounts for camera zoom")
	player.camera_2d.zoom = Vector2.ONE
	game._world_viewport_container.stretch_shrink = 2
	await frames()
	check(is_equal_approx(ground.horizon.camera_scale,2.0),"parallax scales with the enlarged world viewport")
	game._world_viewport_container.stretch_shrink = 1
	# Let the renderer settle after traversal and viewport resize checks before
	# photographing the production view. No art or performance HUD overrides.
	await frames(40)
	await capture("cavern_still.png")
	if foreground_review: await capture_foreground_details()
	check((ground.horizon.get_parent() as CanvasLayer).layer>-3,"darkness occludes the complete combat viewport")
	check(ground.horizon.darkness_end()>=ground.horizon.far_height(),"all cave artwork is outside the monster reveal band")
	var mean_width := 0.0
	for variants: Array in ground.ground_textures: mean_width += (variants[0] as Texture2D).get_width()*CavernBattleBackdrop.PATCH_SCALE/float(ground.config.get("ground_texture_density",1.0))/float(ground.ground_textures.size())
	if not ground is CavernMeadowBackdrop:
		check(mean_width>=1200,"complete 01 remains large in world space")
	var entry_probe := battle.wave_manager.spawn_enemy("enemy_echo_bat",Vector2(100,-420)) as EchoBat
	entry_probe.set_physics_process(false)
	check(not ground.get_darkness_entry_direction(entry_probe.global_position).is_zero_approx(),"enemy above the dark band must approach")
	entry_probe.cooldown = 0.0
	entry_probe._physics_process(1.0/30.0)
	check(entry_probe.skill_state=="move" and entry_probe.velocity.y>0,"hidden bat approaches instead of firing")
	entry_probe.queue_free()
	await frames()
	if not quick:
		player.set_physics_process(true)
		for i in 180:
			var direction := Vector2.RIGHT if i<90 else Vector2.LEFT
			player.set_mobile_move_direction(direction*.62)
			await frames(2)
			await capture("tour_%03d.png" % i)
			samples.append({"i":i,"frame":Engine.get_process_frames(),"player_x":player.position.x,
				"camera_x":ground.horizon.camera_x,"ruins":ground.horizon.snapshot(),
				"loaded_cells":ground.cells.size(),"fragments":ground.decals.get_child_count()})
		player.set_mobile_move_direction(Vector2.ZERO)
		check(float(samples[89].player_x)-float(samples[0].player_x)>300,"actual player input travels right")
		check(float(samples[89].player_x)-float(samples[179].player_x)>300,"actual player input returns left")
		move_to(Vector2.ZERO)
		await frames()
		await capture("entry_empty.png")
		var bat := battle.wave_manager.spawn_enemy("enemy_echo_bat",Vector2(120,-420)) as EchoBat
		battle.wave_manager.spawn_enemy("enemy_mutated_grub",Vector2(-155,-410))
		for i in 120:
			await frames(2)
			await capture("entry_%03d.png" % i)
			if is_instance_valid(bat):
				entry_samples.append({"frame":Engine.get_process_frames(),"screen_y":(ground.world_to_ui*bat.global_position).y,
					"state":bat.skill_state,"must_approach":not ground.get_darkness_entry_direction(bat.global_position).is_zero_approx()})
		for sample: Dictionary in entry_samples:
			if sample.must_approach: check(sample.state=="move","hidden ranged enemy never begins attack")
		check(not entry_samples.is_empty() and float(entry_samples.back().screen_y)>ground.horizon.reveal_end(),"live bat emerges from darkness")
		battle.wave_manager.clear_enemies()
		battle.wave_manager.set_process(true)
		var before := battle.wave_manager.wave_time_left
		await frames(120)
		check(battle.wave_manager.wave_time_left<before,"normal combat resumes and progresses")
		await capture("live_combat.png")
	var visual: WeakRef = weakref(player.visual_anchor)
	flow.enter_start_page()
	await frames(15)
	check(get_tree().get_nodes_in_group("battle_cavern").is_empty(),"return to menu releases streamed scene")
	check(visual.get_ref()==null,"player visual freed with battle")
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for audio in AudioManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(.25).timeout
	CampProgression.end_transient_session()
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("verification.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"entry_samples":entry_samples,"captures":captures,
			"production_scene":true,"art_overrides":false,"fixed_fps":30,"tour_enemy_spawning_paused":true,
			"foreground_assets":foreground_assets,"detail_capture_hides_hud_only":foreground_review},"\t"))
	print("CAVERN_REVIEW checks=",checks," failures=",failures)
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
