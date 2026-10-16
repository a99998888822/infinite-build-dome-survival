extends Node
## Real production entrance, native sprite sizes, live collision and input checks.
const OVERLAY = preload("res://scripts/tests/reviews/native_collision_overlay.gd")
var output := "res://artifacts/reviews/native_1080_r02"
var game: GameRoot
var battle: BattleRoot
var player: PlayerController
var ground: CavernSunlightBackdrop
var overlay: Node2D
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var subjects: Array[Dictionary] = []

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	run.call_deferred()

func frames(count: int = 4) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080),"capture is exactly 1920x1080: "+name)
	check(image.save_png(output.path_join(name+".png"))==OK,"save "+name)
	captures.append(name+".png")

func move_to(point: Vector2) -> void:
	player.global_position = point
	player._sync_camera()
	player.camera_2d.force_update_scroll()
	ground._update_area()

func add_enemy(id: String, position: Vector2) -> EnemyController:
	var enemy := battle.wave_manager.spawn_enemy(id,position) as EnemyController
	# Complete the real spawn-warning transition before freezing the lineup.
	if enemy is EliteRusher or enemy is UnderworldWolf: enemy._physics_process(.8)
	enemy.set_physics_process(false)
	return enemy

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",[])
	await frames()
	check(flow.confirm_character_selection(),"production character selection enters battle")
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernSunlightBackdrop
	await frames(12)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.get_current_state()==MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	player = battle.player
	player.set_physics_process(false)
	battle.set_process(false)
	# Fixed-step captures are not a real-time FPS benchmark.
	for node in game.find_children("*","Label",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/ui/combat_performance_line.gd": node.hide()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	await frames()
	var anchor := Vector2.ZERO
	var rock: Dictionary = {}
	var closest := INF
	for nodes: Array in ground.cells.values():
		for node: Node in nodes:
			if not node is Sprite2D or not node.has_meta("scenery"): continue
			var entry: Dictionary = node.get_meta("scenery")
			if entry.kind=="prop" and node.global_position.length_squared()<closest:
				closest = node.global_position.length_squared()
				rock = {"point":node.global_position}
	check(not rock.is_empty(),"review finds an actual streamed obstacle")
	if rock.is_empty():
		get_tree().quit(1)
		return
	anchor = rock.point+Vector2(-280,190)
	move_to(anchor)
	await frames()
	for size in [Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1280,720)]:
		get_tree().root.size = size
		await frames(6)
		check(game._world_viewport.size==Vector2i(1920,1080),"world pixel budget independent of window "+str(size))
		check(get_tree().root.content_scale_size==Vector2i(1152,648),"HUD design canvas preserved")
		check(player.sprite.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE),"one source pixel per world pixel")
	get_tree().root.size = Vector2i(1920,1080)
	await frames()
	var control := battle.active_controller
	control._has_pointer_position = true
	control._pointer_position = (player.get_global_transform_with_canvas().origin+Vector2(200,-50))*Vector2(1152,648)/Vector2(1920,1080)
	check(control.pointer_world().distance_to(player.global_position+Vector2(200,-50))<.01,"HUD pointer maps to the correct world point")
	control._has_pointer_position = false
	var body := player.get_node("CollisionShape2D") as CollisionShape2D
	check(body.shape is CircleShape2D and is_equal_approx(body.shape.radius,24) and body.position==Vector2(0,30),"player lower-body circle: radius 24, center y=30")
	player._configure_visual_body({"body_scale_percent":200})
	check(is_equal_approx(body.shape.radius,24) and body.position==Vector2(0,30),"body configuration does not compound")
	player._configure_visual_body({})
	check(is_equal_approx(body.shape.radius,12) and body.position==Vector2(0,15),"smaller character restores its lower-body circle")
	player._configure_visual_body({"body_scale_percent":200})
	var ids := ["enemy_mutated_grub","enemy_elite_rusher","enemy_echo_bat","enemy_underworld_wolf"]
	var positions := [Vector2(-510,30),Vector2(-265,70),Vector2(325,50),Vector2(575,70)]
	var enemies: Array[EnemyController] = []
	for i in ids.size():
		var enemy := add_enemy(ids[i],anchor+positions[i])
		enemies.append(enemy)
		if i<3: check(enemy.sprite.scale==Vector2.ONE,"native sprite size "+ids[i])
		var collider := enemy.get_node("CollisionShape2D") as CollisionShape2D
		subjects.append({"id":ids[i],"sprite_scale":str(enemy.sprite.scale),"frame_size":str(enemy.sprite.get_rect().size),"collision_type":collider.shape.get_class(),"collision_bounds":str(collider.global_transform*collider.shape.get_rect())})
	var grub := enemies[0]
	grub.global_position = player.global_position+Vector2(55,30)
	check(grub._is_touching_player(),"lower-body circle makes actual contact")
	grub.global_position = player.global_position+Vector2(200,0)
	check(not grub._is_touching_player(),"separated bodies do not inflict contact damage")
	grub.global_position = anchor+positions[0]
	var bat := enemies[2]
	var bat_body := bat.get_node("CollisionShape2D") as CollisionShape2D
	bat.global_position = player.global_position + Vector2(0,-30) - bat_body.position
	check(not bat._is_touching_player(),"upper-body overlap does not cause contact damage")
	bat.global_position = player.global_position + body.position - bat_body.position
	check(bat._is_touching_player(),"lower-body overlap causes contact damage")
	bat.global_position = anchor+positions[2]
	var wolf := enemies[3] as UnderworldWolf
	var wolf_height := wolf.sprite.texture.get_image().get_used_rect().size.y * wolf.sprite.scale.y
	var knight_height := enemies[1].sprite.texture.get_image().get_used_rect().size.y * enemies[1].sprite.scale.y
	check(absf(wolf_height/knight_height-1.0)<.15,"wolf visible height is within 15 percent of knight: %.1f / %.1f" % [wolf_height,knight_height])
	await frames()
	await get_tree().physics_frame
	check(player.test_move(Transform2D(0,rock.point-body.position+Vector2(-180,-2)),Vector2(360,0)),"actual obstacle blocks the offset lower-body circle")
	var layer := CanvasLayer.new()
	layer.layer = 100
	game.add_child(layer)
	overlay = OVERLAY.new()
	layer.add_child(overlay)
	# Draw above the horizon/HUD using the same world-to-canvas presentation.
	overlay.scale = get_viewport().get_visible_rect().size/Vector2(GameRoot.WORLD_RENDER_SIZE)
	overlay.player = player
	overlay.enemies = enemies
	overlay.ground = ground
	overlay.weapon = battle.loadout.weapon_instances[0]
	player.action_animator._show("idle",0)
	await frames(4)
	await capture("01_lineup_collisions_1920")
	overlay.hide()
	await capture("02_lineup_clean_1920")
	# Exercise real movement, enemies and weapon casts after the static review.
	battle.wave_manager.clear_enemies()
	await frames()
	overlay.enemies.clear()
	for i in 8:
		var enemy := add_enemy("enemy_echo_bat" if i%3==0 else "enemy_mutated_grub",player.global_position+Vector2.from_angle(i*TAU/8)*380)
		enemy.set_physics_process(true)
		overlay.enemies.append(enemy)
	player.set_physics_process(true)
	var start := player.global_position
	var hp_before := player.current_hp
	var casts := 0
	for i in 180:
		player.set_mobile_move_direction(Vector2.RIGHT if i<90 else Vector2.UP)
		if i%30==0:
			var targets := get_tree().get_nodes_in_group("enemies")
			if not targets.is_empty():
				if battle.loadout.cast_weapon(battle.loadout.weapon_instances[0],targets[0].global_position): casts += 1
		await get_tree().physics_frame
		await get_tree().process_frame
	player.set_mobile_move_direction(Vector2.ZERO)
	check(player.global_position.distance_to(start)>40,"real player movement advances the enlarged body")
	check(casts>0,"production weapon casting succeeds with new body clearance")
	check(player.alive,"short live combat stays operational")
	player.set_physics_process(false)
	for enemy in overlay.enemies:
		if is_instance_valid(enemy): enemy.set_physics_process(false)
	overlay.caption = "1920×1080 · 实际移动与攻击后的战斗快照"
	overlay.show()
	await capture("03_live_collisions_1920")
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"subjects":subjects,"world_size":str(game._world_viewport.size),"ui_size":str(get_tree().root.content_scale_size),"camera_zoom":str(player.camera_2d.zoom),"player_collision":str(body.shape.get_rect()),"player_collision_type":body.shape.get_class(),"player_collision_offset":str(body.position),"wolf_visible_height":wolf_height,"knight_visible_height":knight_height,"player_move_distance":player.global_position.distance_to(start),"weapon_range":overlay.weapon.get_attack_range(),"casts":casts,"hp_before":hp_before,"hp_after":player.current_hp,"note":"Production rendering and resources; controlled lineup and short live simulation. Review overlay reads actual physics shapes."},"\t"))
	flow.enter_start_page()
	await frames()
	overlay.weapon = null
	overlay.enemies.clear()
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
	print("NATIVE_RESOLUTION_REVIEW checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
