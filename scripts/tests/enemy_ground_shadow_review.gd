extends "res://scripts/tests/native_resolution_review.gd"
## Production actors and rendering; staged positions keep all four feet visible.
var enemies: Array[EnemyController] = []
var animate_lineup := false
var recording: Array[Dictionary] = []


func _process(delta: float) -> void:
	if not animate_lineup: return
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_physics_processing(): continue
		if enemy is EchoBat: enemy._animate(delta)
		elif enemy is EliteRusher: enemy._animate(delta)
		elif enemy is UnderworldWolf: enemy.animate(delta)
		else: enemy._set_movement_visual(true, delta)


func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("Use the private desktop capture helper for this review")
		get_tree().quit(2)
		return
	if output=="res://artifacts/reviews/native_1080_r02": output = "res://artifacts/reviews/enemy_shadows"
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	seed(1016)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1920,1080)
	OS.low_processor_usage_mode = false
	Engine.max_fps = 60
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",[])
	await frames()
	check(flow.confirm_character_selection(),"production character selection enters battle")
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state()==MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	player = battle.player
	player.set_physics_process(false)
	player._invincibility_timer = 1000
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	for node in game.find_children("*","Label",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/ui/combat_performance_line.gd": node.hide()
	await frames()
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	var anchor := Vector2.ZERO
	var closest := INF
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if not node is Sprite2D or not node.has_meta("scenery"): continue
			var entry: Dictionary = node.get_meta("scenery")
			if entry.kind=="prop" and node.global_position.length_squared()<closest:
				closest = node.global_position.length_squared()
				anchor = node.global_position+Vector2(-280,190)
	move_to(anchor)
	await frames()
	ground.set_process(false)
	var ids := ["enemy_mutated_grub","enemy_elite_rusher","enemy_echo_bat","enemy_underworld_wolf"]
	var points := [Vector2(-510,30),Vector2(-265,70),Vector2(325,50),Vector2(575,70)]
	for i in ids.size():
		var enemy := add_enemy(ids[i],anchor+points[i])
		enemies.append(enemy)
		_verify_shadow(enemy)
	player.action_animator._show("idle",0)
	await frames()
	for enemy in enemies:
		var shadow := enemy.get_node("GroundShadow") as Sprite2D
		shadow.set_process(false)
		shadow.hide()
	await capture("01_shadow_off_1920")
	for enemy in enemies:
		var shadow := enemy.get_node("GroundShadow") as Sprite2D
		shadow.refresh()
		shadow.set_process(true)
	await capture("02_shadow_on_1920")
	for enemy in enemies:
		subjects.append({"id":enemy.enemy_id,"screen_point":enemy.get_global_transform_with_canvas().origin,
			"footprint":enemy.get_node("GroundShadow").footprint,"origin":enemy.get_node("GroundShadow").position})
	var wolf := enemies[3] as UnderworldWolf
	var wolf_shadow := wolf.get_node("GroundShadow") as Sprite2D
	var grounded_size: Vector2i = wolf_shadow.footprint
	var grounded_position := wolf_shadow.position
	wolf.air_height = 66
	wolf.animate(0)
	wolf_shadow.refresh()
	check(wolf_shadow.position==grounded_position and wolf_shadow.footprint.x<grounded_size.x and is_equal_approx(wolf_shadow.modulate.a,0.5),"wolf leap keeps the shadow on the ground, smaller and lighter")
	wolf.air_height = 0
	wolf.animate(0)
	wolf_shadow.refresh()
	check(wolf_shadow.footprint==grounded_size and is_equal_approx(wolf_shadow.modulate.a,1),"wolf landing restores ground contact")
	wolf.global_position = anchor+Vector2(280,150)
	wolf.leap_cooldown = 0
	wolf.breath_cooldown = 99
	animate_lineup = true
	if DisplayServer.get_name()=="headless":
		check(wolf.begin_skill("leap"),"real wolf leap starts")
		var peak := 0.0
		for i in 130:
			await get_tree().physics_frame
			wolf._physics_process(1.0/60.0)
			peak = maxf(peak,wolf.air_height)
		check(peak>60 and wolf.air_height==0,"real leap reaches height then lands")
	else:
		await _record_leap(wolf)
	animate_lineup = false
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"subjects":subjects,"frames":recording,"note":"Production resources and scene. Staged lineup with in-place animation; wolf uses its actual leap skill. Camera and sprites retain production scale."},"\t"))
	flow.enter_start_page()
	await frames()
	enemies.clear()
	game.queue_free()
	await frames()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for audio in AudioManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(.25).timeout
	CampProgression.end_transient_session()
	print("ENEMY_GROUND_SHADOW_REVIEW checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _verify_shadow(enemy: EnemyController) -> void:
	var shadow := enemy.get_node("GroundShadow") as Sprite2D
	shadow.refresh()
	check(shadow.visible and shadow.texture!=null and shadow.z_index<enemy.sprite.z_index,"ground shadow present below body: "+enemy.enemy_id)
	var original := shadow.position
	var dimensions: Vector2i = shadow.footprint
	var tex := shadow.texture
	var body_position := enemy.sprite.position
	var body_offset := enemy.sprite.offset
	var color := enemy.sprite.modulate
	enemy.sprite.position += Vector2(0,-40)
	enemy.sprite.offset += Vector2(14,7)
	enemy.sprite.modulate = Color(0.2,0.8,1,0.5)
	shadow.refresh()
	check(shadow.position==original and shadow.texture==tex and shadow.modulate==Color(1,1,1,0.5),"pose and hit offset do not move shadow; only fade is inherited: "+enemy.enemy_id)
	enemy.sprite.hide()
	shadow.refresh()
	check(not shadow.visible,"hidden spawning body has no premature shadow: "+enemy.enemy_id)
	enemy.sprite.show()
	enemy.sprite.position = body_position
	enemy.sprite.offset = body_offset
	enemy.sprite.modulate = color
	enemy.apply_body_scale(.75)
	shadow.refresh()
	check(absf(shadow.footprint.x-dimensions.x*.75)<=1 and shadow.scale==Vector2.ONE,"challenge scale redraws footprint at whole pixels: "+enemy.enemy_id)
	enemy.apply_body_scale(1)
	shadow.refresh()
	check(shadow.footprint==dimensions and shadow.texture==tex,"restored body reuses shared texture: "+enemy.enemy_id)
	var image := shadow.texture.get_image()
	var colors := {}
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x,y)
			if pixel.a>0: colors[pixel.to_rgba32()] = true
	check(colors.size()<=4 and not image.has_mipmaps() and shadow.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"at most four broad shadow tones, no filtered edge: "+enemy.enemy_id)


