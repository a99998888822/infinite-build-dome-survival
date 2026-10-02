extends Node

var mode := "resonance"
var capture_dir := ""
var frame := 0
var launches: Array = []
var replay_count := 0
var observed: Dictionary = {}
var shockwave_targets: Array[EnemyController] = []
var shockwave_origins: Array[Vector2] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	seed(9302026)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	var first := "weapon_mutant_tentacle" if mode == "bounce" else "weapon_camp_dagger"
	if mode == "shockwave": first = "weapon_void_blade"
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [first])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(2)
		return
	var battle: BattleRoot = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(6)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	var player := battle.player
	var loadout := battle.loadout
	player.set_physics_process(false)
	player.camera_2d.offset = Vector2(100, -20)
	player.modifier_stack.set_base_stat("load_capacity", 200)
	if mode == "resonance":
		loadout.equip_weapon("weapon_mutant_tentacle")
		loadout.equip_weapon("weapon_earth_hammer")
	for weapon in loadout.weapon_instances:
		weapon.runtime_stats.crit_chance = 0
		weapon.attack_timer = 0.5
		# The starting bow may already carry its character's starting enchantment.
		for equipped in weapon.get_attached_item_instances():
			loadout.detach_item_from_weapon(weapon.weapon_id, equipped.item_instance_id)
		var item_id := "scroll_explosion" if mode == "shockwave" else "scroll_" + mode
		var item := player.item_inventory.add_item_from_base(item_id, "capture")
		if not loadout.attach_item_to_weapon(weapon.weapon_id, item.item_instance_id):
			push_error("Capture could not attach " + item_id + " to " + weapon.weapon_id)
			get_tree().quit(3)
			return
	var positions := [Vector2(110, 0), Vector2(160, 10), Vector2(215, 0), Vector2(270, 0)] if mode == "bounce" else [Vector2(60, 0), Vector2(120, 10), Vector2(180, 0), Vector2(255, 0)]
	if mode == "shockwave": positions = [Vector2(110, 0), Vector2(135, -30), Vector2(140, 30), Vector2(105, 75), Vector2(105, -75)]
	for at in positions:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		if mode == "shockwave": enemy.set_script(preload("res://scripts/tests/water_review_target.gd"))
		enemy.auto_initialize_on_ready = false
		player.get_parent().add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 100000
		enemy.set_physics_process(mode == "shockwave")
		enemy.global_position = player.global_position + at
		if mode == "shockwave":
			shockwave_targets.append(enemy)
			shockwave_origins.append(enemy.global_position)
		enemy.damage_received.connect(battle.wave_manager._on_enemy_damage_received)
	var overlay := CanvasLayer.new()
	game.add_child(overlay)
	var label := Label.new()
	overlay.add_child(label)
	label.position = Vector2(210, 90)
	label.add_theme_font_size_override("font_size", 20)
	var title := "弹跳：首次命中位置，立刻再攻击一次" if mode == "bounce" else "共鸣：轻型短刀 → 异化触手 → 裂地战锤"
	if mode == "shockwave": title = "震荡：作用半径 %s · 推开距离减半 · 白色粒子" % str(DataRegistry.get_record("augmentations", "scroll_explosion").effect_parameters.radius)
	label.text = title + "\n正式武器与附魔逻辑 · 固定敌人位置和生命值"
	if mode == "shockwave": label.text = title + "\n固定初始布置；使用正式击退、碰撞与伤害逻辑"
	var current := Label.new()
	overlay.add_child(current)
	current.position = Vector2(210, 152)
	current.add_theme_font_size_override("font_size", 18)
	loadout.weapon_fired.connect(func(id: String, count: int):
		launches.append({"frame": frame, "weapon": id, "count": count})
		current.text = "正在攻击：" + str(DataRegistry.get_record("weapons", id).display_name))
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(4)
		return
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(6)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	battle.set_process(true)
	var frame_count := 180 if mode == "shockwave" else 240
	for i in frame_count:
		frame = i
		for node in get_tree().get_nodes_in_group("bounce_attacks"):
			if not observed.has(node.get_instance_id()):
				observed[node.get_instance_id()] = true
				replay_count += 1
		if mode == "bounce": current.text = "已触发弹跳：%d 次" % replay_count
		if graphical:
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % i))
			if error != OK:
				get_tree().quit(5)
				return
		else:
			await get_tree().process_frame
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var valid: bool = replay_count > 0 if mode == "bounce" else launches.size() >= 3 and launches[0].weapon == first and launches[1].weapon == "weapon_mutant_tentacle" and launches[2].weapon == "weapon_earth_hammer"
	var pushed := 0
	for i in shockwave_targets.size():
		if shockwave_targets[i].global_position.distance_to(shockwave_origins[i]) > 30:
			pushed += 1
	if mode == "shockwave": valid = pushed >= 3 and not launches.is_empty()
	var report := {"mode": mode, "production": true, "fps": 30, "frames": frame_count, "launches": launches, "replays": replay_count, "pushed_targets": pushed, "valid": valid, "damage": battle.wave_manager.weapon_damage_this_wave}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("BOUNCE_RESONANCE_CAPTURE ", JSON.stringify(report))
	game.queue_free()
	await frames(4)
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	get_tree().quit(0 if valid else 6)
