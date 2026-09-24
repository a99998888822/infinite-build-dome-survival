extends Node

# Records the production attack loop; only the player, spawns and targets are fixed.
# Run in an isolated project/user directory with --fixed-fps 30.
const WEAPON := "weapon_iron_grenade_cannon"
const FRAME_COUNT := 180
var capture_dir := ""
var observed: Dictionary = {}
var events: Array[Dictionary] = []
var frame_index := 0
var variant := "plain"
var attachments: Array[String] = []
var root_launches := 0
var child_launches := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--variant="):
			variant = arg.trim_prefix("--variant=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _on_detonated(hit_count: int, projectile: GrenadeProjectile) -> void:
	var child := projectile.split_generation > 0
	events.append({"event": "detonation", "frame": frame_index, "hits": hit_count, "child": child, "impact_batches": projectile.impact_batches})
	print("CAPTURE_DETONATION frame=", frame_index, " hits=", hit_count, " child=", child, " batches=", projectile.impact_batches)


func _run() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [WEAPON])
	await frames(4)
	if not flow.confirm_character_selection():
		push_error("CAPTURE_BATTLE_START_FAILED")
		get_tree().quit(1)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	await frames(8)
	var player := flow.get_bound_player()
	var loadout := flow.get_bound_loadout()
	flow._bound_wave_manager.set_process(false)
	player.set_physics_process(false)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		enemy.free()
	for projectile in get_tree().get_nodes_in_group("grenade_projectiles"):
		projectile.free()
	var host := Node2D.new()
	player.get_parent().add_child(host)
	var targets: Array[EnemyController] = []
	var offsets: Array[Vector2] = [Vector2(200, 0), Vector2(210, 25), Vector2(245, 0), Vector2(280, 0)]
	if variant == "split":
		# Sparse outer targets show the children searching beyond the first blast.
		for index in 8:
			offsets.append(Vector2(245, 0) + Vector2.RIGHT.rotated(TAU * index / 8.0) * 138)
	for offset: Vector2 in offsets:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.global_position = player.global_position + offset
		enemy.current_hp = 1000
		enemy.set_physics_process(false)
		targets.append(enemy)
	var weapon := loadout.get_weapon_instance(WEAPON)
	if variant == "fire":
		var fire := player.item_inventory.add_item_from_base("scroll_fire", "capture")
		loadout.attach_item_to_weapon(WEAPON, fire.item_instance_id)
		attachments.append("scroll_fire")
	elif variant == "split":
		var split := player.item_inventory.add_item_from_base("scroll_split", "capture")
		loadout.attach_item_to_weapon(WEAPON, split.item_instance_id)
		attachments.append("scroll_split")
	weapon.runtime_stats.crit_chance = 0
	weapon.attack_timer = 0.35
	await frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		push_error("CAPTURE_DIR_REQUIRED")
		get_tree().quit(1)
		return
	if graphical:
		DirAccess.make_dir_recursive_absolute(capture_dir)
	battle.set_process(true)
	for index in FRAME_COUNT:
		frame_index = index
		if graphical:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		for node in get_tree().get_nodes_in_group("grenade_projectiles"):
			var id: int = node.get_instance_id()
			if not observed.has(id):
				observed[id] = true
				node.detonated.connect(_on_detonated.bind(node))
				var child: bool = node.split_generation > 0
				child_launches += 1 if child else 0
				root_launches += 0 if child else 1
				events.append({"event": "launch", "frame": index, "child": child})
				print("CAPTURE_LAUNCH frame=", index, " child=", child)
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				push_error("CAPTURE_FRAME_SAVE_FAILED")
				get_tree().quit(2)
				return
	battle.set_process(false)
	var blasts := events.filter(func(event: Dictionary) -> bool: return event.event == "detonation" and not event.child)
	var valid := root_launches == 4 and blasts.size() == 3
	# The fourth shot starts near the end of the six-second recording.
	for blast in blasts:
		valid = valid and int(blast.hits) == 4 and int(blast.impact_batches) == 4
	if variant == "split":
		var child_blasts := events.filter(func(event: Dictionary) -> bool: return event.event == "detonation" and event.child)
		valid = valid and child_launches == 24 and child_blasts.size() == 24
		for index in targets.size():
			valid = valid and targets[index].current_hp == (952 if index < 4 else 970)
		for blast in child_blasts:
			valid = valid and int(blast.hits) == 1 and int(blast.impact_batches) == 1
		print("CAPTURE_SPLIT_CHECK children=", child_launches, " core_hp=", targets[0].current_hp, " outer_hp=", targets[4].current_hp)
	if graphical:
		var manifest := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		manifest.store_string(JSON.stringify({"fps": 30, "frames": FRAME_COUNT, "weapon": WEAPON,
			"level": 1, "variant": variant, "enchantments": attachments, "stationary_targets": true, "target_hp": 1000,
			"critical_chance_override": 0, "attack_interval": weapon.get_actual_attack_interval_seconds(),
			"flight_seconds": weapon.weapon_data.get("grenade_flight_seconds"), "events": events}, "\t"))
	print("CAPTURE_DONE frames=", FRAME_COUNT, " launches=", observed.size(), " detonations=", blasts.size(), " valid=", valid)
	get_tree().quit(0 if valid else 3)
