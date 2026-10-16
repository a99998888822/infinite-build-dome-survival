extends "res://scripts/tests/weapon_hit_feedback_review.gd"
## Uses real active casts; shared capture helper records wall-clock frames/damage.


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
	battle.player.add_runtime_modifier({"id": "visual_review_capacity", "source_id": "visual_review", "source_type": "test", "stat": "load_capacity", "operation": "override", "value": 1000, "duration": -1, "stack_rule": "unique", "target_scope": "player"})
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
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if DisplayServer.get_name() != "headless" and (only.is_empty() or "cannon" in only.split(",")):
		await _warm_cannon_jet(origin)
	for row in [
		["grenade", "铸铁榴弹炮 · 爆焰", "weapon_iron_grenade_cannon", Vector2(260, 30)],
		["tome", "坤舆秘仪书 · 点名符印", "weapon_kunyu_ritual_tome", Vector2(130, -10)],
		["tentacle", "异化触手 · 甩击带", "weapon_mutant_tentacle", Vector2(100, 0)],
		["hammer", "裂地战锤 · 锤弧", "weapon_earth_hammer", Vector2(60, 0)],
		["spear", "守夜长枪 · 枪芒", "weapon_nightwatch_spear", Vector2(160, 0)],
		["flail", "流星摆锤 · 宽弧拖尾", "weapon_meteor_flail", Vector2(140, 0)],
		["cannon", "巨型手持火炮 · 枪口焰", "weapon_hand_cannon", Vector2(120, 0)],
	]:
		if not only.is_empty() and row[0] not in only.split(","): continue
		battle.player.global_position = origin
		_spawn("enemy_mutated_grub", origin + Vector2(row[3]))
		await _clip(row[0], row[1], row[2], origin + Vector2(row[3]), [])
		_clear_units()
	var file := FileAccess.open(capture_dir.path_join("recording.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"real_time": true, "fixed_fps": false, "direct_damage_calls": false,
		"failures": failures, "clips": records}, "\t"))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("WEAPON_BLOCK_REVIEW_COMPLETE failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _warm_cannon_jet(origin: Vector2) -> void:
	# Compile the GPU material through a real cast before recording its motion.
	# No targets or damage receipts are part of this warmup.
	if not battle.loadout.equip_weapon("weapon_hand_cannon"):
		failures += 1
		return
	var weapon := battle.loadout.get_weapon_instance("weapon_hand_cannon")
	if not battle.loadout.active_casting.cast(weapon, origin + Vector2(120, 0)):
		failures += 1
	await get_tree().create_timer(3.0, true, false, true).timeout
	battle.loadout.remove_weapon("weapon_hand_cannon")
	battle.player.global_position = origin
	await get_tree().create_timer(0.5, true, false, true).timeout
	print("WEAPON_BLOCK_REVIEW_CANNON_WARMUP_COMPLETE")
