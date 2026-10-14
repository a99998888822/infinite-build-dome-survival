extends Node
## Boots the real game and replaces scenery in memory for this review only.
const REVIEW_BACKDROP = preload("res://scripts/tests/reviews/cavern_population_backdrop.gd")
const REVIEW_HORIZON = preload("res://scripts/tests/reviews/cavern_population_horizon.gd")
var output := ""
var quick := false
var profile_only := false
var occlusion_review := false
var atmosphere_review := false
var depth_panorama_review := false
var production_assets := false
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var ground: CavernMeadowBackdrop
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var route: Array[Dictionary] = []
var idle_metrics: Array[Dictionary] = []
var occlusion_samples: Array[Dictionary] = []
var spacing_report: Dictionary = {}
var atmosphere_report: Dictionary = {}
var depth_report: Dictionary = {}

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg=="--quick": quick = true
		if arg=="--profile-only": profile_only = true
		if arg=="--occlusion-review": occlusion_review = true
		if arg=="--atmosphere-review": atmosphere_review = true
		if arg=="--depth-panorama-review": depth_panorama_review = true; atmosphere_review = true
		if arg=="--production-assets": production_assets = true; depth_panorama_review = true; atmosphere_review = true
	_run.call_deferred()

func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func move_to(point: Vector2) -> void:
	player.position = point
	player._sync_camera()
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	await frames()

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless" or profile_only: return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"PNG saved: "+name)

func population_check() -> Dictionary:
	var stats: Dictionary = ground.population_stats()
	check(stats.cells<=30,"streamed cells stay bounded")
	check(stats.grass_batch_nodes<=stats.cells*32,"grass depth bands stay bounded per cell")
	check(stats.minimum_suitability>=.30,"green grass roots match green terrain; brown-ground companions use dry grass")
	check(stats.large_visible.count(0)<=1 and stats.large_visible.count(1)<=1,"same A silhouette never duplicated in view")
	check(ground.horizon.entries.size()<=2,"at most two distant ruins")
	for entry: Dictionary in ground.horizon.entries:
		check(entry.root.x<ground.horizon.view_size.x*.32 or entry.root.x>ground.horizon.view_size.x*.68,"ruins restricted to side darkness")
		var size: Vector2 = ground.horizon.ruin_display_size(entry.index)*entry.scale
		var rect := Rect2(entry.root-Vector2(size.x*.5,size.y),size)
		for opening: Dictionary in ground.horizon.cave_openings():
			check(not rect.intersects(opening.rect),"visible ruin does not cover a cavern opening")
	return stats

func verify_grass_depth() -> void:
	var props: Array[Sprite2D] = []
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if node is Sprite2D: props.append(node)
	var overlaps := 0
	var bad_order := 0
	var companions := 0
	for group: Dictionary in ground.grass_cells.values():
		for band: Dictionary in group.bands:
			for batch: MultiMeshInstance2D in [band.back,band.front]:
				var reverse: bool = batch.get_meta("scenery").reverse
				var sort_y: float = (batch.get_parent() as Node2D).global_position.y
				for i in batch.multimesh.visible_instance_count:
					var blade: Dictionary = band.blades[band.blades.size()-1-i if reverse else i]
					if blade.get("companion",false): companions += 1
					var rect := Rect2(blade.point-Vector2(20,34),Vector2(40,38))
					for prop: Sprite2D in props:
						if not rect.intersects(prop.global_transform*prop.get_rect()): continue
						if absf(blade.point.y-prop.position.y)<.01: continue
						overlaps += 1
						if (blade.point.y<prop.position.y)!=(sort_y<prop.position.y): bad_order += 1
	check(overlaps>0 and bad_order==0,"all overlapping grass batches sort by the object's base")
	check(companions>0,"sparse foreground grass occurs at prop bases")
	depth_report.merge({"grass_prop_overlaps_checked":overlaps,"bad_depth_orders":bad_order,"companion_grass_loaded":companions},true)

