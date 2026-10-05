extends "res://scripts/tests/active_attack_revision_test.gd"

# Expected live damage, seconds, count, area bonus and reach bonus by level.
const PROGRESSION := {
	"weapon_void_blade": [[12,2.0,1,0,0],[12,2.0,2,0,0],[17,1.9,2,0,0],[22,1.8,2,0,0],[27,1.7,3,0,0]],
	"weapon_plasma_cannon": [[12,3.0,1,0,0],[14,2.9,1,0,0],[16,2.8,1,0,0],[18,2.7,1,0,0],[21,2.6,2,0,0]],
	"weapon_iron_grenade_cannon": [[36,4.0,1,0,0],[41,3.9,1,0,0],[46,3.8,1,0,0],[51,3.7,1,0,0],[51,3.6,2,10,0]],
	"weapon_kunyu_ritual_tome": [[16,3.5,1,0,0],[19,3.4,1,0,0],[22,3.3,1,0,0],[25,3.2,2,0,0],[28,3.1,3,0,0]],
	"weapon_rentier_purse": [[12,2.8,3,0,0],[12,2.8,4,0,0],[17,2.7,4,0,0],[22,2.6,4,0,0],[27,2.5,5,0,0]],
	"weapon_copper_lamp": [[4,3.2,1,0,0],[5,3.1,1,0,0],[6,3.0,1,0,0],[7,2.9,1,0,0],[9,2.8,1,20,0]],
	"weapon_mutant_tentacle": [[40,3.5,1,0,0],[43,3.4,1,5,0],[46,3.3,1,10,0],[49,3.2,1,15,0],[54,3.1,2,20,0]],
	"weapon_earth_hammer": [[30,4.0,1,0,0],[35,3.9,1,0,0],[40,3.8,1,0,0],[45,3.7,1,0,0],[50,3.6,2,0,0]],
	"weapon_camp_dagger": [[16,1.8,1,0,0],[16,1.8,2,0,0],[18,1.7,2,0,0],[20,1.6,2,0,0],[25,1.5,3,0,0]],
	"weapon_nightwatch_spear": [[26,3.2,1,0,0],[29,3.1,1,0,5],[32,3.0,1,0,10],[35,2.9,1,0,15],[40,2.8,2,0,20]],
	"weapon_meteor_flail": [[36,3.8,1,0,0],[41,3.7,1,0,0],[46,3.6,1,0,0],[51,3.5,1,0,0],[56,3.4,2,0,0]],
}

func _run() -> void:
	CampProgression.begin_transient_session()
	check(DataRegistry.get_load_errors().is_empty(), "upgraded configs validate")
	for id in PROGRESSION:
		await fixture(id, [])
		weapon.use_active_range_rules = true
		var load_cost := weapon.get_load_cost()
		for index in 5:
			if index > 0:
				var snapshot := weapon.make_cast_copy()
				var previous_cd := snapshot.get_active_cooldown_seconds()
				var previous_damage := snapshot.get_base_attack_damage()
				var previous_count := snapshot.get_stat("projectile_count")
				check(weapon.upgrade(), id + " upgrades to " + str(index + 1))
				check(snapshot.level == index and snapshot.get_active_cooldown_seconds() == previous_cd
					and snapshot.get_base_attack_damage() == previous_damage and snapshot.get_stat("projectile_count") == previous_count,
					"in-flight snapshot survives upgrade " + id)
			_check_stats(weapon, PROGRESSION[id][index], id + " level " + str(index + 1))
			check(weapon.get_load_cost() == load_cost, "upgrade keeps load " + id)
			if index < 4:
				_check_shop_text(id, index + 1)
		check(not weapon.upgrade() and weapon.level == 5, "level cap " + id)
		_check_runtime()
		var plain_cd := weapon.get_active_cooldown_seconds()
		weapon.runtime_stats.attack_speed = 100
		check(is_equal_approx(weapon.get_active_cooldown_seconds(), plain_cd / 2.0), "haste scales the reduced cooldown " + id)
		var cast := weapon.make_cast_copy()
		var replay := cast.make_bounce_copy(Vector2(100, 0))
		check(is_equal_approx(cast.get_active_cooldown_seconds(), plain_cd / 2.0)
			and replay.get_active_cooldown_seconds() == cast.get_active_cooldown_seconds(), "cast and bounce keep upgraded cooldown " + id)
		weapon.initialize(id, player)
		_check_stats(weapon, PROGRESSION[id][0], "reinitialize resets upgrades " + id)
		host.queue_free()
		await frames()
	CampProgression.end_transient_session()
	print("WEAPON_UPGRADE_PROGRESSION checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func _check_stats(source: WeaponInstance, expected: Array, label: String) -> void:
	check(source.get_base_attack_damage() == expected[0]
		and is_equal_approx(source.get_active_cooldown_seconds(), float(expected[1]))
		and source.get_stat("projectile_count") == expected[2]
		and source.get_stat("damage_area_size") == expected[3]
		and source.get_stat("area_size") == expected[4], label)

func _check_shop_text(id: String, current_level: int) -> void:
	var offers := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity": 1000, "current_load": 0,
		"owned_weapon_ids": [id], "equipped_weapons": [{"weapon_id": id, "level": current_level}], "luck": 350})
	var upgrades := offers.filter(func(offer): return offer.offer_type == "weapon_upgrade" and offer.target_id == id)
	check(upgrades.size() == 1, "shop has next upgrade " + id)
	if upgrades.is_empty(): return
	var description := str(upgrades[0].description)
	check(not description.contains("（") and not description.contains("(") and not description.contains("projectile_count"), "shop hides implementation explanation " + id)
	if id in ["weapon_kunyu_ritual_tome", "weapon_camp_dagger", "weapon_meteor_flail"]:
		check(not description.contains("额外投射物"), "count-based weapon uses action label " + id)

