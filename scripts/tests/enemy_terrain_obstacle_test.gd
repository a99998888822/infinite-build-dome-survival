extends Node
## Production terrain, four enemy controllers, and GPU occlusion comparisons.
const IDS := ["enemy_mutated_grub", "enemy_elite_rusher", "enemy_underworld_wolf", "enemy_echo_bat"]
var checks := 0
var failures := 0
var output := ""
var game: GameRoot
var battle: BattleRoot
var ground: CavernPopulationBackdrop
var rock: Sprite2D
var obstacle: BattleTerrainObstacle

func _ready() -> void:
	WindowSettings._startup_applied = true
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(9)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	get_tree().create_timer(180).timeout.connect(func(): get_tree().quit(99))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame

func make_enemy(index: int) -> EnemyController:
	var enemy := battle.wave_manager.spawn_enemy(IDS[index], rock.global_position + Vector2(-300, 0))
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().size = Vector2i(1280, 720)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	check(flow.confirm_character_selection(), "open production battle")
	await frames(30)
	# Runtime world nodes live in the combat viewport, not under BattleRoot.
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernPopulationBackdrop
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	battle.active_controller.enabled = false
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var point := Vector2.ZERO
	var found := false
	for y in range(-2, 3):
		for x in range(-2, 3):
			var entry := ground.landmark(Vector2i(x, y))
			if entry.index == 0 and (not found or entry.point.length_squared() < point.length_squared()):
				point = entry.point
				found = true
	check(found, "locate a real streamed stone")
	battle.player.global_position = point + Vector2(150, 60)
	battle.player._sync_camera()
	battle.player.camera_2d.reset_smoothing()
	battle.player.camera_2d.force_update_scroll()
	await frames(30)
	for candidate in ground.occluding_rocks:
		if is_instance_valid(candidate) and candidate.global_position.distance_to(point) < 1:
			rock = candidate
	check(rock != null, "stone loads with production scenery")
	if rock == null:
		get_tree().quit(1)
		return
	for child in rock.get_children():
		if child is BattleTerrainObstacle: obstacle = child
	check(obstacle != null, "stone registers its collision footprint for routing")
	check(battle.wave_manager.enemy_root.get_parent() == ground.roots, "enemies and stone share depth sorting")
	ground.set_process(false)
	if DisplayServer.get_name() == "headless": await physics_checks()
	await visual_checks()
	var manager := battle.wave_manager
	ground.detach_player()
	check(manager.enemy_root.get_parent() == manager, "scene teardown restores enemy container ownership")
	game.queue_free()
	await frames()
	check(BattleTerrainObstacle.active.is_empty(), "streamed obstacle registry is cleaned up")
	CampProgression.end_transient_session()
	print("ENEMY_TERRAIN_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func physics_checks() -> void:
	var center := (obstacle.global_transform * obstacle.footprint).get_center()
	for index in IDS.size():
		var enemy := make_enemy(index)
		if index == 1: enemy.apply_body_scale(1.5)
		check(enemy.get_collision_mask_value(3), IDS[index] + " detects terrain")
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			battle.player.global_position = center + Vector2(1500, 1500)
			enemy.global_position = center - direction * 400
			await get_tree().physics_frame
			var collision := enemy.move_and_collide(direction * 800)
			check(collision != null and collision.get_collider() == obstacle, IDS[index] + " swept motion stops at stone " + str(direction))
			enemy.global_position = center - direction * 340
			enemy.velocity = Vector2.ZERO
			battle.player.global_position = center + direction * 340
			var shape := enemy.get_node("CollisionShape2D") as CollisionShape2D
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape.shape
			query.collision_mask = 4
			var penetrated := false
			var reached := false
			for frame in 1300:
				await get_tree().physics_frame
				if enemy is EchoBat: enemy._step_delta = 1.0 / 60.0
				enemy._process_chase()
				query.transform = shape.global_transform
				if not enemy.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): penetrated = true
				if enemy.global_position.distance_to(battle.player.global_position) < (290.0 if enemy is EchoBat else 100.0):
					reached = true
					break
			check(reached and not penetrated, IDS[index] + " chases around stone without penetration " + str(direction))
			if not reached: print("STUCK ", enemy.global_position - center)
		enemy.free()
	# High-speed special movement uses the same collision mask.
	battle.player.global_position = center + Vector2(0, 350)
	var knight := make_enemy(1) as EliteRusher
	knight.global_position = center + Vector2(0, -200)
	knight.skill_state = "dash"
	knight._origin = knight.global_position
	knight._direction = Vector2.DOWN
	knight._state_time = 0
	await get_tree().physics_frame
	knight._process_special_behavior(0.16)
	check(knight._dash_blocked and knight.global_position.y < center.y + 120, "elite dash stops at stone")
	knight.free()
	var wolf := make_enemy(2) as UnderworldWolf
	wolf.global_position = center + Vector2(0, -200)
	wolf.leap_origin = wolf.global_position
	wolf.locked_point = center + Vector2(0, 350)
	wolf.state = "leap"
	wolf.state_time = 0
	await get_tree().physics_frame
	wolf._process_special_behavior(float(wolf.profile.leap_seconds))
	check(wolf.global_position.y < center.y + 100, "wolf leap stops at stone")
	wolf.free()