func capture_depth_details() -> void:
	var rock: Vector2 = ground.landmark(Vector2i.ZERO).point
	await move_to(rock-Vector2(220,80))
	verify_grass_depth()
	await capture("base_grass")
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if node.get_meta("scenery").kind=="grass_batch": node.hide()
	await capture("base_control")
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if node.get_meta("scenery").kind=="grass_batch": node.show()
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if not node is Sprite2D: continue
			var entry: Dictionary = node.get_meta("scenery")
			if entry.kind=="prop" and entry.point.distance_to(rock)<1:
				var rect: Rect2 = ground.world_to_ui*node.global_transform*node.get_rect()
				depth_report.rock_screen_rect = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	await move_to(Vector2.ZERO)
	var seen: Dictionary = {}
	for i in 5:
		var camera_step: float = 310.0*ground.horizon.art_scale/(ground.horizon.camera_scale*ground.horizon.FAR_SPEED)
		await move_to(Vector2(i*camera_step,0.0))
		await capture("cave_bank_%d"%i)
		for opening: Dictionary in ground.horizon.far_snapshot(): seen[opening.source] = true
	check(seen.size()==5,"horizontal world traversal reveals all five authored caves")
	depth_report.cave_sources = seen.keys()
	await move_to(Vector2.ZERO)

func verify_horizontal_parallax() -> void:
	var period: float = ground.horizon.panorama.get_width()*ground.horizon.art_scale*.5
	var ruin_pairs := 0
	var horizontal_pairs := 0
	var fixed_pairs := 0
	for i in range(1,samples.size()):
		var previous: Dictionary = samples[i-1]
		var current: Dictionary = samples[i]
		var dx: float = (current.camera[0]-previous.camera[0])*ground.horizon.camera_scale
		var far_delta := wrapf(current.far_offset-previous.far_offset,-period*.5,period*.5)
		check(absf(far_delta-dx*.08)<.001,"cave offset follows horizontal displacement at 0.08 only")
		if absf(dx)<.001: fixed_pairs += 1
		else: horizontal_pairs += 1
		for key in previous.ruins:
			if not current.ruins.has(key): continue
			var ruin_delta: float = current.ruins[key].root[0]-previous.ruins[key].root[0]
			check(absf(ruin_delta+dx*.18)<.001,"ruin position follows horizontal displacement at 0.18 only")
			ruin_pairs += 1
	check(horizontal_pairs>0 and fixed_pairs>0 and ruin_pairs>0,"parallax verified during horizontal, vertical and stationary samples")
	depth_report.horizontal_parallax = {"camera_driven_only":true,"cavern_rate":.08,"ruin_rate":.18,
		"horizontal_pairs":horizontal_pairs,"fixed_pairs":fixed_pairs,"ruin_pairs":ruin_pairs}

func verify_small_prop_spacing() -> void:
	var bins: Dictionary = {}
	var minimum := INF
	var count := 0
	var types: Dictionary = {}
	# Includes positive/negative coordinates and hundreds of cell boundaries.
	for y in range(-8,9):
		for x in range(-8,9):
			for entry: Dictionary in ground._plan_cell(Vector2i(x,y)):
				if entry.kind!="rubble": continue
				count += 1
				types[entry.index] = true
				var bucket := Vector2i((entry.point/400.0).floor())
				for dy in range(-1,2):
					for dx in range(-1,2):
						var near_key := Vector3i(bucket.x+dx,bucket.y+dy,entry.index)
						for other: Vector2 in bins.get(near_key,[]): minimum = minf(minimum,entry.point.distance_to(other))
				var bin_key := Vector3i(bucket.x,bucket.y,entry.index)
				if not bins.has(bin_key): bins[bin_key] = []
				bins[bin_key].append(entry.point)
	check(types.size()==9,"spacing rule retains all nine B/Q assets")
	check(minimum>=ground.RUBBLE_REPEAT_DISTANCE,"same B/Q shape separated across cell boundaries")
	spacing_report = {"cells_tested":289,"objects_tested":count,"types":types.size(),"minimum_same_shape_distance":minimum,"required_distance":ground.RUBBLE_REPEAT_DISTANCE}

