extends Node
## Exercise the installed battle through character selection; no art overrides.
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var ground: MeadowBattleBackdrop
var capture_dir := ""
var checks := 0
var failures := 0
var captures: Array = []
var metrics: Dictionary = {}


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name)) == OK,"capture "+name)
	captures.append({"file":name,"frame":Engine.get_process_frames(),"position":[player.position.x,player.position.y]})


func move_to(point: Vector2) -> void:
	player.position = point
	player._sync_camera()
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()


func collision_count(node: Node) -> int:
	var result := 1 if node is CollisionObject2D else 0
	for child in node.get_children(): result += collision_count(child)
	return result


func start_character(id: String) -> void:
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection(id,[])
	await frames()
	check(flow.confirm_character_selection(),"production character selection "+id)
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	player = battle.player
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player.set_physics_process(false)
	ground = get_tree().get_first_node_in_group("battle_meadow") as MeadowBattleBackdrop
	check(ground != null and ground.initialized,"production meadow is initialized")
	check(get_tree().get_nodes_in_group("battle_meadow").size()==1,"one streamed meadow per battle")
	check(get_tree().get_nodes_in_group("battle_wetland").is_empty(),"legacy backdrop is no longer instantiated")
	check(ground._horizon is MeadowBattleHorizon,"production horizon uses terrain-anchored ruins")
	check(player.character_id==id and player.visual_anchor.get_parent()==ground.proxy,"selected character uses root sorting")
	check(player.get_parent()==game.get_world_viewport_root(),"player physics body stays in the world")
	check(ground._foot_texture==player._idle_texture,"root bounds use the selected character texture")
	check(collision_count(ground)==0 and collision_count(ground._horizon)==0,"scenery adds no physics collisions")
	var texture: Texture2D = ground.ground_material.get_shader_parameter("ground_texture")
	check(texture.resource_path=="res://assets/sprites/background/meadow/meadow-ground.png","installed ground texture, no review override")
	check(ground.grass_atlas.resource_path=="res://assets/sprites/background/meadow/grass-atlas.png","installed grass atlas")
	check(texture.get_size()==Vector2(2176,1600),"approved continuous terrain dimensions")
	move_to(Vector2.ZERO)
	await frames()
	var sky := battle.get_node("BattleSky/Sky") as TextureRect
	check(sky.offset_top==0 and sky.offset_bottom==ceilf(get_tree().root.get_visible_rect().size.x/16.0),"C sky fills the removed top strip")
	check(not (battle.get_node("BattleTopBarBackground/Background") as CanvasItem).visible,"C top black strip stays hidden")
	var wave := battle.get_node("BattleTopBar/WavePanel") as PanelContainer
	var style := wave.get_theme_stylebox("panel") as StyleBoxFlat
	check(is_equal_approx(style.bg_color.a,.5) and is_equal_approx(style.border_color.a,.5),"wave frame has 50 percent opacity")
	check(wave.modulate.a==1 and wave.self_modulate.a==1,"wave frame does not dim its text children")
	for name in ["WaveLabel","TimerLabel"]:
		var label := wave.get_node("Content/"+name) as Label
		check(label.get_theme_color("font_color").a==1 and label.modulate.a==1,"wave text remains opaque")


func verify_streaming() -> void:
	metrics.initial_counts = ground.visible_counts()
	check(int(metrics.initial_counts.grass)==455 and int(metrics.initial_counts.small_grass)==419,"approved R05 grass layout preserved")
	check(int(metrics.initial_counts.tall_props)==0,"tall ruins absent from combat plane")
	# The approved C comparison used this station; retain its exact composition.
	var station := Vector2(0,60)
	move_to(station)
	await frames()
	var initial := ground.layout_signature()
	var ruins: Dictionary = ground._horizon.snapshot()
	metrics.c_reference_ruins = ruins
	check(not ruins.is_empty(),"reference station contains visible ruins")
	await capture("installed-c-reference.png")
	var poses := [Vector2(47,0),Vector2(0,-35),Vector2(-4300,-3300),Vector2(42000,-33000),Vector2.ZERO]
	var verified := 0
	for pose in poses:
		move_to(station+pose)
		await frames()
		check(ground.cells.size()==ground.cell_rect.get_area() and ground.cells.size()<=90,"streaming cells stay bounded")
		check(ground.plans.size()<=ground.cell_rect.grow(1).get_area(),"neighbour plans are reclaimed")
		var visible_world: Rect2 = ground.get_viewport().get_canvas_transform().affine_inverse()*ground.get_viewport_rect()
		check(Rect2(ground.ground.position,ground.ground.size).encloses(visible_world),"terrain covers the current camera")
		var current: Dictionary = ground._horizon.snapshot()
		for key in current:
			if ruins.has(key):
				check(current[key].terrain_anchor==ruins[key].terrain_anchor,"same ruin keeps fixed terrain anchor")
				verified += 1
			check(float(current[key].root_snap_error_px)<=.708,"root projection retains nearest-pixel accuracy")
			check(float(current[key].scale)>=1.4 and float(current[key].scale)<=2.3,"approved ruin display scale")
	check(verified>4,"anchor checks cover multiple camera poses")
	check(ground.layout_signature()==initial and ground._horizon.snapshot()==ruins,"far traversal and return restore the same scene")
	seed(31415)
	var expected := randi()
	seed(31415)
	ground._plan_cell(Vector2i(120,-90))
	ground._horizon._update_ruins()
	check(randi()==expected,"scenery leaves the gameplay RNG untouched")
	ground.plans.erase(Vector2i(120,-90))
	var clock := ground.get_environment_time()
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await frames()
	check(is_equal_approx(clock,ground.get_environment_time()),"environment clock pauses")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	await frames()
	check(ground.get_environment_time()>clock,"environment clock resumes")
	move_to(Vector2.ZERO)
	await frames()


