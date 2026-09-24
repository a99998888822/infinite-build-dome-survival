extends Node

const PREVIEW = preload("res://scripts/tests/nightwatch_spear_preview.gd")
var variant := "line"
var capture_dir := ""
var frame_index := 0
var events: Array[Dictionary] = []
var checks := 0
var failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_iron_grenade_cannon"])
	await frames(4)
	check(flow.confirm_character_selection(), "battle scene available for review")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	await frames(8)
	var player := flow.get_bound_player()
	flow._bound_wave_manager.set_process(false)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for node in get_tree().get_nodes_in_group("grenade_projectiles"): node.free()
	flow.get_bound_loadout().remove_weapon("weapon_iron_grenade_cannon")
	player.set_physics_process(false)
	var origin := player.global_position
	var host := Node2D.new()
	player.get_parent().add_child(host)
	var enemies: Array[EnemyController] = []
	var offsets: Array[Vector2] = [Vector2(70,0),Vector2(115,0),Vector2(160,0),Vector2(207,0),Vector2(125,-52),Vector2(167,55),Vector2(260,0)]
	if variant == "kite":
		offsets = [Vector2(130,0),Vector2(176,-8),Vector2(223,10),Vector2(268,-5),Vector2(280,70),Vector2(327,-62)]
	for offset in offsets:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.global_position = origin + offset
		enemy.current_hp = 1000
		enemy.set_physics_process(false)
		enemies.append(enemy)
	var spear = PREVIEW.new()
	host.add_child(spear)
	spear.initialize(player)
	spear.diagnostic = variant == "diagnostic"
	spear.set_physics_process(false)
	check(spear.find_nearest() == enemies[0], "aim selects nearest enemy")
	spear.thrust_started.connect(func(target: int): events.append({"event":"start","frame":frame_index,"target":target}))
	spear.thrust_finished.connect(func(count: int): events.append({"event":"finish","frame":frame_index,"hits":count}))
	await frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical:
		if capture_dir.is_empty():
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	if variant == "kite":
		player.set_physics_process(true)
		# Same native movement/chase controllers as gameplay, with scripted input.
		for enemy in enemies: enemy.set_physics_process(true)
	spear.set_physics_process(true)
	var frame_count := 198 if variant == "kite" else 132
	for index in frame_count:
		frame_index = index
		if variant == "kite":
			player.set_mobile_move_direction(Vector2.LEFT * 0.40)
		if graphical: await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(3)
				return
	spear.set_physics_process(false)
	player.set_mobile_move_direction(Vector2.ZERO)
	player.set_physics_process(false)
	var finished := events.filter(func(event): return event.event == "finish")
	if variant != "kite":
		check(finished.size() == 4 and finished.all(func(event): return event.hits == 4), "four thrusts each hit all four aligned targets")
		check(enemies.slice(0,4).all(func(enemy): return enemy.current_hp == 944), "each aligned target receives one 14-damage hit per thrust")
		check(enemies.slice(4).all(func(enemy): return enemy.current_hp == 1000), "side and beyond-tip targets are untouched")
	else:
		check(finished.size() >= 4 and finished.any(func(event): return event.hits >= 2), "native movement and chasing produce multi-target line hits")
		check(player.current_hp == 10, "spacing avoids contact damage")
	# Verify the preview honors the game's pause flag.
	spear.age = 0.05
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	spear._physics_process(1.0)
	check(spear.age == 0.05, "pause freezes attack timing")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	if graphical:
		var manifest := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		manifest.store_string(JSON.stringify({"prototype":true,"variant":variant,"fps":30,"frames":frame_count,"damage":14,"reach":220,"width":28,"interval":1.1,"scripted_player_movement":variant=="kite","events":events,"checks":checks,"failures":failures},"\t"))
	print("SPEAR_REVIEW_COMPLETE variant=", variant, " checks=",checks," failures=",failures," attacks=",finished.size())
	get_tree().quit(0 if failures == 0 else 1)
