extends Node
## Exercise the production entrance, pause lifecycle, streaming and receivers.
var game: GameRoot
var flow: MainFlowCoordinator
var battle: BattleRoot
var player: PlayerController
var ground: CavernSunlightBackdrop
var output := ""
var record := false
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var weapon_fires := 0
var population_report: Dictionary = {}
var depth_only := false

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg == "--record": record = true
		if arg == "--depth-only": depth_only = true
	_run.call_deferred()

func frames(count: int = 6) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)
	var objects: Array = []
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if not node is Sprite2D: continue
			var entry: Dictionary = node.get_meta("scenery")
			if entry.kind not in ["rubble","prop"]: continue
			var point: Vector2 = ground.world_to_ui * entry.point
			if not Rect2(Vector2.ZERO,ground.horizon.view_size).has_point(point) or point.y<=ground.horizon.reveal_at(point.x): continue
			objects.append({"kind":entry.kind,"index":entry.index,"screen":[point.x,point.y]})
	captures.append({"file": label + ".png", "frame": Engine.get_process_frames(), "time": ground.environment_time,
		"player_screen_y": (ground.world_to_ui * player.global_position).y,
		"view_height": ground.horizon.view_size.y, "population_seed": ground.population_seed,"visible_objects":objects,
		"ruins":ground.horizon.snapshot()})

func move_to(point: Vector2) -> void:
	player.global_position = point
	player._sync_camera()
	player.camera_2d.force_update_scroll()
	await frames()

func verify_framing() -> void:
	for size in [Vector2i(1152, 648), Vector2i(1600, 900), Vector2i(1152, 864)]:
		get_tree().root.size = size
		await frames()
		player._sync_camera()
		player.camera_2d.force_update_scroll()
		await frames(2)
		var screen := player.get_global_transform_with_canvas().origin
		var view := player.get_viewport_rect().size
		check(absf(screen.y - view.y * .57) <= 1.0 and absf(screen.x - view.x * .5) <= 1.0,
			"player stays at 57 percent height after resizing to " + str(size))
		await capture("framing_%dx%d" % [size.x, size.y])
	get_tree().root.size = Vector2i(1152, 648)
	await frames()
	for zoom in [1.25, 1.0]:
		player.camera_2d.zoom = Vector2.ONE * zoom
		player._sync_camera()
		player.camera_2d.force_update_scroll()
		await frames(2)
		var screen := player.get_global_transform_with_canvas().origin
		check(absf(screen.y - player.get_viewport_rect().size.y * .57) <= 1.0,
			"player framing survives zoom " + str(zoom))

func verify_receivers() -> void:
	var expected := 0
	var colliders := 0
	var props := 0
	var valid := true
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if not node is Sprite2D: continue
			var sprite := node as Sprite2D
			var entry: Dictionary = sprite.get_meta("scenery")
			if entry.kind == "prop":
				props += 1
				for child: Node in sprite.get_children():
					if child is StaticBody2D: colliders += 1
			if entry.kind == "contact": continue
			expected += 1
			var material := sprite.material as ShaderMaterial
			valid = valid and material.shader.resource_path.begins_with(CavernSunlightBackdrop.SHADERS)
			valid = valid and material.get_shader_parameter("cloud_texture") == CavernSunlightBackdrop.CLOUD_TEXTURE
			valid = valid and absf(float(material.get_shader_parameter("sun_time")) - ground.environment_time) < .04
	check(valid and expected == ground.lit_objects.size(), "streamed objects share current production lighting without stale receivers")
	check(props == colliders, "every large obstacle retains its collision body")
	for material: ShaderMaterial in [ground.ground_material, ground.grass_material, ground.hero_material]:
		check(material.shader.resource_path.begins_with(CavernSunlightBackdrop.SHADERS), "receiver shader uses a production path")
		check(material.get_shader_parameter("cloud_texture") == CavernSunlightBackdrop.CLOUD_TEXTURE, "receiver uses the imported cloud texture")
	check(ground.cells.size() <= 30, "streaming stays bounded")