func _record_leap(wolf: UnderworldWolf) -> void:
	var images: Array[Image] = []
	var start := Time.get_ticks_usec()
	var sampled := start-40000
	var launched := false
	var peak := 0.0
	var peak_image: Image
	while Time.get_ticks_usec()-start<4500000:
		if not launched and Time.get_ticks_usec()-start>=800000:
			check(wolf.begin_skill("leap"),"real wolf leap starts")
			wolf.set_physics_process(true)
			launched = true
		if launched and wolf.state=="chase": wolf.set_physics_process(false)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if now-sampled<33000: continue
		sampled = now
		var image := get_tree().root.get_texture().get_image()
		images.append(image)
		recording.append({"time_ms":(now-start)/1000.0,"wolf_state":wolf.state,"air_height":wolf.air_height,"shadow_origin":wolf.get_node("GroundShadow").position,"shadow_size":wolf.get_node("GroundShadow").footprint})
		if wolf.air_height>peak:
			peak = wolf.air_height
			peak_image = image
	wolf.set_physics_process(false)
	check(peak>55 and wolf.air_height==0,"captured real leap airborne and landed")
	var directory := output.path_join("motion")
	DirAccess.make_dir_recursive_absolute(directory)
	for i in images.size(): images[i].save_jpg(directory.path_join("frame_%04d.jpg" % i),0.97)
	if peak_image!=null: peak_image.save_png(output.path_join("03_wolf_airborne_1920.png"))
	await capture("04_wolf_landed_1920")