func _check_runtime() -> void:
	if weapon.is_ritual_tome():
		var ritual := domain()
		check(ritual.marks_remaining == 5, "upgraded tome schedules five real marks")
	elif weapon.is_camp_dagger():
		var dagger := CampDagger.new()
		host.add_child(dagger)
		dagger.initialize(weapon, Vector2.RIGHT)
		dagger.configure_continuous_combo()
		dagger.set_physics_process(false)
		check(dagger.cuts.size() == 3 and is_equal_approx(dagger.cut_end(dagger.cuts[-1]) * dagger.time_scale, 0.55), "upgraded dagger schedules three continuous cuts")
	elif weapon.is_meteor_flail():
		var flail := MeteorFlail.new()
		host.add_child(flail)
		flail.initialize(weapon, Vector2.RIGHT)
		flail.set_physics_process(false)
		check(flail.swings.size() == 2 and is_equal_approx(flail.sequence_duration(), 1.2), "upgraded flail schedules two complete swings")
	elif weapon.is_mutant_tentacle():
		var tentacle := MutantTentacle.new()
		host.add_child(tentacle)
		tentacle.initialize(weapon)
		tentacle.set_physics_process(false)
		tentacle.try_attack(Vector2.RIGHT)
		check(tentacle.directions.size() == 2 and is_equal_approx(weapon.get_hit_radius(), 24), "upgraded tentacle has two wider contacts")
	elif weapon.is_earth_hammer():
		var hammer := EarthHammer.new()
		host.add_child(hammer)
		hammer.initialize(weapon, Vector2.RIGHT)
		hammer.set_physics_process(false)
		check(hammer.rays.size() == 2 and hammer.node_count == 5, "upgraded hammer has two five-node rays")
	elif weapon.is_nightwatch_spear():
		var spear := NightwatchSpear.new()
		host.add_child(spear)
		spear.initialize(weapon, Vector2.RIGHT)
		spear.set_physics_process(false)
		check(spear.thrusts.size() == 2 and is_equal_approx(weapon.get_attack_range(), 264), "upgraded spear has two longer thrusts")
	elif weapon.is_grenade():
		check(is_equal_approx(weapon.get_grenade_blast_radius(), 70.4)
			and AttackFootprint.grenade_landings(weapon, Vector2(100, 0)).size() == 2, "grenade gains percent blast area and a second landing")
	elif weapon.is_copper_lamp():
		check(is_equal_approx(weapon.get_attack_range(), 144) and is_equal_approx(weapon.get_lamp_spray_seconds(), 1.8), "lamp area extends its cone without adding duration")
	else:
		check(weapon.get_projectile_angles().size() == int(PROGRESSION[weapon.weapon_id][4][2]), "upgraded ranged volley count " + weapon.weapon_id)