func solid_signature(backdrop: CavernPopulationBackdrop) -> Array:
	var result: Array = []
	for y in range(-2,3):
		for x in range(-2,3): result.append(backdrop._solid_plan(Vector2i(x,y)).entries)
	return result

func verify_horizon() -> void:
	var horizon := ground.horizon as CavernPitHorizon
	var inside := true
	var all_clear := true
	var cave_level := true
	var beside_cave := true
	var no_combat_props := true
	var sampled := 0
	# Check rendered rectangles after rounding, across each complete lower edge.
	for size in [Vector2(1152,648),Vector2(1600,900),Vector2(1152,864)]:
		for x in range(-24000,24001,577):
			horizon.configure_view(size,float(x),1.0)
			for child: Node in horizon.find_children("*","Sprite2D",true,false):
				no_combat_props = no_combat_props and not (child as Sprite2D).texture in ground.prop_textures
			for sprite: Sprite2D in horizon.ruin_sprites:
				if not sprite.visible: continue
				var rect: Rect2 = sprite.transform*sprite.get_rect()
				cave_level = cave_level and rect.position.y>=12.0*horizon.art_scale*CavernPitHorizon.FAR_SCALE_RATIO and rect.end.y<=horizon.darkness_end()
				var side_gap := INF
				for pixel in range(floori(rect.position.x),ceili(rect.end.x)+1):
					inside = inside and rect.end.y <= horizon.reveal_at(float(pixel))
				for opening: Dictionary in horizon.cave_openings():
					all_clear = all_clear and not rect.intersects(opening.rect)
					var cave: Rect2 = opening.rect
					side_gap = minf(side_gap,minf(absf(rect.end.x-cave.position.x),absf(rect.position.x-cave.end.x)))
				# Only fully on-screen art needs its neighboring opening on-screen.
				if rect.position.x>100*horizon.art_scale and rect.end.x< size.x-100*horizon.art_scale:
					beside_cave = beside_cave and side_gap<=11.0*horizon.art_scale*CavernPitHorizon.FAR_SCALE_RATIO
				sampled += 1
	check(inside and sampled>400,"all drawn distant texture bottoms stay above the ellipse across camera positions and aspect ratios")
	check(all_clear,"raised distant art also stays clear of cave openings")
	check(cave_level,"all distant art is inside the cave-height band rather than on the ground arc")
	check(beside_cave,"distant art sits beside cave opening edges within the wall gaps")
	check(no_combat_props,"A01 and A05 never appear anywhere in the far scenery tree across camera positions")
	var seen: Dictionary = {}
	for x in [-6000.0,0.0,6000.0]:
		await move_to(Vector2(x,0))
		var clear := true
		var visible := 0
		for i in horizon.entries.size():
			var entry: Dictionary = horizon.entries[i]
			var sprite := horizon.ruin_sprites[i]
			var size := horizon.ruin_display_size(entry.index)*float(entry.scale)
			var rect := Rect2(entry.root-Vector2(size.x*.5,size.y),size)
			for opening: Dictionary in horizon.cave_openings(): clear = clear and not rect.intersects(opening.rect)
			if sprite.is_visible_in_tree() and sprite.modulate.a>.25 and sprite.texture!=null:
				visible += 1
				seen[entry.index] = true
		check(visible>=2 and visible<=4, "sparse cave-side ruin sprites remain visible at camera " + str(x))
		check(clear, "ruin silhouettes avoid the cave artwork at camera " + str(x))
		await capture("ruins_%d" % int(x))
	check(seen.size()==horizon.config.ruins.size(), "horizontal exploration reveals all four ruin textures")
	await move_to(Vector2.ZERO)
	var start := horizon.snapshot()
	await move_to(Vector2(100,0))
	var moved := horizon.snapshot()
	var parallax := false
	for key: String in start:
		if moved.has(key): parallax = is_equal_approx(float(moved[key].root[0])-float(start[key].root[0]),-8.0)
	check(parallax, "ruins share eight-percent cave parallax and stay attached to their openings")
	var wrap_stable := true
	for boundary in [-1725.0,21510.0]:
		await move_to(Vector2(boundary-4.0,0))
		var before := horizon.snapshot()
		await move_to(Vector2(boundary+4.0,0))
		var after := horizon.snapshot()
		for key: String in before:
			if after.has(key):
				wrap_stable = wrap_stable and before[key].index==after[key].index and absf(float(after[key].root[0])-float(before[key].root[0])+.64)<=1.0
	check(wrap_stable,"panorama wrapping preserves each ruin identity and wall placement")
	await move_to(Vector2(100,300))
	check(horizon.snapshot()==moved, "vertical movement leaves screen-space ruins stable")
	await move_to(Vector2.ZERO)
	check(horizon.snapshot()==start, "returning restores identical ruin placement")
	check(horizon.ruin_sprites.size()<=4, "distant ruin sprite pool stays bounded")

