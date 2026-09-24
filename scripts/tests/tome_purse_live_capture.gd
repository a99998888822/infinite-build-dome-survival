extends Node

# Real BattleRoot/WeaponLoadout and moving EnemyControllers; no preview weapons.
# A fixed encounter keeps the two recordings comparable and avoids reward modals.
const TOME := "weapon_kunyu_ritual_tome"
const PURSE := "weapon_rentier_purse"
const FRAME_COUNT := 240
var variant := "tome"
var capture_dir := ""
var frame_index := 0
var launches: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var observed: Dictionary = {}
var dead_count := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func observe_contacts() -> void:
	for group in ["ritual_domains", "coin_projectiles"]:
		for effect in get_tree().get_nodes_in_group(group):
			var id: int = effect.get_instance_id()
			if observed.has(id): continue
			observed[id] = true
			effect.target_hit.connect(func(target_id: int, damage: int, child: bool):
				contacts.append({"frame":frame_index,"target":target_id,"damage":damage,"child":child}))


func _run() -> void:
	if variant not in ["tome", "purse", "combined"]:
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
	var ids: Array[String] = []
	if variant in ["tome", "combined"]: ids.append(TOME)
	if variant in ["purse", "combined"]: ids.append(PURSE)
	flow.enter_battle_selection("character_void_hunter", ids)
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	await frames(8)
	var player := flow.get_bound_player()
	var loadout := flow.get_bound_loadout()
	flow._bound_wave_manager.set_process(false)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
	for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"): effect.free()
	# Only demonstration resources change: enough health to avoid an interrupted clip,
	# and 400 principal for an easily inspected 10-damage baseline coin.
	player.add_runtime_modifier({"id":"capture_health","source_type":"test","source_id":"live_capture",
		"stat":"max_hp","operation":"add_flat","value":990,"duration":-1,"stack_rule":"replace_same_source","target_scope":"player"})
	# Let the existing HUD's maximum-health tween finish before healing the fixture.
	await frames(8)
	if variant != "tome":
		flow._bound_wave_manager.finance_system.deposit(400, true, "live_capture")
	player.restore_full_health()
	await frames(8)
	var attachments: Array[String] = []
	for weapon in loadout.get_weapon_instances():
		weapon.runtime_stats.crit_chance = 0
		weapon.attack_timer = 0.35
		if variant == "combined":
			for item_id in ["scroll_split", "scroll_fire"]:
				var item := player.item_inventory.add_item_from_base(item_id, "live_capture")
				if not loadout.attach_item_to_weapon(weapon.weapon_id, item.item_instance_id):
					get_tree().quit(4)
					return
				attachments.append(weapon.weapon_id + ":" + item_id)
	loadout.weapon_fired.connect(func(id: String, count: int): launches.append({"frame":frame_index,"weapon":id,"count":count}))
	var host := Node2D.new()
	player.get_parent().add_child(host)
	for index in 18:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		var angle := index * TAU / 18.0
		var radius := 185.0 + (index % 3) * 45.0
		enemy.global_position = player.global_position + Vector2(cos(angle) * radius, sin(angle) * radius * 0.72)
		enemy.died.connect(func(_enemy, _drop, _where): dead_count += 1)
	var start := player.global_position
	var max_movement := 0.0
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(5)
		return
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	battle.set_process(true)
	for index in FRAME_COUNT:
		frame_index = index
		# Drive the existing mobile movement input, leaving movement/collision native.
		var move := Vector2.ZERO
		if index >= 35 and index < 80: move = Vector2(-0.48, 0.2)
		elif index >= 95 and index < 150: move = Vector2(0.48, -0.12)
		elif index >= 175 and index < 220: move = Vector2(-0.30, 0.15)
		player.set_mobile_move_direction(move)
		observe_contacts()
		if graphical: await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		max_movement = maxf(max_movement, start.distance_to(player.global_position))
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(6)
				return
	battle.set_process(false)
	player.set_mobile_move_direction(Vector2.ZERO)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var valid := not contacts.is_empty() and launches.size() >= 7 and max_movement > 50 and player.alive
	if variant == "purse":
		valid = valid and launches.all(func(event): return event.count == 3) and loadout.get_current_principal() == 400
	if variant == "combined":
		valid = valid and contacts.any(func(event): return event.child)
	var report := {"production":true,"variant":variant,"fps":30,"frames":FRAME_COUNT,"weapons":ids,
		"attachments":attachments,"moving_enemies":true,"enemy_count":18,"native_enemy_stats":true,
		"player_health_override":1000,"principal":loadout.get_current_principal(),"critical_chance_override":0,
		"max_player_movement":max_movement,"kills":dead_count,"launches":launches,"contacts":contacts,"valid":valid}
	if not capture_dir.is_empty():
		var output := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(report,"\t"))
	print("TOME_PURSE_LIVE_COMPLETE variant=",variant," attacks=",launches.size()," hits=",contacts.size()," kills=",dead_count," valid=",valid)
	get_tree().quit(0 if valid else 7)