func verify_atmosphere() -> void:
	var horizon := ground.horizon
	var center: float = horizon.reveal_at(640.0)
	var side: float = horizon.reveal_at(40.0)
	check(side>center+50,"pit wall shadow reaches farther into the floor at the sides")
	check(is_equal_approx(horizon.reveal_at(40.0),horizon.reveal_at(1240.0)),"pit opening has balanced left and right arcs")
	check(horizon.darkness_end()>=horizon.far_height(),"opaque darkness still covers the cavern panorama band")
	var inverse := ground.world_to_ui.affine_inverse()
	check(ground.get_darkness_entry_direction(inverse*Vector2(640,center+20)).is_zero_approx(),"centre opening is clear")
	check(ground.get_darkness_entry_direction(inverse*Vector2(40,center+20)).y>0,"side enemies keep approaching through curved darkness")
	check(ground.get_darkness_entry_direction(inverse*Vector2(40,side+20)).is_zero_approx(),"side enemies emerge after clearing their local arc")
	horizon.configure_view(Vector2(1280,720),0.0,1.0)
	var first: Dictionary = horizon.snapshot()
	horizon.configure_view(Vector2(1280,720),120.0,1.0)
	var second: Dictionary = horizon.snapshot()
	var matched := 0
	for key in first:
		if not second.has(key): continue
		matched += 1
		check(is_equal_approx(first[key].root[0]-second[key].root[0],21.6),"larger distant ruins use slower 0.18 parallax")
	check(matched>0,"parallax comparison sees a stable ruin")
	horizon.configure_view(Vector2(1920,1080),0.0,1.0)
	check(is_equal_approx(horizon.reveal_at(60.0)/1.5,side),"curved shadow scales with viewport size")
	horizon.configure_view(Vector2(1280,720),player.camera_2d.get_screen_center_position().x,1.0)
	atmosphere_report = {"center_reveal_y":center,"side_reveal_y":side,"ruin_scale_factor":1.28,
		"ruin_parallax":.18,"cavern_parallax":.08,"bottom_shadow":true,"light_pool":true}

func capture_occlusion_route() -> void:
	var rock: Vector2 = ground.landmark(Vector2i.ZERO).point
	await move_to(rock+Vector2(0,-190))
	player.set_physics_process(true)
	var index := 0
	var legs := [{"name":"approach_and_block","direction":Vector2.DOWN,"samples":20},
		{"name":"sidestep_right","direction":Vector2.RIGHT,"samples":12},
		{"name":"walk_to_front","direction":Vector2.DOWN,"samples":10},
		{"name":"front_crossing","direction":Vector2.LEFT,"samples":12},
		{"name":"front_block","direction":Vector2.UP,"samples":10},
		{"name":"around_right","direction":Vector2.RIGHT,"samples":12},
		{"name":"around_back","direction":Vector2.UP,"samples":16},
		{"name":"behind_crossing","direction":Vector2.LEFT,"samples":12},
		{"name":"return_and_block","direction":Vector2.DOWN,"samples":14}]
	for leg: Dictionary in legs:
		var start := player.position
		player.set_mobile_move_direction(leg.direction)
		var positions: Array[Vector2] = []
		for i in leg.samples:
			await frames(3)
			await capture("occlusion_%03d"%index)
			positions.append(player.position)
			occlusion_samples.append({"frame":index,"phase":leg.name,"player":[player.position.x,player.position.y],
				"shadow_active":ground.shadow_active_count,"sprite_frame":player.sprite.frame,
				"sprite_flip":player.visual_anchor.scale.x<0,"slide_collisions":player.get_slide_collision_count()})
			index += 1
		if leg.name=="approach_and_block":
			check(player.position.y<rock.y-30 and player.position.y>start.y+60,"back approach hits the rock footprint")
			check(positions.back().distance_to(positions[-5])<.5,"continued down input cannot pass through rock")
			check(ground.shadow_active_count==1,"occluded player has one animated silhouette")
			await capture("blocked_shadow")
			# Pixel-level control shot uses the very same animation pose/camera.
			player.set_physics_process(false)
			ground.shadow_enabled = false
			ground._update_player_shadow()
			await capture("blocked_control")
			ground.shadow_enabled = true
			ground._update_player_shadow()
			player.set_physics_process(true)
		if leg.name=="sidestep_right": check(ground.shadow_active_count==0,"shadow disappears when player clears the side")
		if leg.name=="front_crossing":
			check(ground.shadow_active_count==0,"player in front keeps normal rendering")
			await capture("front_normal")
		if leg.name=="front_block":
			check(player.position.y>rock.y,"front approach cannot pass through rock")
			# A curved footprint may slide sideways; progress into it must stop.
			check(absf(positions.back().y-positions[-5].y)<2.0 and player.get_slide_collision_count()>0,"continued up input cannot pass through rock")
			check(ground.shadow_active_count==0,"front collision never creates x-ray shadow")
		if leg.name=="return_and_block":
			check(ground.shadow_active_count==1,"shadow returns after walking around rock")
	player.set_mobile_move_direction(Vector2.ZERO)
	player.set_physics_process(false)
	check(player.visual_anchor.scale.x<0,"capture also covers mirrored character silhouette")

