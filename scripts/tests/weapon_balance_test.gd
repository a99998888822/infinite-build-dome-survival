extends "res://scripts/tests/pixel_combat_effect_test.gd"

const BOW := "weapon_void_blade"
const PLASMA := "weapon_plasma_cannon"
const LOADS := {
	BOW: 12,
	"weapon_rentier_purse": 14,
	"weapon_kunyu_ritual_tome": 18,
	PLASMA: 24,
	"weapon_iron_grenade_cannon": 25,
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
		var offers := generator.build_shop_candidate_pool(shop_context(loadout))
		var match_offer := offers.filter(func(offer): return offer.target_id == weapon_id and offer.offer_type == "new_weapon")
		check(match_offer.size() == 1 and match_offer[0].load_cost == LOADS[weapon_id], "shop advertises current load for " + weapon_id)
		check(loadout.try_buy_weapon(weapon_id), "all five distinct weapons fit through purchase validation: " + weapon_id)
	check(loadout.get_total_load_cost() == 93 and loadout.get_weapon_instances().size() == 5,
		"five weapons consume ninety-three load with seven remaining")
	check(not loadout.try_buy_weapon(BOW) and loadout.get_total_load_cost() == 93, "duplicate purchase still rejected without altering load")

	var bow := loadout.get_weapon_instance(BOW)
	var plasma := loadout.get_weapon_instance(PLASMA)
	bow.runtime_stats.crit_chance = 0
	plasma.runtime_stats.crit_chance = 0
	var bow_dps := bow.get_base_attack_damage() / bow.get_actual_attack_interval_seconds()
	for next_level in range(2, 6):
		var offers := generator.build_shop_candidate_pool(shop_context(loadout))
		for current in loadout.get_weapon_instances():
			var upgrades := offers.filter(func(offer): return offer.target_id == current.weapon_id and offer.offer_type == "weapon_upgrade")
			check(upgrades.size() == 1 and upgrades[0].to_level == next_level,
				"shop offers exactly the next upgrade for %s level %d" % [current.weapon_id, next_level])
			check(loadout.upgrade_weapon(current.weapon_id), "upgrade applies for %s level %d" % [current.weapon_id, next_level])
		var next_dps := bow.get_base_attack_damage() / bow.get_actual_attack_interval_seconds()
		check(next_dps > bow_dps and next_dps / bow_dps < 1.5 and bow.get_stat("projectile_count") == 1,
			"bow grows smoothly without a level-five projectile jump: %d" % next_level)
		bow_dps = next_dps
		check(plasma.calculate_damage_events()[0].damage == 10 + 2 * next_level
			and is_equal_approx(plasma.get_actual_attack_interval_seconds(), 1.5) and plasma.get_hit_radius() == 12.0,
			"plasma gains damage while preserving timing and contact size: %d" % next_level)
		check(loadout.get_total_load_cost() == 93, "upgrades never increase equipped load")
	check(bow.get_base_attack_damage() == 9 and is_equal_approx(bow_dps, 18.0), "max-level bare bow deals nine every half second")
	var final_offers := generator.build_shop_candidate_pool(shop_context(loadout))
	check(not final_offers.any(func(offer): return offer.offer_type in ["new_weapon", "weapon_upgrade"]),
		"all-owned max-level loadout offers no duplicate weapons or sixth-level upgrades")
	check(not loadout.upgrade_weapon(PLASMA), "plasma stops at its configured maximum level")

	loadout.remove_weapon("weapon_iron_grenade_cannon")
	player.add_runtime_modifier({"id": "balance_capacity", "source_type": "test", "source_id": "balance_capacity",
		"target_scope": "player", "stat": "load_capacity", "operation": "add_flat", "value": -8,
		"duration": -1, "stack_rule": "unique"})
	var tight_offers := generator.build_shop_candidate_pool(shop_context(loadout))
	check(not tight_offers.any(func(offer): return offer.target_id == "weapon_iron_grenade_cannon")
		and not loadout.try_buy_weapon("weapon_iron_grenade_cannon") and loadout.get_total_load_cost() == 68,
		"shop and purchase both reject grenade when only twenty-four load remains")
	player.remove_runtime_modifiers_by_source("test", "balance_capacity")
	check(loadout.try_buy_weapon("weapon_iron_grenade_cannon"), "grenade is purchasable again after restoring capacity")
	host.queue_free()
	await frames()
	print("WEAPON_BALANCE_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
