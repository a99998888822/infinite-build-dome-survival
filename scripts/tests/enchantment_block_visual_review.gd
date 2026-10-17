extends "res://scripts/tests/weapon_hit_feedback_review.gd"
## Production weapon casts and attachments, with stationary high-HP targets.
## Physics stays active so the real shockwave and wind knockback remain visible.
const CASES := [
	["shock", "震荡", "scroll_explosion"],
	["water", "水流", "scroll_water"],
	["hole", "黑洞", "scroll_black_hole"],
	["sword", "光辉剑", "scroll_light_sword"],
	["wind", "风刃", "scroll_wind"],
]


func _run() -> void:
	if capture_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.low_processor_usage_mode = false
	Engine.max_fps = 60
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	seed(1017)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1920, 1080)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.player._invincibility_timer = 10000
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"): runtime.queue_free()
	for weapon in battle.loadout.weapon_instances.duplicate(): battle.loadout.remove_weapon(weapon.weapon_id)
	await frames(4)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	layer.hide()
	title = Label.new()
	title.position = Vector2(570, 160)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_constant_override("outline_size", 6)
	layer.add_child(title)
	receipt = Label.new()
	receipt.position = Vector2(570, 200)
	receipt.add_theme_font_size_override("font_size", 20)
	receipt.add_theme_constant_override("outline_size", 5)
	layer.add_child(receipt)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	for row in CASES:
		if not only.is_empty() and row[0] not in only.split(","):
			continue
		await _record_case(row)
	var file := FileAccess.open(capture_dir.path_join("recording.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"real_time": true, "direct_damage_calls": false,
		"direct_effect_spawns": false, "resolution": [1920,1080], "native_crop": [840,220,900,680],
		"failures": failures, "clips": records}, "\t"))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("ENCHANTMENT_BLOCK_REVIEW_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _process(_delta: float) -> void:
	pass


func _spawn(id: String, at: Vector2) -> void:
	super._spawn(id, at)
	units[-1].set_target_player(null)
	units[-1].set_physics_process(true)
	# Review targets do not collide with one another; production knockback runs.
	units[-1].collision_mask = 0


func _targets(kind: String) -> Vector2:
	var center := battle.player.global_position + Vector2(220, 30)
	_spawn("enemy_mutated_grub", center)
	if kind == "wind":
		for offset in [Vector2(85, 0), Vector2(150, 0), Vector2(210, 0)]:
			_spawn("enemy_mutated_grub", center + offset)
	else:
		for offset in [Vector2(35,-34),Vector2(35,34),Vector2(70,0),Vector2(100,-65),Vector2(100,65)]:
			_spawn("enemy_echo_bat",center+offset)
	return center


func _record_case(row: Array) -> void:
	_clear_units()
	for previous in battle.loadout.weapon_instances.duplicate(): battle.loadout.remove_weapon(previous.weapon_id)
	if not battle.loadout.equip_weapon("weapon_void_blade"):
		failures += 1
		return
	var weapon := battle.loadout.get_weapon_instance("weapon_void_blade")
	weapon.runtime_stats["crit_chance"] = 0
	var item := battle.player.item_inventory.add_item_from_base(row[2], "enchantment_block_review")
	if not weapon.attach_item_instance(item):
		push_error("REVIEW attachment failed " + row[2])
		failures += 1
		return
	var aim := _targets(row[0])
	await frames(5)
	# Warm the exact production shader through a real cast before recording.
	if not battle.loadout.active_casting.cast(weapon,aim): failures += 1
	await get_tree().create_timer(2.5, true, false, true).timeout
	_clear_units()
	aim = _targets(row[0])
	title.text = row[1] + " · 大色块像素效果"
	receipt.text = "木质弓箭附魔 · 实际命中触发 · 原始游戏倍率"
	await get_tree().create_timer(0.6, true, false, true).timeout
	damage_events.clear()
	var images: Array[Image] = []
	var samples: Array[Dictionary] = []
	var observed: Dictionary = {}
	var casted := false
	var previous_capture := 0
	var starts: Array[Vector2] = []
	for unit in units: starts.append(unit.global_position)
	clip_start = Time.get_ticks_usec()
	while Time.get_ticks_usec()-clip_start < 3300000:
		if not casted and Time.get_ticks_usec()-clip_start >= 550000:
			if not battle.loadout.active_casting.cast(weapon,aim):
				push_error("REVIEW cast failed " + row[0])
				failures += 1
			casted = true
		if DisplayServer.get_name() == "headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw
		var at := Time.get_ticks_usec()
		if at - previous_capture < 32000: continue
		previous_capture = at
		if DisplayServer.get_name() != "headless":
			images.append(get_tree().root.get_texture().get_image().get_region(Rect2i(840,220,900,680)))
		for node in CombatEffectWorld._get_visual_parent(battle).get_children():
			if node is WaterWaveEffect or node is BlackHoleEffect or node is LightSwordEffect or node is WindBladeEffect:
				observed[node.get_script().resource_path] = true
		for node in get_tree().get_nodes_in_group("enchantment_block_shockwaves"):
			observed[node.get_script().resource_path] = true
		samples.append({"time_ms":(at-clip_start)/1000.0})
	var moved := 0
	var unique: Dictionary = {}
	for index in units.size():
		if units[index].global_position.distance_to(starts[index])>3: moved += 1
	for hit in damage_events: unique[hit.enemy] = true
	if damage_events.is_empty() or observed.is_empty() or (row[0] in ["shock","hole","wind"] and moved==0):
		push_error("REVIEW missing gameplay evidence " + row[0])
		failures += 1
	var directory := capture_dir.path_join(row[0])
	DirAccess.make_dir_recursive_absolute(directory)
	for index in images.size(): images[index].save_png(directory.path_join("frame_%04d.png" % index))
	records.append({"name":row[0],"attachment":row[2],"weapon":"weapon_void_blade","casts":1,
		"damage":damage_events.duplicate(true),"unique_targets":unique.size(),"moved":moved,
		"observed":observed.keys(),"frames":samples,"duration_ms":samples[-1].time_ms})
	print("ENCHANTMENT_CLIP ",row[0]," effects=",observed.keys()," targets=",unique.size()," moved=",moved)
	_clear_units()