func verify_population() -> void:
	var probe := CavernGrasslandBackdrop.new()
	probe.config = ground.config
	probe.surface_context = ground.surface_context
	probe.sample_offset = ground.sample_offset
	probe.population_seed = ground.population_seed
	check(ground.population_seed != 0, "normal battle chooses its own population seed")
	for cell in [Vector2i.ZERO,Vector2i(-1,0),Vector2i(2,-3)]:
		check(probe._plan_cell(cell) == ground._plan_cell(cell), "same seed reproduces grass and objects " + str(cell))
	var original := solid_signature(probe)
	probe.population_seed += 1
	check(solid_signature(probe) != original, "another seed changes object positions and types")
	var sparse := true
	var stable := true
	var separation := true
	var spawn_clear := true
	var small_count := 0
	var minimum_gap := INF
	for value in [1,101,1729,20261015,ground.population_seed]:
		probe.population_seed = value
		var points: Array[Vector2] = []
		var planned: Dictionary = {}
		for y in range(-3,4):
			for x in range(-3,4):
				var key := Vector2i(x,y)
				var entries: Array = probe._solid_plan(key).entries
				planned[key] = entries
				var count := 0
				for entry: Dictionary in entries:
					if entry.kind == "rubble":
						count += 1
						points.append(entry.point)
					else: spawn_clear = spawn_clear and entry.point.length() >= 259.0
				small_count += count
				sparse = sparse and count <= 2
		# Reverse cell order must not consume shared RNG state or alter neighbors.
		var keys := planned.keys()
		keys.reverse()
		for key: Vector2i in keys: stable = stable and planned[key] == probe._solid_plan(key).entries
		for i in points.size():
			for j in range(i+1,points.size()): minimum_gap = minf(minimum_gap,points[i].distance_to(points[j]))
		var landmarks: Array[Vector2] = []
		for y in range(-2,3):
			for x in range(-2,3): landmarks.append(probe.landmark(Vector2i(x,y)).point)
		for i in landmarks.size():
			for j in range(i+1,landmarks.size()): separation = separation and landmarks[i].distance_to(landmarks[j]) >= 338.0
	check(sparse and float(small_count)/245.0 < 1.25, "random small objects remain sparse across 245 cells and five seeds")
	check(minimum_gap >= 53.0, "small objects retain spacing across negative coordinates and cell borders")
	check(separation and spawn_clear, "large obstacles stay separated and leave the starting clearing open")
	check(stable, "streaming in reverse order reproduces identical objects")
	population_report = {"first_seed":ground.population_seed,"sampled_cells":245,"small_objects":small_count,
		"mean_small_per_cell":float(small_count)/245.0,"minimum_small_gap":minimum_gap}
	probe.free()