func visual_checks() -> void:
	battle.player.global_position = rock.global_position + Vector2(150, 60)
	battle.player._sync_camera()
	battle.player.camera_2d.reset_smoothing()
	battle.player.camera_2d.force_update_scroll()
	ground._update_area()
	var enemies: Array[EnemyController] = []
	for index in [0, 1, 3]:
		var enemy := make_enemy(index)
		# Freeze after the authored spawn/first animation frame is visible.
		if enemy is EliteRusher:
			enemy.sprite.show()
			enemy._set_animation(&"move")
			enemy._animate(0.4)
		if enemy is EchoBat: enemy._animate(0.0)
		enemy.global_position = rock.global_position + Vector2(-35 + enemies.size() * 34, -45)
		enemies.append(enemy)
	ground._update_player_shadow()
	check(ground.enemy_shadow_active_count >= 3, "several enemy silhouettes can share one stone")
	await capture("real_enemies_behind_stone")
	for enemy in enemies: enemy.free()
	# A bright fixture makes stone occlusion and exposed pixels measurable.
	var probe := make_enemy(0)
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	for child in probe.get_children():
		if child is CanvasItem: child.visible = child == probe.sprite
	var bitmap := Image.create(100, 70, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.MAGENTA)
	probe.sprite.texture = ImageTexture.create_from_image(bitmap)
	probe.sprite.hframes = 1
	probe.sprite.vframes = 1
	probe.sprite.scale = Vector2.ONE
	probe.sprite.position = Vector2(0, -35)
	probe.sprite.material = null
	probe.global_position = rock.global_position + Vector2(0, -30)
	ground.shadow_enabled = false
	ground._update_player_shadow()
	var plain := await world_image()
	ground.shadow_enabled = true
	ground._update_player_shadow()
	check(ground.enemy_shadow_active_count == 1, "behind-stone silhouette activates")
	var shaded := await world_image()
	if plain != null and shaded != null:
		var changes := 0
		var leaked := 0
		for y in plain.get_height():
			for x in plain.get_width():
				var before := plain.get_pixel(x, y)
				var after := shaded.get_pixel(x, y)
				if before.is_equal_approx(after): continue
				changes += 1
				if before.r > .9 and before.b > .9 and before.g < .1: leaked += 1
		check(changes > 30, "GPU paints a visible silhouette on stone pixels")
		check(leaked == 0, "GPU leaves exposed enemy pixels unchanged")
	await capture("masked_enemy_fixture")
	await animation_checks(probe)
	probe.sprite.texture = ImageTexture.create_from_image(bitmap)
	probe.sprite.hframes = 1
	probe.sprite.flip_h = false
	probe.sprite.flip_v = false
	probe.global_position = rock.global_position + Vector2(0, 45)
	ground._update_player_shadow()
	check(ground.enemy_shadow_active_count == 0, "front-of-stone enemy has no silhouette")
	var front := await world_image()
	if front != null:
		var screen := probe.get_viewport().get_canvas_transform() * (rock.global_position + Vector2(0, -10))
		check(front.get_pixelv(Vector2i(screen)).is_equal_approx(Color.MAGENTA), "GPU draws front enemy over stone")
	await capture("enemy_in_front_of_stone")
	probe.global_position = rock.global_position + Vector2(0, -30)
	probe.alive = false
	ground._update_player_shadow()
	check(ground.enemy_shadow_active_count == 0, "dead enemy clears its silhouette")
	probe.free()

func animation_checks(probe: EnemyController) -> void:
	var sheet := Image.create(200, 70, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	sheet.fill_rect(Rect2i(0, 0, 40, 70), Color.MAGENTA)
	sheet.fill_rect(Rect2i(100, 0, 80, 20), Color.MAGENTA)
	sheet.fill_rect(Rect2i(100, 20, 30, 50), Color.MAGENTA)
	var texture := ImageTexture.create_from_image(sheet)
	var crop := Rect2i(100, 0, 100, 70)
	for flipped in [false, true]:
		probe.sprite.flip_h = flipped
		probe.sprite.flip_v = flipped
		probe.sprite.texture = ImageTexture.create_from_image(sheet.get_region(crop))
		probe.sprite.hframes = 1
		ground._update_player_shadow()
		var reference := await world_image()
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(crop)
		probe.sprite.texture = atlas
		ground._update_player_shadow()
		var cropped := await world_image()
		probe.sprite.texture = texture
		probe.sprite.hframes = 2
		probe.sprite.frame = 1
		ground._update_player_shadow()
		var animated := await world_image()
		if reference == null: continue
		var viewport := probe.get_viewport()
		var area := Rect2i(viewport.get_canvas_transform() * rock.global_transform * rock.get_rect())
		check(reference.get_region(area).get_data() == cropped.get_region(area).get_data(), "GPU atlas silhouette matches current cropped frame, flipped=" + str(flipped))
		check(reference.get_region(area).get_data() == animated.get_region(area).get_data(), "GPU sprite-sheet silhouette matches current frame, flipped=" + str(flipped))

func world_image() -> Image:
	await frames(3)
	if DisplayServer.get_name() == "headless": return null
	await RenderingServer.frame_post_draw
	return battle.player.get_viewport().get_texture().get_image()

func capture(id: String) -> void:
	await frames(3)
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	get_window().get_texture().get_image().save_png(output.path_join(id + ".png"))
