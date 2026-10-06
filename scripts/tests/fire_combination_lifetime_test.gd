extends "res://scripts/tests/burning_lifetime_test.gd"


func _run() -> void:
	CampProgression.begin_transient_session()
	var cases: Array = []
	for other in ["water", "black_hole", "light_sword", "ice", "lightning", "electric_spark", "wind", "explosion"]:
		cases.append(["fire", other])
		cases.append([other, "fire"])
	for order in [
		["fire", "water", "black_hole"], ["water", "fire", "black_hole"],
		["black_hole", "fire", "water"], ["black_hole", "water", "fire"],
		["fire", "water", "light_sword"], ["water", "fire", "light_sword"],
		["fire", "water", "lightning"], ["water", "fire", "electric_spark"],
	]: cases.append(order)
	for effect_ids in cases:
		print("FIRE_COMBINATION_BEGIN ", effect_ids)
		await _test_live_fire_tail(effect_ids)
	for water_frame in [30, 90, 300]:
		await _test_live_fire_tail(["fire"], water_frame)
	var native_cases := 0
	for record in DataRegistry.get_table("weapons"):
		for order in [["fire", "water"], ["water", "fire"]]:
			await _test_native_fire_water(str(record.id), order)
			native_cases += 1
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	# Fast fixed-FPS simulation must still let the real audio thread drain.
	OS.delay_msec(300)
	await frames()
	CampProgression.end_transient_session()
	print("FIRE_COMBINATION_LIFETIME_COMPLETE effect_cases=%d native_cases=%d checks=%d failures=%d" % [cases.size() + 3, native_cases, checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_native_fire_water(weapon_id: String, order: Array) -> void:
	await setup([Vector2(30, 0), Vector2(70, 0), Vector2(120, 0)])
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	player.last_move_direction = Vector2.RIGHT
	var loadout := WeaponLoadout.new()
	host.add_child(loadout)
	loadout.initialize(player)
	loadout.set_active_combat_enabled(true)
	check(loadout.equip_weapon(weapon_id), "native fire/water equip " + weapon_id)
	weapon = loadout.get_weapon_instance(weapon_id)
	while weapon.get_attachment_slot_count() < 2:
		if not loadout.upgrade_weapon(weapon_id): break
	for id in order:
		var item := player.item_inventory.add_item_from_base("scroll_" + str(id), "fire_lifetime")
		check(loadout.attach_item_to_weapon(weapon_id, item.item_instance_id), "native attach " + str(id))
	var state := {"frame": 0, "hits": 0, "late_hits": 0, "last_hit": -1}
	for enemy in enemies:
		enemy.set_physics_process(true)
		enemy.damage_received.connect(func(_source: String, _damage: int):
			state.hits += 1
			state.last_hit = state.frame
			if state.frame > 720: state.late_hits += 1
		)
	await frames()
	check(loadout.cast_weapon(weapon, Vector2(70, 0)), "single native cast " + weapon_id)
	for step in 1200:
		state.frame = step
		if step == 180:
			for index in enemies.size(): enemies[index].position = Vector2(800, index * 60)
		loadout.active_casting.tick(1.0 / 60.0)
		await get_tree().physics_frame
	check(state.hits > 0, "native attack reaches a real enemy " + weapon_id)
	check(state.late_hits == 0 and enemies.all(func(e): return not e.has_status("burning")), "native fire/water stops damaging after departure " + weapon_id)
	check(EnemyController.active_damage_numbers == 0, "native fire/water leaves no damage numbers " + weapon_id)
	print("NATIVE_FIRE_WATER weapon=%s order=%s hits=%d last_hit_frame=%d late_hits=%d" % [weapon_id, str(order), state.hits, state.last_hit, state.late_hits])
