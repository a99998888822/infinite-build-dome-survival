extends "res://scripts/tests/reaction_block_visual_review.gd"
## Real projectile review plus read-only measurements of production pixel sizing.
var pipeline: Dictionary = {}
var bodies: Array = []
const ANCHORS = preload("res://scripts/effects/enemy_visual_anchors.gd")

func _setup(entry: Dictionary) -> void:
	await super._setup(entry)
	if not entry.get("bosses",false): return
	for enemy in enemies: enemy.free()
	enemies.clear()
	var names := ["elite_rusher","underworld_wolf"]
	for index in names.size():
		var enemy := load("res://scenes/enemy/"+names[index]+".tscn").instantiate() as EnemyController
		host.add_child(enemy)
		enemy.initialize(enemy.enemy_id,null)
		enemy.current_hp = 10000
		enemy.global_position = center+Vector2(index*180,index*110-25)
		enemy.collision_mask = 0
		enemy.damage_received.connect(func(source: String,damage: int):
			hit_records.append({"enemy":enemy.get_instance_id(),"source":source,"damage":damage,"time":float(Time.get_ticks_usec()-recording_start)/1e6}))
		enemies.append(enemy)
	await get_tree().create_timer(1.1).timeout

func _run() -> void:
	if output.is_empty() or cases_path.is_empty():
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	var original_enabled := BLOCKS.enabled
	var original_thunder_fire := BLOCKS.thunder_fire_enabled
	if OS.get_cmdline_user_args().has("--baseline"):
		BLOCKS.enabled = false
		BLOCKS.thunder_fire_enabled = false
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	DirAccess.make_dir_recursive_absolute(output)
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	for entry: Dictionary in cases:
		if not only.is_empty() and str(entry.id) != only: continue
		if OS.get_cmdline_user_args().has("--warm-review"):
			# Compile through actual casts, then rebuild a clean encounter for capture.
			await _setup(entry)
			Engine.max_fps = 60
			var previous_capture := no_capture
			no_capture = true
			await _audit_case(entry,"")
			no_capture = previous_capture
			await _cleanup()
		await _setup(entry)
		# Use the actual production UI canvas, not the previous review override.
		get_tree().root.size = Vector2i(1920,1080)
		game._configure_content_scale()
		Engine.max_fps = 60
		caption.get_parent().hide()
		player.camera_2d.reset_smoothing()
		player.camera_2d.force_update_scroll()
		await frames(8)
		pipeline = _pipeline()
		bodies = _bodies()
		var directory := output.path_join(entry.id)
		DirAccess.make_dir_recursive_absolute(directory)
		var row := await _audit_case(entry,directory)
		row.pipeline = pipeline
		row.bodies = bodies
		if entry.id == "frost" and not no_capture and DisplayServer.get_name() != "headless":
			row.frost_evidence = await _frost_evidence(directory)
		summary.append(row)
		FileAccess.open(directory.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(row,"\t"))
		print("PIXEL_ALIGNMENT_CASE ",entry.id," passed=",row.passed)
		await _cleanup()
	BLOCKS.enabled = original_enabled
	BLOCKS.thunder_fire_enabled = original_thunder_fire
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("PIXEL_ALIGNMENT_COMPLETE cases=",summary.size()," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _pipeline() -> Dictionary:
	var viewport: SubViewport = game._world_viewport
	var surface: SubViewportContainer = game._world_viewport_container
	return {"window":get_tree().root.size,"ui_design":get_tree().root.content_scale_size,
		"ui_visible":get_tree().root.get_visible_rect().size,"world":viewport.size,
		"container_size":surface.size,"container_scale":surface.scale,
		"container_canvas_transform":surface.get_screen_transform().get_scale(),
		"window_final_transform":get_tree().root.get_final_transform().get_scale(),
		"world_filter":viewport.canvas_item_default_texture_filter,"surface_filter":surface.texture_filter,
		"snap_transforms":viewport.snap_2d_transforms_to_pixel,"camera_zoom":player.camera_2d.zoom}

func _body(enemy: EnemyController) -> Dictionary:
	var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var sprite := enemy.get_node("Sprite2D") as Sprite2D
	var status := enemy.get_node("EnemyStatusVisual")
	var radius: float = status._get_body_radius()
	return {"id":enemy.enemy_id,"collision":body.shape.get_class(),"collision_radius":body.shape.radius,
		"collision_scale":body.scale,"body_multiplier":enemy.body_scale_multiplier,
		"sprite_frame":sprite.get_rect().size,"sprite_scale":sprite.scale,"sprite_position":sprite.position,
		"status_radius":radius,"body_factor":ANCHORS.factor(enemy),"snowflake_scale":maxf(1.0,radius*0.88/16.0),
		"frozen_frame":int(round(clampf(radius*1.1,15,25)-15)),"original_ice_atlases":true,
		"foot_anchor":ANCHORS.foot(enemy),"head_anchor":ANCHORS.head(enemy),"native_frost_grid":1,
		"status_z":status.z_index,"slowed":enemy.has_status("slowed"),"frozen":enemy.has_status("frozen")}

func _bodies() -> Array:
	var rows: Array = [_body(enemies[0])]
	for scene in ["echo_bat","elite_rusher","underworld_wolf"]:
		var enemy := load("res://scenes/enemy/"+scene+".tscn").instantiate() as EnemyController
		host.add_child(enemy)
		enemy.initialize(enemy.enemy_id,player)
		enemy.global_position = center + Vector2(4000,4000)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		rows.append(_body(enemy))
		enemy.queue_free()
	return rows

func _save_frame(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)

func _frost_evidence(directory: String) -> Dictionary:
	# Pause one actual bow-hit scene, then remove only its status drawing.
	# The second image is a layer diagnosis, not a proposed replacement effect.
	get_tree().paused = true
	var statuses: Array = []
	for enemy in enemies:
		if enemy.has_status("slowed"): statuses.append(_body(enemy))
	await _save_frame(directory.path_join("status-visible-1080.png"))
	game._world_viewport.get_texture().get_image().save_png(directory.path_join("world-1080.png"))
	var shakes: Array = []
	for amount in [1,2,6]:
		CombatHitFeedback._set_screen_offset(Vector2(amount,0))
		var uv: Vector2 = CombatHitFeedback._presentation_material.get_shader_parameter("shake_uv")
		shakes.append({"requested":amount,"uv":uv,"world_pixel_offset":uv*Vector2(game._world_viewport.size)})
		await _save_frame(directory.path_join("shake-%d-1080.png" % amount))
	CombatHitFeedback._set_screen_offset(Vector2.ZERO)
	for enemy in enemies: enemy.get_node("EnemyStatusVisual").hide()
	await _save_frame(directory.path_join("status-hidden-1080.png"))
	for enemy in enemies: enemy.get_node("EnemyStatusVisual").show()
	get_tree().root.size = Vector2i(1152,648)
	await frames(3)
	var small := _pipeline()
	await _save_frame(directory.path_join("status-visible-648.png"))
	get_tree().root.size = Vector2i(1920,1080)
	await frames(3)
	get_tree().paused = false
	return {"active_statuses":statuses,"small_window_pipeline":small,"shake_diagnostic":shakes,"hidden_image_is_diagnostic_only":true}