func _run() -> void:
	if output.is_empty(): output = "res://artifacts/analysis/cavern_population_review_20261013/headless"
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
	check(flow.confirm_character_selection(),"real battle entered")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state()==MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	player = battle.player
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernMeadowBackdrop
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player.set_physics_process(false)
	if production_assets:
		# Inspect the actual scene from character selection; inject no scenery.
		check(ground.get_script().resource_path=="res://scripts/battle/cavern_population_backdrop.gd","formal scene uses the approved population script")
		check(ground.horizon.get_script().resource_path=="res://scripts/battle/cavern_pit_horizon.gd","formal scene uses horizontal-only pit parallax")
		check(ground.scenery_config_path=="res://data_config/cavern_meadow_battlefield.json","formal scene loads production scenery configuration")
	else:
		# Mirror the ready-before-viewport-reparent production lifecycle.
		var parent := ground.get_parent()
		var viewport_parent := parent.get_parent()
		ground.detach_player()
		parent.remove_child(ground)
		ground.queue_free()
		var old_horizon := battle.get_node("BattleSky/DistantRuins")
		var sky := old_horizon.get_parent()
		sky.remove_child(old_horizon)
		old_horizon.queue_free()
		var new_horizon := REVIEW_HORIZON.new()
		new_horizon.name = "DistantRuins"
		sky.add_child(new_horizon)
		parent.reparent(battle,false)
		ground = REVIEW_BACKDROP.new()
		ground.name = "Backdrop"
		parent.add_child(ground)
		parent.reparent(viewport_parent,false)
		var environment := battle.get_node("BattleEnvironment") as BattleEnvironment
		environment.ground = ground
		environment.ruins = new_horizon
		ground.set_world_context(player,battle.wave_manager)
	await frames(20)
	check(ground.config.props.size()==2 and ground.config.rubble.size()==9,"all approved A/B/Q registered")
	check(ground.horizon.ruins.size()==4 and ground.horizon.foreground_root.get_child_count()==4,"all C/D registered")
	await move_to(Vector2.ZERO)
	var before := ground.layout_signature()
	var old_node: WeakRef = weakref(ground.cells.values()[0][0])
	# Structural and regeneration checks occur before recording, not in the GIF.
	for point in [Vector2(9000,9000),Vector2(-8000,-6500),Vector2(3000,-7000),Vector2.ZERO]:
		await move_to(point)
		population_check()
	check(old_node.get_ref()==null,"off-camera cell nodes actually freed")
	check(before==ground.layout_signature(),"same layout regenerated after return")
	check(player.visual_anchor.get_parent()==ground.proxy,"player foot depth proxy preserved")
	var collision_probe := PhysicsPointQueryParameters2D.new()
	collision_probe.position = ground.landmark(Vector2i.ZERO).point+Vector2(0,-12)
	collision_probe.collision_mask = 4
	check(not player.get_world_2d().direct_space_state.intersect_point(collision_probe).is_empty(),"A has a terrain footprint")
	var q_types: Dictionary = {}
	for y in range(-3,4):
		for x in range(-3,4):
			for entry: Dictionary in ground._plan_cell(Vector2i(x,y)):
				if entry.kind=="rubble": q_types[entry.index] = true
	check(q_types.size()==9,"B01/B02 and Q01-Q07 all occur in generated terrain")
	verify_small_prop_spacing()
	var c_types: Dictionary = {}
	for x in range(-60000,60001,100):
		ground.horizon.configure_view(Vector2(1280,720),x,1.0)
		for entry: Dictionary in ground.horizon.entries: c_types[entry.index] = true
	check(c_types.size()==4,"all four C variants occur along parallax traversal")
	await move_to(Vector2.ZERO)
	await frames(40)
	if atmosphere_review: verify_atmosphere()
	await capture("overview")
	if depth_panorama_review:
		await capture_depth_details()
		verify_grass_depth()
	# Idle samples exclude PNG readback. No minimum frame-rate claim is made.
	for i in 60:
		await frames(1)
		idle_metrics.append({"process_seconds":Performance.get_monitor(Performance.TIME_PROCESS),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	if occlusion_review:
		await capture_occlusion_route()
	elif not quick:
		ground.profile_enabled = true
		player.set_physics_process(true)
		var frame_index := 0
		var leg_samples := 40 if atmosphere_review else 80
		if depth_panorama_review:
			var fixed_player := player.position
			var before_far: float = ground.horizon.far_offset()
			var before_ruins: Dictionary = ground.horizon.snapshot()
			for i in 20:
				await frames(3)
				await capture("tour_%03d"%frame_index)
				var stats := population_check()
				stats.merge({"frame":frame_index,"direction":"idle","player":[player.position.x,player.position.y],
					"camera":[ground.horizon.camera_x,player.camera_2d.get_screen_center_position().y],
					"ruins":ground.horizon.snapshot(),"caves":ground.horizon.far_snapshot(),"far_offset":ground.horizon.far_offset()},true)
				samples.append(stats)
				frame_index += 1
			check(player.position.distance_to(fixed_player)<.01 and is_equal_approx(ground.horizon.far_offset(),before_far),"cave bank stays fixed while the player stands still")
			check(ground.horizon.snapshot()==before_ruins,"ruins stay fixed while the player stands still")
		for leg in [{"name":"right","dir":Vector2.RIGHT},{"name":"down","dir":Vector2.DOWN},
			{"name":"left","dir":Vector2.LEFT},{"name":"up","dir":Vector2.UP}]:
			var start := player.position
			var start_far: float = ground.horizon.far_offset()
			var start_ruins: Dictionary = ground.horizon.snapshot()
			player.set_mobile_move_direction(leg.dir)
			for i in leg_samples:
				await frames(3)
				await capture("tour_%03d"%frame_index)
				var stats := population_check()
				stats["frame"] = frame_index
				stats["direction"] = leg.name
				stats["player"] = [player.position.x,player.position.y]
				stats["camera"] = [ground.horizon.camera_x,player.camera_2d.get_screen_center_position().y]
				stats["ruins"] = ground.horizon.snapshot()
				stats["caves"] = ground.horizon.far_snapshot()
				stats["far_offset"] = ground.horizon.far_offset()
				if i==0 and leg.dir.x==0.0:
					# Start after the previous horizontal frame has reached the camera.
					start_far = stats.far_offset
					start_ruins = stats.ruins
				samples.append(stats)
				frame_index += 1
			var travelled: float = (player.position-start).dot(leg.dir)
			route.append({"direction":leg.name,"distance":travelled,"start":[start.x,start.y],"end":[player.position.x,player.position.y]})
			check(travelled>(440 if atmosphere_review else 900),"real input travels the complete "+leg.name+" leg")
			if leg.dir.x==0.0:
				check(is_equal_approx(ground.horizon.far_offset(),start_far),"caves stay fixed during "+leg.name+" movement")
				check(ground.horizon.snapshot()==start_ruins,"ruins stay fixed during "+leg.name+" movement")
		player.set_mobile_move_direction(Vector2.ZERO)
		ground.profile_enabled = false
		if depth_panorama_review: verify_grass_depth()
		if depth_panorama_review: verify_horizontal_parallax()
		await frames(15)
		await capture("returned")
	# Supplementary stills: both A silhouettes, selected via normal world rules.
	player.set_physics_process(false)
	await move_to(Vector2(140,50))
	await capture("rock_area")
	await move_to(ground.landmark(Vector2i(0,1)).point-Vector2(260,110))
	await capture("log_area")
	var final_stats := population_check()
	var update_profile: Array = ground.update_profile
	var visual: WeakRef = weakref(player.visual_anchor)
	flow.enter_start_page()
	await frames(15)
	check(get_tree().get_nodes_in_group("battle_cavern").is_empty(),"review scene releases on exit")
	check(visual.get_ref()==null,"player visual released on exit")
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	# Release review audio immediately; headless can finish before fades expire.
	for audio in AudioManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await frames(3)
	CampProgression.end_transient_session()
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"route":route,
		"atmosphere":atmosphere_report,
		"depth_and_panorama":depth_report,
		"occlusion_samples":occlusion_samples,"small_prop_spacing":spacing_report,
		"idle_metrics":idle_metrics,"update_profile":update_profile,"profile_only":profile_only,
		"final_population":final_stats,"review_only":not production_assets,"production_scene":production_assets,"art_overrides":not production_assets,"engine_fixed_fps":30,
		"capture_fps":10,"enemy_spawning_paused":true,"recorded_movement":"real player directional input; no teleport in tour"},"\t"))
	print("POPULATION_REVIEW checks=",checks," failures=",failures)
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
