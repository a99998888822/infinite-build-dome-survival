extends "res://scripts/tests/pixel_combat_effect_test.gd"

var player: PlayerController


func fixture(id: String, points: Array) -> void:
	await setup(points)
	player = load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	weapon = WeaponInstance.new()
	weapon.initialize(id, player)
	weapon.runtime_stats.crit_chance = 0
	await frames()


func domain() -> RitualDomain:
	var runtime := RitualDomain.new()
	host.add_child(runtime)
	runtime.initialize(weapon, true)
	runtime.set_physics_process(false)
	return runtime


func _run() -> void:
	CampProgression.begin_transient_session()
	await fixture("weapon_iron_grenade_cannon", [])
	check(AttackFootprint.player_clearance(weapon) > 33, "indicator leaves the real capsule plus padding clear")
	for count in [1, 3, 8]:
		weapon.runtime_stats.projectile_count = count
		var valid := true
		var stable := true
		for i in 24:
			var pointer := Vector2.from_angle(TAU * i / 24.0) * 5000
			var landings := AttackFootprint.grenade_landings(weapon, pointer)
			var farther := AttackFootprint.grenade_landings(weapon, pointer * 10)
			for index in landings.size():
				stable = stable and landings[index].distance_to(farther[index]) < 0.001
			valid = valid and landings.size() == count
			for center in landings:
				for j in 96:
					var edge := center + Vector2.from_angle(TAU * j / 96.0) * AttackFootprint.grenade_blast_axes(weapon)
					valid = valid and (edge / AttackFootprint.grenade_range_axes(weapon)).length_squared() < 1.00001
		check(valid, "entire landing ellipse contained at all bearings, projectile count %d" % count)
		check(stable, "multi-grenade spread stays stable when cursor moves farther beyond range")
		if count > 1:
			var edge := AttackFootprint.grenade_landings(weapon, Vector2(5000, 0))
			check(edge[0].distance_to(edge[-1]) > 40, "out-of-range grenade volley retains visibly separate landing centers")
	weapon.runtime_stats.projectile_count = 1
	check(AttackFootprint.grenade_landings(weapon, Vector2(500, 0))[0].is_equal_approx(AttackFootprint.grenade_landings(weapon, Vector2(5000, 0))[0]), "pointer beyond range keeps maximum landing stable")
	await fixture("weapon_iron_grenade_cannon", [Vector2(50, 0), Vector2(0, 50), Vector2(0, 30)])
	var grenade := GrenadeProjectile.new()
	host.add_child(grenade)
	grenade.initialize(weapon, weapon.calculate_damage_events()[0], Vector2(-80, 0), Vector2.ZERO)
	grenade.elliptical_blast = true
	grenade.set_physics_process(false)
	grenade._detonate()
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000 and enemies[2].current_hp < 10000, "real grenade damage uses the landing ellipse")
	await fixture("weapon_copper_lamp", [Vector2(16, 0) + Vector2.from_angle(deg_to_rad(29)) * 80, Vector2(16, 0) + Vector2.from_angle(deg_to_rad(31)) * 80, Vector2(145, 0), Vector2(-10, 0)])
	check(is_equal_approx(weapon.get_lamp_cone_degrees(), 60), "base lamp cone is 60 degrees")
	var lamp := CopperLamp.new()
	host.add_child(lamp)
	lamp.initialize(weapon)
	lamp.set_physics_process(false)
	lamp.manual_control = true
	lamp.manual_direction = Vector2.RIGHT
	lamp.externally_driven = true
	lamp.burst_active = true
	lamp._physics_process(0.01)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000 and enemies[2].current_hp == 10000 and enemies[3].current_hp == 10000, "real lamp hits inside 30 degrees and rejects outside, range and rear")
	lamp.manual_direction = Vector2.UP
	lamp._physics_process(0.01)
	check(lamp.heading == Vector2.UP, "manual flame turns with movement")
	check(lamp.flame_visuals.size() == 1 and is_equal_approx(lamp.flame_visuals[0].rotation, -PI / 2), "continuous flame visual follows the real spray heading")
	lamp.manual_direction = Vector2.ZERO
	lamp._physics_process(0.01)
	check(lamp.heading == Vector2.UP, "stationary flame keeps last movement direction")
	await fixture("weapon_meteor_flail", [Vector2(40, 0), Vector2.from_angle(deg_to_rad(64)) * 90, Vector2.from_angle(deg_to_rad(67)) * 90, Vector2(150, 0), Vector2(-30, 0)])
	var flail := MeteorFlail.new()
	host.add_child(flail)
	flail.initialize(weapon, Vector2.RIGHT)
	flail.set_physics_process(false)
	flail._physics_process(0.12)
	check(enemies.all(func(enemy): return enemy.current_hp == 10000), "fan windup deals no damage")
	flail._physics_process(0.60)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp < 10000, "real flail sweeps the inner fan and angular edge")
	check(enemies[2].current_hp == 10000 and enemies[3].current_hp == 10000 and enemies[4].current_hp == 10000, "real flail excludes outside angle, radius and rear")
	await fixture("weapon_kunyu_ritual_tome", [Vector2(500, 0)])
	weapon.runtime_stats.projectile_count = 3
	var ritual := domain()
	check(ritual.marks_remaining == 5 and ritual.is_attacking(), "tome budget equals 3 plus extra projectile count")
	ritual._physics_process(30)
	check(ritual.marks_remaining == 5 and ritual.marks_completed == 0 and not ritual.cancelled, "empty ring persists without spending marks or finishing")
	player.global_position = Vector2(300, 300)
	ritual._physics_process(0.1)
	check(ritual.global_position == Vector2.ZERO, "active ring remains at cast location")
	enemies[0].global_position = Vector2(60, 0)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	ritual._physics_process(5)
	check(ritual.marks_completed == 0, "pause freezes waiting ritual and attacks")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	ritual._physics_process(0.11)
	check(ritual.marks_completed == 1 and ritual.marks_remaining == 4 and enemies[0].current_hp < 10000, "enemy entering fixed ring gets the first sequential mark")
	enemies[0].global_position = Vector2(500, 0)
	ritual._physics_process(8)
	check(ritual.marks_completed == 1 and ritual.is_attacking(), "enemy leaving makes ring wait with remaining budget")
	enemies[0].global_position = Vector2(60, 0)
	for i in 4:
		ritual._physics_process(RitualDomain.MARK_INTERVAL)
	check(ritual.marks_completed == 5 and ritual.marks_remaining == 0, "same surviving enemy can receive all remaining sequential marks")
	check(ritual.is_attacking(), "last mark recovery completes before cooldown can start")
	ritual._physics_process(0.31)
	check(ritual.cancelled and not ritual.is_attacking(), "completed ritual expires and releases the cooldown gate")
	await fixture("weapon_kunyu_ritual_tome", [Vector2(60, 0)])
	weapon.runtime_stats.projectile_count = 5
	ritual = domain()
	ritual._physics_process(0.22)
	check(ritual.marks_completed == 1, "tome first mark keeps its original opening delay")
	ritual._physics_process(0.34)
	check(ritual.marks_completed == 1, "tome marks cannot fire before 350ms interval")
	ritual._physics_process(0.02)
	check(ritual.marks_completed == 2, "tome now repeats after 350ms")
	ritual._physics_process(1.76)
	check(ritual.marks_completed == 3 and ritual.is_attacking(), "long frame does not collapse several marks into one instant")
	for i in 4:
		ritual._physics_process(0.351)
	check(ritual.marks_completed == 7 and ritual.is_attacking(), "seven-mark budget completes at distinct 350ms intervals")
	ritual._physics_process(0.31)
	check(ritual.cancelled, "rapid tome finishes after last hit recovery")
	await fixture("weapon_kunyu_ritual_tome", [])
	ritual = domain()
	player.alive = false
	ritual._physics_process(0.1)
	check(ritual.cancelled, "death cancels an indefinitely waiting circle")
	await _check_remaining_multi()
	await _check_continuous_dagger()
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("ACTIVE_ATTACK_REVISION_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _check_remaining_multi() -> void:
	var first_tick_damage := -1
	for count in [1, 3, 5]:
		await fixture("weapon_copper_lamp", [Vector2(80, 0), Vector2(16, 0) + Vector2.from_angle(deg_to_rad(31)) * 80])
		weapon.runtime_stats.projectile_count = count
		var lamp := CopperLamp.new()
		host.add_child(lamp)
		lamp.initialize(weapon)
		lamp.set_physics_process(false)
		lamp.externally_driven = true
		lamp.manual_control = true
		lamp.burst_active = true
		lamp._physics_process(0.01)
		var damage := 10000 - enemies[0].current_hp
		if first_tick_damage < 0:
			first_tick_damage = damage
		check(damage == first_tick_damage and damage > 0, "extra lamp projectiles never multiply damage per tick")
		check(lamp.beams.size() == 1 and lamp.beams[0].direction == Vector2.RIGHT and enemies[1].current_hp == 10000, "extra lamp projectiles keep one native 60-degree cone")
		check(lamp.flame_visuals.size() == 1 and lamp.flame_visuals[0].visible, "one reused flame visual per native beam")
		check(is_equal_approx(lamp.burst_duration, count * 1.8), "lamp duration is base duration times projectile count")
		weapon.runtime_stats.projectile_count = 9
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		lamp._physics_process(10)
		check(is_equal_approx(lamp.heat, 0.01 / (count * 1.8)), "pause freezes the extended spray")
		GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		lamp._physics_process(count * 1.8 - 0.02)
		check(lamp.burst_active and lamp.cooling == 0 and is_equal_approx(lamp.burst_duration, count * 1.8), "spray uses its cast snapshot and remains active until its last 10ms")
		lamp._physics_process(0.02)
		check(not lamp.burst_active and not lamp.firing and lamp.cooling > 0, "extended spray finishes before cooldown starts")
		check(not lamp.flame_visuals[0].visible, "flame visual disappears as soon as spray ends")
	for count in [1, 3, 5]:
		await fixture("weapon_meteor_flail", [Vector2(60, 0)])
		weapon.runtime_stats.projectile_count = count
		var flail := MeteorFlail.new()
		host.add_child(flail)
		flail.initialize(weapon, Vector2.RIGHT)
		flail.set_physics_process(false)
		check(is_equal_approx(flail.sequence_duration(), 0.60 * count), "flail adds complete 600ms swings")
		for index in count:
			check(is_equal_approx(flail.swings[index].start, index * 0.60), "flail swings do not overlap")
			flail._physics_process(0.60 * flail.time_scale)
			check(enemies[0].current_hp == 10000 - int(weapon.get_base_attack_damage()) * (index + 1), "each complete swing hits the same living target exactly once")
			if index < count - 1:
				check(flail.is_swinging(), "queued full swings keep the attack active")
		flail._physics_process(0.001)
		check(not flail.is_swinging(), "last full recovery releases the attack gate")


func _check_continuous_dagger() -> void:
	for count in [1, 3, 5]:
		await fixture("weapon_camp_dagger", [Vector2(60, 0)])
		weapon.runtime_stats.projectile_count = count
		var dagger := CampDagger.new()
		host.add_child(dagger)
		dagger.initialize(weapon, Vector2.RIGHT)
		dagger.configure_continuous_combo()
		dagger.set_physics_process(false)
		check(is_equal_approx(dagger.cut_end(dagger.cuts[-1]) * dagger.time_scale, 0.175 + count * 0.125), "continuous dagger retains 125ms sweeps with only one opening and recovery")
		_check_dagger_seams(dagger)
		for tick in 120:
			if dagger.cancelled:
				break
			dagger._physics_process(0.01)
		check(dagger.cancelled and enemies[0].current_hp == 10000 - count * int(weapon.get_base_attack_damage()), "continuous dagger completes exactly N real hits on one living target")
	await fixture("weapon_camp_dagger", [Vector2(60, 0)])
	weapon.runtime_stats.projectile_count = 3
	var item := player.item_inventory.add_item_from_base("scroll_split", "continuous_dagger")
	check(weapon.attach_item_instance(item), "attach real split to continuous dagger")
	var dagger := CampDagger.new()
	host.add_child(dagger)
	dagger.initialize(weapon, Vector2.RIGHT)
	dagger.configure_continuous_combo()
	dagger.set_physics_process(false)
	var contacts: Array[bool] = []
	dagger.target_hit.connect(func(_id: int, _damage: int, child: bool): contacts.append(child))
	dagger._physics_process(0.20)
	check(dagger.cuts.size() == 5, "first real hit queues two split cuts after three main cuts")
	_check_dagger_seams(dagger)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var age_before := dagger.age
	dagger._physics_process(1.0)
	check(dagger.age == age_before, "pause freezes a continuous combo with queued split cuts")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	dagger._physics_process(1.0)
	check(dagger.cancelled and contacts.count(false) == 3 and contacts.count(true) == 2, "long frame processes every continuous main and split cut exactly once")


func _check_dagger_seams(dagger: CampDagger) -> void:
	for i in range(1, dagger.cuts.size()):
		var previous := dagger.cuts[i - 1]
		var current := dagger.cuts[i]
		var boundary := dagger.cut_end(previous)
		check(is_zero_approx(previous.recover) and is_zero_approx(current.windup) and is_equal_approx(boundary, current.start), "no recovery or new windup between dagger cuts")
		check(dagger.blade_direction(previous, boundary).is_equal_approx(dagger.blade_direction(current, current.start)), "next reverse slash starts exactly at the previous blade endpoint")
		check(dagger.cut_opacity(previous, boundary) == 1.0 and dagger.cut_opacity(current, current.start) == 1.0, "blade never fades out at intermediate dagger boundaries")
