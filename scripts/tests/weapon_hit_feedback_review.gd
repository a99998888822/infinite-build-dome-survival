extends "res://scripts/tests/iron_knight_live_capture.gd"
## Real weapon casting, collision and damage; no direct damage or feedback calls.
var game: GameRoot
var battle: BattleRoot
var units: Array[EnemyController] = []
var records: Array[Dictionary] = []
var feedback_events: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []
var clip_start := 0
var title: Label
var receipt: Label
var failures := 0


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
	seed(1016)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1152, 648)
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
	title = Label.new()
	title.position = Vector2(320, 64)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_constant_override("outline_size", 5)
	layer.add_child(title)
	receipt = Label.new()
	receipt.position = Vector2(320, 94)
	receipt.add_theme_font_size_override("font_size", 18)
	receipt.add_theme_constant_override("outline_size", 5)
	layer.add_child(receipt)
	CombatHitFeedback.feedback_started.connect(_on_feedback)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var origin := battle.player.global_position
	_spawn("enemy_mutated_grub", origin + Vector2(85, 0))
	await _clip("01_single", "短刀命中单只：怪物震动，屏幕不震", "weapon_camp_dagger", origin + Vector2(85, 0), [])
	_clear_units()
	_spawn("enemy_elite_rusher", origin + Vector2(90, 0))
	await _clip("02_boss", "短刀命中小 Boss：只震动，不闪白", "weapon_camp_dagger", origin + Vector2(90, 0), [])
	_clear_units()
	for count in [3, 6, 12]:
		# A normal equipment stat provides enough blast area to see each target.
		var center := origin + Vector2(240, 80)
		for index in count:
			_spawn("enemy_mutated_grub", center + Vector2((index % 4 - 1.5) * 70, (index / 4 - 1) * 48))
		await _clip("%02d_grenade" % count, "榴弹命中 %d 只：第 %d 档震屏＋0.05 秒卡肉" % [count, CombatHitFeedback.tier_for_count(count)], "weapon_iron_grenade_cannon", center, [count])
		_clear_units()
	# Default hammer cells arrive 0.1 seconds apart. Real collision divides 18
	# bats into 3, 3, 6, 3, 3 contacts, all inside the first group's local radius.
	for column in [[64, 3], [112, 3], [176, 6], [240, 3], [294, 3]]:
		for index in int(column[1]):
			var x: float = float(column[0]) + (-6 if index >= 3 else 0)
			_spawn("enemy_echo_bat", origin + Vector2(x, (index % 3 - 1) * 22 + 7))
	await _clip("18_hammer_chain", "战锤一次挥击：3 → 6 → 12 → 15 → 18 连续卡肉", "weapon_earth_hammer", origin + Vector2(296, 0), [3, 6, 12, 15, 18])
	_clear_units()
	var file := FileAccess.open(capture_dir.path_join("recording.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"real_time": true, "fixed_fps": false, "direct_damage_calls": false,
		"scene": "res://scenes/core/game_root.tscn", "failures": failures, "clips": records}, "\t"))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("WEAPON_FEEDBACK_REVIEW_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _spawn(id: String, at: Vector2) -> void:
	var unit := battle.wave_manager.spawn_enemy(id, at)
	unit.current_hp = 100000
	unit.set_physics_process(false)
	unit.sprite.show()
	if unit is EliteRusher: unit.skill_state = "chase"
	if unit is UnderworldWolf: unit.state = "chase"
	unit.damage_received.connect(func(source: String, damage: int):
		damage_events.append({"enemy": unit.get_instance_id(), "source": source, "damage": damage,
			"time_ms": (Time.get_ticks_usec() - clip_start) / 1000.0}))
	units.append(unit)


func _process(delta: float) -> void:
	if get_tree().paused: return
	for unit in units:
		if unit is EliteRusher or unit is EchoBat: unit._animate(delta)
		elif unit is UnderworldWolf: unit.animate(delta)


func _on_feedback(tier: int, count: int) -> void:
	feedback_events.append({"time_ms": (Time.get_ticks_usec() - clip_start) / 1000.0, "tier": tier, "count": count})
	receipt.text = "累计 %d 只｜卡肉第 %d 次｜每次 0.05 秒" % [count, feedback_events.size()]


func _clear_units() -> void:
	CombatHitFeedback.clear()
	for unit in units: unit.free()
	units.clear()
	for runtime in get_tree().get_nodes_in_group("weapon_runtime_effects"): runtime.cancel()


func _clip(name: String, caption: String, weapon_id: String, aim: Vector2, expected: Array) -> void:
	for previous in battle.loadout.weapon_instances.duplicate(): battle.loadout.remove_weapon(previous.weapon_id)
	if not battle.loadout.equip_weapon(weapon_id):
		push_error("REVIEW cannot equip " + weapon_id)
		failures += 1
		return
	var weapon := battle.loadout.get_weapon_instance(weapon_id)
	if weapon.is_grenade():
		weapon.runtime_stats["area_size"] = 200
		weapon.runtime_stats["damage_area_size"] = 200
	weapon.runtime_stats["crit_chance"] = 0
	title.text = caption
	receipt.text = "准备挥击"
	await get_tree().create_timer(0.5, true, false, true).timeout
	feedback_events.clear()
	damage_events.clear()
	var images: Array[Image] = []
	var frames_data: Array[Dictionary] = []
	var cast_count := 0
	var cast_id := 0
	clip_start = Time.get_ticks_usec()
	while Time.get_ticks_usec() - clip_start < 3000000:
		if cast_count == 0 and Time.get_ticks_usec() - clip_start >= 600000:
			if not battle.loadout.active_casting.cast(weapon, aim):
				push_error("REVIEW cast failed " + name)
				failures += 1
			cast_count += 1
			cast_id = DamageEvent.feedback_attack_id(weapon.attack_context)
			receipt.text = "武器已出手"
		if DisplayServer.get_name() == "headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw
		var at := Time.get_ticks_usec()
		if DisplayServer.get_name() != "headless": images.append(get_tree().root.get_texture().get_image())
		var offset := CombatHitFeedback.screen_offset
		frames_data.append({"time_ms": (at - clip_start) / 1000.0, "paused": get_tree().paused,
			"offset": [offset.x, offset.y], "local_count": CombatHitFeedback.last_local_count})
	var actual: Array = feedback_events.map(func(row: Dictionary): return row.count)
	if actual != expected or damage_events.is_empty():
		push_error("REVIEW %s expected=%s actual=%s damages=%d" % [name, expected, actual, damage_events.size()])
		failures += 1
	var directory := capture_dir.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	# Fast frame export after recording avoids introducing encoder stalls into play.
	for index in images.size(): images[index].save_jpg(directory.path_join("frame_%04d.jpg" % index), 0.96)
	records.append({"name": name, "weapon": weapon_id, "casts": cast_count, "attack_id": cast_id,
		"expected": expected, "feedback": feedback_events.duplicate(true), "damage": damage_events.duplicate(true),
		"frames": frames_data, "duration_ms": frames_data[-1].time_ms})
	print("WEAPON_FEEDBACK_CLIP ", name, " feedback=", actual, " damage_receipts=", damage_events.size())
