extends Node

# Real GameRoot rendering, shipped weapons and damage. Only enemy placement and
# health are fixtures; transient sessions never write player progression.
var kind := "copper_lamp"
var capture_dir := ""
var fps := 60
var current_frame := 0
var player: PlayerController
var loadout: WeaponLoadout
var enemies: Array[EnemyController] = []
var observed: Dictionary = {}
var contacts: Array = []
var launches: Array = []
var points: Array = []
var samples: Array = []
var weapon: WeaponInstance


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="): kind = arg.trim_prefix("--kind=")
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--fps="): fps = int(arg.trim_prefix("--fps="))
	_run.call_deferred()


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func observe() -> void:
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if node.weapon != weapon or observed.has(node.get_instance_id()): continue
		observed[node.get_instance_id()] = true
		node.target_hit.connect(func(id: int, damage: int, child: bool): contacts.append({"frame":current_frame,"target":id,"damage":damage,"child":child}))
		if node is EarthHammer:
			node.node_created.connect(func(i: int, p: Vector2): points.append({"frame":current_frame,"index":i,"point":[p.x,p.y]}))


func _run() -> void:
	if kind not in ["copper_lamp", "mutant_tentacle", "earth_hammer", "hammer_enchanted"]:
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	seed(9302026)
	var id := "weapon_" + ("earth_hammer" if kind == "hammer_enchanted" else kind)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1152,768)
	get_tree().root.content_scale_size = Vector2i(1152,768)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [id])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(3)
		return
	var battle: BattleRoot = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await frames(6)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player = battle.player
	loadout = battle.loadout
	player.set_physics_process(false)
	player.camera_2d.offset = Vector2(130,-35)
	weapon = loadout.get_weapon_instance(id)
	weapon.runtime_stats.crit_chance = 0
	weapon.attack_timer = 0.30
	loadout.weapon_fired.connect(func(weapon_id: String, count: int): launches.append({"frame":current_frame,"weapon":weapon_id,"count":count}))
	if kind == "hammer_enchanted":
		for item_id in ["scroll_electric_spark", "scroll_split"]:
			var item := player.item_inventory.add_item_from_base(item_id,"trio_capture")
			if not loadout.attach_item_to_weapon(id,item.item_instance_id):
				get_tree().quit(4)
				return
	var positions: Array = [Vector2(160,-25),Vector2(190,40)] if kind == "copper_lamp" else [Vector2(65,0),Vector2(125,10),Vector2(215,0),Vector2(280,0),Vector2(120,100)]
	for at in positions:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		player.get_parent().add_child(enemy)
		enemy.initialize("enemy_mutated_grub",player)
		enemy.current_hp = 5000
		enemy.set_physics_process(false)
		enemy.global_position = player.global_position + at
		enemy.damage_received.connect(battle.wave_manager._on_enemy_damage_received)
		enemies.append(enemy)
	var caption := CanvasLayer.new()
	game.add_child(caption)
	var label := Label.new()
	caption.add_child(label)
	label.position = Vector2(48,100)
	label.add_theme_font_size_override("font_size",20)
	label.text = "%s · 正式武器实机验证\n受控敌人布置；武器、伤害与附魔使用正式逻辑" % str(weapon.weapon_data.display_name)
	await frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(5)
		return
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	battle.set_process(true)
	var frame_count := fps * (9 if kind == "copper_lamp" else 6)
	for i in frame_count:
		current_frame = i
		var t := float(i) / fps
		if kind == "copper_lamp":
			var a := Vector2(160,-25)
			var b := Vector2(190,40)
			if t >= 1 and t < 1.5: a = Vector2(85,-25)
			elif t >= 1.5 and t < 2.0: b = Vector2(-80,20)
			elif t >= 3.2 and t < 5.8: a = Vector2(90,-30)
			elif t >= 5.8 and t < 6.5: b = Vector2(-80,-25)
			enemies[0].global_position = player.global_position + a
			enemies[1].global_position = player.global_position + b
		observe()
		if graphical:
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
		else: await get_tree().process_frame
		if i % 3 == 0:
			for node in get_tree().get_nodes_in_group("copper_lamps"):
				if node.weapon == weapon:
					samples.append({"frame":i,"firing":node.firing,"heat":node.heat,"cooling":node.cooling,"heading":node.heading.angle(),"target":node.target.get_instance_id() if is_instance_valid(node.target) else 0})
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % i))
			if error != OK:
				get_tree().quit(6)
				return
	battle.set_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	var attributed: int = battle.wave_manager.weapon_damage_this_wave.get(id,0)
	var valid := not contacts.is_empty() and not launches.is_empty() and attributed > 0
	var report := {"production":true,"kind":kind,"weapon":id,"fps":fps,"frames":frame_count,
		"fixture":"stationary player, scripted enemy positioning, enemy health 5000", "contacts":contacts,
		"launches":launches,"points":points,"samples":samples,"attributed_damage":attributed,"valid":valid}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("WEAPON_TRIO_LIVE kind=",kind," hits=",contacts.size()," damage=",attributed," valid=",valid)
	game.queue_free()
	await frames(3)
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	get_tree().quit(0 if valid else 7)