func depth_crop() -> Image:
	await RenderingServer.frame_post_draw
	var center := player.sprite.get_global_transform_with_canvas().origin
	return player.get_viewport().get_texture().get_image().get_region(Rect2i(Vector2i(center)-Vector2i(48,64),Vector2i(96,128)))

func verify_grass_depth() -> void:
	await move_to(Vector2.ZERO)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	ground.environment_time = 12.0
	player.action_animator.reset()
	var source := player.sprite
	var original_scale := source.scale
	var original_facing := player.visual_anchor.scale
	var saved_groups := ground.grass_cells
	# The contact marker shares z=-1 with the forced-behind reference.
	# Hide it only in the fixture so the reference changes grass/player order alone.
	player.get_node("GroundMarker").hide()
	var hidden: Array[CanvasItem] = []
	for nodes: Array in ground.cells.values():
		for node: CanvasItem in nodes:
			if node.visible: hidden.append(node); node.hide()
	for factor in [.5,.75]:
		source.scale = Vector2.ONE*factor
		player.visual_anchor.scale.x = -1.0 if factor==.75 else 1.0
		ground._update_area()
		var bounds := source.texture.get_image().get_used_rect()
		var feet: Vector2 = source.global_transform*(source.get_rect().position+Vector2(bounds.position.x+bounds.size.x*.5,bounds.end.y))
		check(absf(ground.proxy.global_position.y-feet.y)<.01,"sort anchor matches rendered feet at sprite scale " + str(factor))
		for delta in [-4.0,0.0,4.0]:
			var point := Vector2(player.global_position.x,feet.y+delta)
			var entry := ground._placement("grass",1,point,1.25,false)
			entry.tint = Color(.65,.73,.70)
			# This is the real dense grass asset; its alpha bottom is at anchor 26.
			entry.sort_y = point.y
			var blades: Array[Dictionary] = [entry]
			var back := ground._grass_batch(blades,Vector2i.ZERO,false)
			var front := ground._grass_batch(blades,Vector2i.ZERO,true)
			ground.grass_cells = {Vector2i.ZERO:{"blades":blades,"bands":[{"blades":blades,"back":back,"front":front,"origin":Vector2.ZERO}]}}
			ground._update_area()
			await frames(2)
			if DisplayServer.get_name() != "headless":
				var label := "grass_%d_%s" % [int(factor*100),"behind" if delta<0 else ("equal" if delta==0 else "front")]
				var actual: Image = await depth_crop()
				await capture(label)
				if not output.is_empty(): actual.save_png(output.path_join(label+"_crop.png"))
				# Force both alternatives without changing art, position or lighting.
				# The expected image proves draw order, independently of CPU anchors.
				for batch in [back,front]: batch.get_parent().z_index = -1 if delta<=0 else 1
				await frames(2)
				var expected: Image = await depth_crop()
				for batch in [back,front]: batch.get_parent().z_index = 1 if delta<=0 else -1
				await frames(2)
				var opposite: Image = await depth_crop()
				if not output.is_empty():
					expected.save_png(output.path_join(label+"_expected.png"))
					opposite.save_png(output.path_join(label+"_opposite.png"))
				check(expected.get_data()!=opposite.get_data(),label+" fixture has visible overlapping pixels")
				check(actual.get_data()==expected.get_data(),label+" GPU pixels match the required front/back order")
			back.get_parent().free()
			front.get_parent().free()
			ground.grass_cells = saved_groups
	source.scale = original_scale
	player.visual_anchor.scale = original_facing
	player.get_node("GroundMarker").show()
	for node: CanvasItem in hidden: node.show()
	ground.grass_cells = saved_groups
	ground._update_area()
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	# Animation and sprite transforms must refresh the foot without rebuilding
	# thousands of grass instances, including a frame change on the same sheet.
	var frames_valid := true
	var stationary := true
	for clip in ["idle","move","attack","sustain","move_sustain","jump_forward","jump_backward"]:
		var count: int = player.action_animator._clips[clip].get("frames",1)
		for frame in count:
			player.action_animator._show(clip,frame)
			var before := source.global_transform
			ground._update_area()
			stationary = stationary and source.global_transform.is_equal_approx(before)
			var frame_size := source.texture.get_size()/Vector2(source.hframes,source.vframes)
			var bounds := source.texture.get_image().get_region(Rect2i(Vector2(source.frame_coords)*frame_size,frame_size)).get_used_rect()
			var feet: Vector2 = source.global_transform*(source.get_rect().position+Vector2(0,bounds.end.y))
			frames_valid = frames_valid and absf(ground.proxy.global_position.y-feet.y)<.01
	check(frames_valid,"all action frames sort at their actual scaled feet")
	check(stationary,"refreshing foot anchors never moves player artwork")
	player.action_animator.reset()
	ground._update_area()