func probe_occlusion(prefix: String) -> void:
	var probe: Sprite2D
	var best := INF
	for child in ground.roots.get_children():
		if child is Sprite2D and child.get_meta("grass_id","")=="G10_grass_dense-32":
			var distance: float = child.position.distance_squared_to(Vector2(0,50))
			if distance<best:
				best = distance
				probe = child
	check(probe!=null,"dense grass available for occlusion")
	if probe==null: return
	var root := probe.global_position
	var center := root+Vector2(0,-35)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	for state in ["behind","front"]:
		player.position = root+Vector2(0,-5 if state=="behind" else 7)-ground.foot_offset
		player.camera_2d.offset = center-player.position
		move_to(player.position)
		await frames()
		check((ground.proxy.global_position.y<root.y)==(state=="behind"),"actual player root order "+prefix+state)
		await capture(prefix+"probe-"+state+"-both.png")
		ground.proxy.hide()
		await frames(2)
		await capture(prefix+"probe-"+state+"-grass.png")
		probe.hide()
		await frames(2)
		await capture(prefix+"probe-"+state+"-background.png")
		ground.proxy.show()
		await frames(2)
		await capture(prefix+"probe-"+state+"-player.png")
		probe.show()
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	player.camera_2d.offset = Vector2.ZERO
	move_to(Vector2.ZERO)
	await frames()


func check_view_mapping() -> void:
	player.camera_2d.zoom = Vector2(.75,.75)
	player.camera_2d.force_update_scroll()
	await frames()
	var area: Rect2 = ground.get_viewport().get_canvas_transform().affine_inverse()*ground.get_viewport_rect()
	check(Rect2(ground.ground.position,ground.ground.size).encloses(area),"zoomed camera remains covered")
	for entry: Dictionary in ground._horizon.snapshot().values():
		check(float(entry.root_snap_error_px)<=.708,"zoom preserves terrain anchors")
	player.camera_2d.zoom = Vector2.ONE
	get_tree().root.size = Vector2i(640,360)
	get_tree().root.content_scale_size = Vector2i(640,360)
	await frames(12)
	check(ground._horizon.view_size==get_tree().root.get_visible_rect().size,"resized horizon follows UI viewport")
	await capture("small-window.png")
	get_tree().root.size = Vector2i(1152,768)
	get_tree().root.content_scale_size = Vector2i(1152,768)
	await frames(12)
	# A reduced world render size must still use UI-space terrain projection.
	game._world_viewport_container.stretch_shrink = 2
	await frames(12)
	var parameters: Dictionary = ground._horizon.surface_parameters
	var inverse := ground.get_viewport().get_canvas_transform().affine_inverse()
	var ratio := ground.get_viewport_rect().size/get_tree().root.get_visible_rect().size
	check((parameters.world_screen_x as Vector2).is_equal_approx(inverse.x*ratio.x),"separate world/UI viewport scales agree")
	game._world_viewport_container.stretch_shrink = 1
	await frames(12)
	move_to(Vector2.ZERO)
	await frames()


func _run() -> void:
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152,768)
	get_tree().root.content_scale_size = Vector2i(1152,768)
	await start_character("character_void_hunter")
	await capture("installed-meadow.png")
	await verify_streaming()
	await probe_occlusion("")
	await check_view_mapping()
	player.set_physics_process(true)
	for i in 180:
		var directions := [Vector2.RIGHT*.25,Vector2.UP*.20,Vector2.LEFT*.25,Vector2.DOWN*.20]
		player.set_mobile_move_direction(directions[int(i/45)])
		await get_tree().physics_frame
		await get_tree().process_frame
		if i%3==0: await capture("tour_%03d.png" % int(i/3))
	player.set_mobile_move_direction(Vector2.ZERO)
	var flow := game.get_main_flow_coordinator()
	var old_visual: WeakRef = weakref(player.visual_anchor)
	flow.enter_start_page()
	await frames(20)
	check(get_tree().get_nodes_in_group("battle_meadow").is_empty(),"return to menu frees scenery")
	check(old_visual.get_ref()==null,"player visual is released with its battle")
	await start_character("character_capitalist")
	await capture("capitalist-installed.png")
	await probe_occlusion("capitalist-")
	player.set_physics_process(true)
	battle.wave_manager.set_process(true)
	var before := battle.wave_manager.wave_time_left
	await frames(150)
	check(battle.wave_manager.wave_time_left<before,"normal combat progresses with installed meadow")
	await capture("live-combat.png")
	flow.enter_start_page()
	await frames(20)
	check(get_tree().get_nodes_in_group("battle_meadow").is_empty(),"second battle releases all streamed scenery")
	game.queue_free()
	await frames(8)
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
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"production_scene":true,
			"no_art_overrides":true,"metrics":metrics,"captures":captures,"fixed_fps":30},"\t"))
	print("MEADOW_INSTALL_REVIEW checks=",checks," failures=",failures)
	get_tree().quit.call_deferred(0 if failures==0 else 1)
