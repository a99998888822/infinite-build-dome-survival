extends Node

# Production weapon and projectile in the actual arena; stationary durable targets
# keep the full flight visible instead of ending each shot next to the player.
const WEAPON := "weapon_plasma_cannon"
const FRAME_COUNT := 240
var capture_dir := ""
var launches := 0
var observed: Dictionary = {}
var samples: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var frame_index := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func record_contact(target: EnemyController, damage: int, projectile: ProjectileInstance) -> void:
	var collider := target.get_node("CollisionShape2D") as CollisionShape2D
	var enemy_radius: float = collider.shape.radius * absf(collider.global_scale.x)
	var visual_radius: float = projectile._plasma_visual.core_radius
	var gap := projectile.global_position.distance_to(collider.global_position) - visual_radius - enemy_radius
	contacts.append({"frame":frame_index, "projectile":projectile.projectile_id,
		"damage":damage, "visual_radius":visual_radius, "enemy_radius":enemy_radius, "surface_gap":gap})


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
		get_tree().quit(2)
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
	var host := Node2D.new()
	player.get_parent().add_child(host)
	var targets: Array[EnemyController] = []
	for offset in [Vector2(310, 0), Vector2(330, 30), Vector2(345, -25)]:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		host.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.global_position = player.global_position + offset
		enemy.current_hp = 1000
		enemy.set_physics_process(false)
		targets.append(enemy)
	var weapon := loadout.get_weapon_instance(WEAPON)
	weapon.runtime_stats.crit_chance = 0
	weapon.attack_timer = 0.35
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(3)
		return
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	battle.set_process(true)
	for index in FRAME_COUNT:
		frame_index = index
		if graphical:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		for node in loadout._get_visual_root().get_children():
			if node is ProjectileInstance and node.active and node._plasma_visual != null:
				if not observed.has(node.projectile_id):
					observed[node.projectile_id] = true
					launches += 1
					node.plasma_target_hit.connect(record_contact.bind(node))
				var center: Vector2 = node.get_global_transform_with_canvas().origin
				samples.append({"frame":index, "id":node.projectile_id,
					"center":[center.x, center.y], "age":node._plasma_visual.elapsed, "ticks":node._plasma_tick_count})
		if graphical:
			var error := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if error != OK:
				get_tree().quit(4)
				return
	# The visual clock and world-space feet must remain frozen when battle pauses.
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var frozen: Array[Dictionary] = []
	for node in loadout._get_visual_root().get_children():
		if node is ProjectileInstance and node.active and node._plasma_visual != null:
			frozen.append({"node":node, "age":node._plasma_visual.elapsed,
				"position":node.global_position, "arcs":node._plasma_visual._arcs.duplicate(true)})
	await frames(6)
	var paused := not frozen.is_empty()
	for record in frozen:
		paused = paused and record.node.global_position == record.position
		paused = paused and record.node._plasma_visual.elapsed == record.age
		paused = paused and record.node._plasma_visual._arcs == record.arcs
	var health: Array[int] = []
	for enemy in targets:
		health.append(enemy.current_hp)
	var contact_verified := not contacts.is_empty() and contacts.all(func(hit): return hit.surface_gap <= 0.25)
	var valid := launches >= 4 and samples.size() > 100 and health[0] < 1000 and paused and contact_verified
	var report := {"production":true, "valid":valid, "fps":30, "frames":FRAME_COUNT,
		"weapon":WEAPON, "stationary_targets":true, "target_initial_hp":1000, "target_final_hp":health,
		"critical_chance_override":0, "launches":launches, "pause_verified":paused,
		"contact_verified":contact_verified, "contacts":contacts, "samples":samples}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("PLASMA_LIVE_COMPLETE launches=", launches, " target_hp=", health, " paused=", paused,
		" contact_verified=", contact_verified, " valid=", valid)
	get_tree().quit(0 if valid else 5)
