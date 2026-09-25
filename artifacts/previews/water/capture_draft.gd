extends Node

const DRAFT = preload("res://scripts/debug/expanding_water_draft.gd")
var capture_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int) -> void:
	for index in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection():
		get_tree().quit(2)
		return
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if effect.has_method("cancel"): effect.cancel()
	var player: PlayerController = battle.player
	player.set_physics_process(false)
	var center := player.global_position + Vector2(130, 15)
	var range_check: Dictionary = await _verify_damage_range(player)
	if not range_check["passed"]:
		get_tree().quit(5)
		return
	var enemy: EnemyController = battle.wave_manager.spawn_enemy("enemy_mutated_grub", center + Vector2(145, 62))
	enemy.set_physics_process(false)
	await frames(8)
	var graphical := DisplayServer.get_name() != "headless"
	if graphical and capture_dir.is_empty():
		get_tree().quit(3)
		return
	if graphical: DirAccess.make_dir_recursive_absolute(capture_dir)
	var spawned := 0
	for index in range(120):
		if index in [8, 68]:
			var draft := DRAFT.new()
			player.get_parent().add_child(draft)
			draft.global_position = center
			spawned += 1
		if graphical:
			await RenderingServer.frame_post_draw
			var result := get_tree().root.get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % index))
			if result != OK:
				get_tree().quit(4)
				return
		else:
			await get_tree().process_frame
	print("WATER_DRAFT_CAPTURE frames=120 spawned=", spawned, " preview_only=true")
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("range_check.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(range_check, "\t"))
	CampProgression.end_transient_session()
	get_tree().quit(0)


func _verify_damage_range(player: PlayerController) -> Dictionary:
	# Exercise the real water damage query with an isolated copy of the scroll.
	# This verifies the candidate radius without editing the production item.
	var host := Node2D.new()
	player.get_parent().add_child(host)
	var center := player.global_position + Vector2(4000, 0)
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", player)
	var item: Dictionary = DataRegistry.get_record("augmentations", "scroll_water").duplicate(true)
	item["item_instance_id"] = "water_preview_radius_probe"
	item["effect_parameters"]["radius"] = float(item["effect_parameters"]["radius"]) * DRAFT.RADIUS_SCALE
	weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()
	weapon.runtime_stats["damage_area_size"] = 0.0
	var targets: Array[EnemyController] = []
	var gap_results: Array = []
	for gap in [-3.0, 3.0]:
		var target := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		host.add_child(target)
		target.initialize("enemy_mutated_grub", player)
		target.set_physics_process(false)
		target.current_hp = 10000
		var body_radius: float = target.get_node("CollisionShape2D").shape.radius
		var direction := Vector2.LEFT if gap < 0.0 else Vector2.RIGHT
		target.global_position = center + direction * (DRAFT.MAX_RADIUS + body_radius + gap)
		targets.append(target)
		gap_results.append({"collider_gap_from_new_boundary": gap, "body_radius": body_radius})
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": weapon.weapon_id})
	WaterWaveEffect.spawn(host, center, weapon, event)
	var actual_radius := 0.0
	for child in host.get_children():
		if child is WaterWaveEffect: actual_radius = child._radius
	var inside_hit := targets[0].current_hp < 10000
	var outside_hit := targets[1].current_hp < 10000
	for index in targets.size(): gap_results[index]["damaged"] = targets[index].current_hp < 10000
	var passed := is_equal_approx(actual_radius, DRAFT.MAX_RADIUS) and inside_hit and not outside_hit
	var result := {"passed": passed, "preview_only": true, "radius_scale": DRAFT.RADIUS_SCALE,
		"reference_radius": DRAFT.REFERENCE_RADIUS, "visual_max_radius": DRAFT.MAX_RADIUS,
		"actual_damage_radius": actual_radius, "probes": gap_results}
	print("WATER_DRAFT_RANGE radius=", actual_radius, " inside_hit=", inside_hit, " outside_hit=", outside_hit, " passed=", passed)
	host.queue_free()
	await frames(3)
	return result
