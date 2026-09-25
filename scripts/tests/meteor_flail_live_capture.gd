extends Node

# Capture production combat in GameRoot. Only encounter layout and health are
# fixtures; flail targeting, movement, hits, attachments and UI all run normally.
const WEAPON := "weapon_meteor_flail"
const FRAMES := 240
var variant := "base"
var capture_dir := ""
var current_frame := 0
var launches: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var observed: Dictionary = {}
var enemies: Array[EnemyController] = []
var kills := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func observe() -> void:
	for flail in get_tree().get_nodes_in_group("meteor_flails"):
		var id: int = flail.get_instance_id()
		if observed.has(id): continue
		observed[id] = true
		flail.target_hit.connect(func(target_id: int, damage: int, child: bool):
			contacts.append({"frame": current_frame, "target": target_id, "damage": damage, "child": child}))


func _run() -> void:
	if variant not in ["base", "split", "split_lightning", "split_fire"]:
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	seed(9252026)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [WEAPON])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(6)
	var player := flow.get_bound_player()
	var loadout := flow.get_bound_loadout()
	flow._bound_wave_manager.set_process(false)
	flow._bound_wave_manager.clear_enemies()
	for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"): effect.cancel()
	player.add_runtime_modifier({"id": "capture_health", "source_type": "test", "source_id": "flail_capture",
		"stat": "max_hp", "operation": "add_flat", "value": 990, "duration": -1,
		"stack_rule": "replace_same_source", "target_scope": "player"})
	await frames(8)
	player.restore_full_health()
	var weapon := loadout.get_weapon_instance(WEAPON)
	weapon.runtime_stats.crit_chance = 0
	weapon.attack_timer = 0.25
	var attachments: Array[String] = []
	if variant != "base": attachments.append("scroll_split")
	if variant == "split_lightning": attachments.append("scroll_lightning")
	if variant == "split_fire": attachments.append("scroll_fire")
	for item_id in attachments:
		var item := player.item_inventory.add_item_from_base(item_id, "flail_capture")
		if not loadout.attach_item_to_weapon(WEAPON, item.item_instance_id):
			get_tree().quit(4)
			return
	loadout.weapon_fired.connect(func(id: String, count: int):
		launches.append({"frame": current_frame, "weapon": id, "count": count}))
	var host := Node2D.new()
	player.get_parent().add_child(host)
	# High-health regular enemies keep weak follow-throughs visible after first contact.
	for index in 12:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 240
		var angle := -1.05 + (index % 6) * 0.42
		var radius := 145.0 + (index / 6) * 85.0
		enemy.global_position = player.global_position + Vector2.from_angle(angle) * radius
		enemy.died.connect(func(_enemy, _drop, _where): kills += 1)
		enemy.damage_received.connect(flow._bound_wave_manager._on_enemy_damage_received)
		enemies.append(enemy)
	var start := player.global_position
	var max_movement := 0.0
	var first_enemy_start := enemies[0].global_position
	var max_enemy_movement := 0.0
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(5)
		return
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	battle.set_process(true)
	for index in FRAMES:
		current_frame = index
		# Kite using the player's existing movement input; preserve native enemy AI.
		var move := Vector2.ZERO
		if index >= 25 and index < 105: move = Vector2(-0.28, 0.05)
		elif index >= 120 and index < 205: move = Vector2(-0.22, -0.10)
		player.set_mobile_move_direction(move)
		observe()
		if graphical: await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		max_movement = maxf(max_movement, start.distance_to(player.global_position))
		if is_instance_valid(enemies[0]):
			max_enemy_movement = maxf(max_enemy_movement, first_enemy_start.distance_to(enemies[0].global_position))
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(6)
				return
	battle.set_process(false)
	player.set_mobile_move_direction(Vector2.ZERO)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var valid := contacts.size() > 0 and launches.size() >= 3 and max_movement > 30 and max_enemy_movement > 30 and player.alive
	if variant != "base": valid = valid and contacts.any(func(hit): return hit.child)
	var report := {"production": true, "variant": variant, "fps": 30, "frames": FRAMES,
		"weapon": WEAPON, "attachments": attachments, "encounter_enemy_count": 12,
		"enemy_health_override": 240, "player_max_hp": player.get_stat("max_hp"), "critical_chance_override": 0,
		"max_player_movement": max_movement, "max_enemy_movement": max_enemy_movement,
		"kills": kills, "launches": launches, "contacts": contacts, "valid": valid}
	if not capture_dir.is_empty():
		var output := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(report, "\t"))
	print("METEOR_FLAIL_LIVE variant=", variant, " attacks=", launches.size(), " hits=", contacts.size(), " kills=", kills, " valid=", valid)
	CampProgression.end_transient_session()
	get_tree().quit(0 if valid else 7)
