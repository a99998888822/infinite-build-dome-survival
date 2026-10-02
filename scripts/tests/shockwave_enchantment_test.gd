extends "res://scripts/tests/weapon_trio_test.gd"

const BOW := "weapon_void_blade"
const POINT := Vector2(200, 100)
var damage_signals := 0


func cast() -> void:
	var hit := DamageEvent.create({"damage": 100000, "original_damage": 100000, "element_damage_bonus": 100000,
		"source_player": player, "source_weapon_id": weapon.weapon_id})
	CombatEffectWorld.trigger_ground_weapon_impact(host, weapon, hit, POINT, Vector2.RIGHT)
	await frames()


func waves() -> Array[Node]:
	return host.get_children().filter(func(child): return child is ExplosionEffect and not child.is_queued_for_deletion())


func _run() -> void:
	CampProgression.begin_transient_session()
	await fixture(BOW, [POINT + Vector2(55, 0), POINT + Vector2(-30, 0), POINT + Vector2(0, -30), POINT + Vector2(0, 30), POINT, POINT + Vector2(56, 0)], ["scroll_explosion"])
	for enemy in enemies:
		enemy.damage_received.connect(func(_amount, _source): damage_signals += 1)
	await cast()
	check(enemies.all(func(enemy): return enemy.current_hp == 10000), "shockwave deals zero damage even with huge elemental base")
	check(damage_signals == 0, "control produces no damage event or damage attribution")
	for index in 4:
		var offset := enemies[index].global_position - POINT
		check(is_equal_approx(enemies[index]._knockback_velocity.dot(offset.normalized()), 450), "outward push at half speed from impact point, direction " + str(index))
	check(is_equal_approx(enemies[4]._knockback_velocity.length(), 450), "enemy exactly at center receives finite outward fallback")
	check(enemies[5]._knockback_timer == 0, "enemy outside radius remains unaffected")
	var particles := host.get_node("ParticleWorld")
	check(waves().is_empty() and particles._particle_order.size() > 0, "burst emits into shared particles and releases the impact node")
	var white := true
	var compact := true
	for slot in particles._particle_order:
		var color: Color = particles._particle_colors[slot]
		white = white and is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b) and color.r >= 0.83
		var distance: float = particles._particle_velocities[slot].length() * particles._particle_lifetimes[slot]
		compact = compact and distance >= 37.37 and distance <= 66.13
	check(white, "all shockwave particles use the white palette, without warm tint")
	check(compact, "original burst travel follows the restored 55.2-pixel radius")
	var positions: PackedVector2Array = particles._particle_positions.duplicate()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	particles._process(1)
	check(particles._particle_positions == positions, "pause freezes shockwave particles")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var start := enemies[0].global_position
	enemies[0]._physics_process(0.1)
	check(enemies[0].global_position.distance_to(POINT) > start.distance_to(POINT), "real enemy movement moves away from the impact")
	particles._process(0.77)
	check(particles._particle_order.is_empty(), "original burst particles expire within 0.76 seconds")

	await fixture(BOW, [POINT + Vector2(75, 0)], ["scroll_explosion"])
	weapon.runtime_stats.area_size = 200
	await cast()
	check(enemies[0]._knockback_timer == 0, "attack range does not expand shockwave")
	weapon.runtime_stats.damage_area_size = 100
	await cast()
	check(enemies[0]._knockback_timer == 0 and enemies[0].current_hp == 10000, "damage area does not expand pure control radius")

	await fixture(BOW, [POINT + Vector2(30, 0), POINT + Vector2(30, 400)], ["scroll_explosion"])
	await cast()
	enemies[1].apply_knockback(Vector2.RIGHT, 900, 0.3)
	var starts := [enemies[0].global_position, enemies[1].global_position]
	for enemy in enemies: enemy.collision_mask = 0
	for step in 18:
		for enemy in enemies: enemy._physics_process(1.0 / 60.0)
	var shortened := enemies[0].global_position.distance_to(starts[0])
	var original := enemies[1].global_position.distance_to(starts[1])
	check(original > 0 and absf(shortened * 2 - original) < 0.05, "actual unobstructed knockback travel is half the previous distance")
	print("SHOCKWAVE_TRAVEL original=", original, " shortened=", shortened)

	await fixture(BOW, [POINT], ["scroll_explosion"])
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	await cast()
	check(enemies[0]._knockback_timer == 0, "scheduled shockwave cannot apply during pause")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()
	check(enemies[0]._knockback_timer > 0, "scheduled shockwave resumes after pause")
	await fixture(BOW, [POINT], ["scroll_explosion"])
	CombatEffectWorld.trigger_ground_weapon_impact(host, weapon, weapon.calculate_damage_events()[0], POINT, Vector2.RIGHT)
	loadout.remove_weapon(BOW)
	await frames()
	check(enemies[0]._knockback_timer == 0 and waves().is_empty(), "selling weapon cancels scheduled shockwave before it can push")

	await fixture(BOW, [POINT + Vector2(30, 0)])
	var hit := DamageEvent.create({"damage": 100, "original_damage": 100, "source_weapon_id": weapon.weapon_id})
	ExplosionEffect.spawn(host, POINT, weapon, hit, "", 1.8, 72, "thunder_fire")
	await frames()
	check(enemies[0].current_hp == 9820, "fire-electric reaction retains its independent explosion damage")

	var data := DataRegistry.get_record("augmentations", "scroll_explosion")
	check(data.rarity == "common" and data.display_name == "震荡", "legacy scroll ID now displays shockwave at white rarity")
	check(data.modifiers.is_empty() and not data.effect_parameters.has("damage"), "scroll has no obsolete damage bonuses")
	for id in ["drop_basic_enemy", "drop_elite_enemy", "drop_boss_enemy"]:
		var table := DataRegistry.get_record("drop_tables", id)
		check((table.augmentation_rarity_weights.get("common", 0) > 0) == (id != "drop_boss_enemy") and table.entries.any(func(entry): return entry.get("item_id", "") == "scroll_explosion"), "white shockwave uses ordinary/elite pools; boss pool starts at green: " + id)
	var validator := DataValidator.new()
	check(validator.validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full data validation")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("SHOCKWAVE_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
