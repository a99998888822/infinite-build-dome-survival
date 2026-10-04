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
		for i in 24:
			var pointer := Vector2.from_angle(TAU * i / 24.0) * 5000
			var landings := AttackFootprint.grenade_landings(weapon, pointer)
			valid = valid and landings.size() == count
			for center in landings:
				for j in 96:
					var edge := center + Vector2.from_angle(TAU * j / 96.0) * AttackFootprint.grenade_blast_axes(weapon)
					valid = valid and (edge / AttackFootprint.grenade_range_axes(weapon)).length_squared() < 1.00001
		check(valid, "entire landing ellipse contained at all bearings, projectile count %d" % count)
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
	lamp.resonance_controlled = true
	lamp.burst_active = true
	lamp._physics_process(0.01)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000 and enemies[2].current_hp == 10000 and enemies[3].current_hp == 10000, "real lamp hits inside 30 degrees and rejects outside, range and rear")
	lamp.manual_direction = Vector2.UP
	lamp._physics_process(0.01)
	check(lamp.heading == Vector2.UP, "manual flame turns with movement")
	lamp.manual_direction = Vector2.ZERO
	lamp._physics_process(0.01)
	check(lamp.heading == Vector2.UP, "stationary flame keeps last movement direction")
	await fixture("weapon_meteor_flail", [Vector2(40, 0), Vector2.from_angle(deg_to_rad(64)) * 90, Vector2.from_angle(deg_to_rad(67)) * 90, Vector2(150, 0), Vector2(-30, 0)])
	var flail := MeteorFlail.new()
	host.add_child(flail)
	flail.initialize(weapon, Vector2.RIGHT)
	flail.set_physics_process(false)
	flail._physics_process(0.17)
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
		ritual._physics_process(0.8)
	check(ritual.marks_completed == 5 and ritual.marks_remaining == 0, "same surviving enemy can receive all remaining sequential marks")
	check(ritual.is_attacking(), "last mark recovery completes before cooldown can start")
	ritual._physics_process(0.31)
	check(ritual.cancelled and not ritual.is_attacking(), "completed ritual expires and releases the cooldown gate")
	await fixture("weapon_kunyu_ritual_tome", [])
	ritual = domain()
	player.alive = false
	ritual._physics_process(0.1)
	check(ritual.cancelled, "death cancels an indefinitely waiting circle")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("ACTIVE_ATTACK_REVISION_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
