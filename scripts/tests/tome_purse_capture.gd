extends "res://scripts/tests/nightwatch_spear_capture.gd"

const MATERIAL_PREVIEW = preload("res://scripts/tests/tome_purse_preview.gd")
var attacks: Array[int] = []
var hit_log: Array[Dictionary] = []


func _run() -> void:
	if variant == "line": variant = "tome"
	if variant not in ["tome", "purse"]:
		get_tree().quit(2)
		return
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152,648)
	get_tree().root.content_scale_size = Vector2i(1152,648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_iron_grenade_cannon"])
	await frames(4)
	check(flow.confirm_character_selection(), "review battle available")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	await frames(8)
	var player := flow.get_bound_player()
	flow._bound_wave_manager.set_process(false)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for node in get_tree().get_nodes_in_group("grenade_projectiles"): node.free()
	flow.get_bound_loadout().remove_weapon("weapon_iron_grenade_cannon")
	player.set_physics_process(false)
	if variant == "purse":
		player.add_runtime_modifier({"id": "review_principal", "stat": "finance", "operation": "add_flat",
			"value": 400 - player.get_stat("finance"), "source_type": "test", "source_id": "material_review",
			"duration": -1, "stack_rule": "replace_same_source", "target_scope": "player"})
	var principal_before := player.get_stat("finance")
	var host := Node2D.new()
	player.get_parent().add_child(host)
	var offsets: Array[Vector2] = [Vector2(155,0),Vector2(-165,15),Vector2(90,-100),Vector2(-110,-85),
		Vector2(105,96),Vector2(-80,108),Vector2(25,-55),Vector2(238,0),Vector2(0,-163),Vector2(-220,110)]
	if variant == "purse":
		offsets.clear()
		for index in 12: offsets.append(Vector2(0,-12) + Vector2.RIGHT.rotated(index * TAU / 12.0) * 185)
	var enemies: Array[EnemyController] = []
	for offset in offsets:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", null)
		enemy.global_position = player.global_position + offset
		enemy.current_hp = 1000
		enemies.append(enemy)
	var preview = MATERIAL_PREVIEW.new()
	host.add_child(preview)
	preview.initialize(player, variant)
	preview.set_physics_process(false)
	preview.attack_emitted.connect(func(count: int): attacks.append(count))
	preview.target_hit.connect(func(target_id: int, amount: int, volley_id: int):
		hit_log.append({"target": target_id, "damage": amount, "volley": volley_id, "frame": frame_index}))
	await frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(2)
		return
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	preview.set_physics_process(true)
	for index in 168:
		frame_index = index
		if graphical: await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(3)
				return
	preview.set_physics_process(false)
	check(not preview.equipment_layer.visible, "weapon body is hidden during combat")
	if variant == "tome":
		check(attacks.size() == 7 and attacks.all(func(count): return count == 1) and hit_log.size() == 7, "seven random single-target ticks")
		check(enemies.slice(7).all(func(enemy): return enemy.current_hp == 1000), "outside-ellipse targets remain untouched")
		var unique: Dictionary = {}
		for hit in hit_log: unique[hit.target] = true
		check(unique.size() >= 3, "random targeting visits different enemies")
	else:
		check(attacks.size() == 5 and attacks.all(func(count): return count == 3), "five three-projectile volleys")
		check(hit_log.size() == 15, "all three coins contact targets per volley")
		var unique: Dictionary = {}
		for hit in hit_log: unique[str(hit.volley) + ":" + str(hit.target)] = true
		check(unique.size() == hit_log.size(), "each target takes one hit per volley")
		check(player.get_stat("finance") == principal_before and principal_before == 400, "principal only scales damage and is not consumed")
		check(preview.damage_value() == 10, "400 principal adds six damage to four base damage")
	check(preview.global_position == player.global_position, "effect centered on player")
	var original_position := player.global_position
	player.global_position += Vector2(36, -24)
	preview._physics_process(0.0)
	check(preview.global_position == player.global_position, "effect follows a moved player")
	player.global_position = original_position
	preview._physics_process(0.0)
	var before: float = preview.elapsed
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	preview._physics_process(1.0)
	check(preview.elapsed == before, "pause freezes particles and attack timing")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var report := {"prototype": true, "variant": variant, "fps": 30, "frames": 168, "damage": preview.damage_value(),
		"principal": principal_before, "attacks": attacks, "hits": hit_log, "checks": checks, "failures": failures}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("MATERIAL_REVIEW_COMPLETE variant=",variant," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures == 0 else 1)
