extends Node

var output := ""
var report := {}
var enemies: Array[EnemyController] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	_run.call_deferred()

func frames(count := 1) -> void:
	for index in count: await get_tree().process_frame

func draw_frame() -> void:
	if DisplayServer.get_name() == "headless": await frames()
	else: await RenderingServer.frame_post_draw

func _run() -> void:
	CampProgression.begin_transient_session()
	if "--profile-hits" in OS.get_cmdline_user_args():
		await _profile_hits()
		return
	get_window().size = Vector2i(1152, 648)
	get_window().content_scale_size = Vector2i(1152, 648)
	var generator := ShopOfferGenerator.new()
	var context := {"owned_weapon_ids": ["weapon_void_blade", "weapon_dash_blade"],
		"equipped_weapons": [{"weapon_id": "weapon_void_blade", "level": 3}],
		"load_capacity": 100, "current_load": 42, "luck": 100}
	var pool_samples: Array[float] = []
	var pool: Array[Dictionary]
	for iteration in 12:
		var started := Time.get_ticks_usec()
		pool = generator.build_shop_candidate_pool(context)
		pool_samples.append((Time.get_ticks_usec() - started) / 1000.0)
	report.candidate_pool_ms = pool_samples
	var popup := preload("res://scenes/ui/shop/shop_popup.tscn").instantiate() as ShopPopup
	add_child(popup)
	await frames(3)
	var opens: Array = []
	var relics := pool.filter(func(c): return c.offer_type == "relic")
	for iteration in 12:
		var offers: Array = [relics[(iteration % 6) * 3], relics[(iteration % 6) * 3 + 1], relics[(iteration % 6) * 3 + 2]]
		if iteration % 2 == 0: offers[0] = pool[0]
		var started := Time.get_ticks_usec()
		popup.configure({"mode": "free", "offers": offers})
		popup.show_popup()
		var sync := (Time.get_ticks_usec() - started) / 1000.0
		await draw_frame()
		opens.append({"sync_ms": sync, "draw_ms": (Time.get_ticks_usec() - started) / 1000.0})
		await frames(8)
		popup.hide_popup()
		await frames(3)
	report.reward_open = opens
	popup.queue_free()
	await frames(3)
	var arena := Node2D.new()
	add_child(arena)
	if "--prepare-battle" in OS.get_cmdline_user_args():
		var started := Time.get_ticks_usec()
		EnemyController.prepare_damage_number_pool(arena)
		report.battle_prepare_ms = (Time.get_ticks_usec() - started) / 1000.0
	for index in 96:
		var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		arena.add_child(enemy)
		enemy.position = Vector2(140 + (index % 12) * 72, 140 + (index / 12) * 52)
		enemy.current_hp = 1000000
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await frames(5)
	var hits: Array = []
	for iteration in 8:
		var started := Time.get_ticks_usec()
		for enemy in enemies:
			enemy.take_damage_with_feedback(10, "benchmark", iteration % 2 == 1, Vector2.RIGHT, &"heavy")
		var sync := (Time.get_ticks_usec() - started) / 1000.0
		await draw_frame()
		hits.append({"sync_ms": sync, "draw_ms": (Time.get_ticks_usec() - started) / 1000.0,
			"active_numbers": EnemyController.active_damage_numbers, "nodes": arena.get_child_count()})
		await get_tree().create_timer(1.2).timeout
	report.hits_96 = hits
	var reaction_text: Script = preload("res://scripts/effects/element_reaction_text.gd")
	var reaction_samples: Array[float] = []
	for iteration in 4:
		var started := Time.get_ticks_usec()
		for enemy in enemies:
			reaction_text.spawn(arena, "thunder_fire", enemy.global_position)
		reaction_samples.append((Time.get_ticks_usec() - started) / 1000.0)
		await get_tree().create_timer(1.0).timeout
	report.reaction_labels_96_ms = reaction_samples
	arena.queue_free()
	enemies.clear()
	await frames(5)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	report.headless = DisplayServer.get_name() == "headless"
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("COMBAT_HITCH_BENCHMARK ", JSON.stringify(report))
	CampProgression.end_transient_session()
	get_tree().quit()


func _profile_hits() -> void:
	var arena := Node2D.new()
	add_child(arena)
	for index in 96:
		var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.current_hp = 100000
		enemies.append(enemy)
	await frames(5)
	for stage in ["numbers", "feedback"]:
		var started := Time.get_ticks_usec()
		for enemy in enemies:
			if stage == "numbers": enemy._spawn_damage_number(10)
			else: enemy._apply_hit_feedback(Vector2.RIGHT, &"heavy")
		var sync := (Time.get_ticks_usec() - started) / 1000.0
		await draw_frame()
		print("HIT_PROFILE ", stage, " sync_ms=", sync, " draw_ms=", (Time.get_ticks_usec() - started) / 1000.0)
	arena.queue_free()
	enemies.clear()
	await frames(5)
	CampProgression.end_transient_session()
	get_tree().quit()
