extends "res://scripts/tests/pixel_combat_effect_test.gd"


func plasma_fixture(positions: Array) -> void:
	await setup(positions)
	weapon.weapon_id = "weapon_plasma_cannon"
	weapon.weapon_data = DataRegistry.get_record("weapons", weapon.weapon_id).duplicate(true)
	weapon.runtime_stats.crit_chance = 0.0
	event = DamageEvent.create({"damage":12, "original_damage":12, "source_weapon_id":weapon.weapon_id})


func shot() -> ProjectileInstance:
	var result := ProjectileInstance.new()
	host.add_child(result)
	result.initialize(weapon, event, "plasma_contact_test", Vector2.ZERO, Vector2.RIGHT, 460.0, null, 1.0)
	result.set_physics_process(false)
	return result


func enemy_radius(index: int = 0) -> float:
	return enemies[index].get_node("CollisionShape2D").shape.radius


func _run() -> void:
	await plasma_fixture([Vector2(80, 0), Vector2(30, 38), Vector2(-100, 0)])
	var ball := shot()
	await frames()
	check(weapon.get_hit_radius() == 12.0, "native plasma contact radius is twelve pixels")
	check(ball._hit_shape.radius == 12.0 and ball._plasma_visual.core_radius == 12.0,
		"native visible core and physical collider match")
	ball._process_plasma_contact(1.0)
	check(enemies.all(func(enemy): return enemy.current_hp == 10000) and ball._plasma_tick_count == 0,
		"old aura and ground discharge footprint deal no remote damage")
	check(ball.speed == 140.0, "distant enemies do not trigger contact slowdown")
	var boundary := 12.0 + enemy_radius()
	enemies[0].position = Vector2(boundary + 0.5, 0)
	await frames()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 10000, "half pixel outside visible contact stays unharmed")
	enemies[0].position = Vector2(boundary - 0.5, 0)
	await frames()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 9988 and ball._plasma_tick_count == 1 and ball.speed == 80.0,
		"visible edge contact starts one tick and slows the ball")
	ball._process_plasma_contact(0.04)
	check(enemies[0].current_hp == 9988, "no second tick before the contact interval")
	ball._process_plasma_contact(0.061)
	check(enemies[0].current_hp == 9976, "continued contact deals the next tick after 0.1 seconds")
	enemies[0].position = Vector2(80, 0)
	await frames()
	ball._process_plasma_contact(1.0)
	check(enemies[0].current_hp == 9976 and ball._plasma_tick_count == 2 and ball.speed == 140.0,
		"leaving contact stops ticks and restores flight speed")
	enemies[0].position = Vector2.ONE.normalized() * (boundary + 0.5)
	await frames()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 9976, "diagonal outside contact is not a bounding-box hit")
	enemies[0].position = Vector2.ONE.normalized() * (boundary - 0.5)
	await frames()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 9964 and ball._plasma_tick_count == 3, "diagonal recontact resumes the remaining ticks")
	ball._process_plasma_contact(0.101)
	ball._process_plasma_contact(0.101)
	check(enemies[0].current_hp == 9940 and not ball.active and ball._plasma_tick_count == 5,
		"five total contact ticks retain the original damage and lifetime limit")
	ball._process_plasma_tick([enemies[0]])
	check(enemies[0].current_hp == 9940, "expired ball cannot add a sixth tick")

	await plasma_fixture([Vector2(24, 0), Vector2(-24, 0), Vector2(80, 0)])
	ball = shot()
	await frames()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 9988 and enemies[1].current_hp == 9988 and enemies[2].current_hp == 10000,
		"a batch hits every touching enemy and excludes nearby noncontacts")

	await plasma_fixture([Vector2(100, 0)])
	ball = shot()
	await frames()
	weapon.runtime_stats.damage_area_size = 100.0
	ball._physics_process(0.0)
	check(weapon.get_hit_radius() == 24.0 and ball._hit_shape.radius == 24.0 and ball._plasma_visual.core_radius == 24.0,
		"live damage-area growth updates visible core and collision together")
	weapon.runtime_stats.area_size = 200.0
	ball._physics_process(0.0)
	check(ball._hit_shape.radius == 24.0 and ball._plasma_visual.core_radius == 24.0 and weapon.get_attack_range() == 1380.0,
		"attack range expands travel without secretly expanding contact")
	enemies[0].position = Vector2(24.0 + enemy_radius() - 0.5, 0)
	await frames()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 9988, "expanded visible edge deals contact damage")
	weapon.runtime_stats.damage_area_size = -100.0
	ball._physics_process(0.0)
	check(ball._hit_shape.radius == 4.0 and ball._plasma_visual.core_radius == 4.0,
		"minimum-radius clamp is shared instead of keeping a larger invisible collider")
	ball.free()
	enemies[0].position = Vector2(4.0 + enemy_radius() + 0.5, 0)
	await frames()
	ball = shot()
	ball._process_plasma_contact(0.0)
	check(enemies[0].current_hp == 9988, "minimum-radius edge still rejects noncontact")

	await plasma_fixture([Vector2(80, 0)])
	ball = shot()
	await frames()
	var first_gap := INF
	for step in 50:
		var before := ball.global_position
		ball._physics_process(1.0 / 60.0)
		if ball._plasma_tick_count > 0:
			first_gap = before.distance_to(enemies[0].global_position) - 12.0 - enemy_radius()
			break
	check(is_finite(first_gap) and first_gap <= 0.0 and first_gap > -3.0,
		"real moving projectile starts damage only after the visible surfaces touch")
	var hp := enemies[0].current_hp
	var clock: float = ball._plasma_visual.elapsed
	var position_before := ball.position
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	ball._physics_process(1.0)
	check(enemies[0].current_hp == hp and ball.position == position_before and ball._plasma_visual.elapsed == clock,
		"pause freezes contact damage, movement and visual clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	check(weapon.build_full_stats_text().contains("命中半径[/color] [color=#FFFFFF]12[/color]"), "item details read the shared twelve-pixel contact radius")
	await check_enchantment_damage()
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.1).timeout
	print("PLASMA_CONTACT_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func check_enchantment_damage() -> void:
	# Use different direct/original damage and a player elemental bonus to catch
	# effects that accidentally bypass the plasma-specific scale.
	await plasma_fixture([Vector2.ZERO, Vector2(60, 0)])
	event = DamageEvent.create({"damage": 100, "original_damage": 80, "element_damage_bonus": 45,
		"source_weapon_id": weapon.weapon_id})
	weapon._attached_item_instances = [{"effect_ids": ["explosion"]}]
	var ball := shot()
	ball._process_plasma_contact(0.0)
	await frames()
	check(enemies[0].current_hp == 9880 and enemies[1].current_hp == 9980,
		"plasma keeps full direct damage but explosion scales original plus elemental bonus to twenty percent")
	for tick in 4:
		ball._process_plasma_contact(0.101)
		await frames()
	check(enemies[0].current_hp == 9400 and enemies[1].current_hp == 9900,
		"five delayed explosions retain their scale even after the plasma ball expires")
	check(event.damage == 100 and event.get_elemental_base_damage() == 125.0,
		"plasma enchantment scaling does not mutate the source or later direct ticks")

	await plasma_fixture([Vector2.ZERO])
	event = DamageEvent.create({"damage": 100, "original_damage": 80, "element_damage_bonus": 45,
		"source_weapon_id": weapon.weapon_id})
	weapon._attached_item_instances = [{"effect_ids": ["lightning"]}]
	ball = shot()
	ball._process_plasma_contact(0.0)
	await frames()
	check(enemies[0].current_hp == 9886, "lightning also receives the scaled base rather than full original damage")

	var small := DamageEvent.create({"damage": 12, "original_damage": 12, "element_damage_bonus": 2,
		"elemental_damage_scale": 0.2})
	var delayed := small.duplicate_event()
	check(is_equal_approx(delayed.get_elemental_base_damage(), 2.8) and delayed.get_elemental_damage(0.55) == 2,
		"small elemental components combine before scaling and final rounding; event copies preserve the scale")
	var ordinary := DamageEvent.create({"damage": 12, "element_damage_bonus": 2})
	check(ordinary.get_elemental_base_damage() == 14.0 and ordinary.get_elemental_damage(0.55) == 8,
		"ordinary weapon elemental damage retains its original scale")
