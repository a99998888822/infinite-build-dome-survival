extends "res://scripts/tests/pixel_combat_effect_test.gd"

const BOW := "weapon_void_blade"
const PLASMA := "weapon_plasma_cannon"
const LOADS := {
	BOW: 20,
	"weapon_rentier_purse": 22,
	"weapon_kunyu_ritual_tome": 28,
	PLASMA: 25,
	"weapon_iron_grenade_cannon": 32,
}


func shop_context(loadout: WeaponLoadout) -> Dictionary:
	var owned: Array[String] = []
	var equipped: Array[Dictionary] = []
	for current in loadout.get_weapon_instances():
		owned.append(current.weapon_id)
		equipped.append({"weapon_id": current.weapon_id, "level": current.level})
	return {"load_capacity": loadout.get_load_capacity(), "current_load": loadout.get_total_load_cost(),
		"owned_weapon_ids": owned, "equipped_weapons": equipped, "luck": 350}


func _run() -> void:
	await setup([])
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	var loadout := WeaponLoadout.new()
	host.add_child(loadout)
	check(loadout.initialize(player) and loadout.get_load_capacity() == 100, "normal character starts with capacity one hundred")
	var generator := ShopOfferGenerator.new()
	for weapon_id in LOADS:
		if weapon_id == "weapon_iron_grenade_cannon":
			check(loadout.get_total_load_cost() == 95 and not loadout.try_buy_weapon(weapon_id),
				"four weapons leave five load and reject the fifth at standard capacity")
			player.add_runtime_modifier({"id": "balance_extra_capacity", "source_type": "test", "source_id": "balance_extra_capacity",
				"target_scope": "player", "stat": "load_capacity", "operation": "add_flat", "value": 27,
				"duration": -1, "stack_rule": "unique"})
		var offers := generator.build_shop_candidate_pool(shop_context(loadout))
		var match_offer := offers.filter(func(offer): return offer.target_id == weapon_id and offer.offer_type == "new_weapon")
		check(match_offer.size() == 1 and match_offer[0].load_cost == LOADS[weapon_id], "shop advertises current load for " + weapon_id)
		check(loadout.try_buy_weapon(weapon_id), "distinct weapon fits available capacity: " + weapon_id)
	check(loadout.get_total_load_cost() == 127 and loadout.get_weapon_instances().size() == 5,
		"five weapons exactly fill the expanded capacity")
	check(not loadout.try_buy_weapon(BOW) and loadout.get_total_load_cost() == 127, "duplicate purchase still rejected without altering load")

	var bow := loadout.get_weapon_instance(BOW)
	var plasma := loadout.get_weapon_instance(PLASMA)
	bow.runtime_stats.crit_chance = 0
	plasma.runtime_stats.crit_chance = 0
	for next_level in range(2, 6):
		var offers := generator.build_shop_candidate_pool(shop_context(loadout))
		for current in loadout.get_weapon_instances():
			var upgrades := offers.filter(func(offer): return offer.target_id == current.weapon_id and offer.offer_type == "weapon_upgrade")
			check(upgrades.size() == 1 and upgrades[0].to_level == next_level,
				"shop offers exactly the next upgrade for %s level %d" % [current.weapon_id, next_level])
			check(loadout.upgrade_weapon(current.weapon_id), "upgrade applies for %s level %d" % [current.weapon_id, next_level])
		check(bow.get_base_attack_damage() == [12, 17, 22, 27][next_level - 2]
			and is_equal_approx(bow.get_active_cooldown_seconds(), [2.0, 1.9, 1.8, 1.7][next_level - 2])
			and bow.get_stat("projectile_count") == (3 if next_level == 5 else 2),
			"bow upgrades alternate projectile and damage/cooldown gains: %d" % next_level)
		check(plasma.calculate_damage_events()[0].damage == [14, 16, 18, 21][next_level - 2]
			and is_equal_approx(plasma.get_active_cooldown_seconds(), 3.0 - 0.1 * (next_level - 1)) and plasma.get_hit_radius() == 12.0,
			"plasma gains damage and fixed cooldown reduction while preserving contact size: %d" % next_level)
		check(loadout.get_total_load_cost() == 127, "upgrades never increase equipped load")
	check(bow.get_base_attack_damage() == 27 and is_equal_approx(bow.get_active_cooldown_seconds(), 1.7), "max-level bow has three fixed cooldown reductions")
	var final_offers := generator.build_shop_candidate_pool(shop_context(loadout))
	check(not final_offers.any(func(offer): return offer.offer_type in ["new_weapon", "weapon_upgrade"]),
		"all-owned max-level loadout offers no duplicate weapons or sixth-level upgrades")
	check(not loadout.upgrade_weapon(PLASMA), "plasma stops at its configured maximum level")

	loadout.remove_weapon("weapon_iron_grenade_cannon")
	player.add_runtime_modifier({"id": "balance_capacity", "source_type": "test", "source_id": "balance_capacity",
		"target_scope": "player", "stat": "load_capacity", "operation": "add_flat", "value": -1,
		"duration": -1, "stack_rule": "unique"})
	var tight_offers := generator.build_shop_candidate_pool(shop_context(loadout))
	check(not tight_offers.any(func(offer): return offer.target_id == "weapon_iron_grenade_cannon")
		and not loadout.try_buy_weapon("weapon_iron_grenade_cannon") and loadout.get_total_load_cost() == 95,
		"shop and purchase both reject grenade when only thirty-one load remains")
	player.remove_runtime_modifiers_by_source("test", "balance_capacity")
	check(loadout.try_buy_weapon("weapon_iron_grenade_cannon"), "grenade is purchasable again after restoring capacity")
	await check_attack_ranges(loadout, player)
	host.queue_free()
	await frames()
	print("WEAPON_BALANCE_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func check_attack_ranges(loadout: WeaponLoadout, player: PlayerController) -> void:
	var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
	enemy.auto_initialize_on_ready = false
	host.add_child(enemy)
	enemy.initialize("enemy_mutated_grub", player)
	enemy.set_physics_process(false)
	for id in [BOW, PLASMA, "weapon_iron_grenade_cannon"]:
		var current := loadout.get_weapon_instance(id)
		# This fixture isolates reach; upgraded volley counts have their own suite.
		var original_count := int(current.runtime_stats.projectile_count)
		current.runtime_stats.projectile_count = 1
		var reach := current.get_attack_range()
		enemy.position = Vector2(reach + 1, 0)
		current.attack_timer = 0
		await frames()
		check(not loadout._try_attack_with_weapon(current) and current.attack_timer == 0,
			id + " does not acquire beyond the new range or spend cooldown")
		enemy.position = Vector2(reach - 1, 0)
		await frames()
		check(loadout._try_attack_with_weapon(current), id + " still attacks just inside range")
		if current.is_grenade():
			var grenades := host.get_children().filter(func(node): return node is GrenadeProjectile)
			check(grenades.size() == 1 and grenades[0].target_position.distance_to(player.global_position) < reach,
				"grenade landing stays inside its throw range")
		else:
			var shots := host.get_children().filter(func(node): return node is ProjectileInstance and node.weapon == current)
			check(shots.size() == 1 and is_equal_approx(shots[0].remaining_distance, reach),
				id + " projectile receives the same distance as targeting")
			if not shots.is_empty():
				var shot := shots[0] as ProjectileInstance
				shot.set_physics_process(false)
				shot._physics_process(10.0)
				check(not shot.active and is_equal_approx(shot.global_position.distance_to(player.global_position), reach),
					id + " expires at exact range even during a long frame")
		enemy.position = Vector2(reach * 1.25, 0)
		await frames()
		check(not loadout._try_attack_with_weapon(current), id + " cannot use the old longer targeting radius")
		current.runtime_stats.area_size = 50
		check(loadout._try_attack_with_weapon(current), id + " earned range bonuses still extend targeting")
		current.runtime_stats.area_size = 0
		current.runtime_stats.projectile_count = original_count