func _run() -> void:
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 648)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "normal character selection enters battle")
	await frames(16)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	player = battle.player
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	check(ground != null and ground.lighting_ready, "production entrance loads sunlight without a preview swap")
	if ground == null:
		get_tree().quit(1)
		return
	check(ground.get_script().resource_path == "res://scripts/battle/cavern_sunlight_backdrop.gd", "formal battle owns the installed script")
	check(ground.horizon.get_script().resource_path == "res://scripts/battle/cavern_pit_horizon.gd", "formal battle uses the accepted cave-side ruins directly")
	var obstacle_ids: Array = []
	for row: Dictionary in ground.config.props: obstacle_ids.append(row.catalog_id)
	check(obstacle_ids.has("A01") and obstacle_ids.has("A05") and ground.prop_textures.size()==2,
		"A01 rock and A05 log remain loaded as production combat obstacles")
	check(player.get_viewport_rect().size == Vector2(1152, 648) and player.camera_2d.zoom == Vector2.ONE, "normal 1x world resolution and camera")
	check(not (ground.horizon as CavernPitHorizon).pit_light.visible, "old additive light is replaced rather than doubled")
	check(CavernSunlightBackdrop.CLOUD_TEXTURE.resource_path == "res://assets/sprites/background/meadow/sunlight/cloud_noise.png" and CavernSunlightBackdrop.ROCK_FACE_MASK.resource_path == "res://assets/sprites/background/meadow/sunlight/rock_face_mask.png", "cloud and rock mask load through exportable resource paths")
	if DisplayServer.get_name() != "headless":
		check(CavernSunlightBackdrop.CLOUD_TEXTURE.get_class() == "CompressedTexture2D" and CavernSunlightBackdrop.ROCK_FACE_MASK.get_class() == "CompressedTexture2D", "GPU uses imported textures instead of runtime image files")
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	player.set_physics_process(false)
	player._clear_move_input()
	await verify_grass_depth()
	if depth_only:
		print("CAVERN_DEPTH_REVIEW_COMPLETE checks=",checks," failures=",failures)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	await verify_framing()
	verify_population()
	await verify_horizon()
	var first_objects := solid_signature(ground)
	await move_to(Vector2(-380, 80))
	var layout := ground.layout_signature()
	var old_receiver: WeakRef = weakref(ground.lit_objects[0])
	for point in [Vector2(9000, 9000), Vector2(-8000, -6500), Vector2(-380, 80)]:
		await move_to(point)
		verify_receivers()
	check(old_receiver.get_ref() == null, "departed receiver nodes are freed")
	check(ground.layout_signature() == layout, "returning restores the identical layout")
	flow.request_esc_overlay()
	await frames()
	check(flow.get_current_state() == MainFlowCoordinator.STATE_ESC_OVERLAY, "real ESC overlay opens")
	var clock := ground.environment_time
	await frames(20)
	check(is_equal_approx(clock, ground.environment_time), "cloud clock freezes while ESC pauses combat")
	check(is_equal_approx(clock, float(ground.ground_material.get_shader_parameter("sun_time"))), "paused shader time stays in sync")
	flow.close_esc_overlay()
	await frames(12)
	check(ground.environment_time > clock, "cloud motion continues after closing ESC")
	# Follow a rock in the generated world instead of assuming a fixed origin prop.
	var landmark := Vector2.ZERO
	var found_rock := false
	for x in range(-128,128):
		var entry: Dictionary = ground.landmark(Vector2i(x,0))
		if entry.index == 0 and (not found_rock or entry.point.length_squared() < landmark.length_squared()):
			landmark = entry.point
			found_rock = true
	check(found_rock, "generated world contains a rock for collision and occlusion review")
	# Place the actual depth-sort foot behind the base, outside its collider.
	await move_to(landmark - ground.foot_offset - Vector2(0, 20))
	check(ground.shadow_active_count > 0, "rock still reveals the player's occluded silhouette")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = landmark + Vector2(0, -12)
	query.collision_mask = 4
	check(not player.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "rock footprint still blocks movement")
	await capture("rock_occlusion")
	await move_to(landmark + Vector2(0, 95))
	check(ground.shadow_active_count == 0, "silhouette clears when the player is in front")
	await move_to(Vector2(-380, 80))
	# Same world location and daylight times as R02, with current camera framing.
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	for time in [0.0, 12.0, 24.0, 36.0, 48.0]:
		ground.environment_time = time
		ground._update_area()
		await frames(2)
		await capture("cloud_%02d" % int(time))
	ground.environment_time = 0.0
	ground._update_area()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	player.set_physics_process(true)
	if record and DisplayServer.get_name() != "headless":
		for i in 1200:
			await get_tree().process_frame
			if i % 3 == 0: await capture("frame_%04d" % (i / 3))
		check(absf(ground.environment_time - 20.0) < .04, "twenty seconds of natural cloud motion recorded")
	# Exercise movement inside the guaranteed clear spawn area, independently
	# of whichever obstacle this run placed near the reference capture camera.
	await move_to(Vector2.ZERO)
	player.set_mobile_move_direction(Vector2.RIGHT)
	var start := player.global_position
	await frames(20)
	player.set_mobile_move_direction(Vector2.ZERO)
	check(player.global_position.x > start.x + 10, "normal player movement works with daylight")
	player._invincibility_timer = 30.0
	battle.loadout.weapon_fired.connect(func(_id: String, _count: int): weapon_fires += 1)
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", true, false)
	battle.wave_manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(150, 20))
	battle.wave_manager.set_process(true)
	var wave_clock := battle.wave_manager.wave_time_left
	await frames(120)
	check(battle.wave_manager.wave_time_left < wave_clock, "normal wave clock resumes")
	check(weapon_fires > 0, "actual automatic weapon attacks still fire")
	await capture("live_combat")
	var visual: WeakRef = weakref(player.visual_anchor)
	var sunlight: WeakRef = weakref(ground)
	flow.enter_start_page()
	await frames(15)
	check(sunlight.get_ref() == null and visual.get_ref() == null, "return to menu releases lighting and player visuals")
	check(get_tree().get_nodes_in_group("battle_cavern").is_empty(), "battle scenery group clears on exit")
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "second battle starts normally")
	await frames(16)
	var second := get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	check(second != null and second.lighting_ready and second.environment_time < 1.0, "new battle receives fresh lighting and clock")
	check(second.population_seed != int(population_report.first_seed) and solid_signature(second) != first_objects,
		"starting another battle rolls a different sparse world")
	population_report.second_seed = second.population_seed
	ground = second
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	player = battle.player
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	player.set_physics_process(false)
	await move_to(Vector2(-380,80))
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	ground.environment_time = 0.0
	ground._update_area()
	await frames(2)
	await capture("second_battle")
	flow.enter_start_page()
	await frames(10)
	if not output.is_empty():
		FileAccess.open(output.path_join("verification.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures, "population":population_report, "production_only": true}, "\t"))
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	print("CAVERN_SUNLIGHT_TEST_COMPLETE checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
