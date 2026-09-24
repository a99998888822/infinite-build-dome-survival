extends "res://scripts/tests/nightwatch_spear_capture.gd"

const VARIANTS := {
	"plain": [], "split": ["scroll_split"], "fire": ["scroll_fire"],
	"ice": ["scroll_ice"], "lightning": ["scroll_lightning"],
	"split_fire": ["scroll_split", "scroll_fire"],
	"split_lightning": ["scroll_split", "scroll_lightning"],
}
var main_impacts := 0
var child_impacts := 0
var child_launches := 0
var child_targets: Dictionary = {}
var observed_status: Dictionary = {}
var launched_events: Array[Dictionary] = []


func _run() -> void:
	if variant == "line": variant = "split"
	if not VARIANTS.has(variant):
		get_tree().quit(2)
		return
	seed(240925)
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
	check(flow.confirm_character_selection(), "battle available")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	await frames(8)
	var player := flow.get_bound_player()
	flow._bound_wave_manager.set_process(false)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for node in get_tree().get_nodes_in_group("grenade_projectiles"): node.free()
	flow.get_bound_loadout().remove_weapon("weapon_iron_grenade_cannon")
	player.set_physics_process(false)
	var host := Node2D.new()
	player.get_parent().add_child(host)
	var enemies: Array[EnemyController] = []
	var offsets: Array[Vector2] = [Vector2(100,0), Vector2(155,0), Vector2(210,0),
		Vector2(155,-65), Vector2(155,65), Vector2(225,-90), Vector2(225,90), Vector2(295,-50), Vector2(295,50),
		Vector2(-250,0), Vector2(550,0)]
	for offset in offsets:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		# No chase target: stationary enemies keep native status timers running.
		enemy.initialize("enemy_mutated_grub", null)
		enemy.global_position = player.global_position + offset
		enemy.current_hp = 2000
		enemies.append(enemy)
	var spear = PREVIEW.new()
	host.add_child(spear)
	spear.initialize(player)
	var ids: Array[String] = []
	ids.assign(VARIANTS[variant])
	spear.configure_enchantments(ids)
	spear.set_physics_process(false)
	spear.thrust_finished.connect(func(count: int): events.append({"frame": frame_index, "main_hits": count}))
	spear.impact_registered.connect(func(target_id: int, child: bool):
		if child:
			child_impacts += 1
			child_targets[target_id] = true
		else: main_impacts += 1)
	spear.shard_launched.connect(func(shard: ProjectileInstance):
		child_launches += 1
		launched_events.append({"damage": shard.damage_event.damage, "element_base": shard.damage_event.original_damage,
			"depth": shard._split_depth, "forward": shard.direction.dot(spear.aim) > 0.0}))
	await frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(2)
		return
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	spear.set_physics_process(true)
	const FRAME_COUNT := 108
	for index in FRAME_COUNT:
		frame_index = index
		if graphical: await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		for enemy_index in enemies.size():
			for status in ["burning", "slowed", "stunned"]:
				if enemies[enemy_index].has_status(status): observed_status[str(enemy_index) + ":" + status] = true
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(3)
				return
	spear.set_physics_process(false)
	check(events.size() == 3 and main_impacts == 9, "three thrusts hit each of three aligned enemies once")
	check(enemies[9].current_hp == 2000 and enemies[10].current_hp == 2000, "distant rear and far controls untouched")
	var split := ids.has("scroll_split")
	check(child_launches == (18 if split else 0), "two children per primary contact, no recursive split")
	if split:
		check(child_impacts == 18 and child_targets.size() == 6, "all six side targets receive child impacts each attack")
		check(launched_events.all(func(event): return event.damage == 8 and event.element_base == 8 and event.depth == 1 and event.forward), "children inherit 60 percent damage and elemental base and travel forward")
	if variant in ["plain", "split"]:
		check(enemies.slice(0,3).all(func(enemy): return enemy.current_hp == 1958), "children never hit primary victims again")
		check(enemies.slice(3,9).all(func(enemy): return enemy.current_hp == (1976 if split else 2000)), "native side-target damage is exact")
	var status := "burning" if ids.has("scroll_fire") else ("slowed" if ids.has("scroll_ice") else "stunned")
	if variant not in ["plain", "split"]:
		var all_primary := true
		for index in 3: all_primary = all_primary and observed_status.has(str(index) + ":" + status)
		check(all_primary, "every primary contact applies native elemental state")
		if split:
			var all_secondary := true
			for index in range(3,9): all_secondary = all_secondary and observed_status.has(str(index) + ":" + status)
			check(all_secondary, "every child victim receives inherited native elemental state")
	check(spear.age < 0, "weapon hidden between attacks")
	var report := {"prototype": true, "variant": variant, "enchantments": ids, "fps": 30, "frames": FRAME_COUNT,
		"main_impacts": main_impacts, "child_launches": child_launches, "child_impacts": child_impacts,
		"events": events, "child_events": launched_events, "observed_status": observed_status,
		"target_hp": enemies.map(func(enemy): return enemy.current_hp), "checks": checks, "failures": failures}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("SPEAR_ENCHANTMENT_REVIEW variant=", variant, " checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
