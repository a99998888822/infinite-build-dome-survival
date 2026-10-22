extends Node

const EXPECTED := {
	"weapon_void_blade": 100,
	"weapon_nightwatch_spear": 90, "weapon_dash_blade": 90,
	"weapon_plasma_cannon": 80, "weapon_kunyu_ritual_tome": 80,
	"weapon_earth_hammer": 80, "weapon_meteor_flail": 80, "weapon_hand_cannon": 80,
}
const SAMPLES := 6000
var generator := ShopOfferGenerator.new()
var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)


func _run() -> void:
	check(DataRegistry.get_load_errors().is_empty(), "all configs validate")
	var context := {"owned_weapon_ids": [], "equipped_weapons": [], "load_capacity": 1000, "current_load": 0, "luck": 0}
	var pool := generator.build_shop_candidate_pool(context)
	var weapons := generator._filter_candidates_by_type(pool, ShopOfferGenerator.OFFER_NEW_WEAPON)
	check(weapons.size() == EXPECTED.size(), "all eight available weapons covered")
	var total := 0
	for weapon in weapons:
		check(int(weapon.weight) == EXPECTED[weapon.target_id], "configured weight " + str(weapon.target_id))
		total += int(weapon.weight)
	check(total == 680, "weights normalized across available individual weapons")
	for kind in [ShopOfferGenerator.OFFER_RELIC, ShopOfferGenerator.OFFER_WEAPON_UPGRADE]:
		check(generator._filter_candidates_by_type(pool, kind).all(func(c): return c.weight == 100), "other candidate weights unchanged")
	_test_distribution(weapons)
	_test_independent_filters(pool)
	_test_constraints()
	_test_offer_ownership_and_prices()
	_test_validation()
	print("NEW_WEAPON_PROBABILITY checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_distribution(weapons: Array[Dictionary]) -> void:
	var type_weights := {"new_weapon": 1, "relic": 0, "weapon_upgrade": 0}
	var low_luck := generator.get_shop_rarity_weights(0)
	var high_luck := generator.get_shop_rarity_weights(530)
	for mode in ["free", "shop"]:
		var counts := {}
		var valid := true
		seed(20261012)
		for index in SAMPLES:
			var offers := generator.roll_shop_offers(low_luck, type_weights, weapons, 1) if mode == "free" else generator.roll_paid_offers(low_luck, type_weights, weapons, 1, index)
			if offers.size() != 1:
				valid = false
				continue
			var id := str(offers[0].target_id)
			counts[id] = int(counts.get(id, 0)) + 1
		check(valid, mode + " always draws exactly one eligible weapon")
		for id in EXPECTED:
			var observed := float(counts.get(id, 0)) / SAMPLES
			check(absf(observed - float(EXPECTED[id]) / 680.0) < 0.015, mode + " per-weapon probability " + id)
		print("NEW_WEAPON_DISTRIBUTION ", mode, " ", JSON.stringify(counts))
		for index in 64:
			seed(index)
			var low := generator.roll_shop_offers(low_luck, type_weights, weapons, 1) if mode == "free" else generator.roll_paid_offers(low_luck, type_weights, weapons, 1, index)
			seed(index)
			var high := generator.roll_shop_offers(high_luck, type_weights, weapons, 1) if mode == "free" else generator.roll_paid_offers(high_luck, type_weights, weapons, 1, index)
			check(low[0].target_id == high[0].target_id, mode + " weapon draw is independent of luck")
	# Giving a weapon its own custom weight must override its rarity's usual value.
	var custom := weapons.duplicate(true)
	custom[0].weight = 1000000
	var hits := 0
	seed(1280)
	for index in 100:
		if generator.roll_shop_offers(low_luck, type_weights, custom, 1)[0].target_id == custom[0].target_id:
			hits += 1
	check(hits >= 95, "custom per-weapon weights are used directly")


func _test_independent_filters(pool: Array[Dictionary]) -> void:
	var disabled := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0, "mythic": 0, "legendary": 0}
	var types := {"new_weapon": 1, "relic": 1, "weapon_upgrade": 1}
	var filtered := generator._filter_candidates_by_rarity_weights(pool, disabled)
	check(filtered.size() == 8 and filtered.all(func(c): return c.offer_type == "new_weapon"), "only available new weapons bypass the shared rarity filter")
	for mode in ["free", "shop"]:
		var offers := generator.roll_shop_offers(disabled, types, pool, 3) if mode == "free" else generator.roll_paid_offers(disabled, types, pool, 3, 99)
		check(offers.size() == 1 and offers[0].offer_type == "new_weapon", mode + " new weapon survives zero shared rarity weights and respects one-per-page")
		var guarantee := generator.roll_shop_offers(disabled, {"relic": 1}, pool, 3, true) if mode == "free" else generator.roll_paid_offers(disabled, {"relic": 1}, pool, 3, 100, [], "epic", true)
		check(guarantee.size() == (1 if mode == "free" else 2)
			and guarantee.any(func(c): return c.offer_type == "new_weapon"), mode + " weapon guarantee uses the independent pool")
		if mode == "shop":
			check(guarantee[0].offer_type == "relic" and guarantee[0].rarity == "epic", "strong refresh retains its epic relic guarantee")
	var common_only := {"common": 1}
	var relics := generator._filter_candidates_by_type(pool, ShopOfferGenerator.OFFER_RELIC)
	for mode in ["free", "shop"]:
		var offers := generator.roll_shop_offers(common_only, {"relic": 1}, relics, 3) if mode == "free" else generator.roll_paid_offers(common_only, {"relic": 1}, relics, 3, 101)
		check(offers.size() == 3 and offers.all(func(c): return c.rarity == "common"), mode + " relics retain the shared rarity curve")


func _test_constraints() -> void:
	var context := {"owned_weapon_ids": ["weapon_void_blade", "weapon_dash_blade"],
		"equipped_weapons": [{"weapon_id": "weapon_void_blade", "level": 1}, {"weapon_id": "weapon_dash_blade", "level": 1}],
		"load_capacity": 100, "current_load": 42, "luck": 0}
	var pool := generator.build_shop_candidate_pool(context)
	var weapons := generator._filter_candidates_by_type(pool, ShopOfferGenerator.OFFER_NEW_WEAPON)
	check(weapons.size() == 6 and weapons.all(func(c): return c.target_id not in context.owned_weapon_ids), "owned weapons excluded")
	context.candidate_pool = pool
	check(generator.get_shop_type_weights(context) == {"new_weapon": 6, "relic": 60, "weapon_upgrade": 4}, "paid type odds unchanged")
	context.offer_mode = "free"
	check(generator.get_shop_type_weights(context) == {"new_weapon": 3, "relic": 60, "weapon_upgrade": 4}, "free type odds unchanged")
	var previous := ["new_weapon:weapon_nightwatch_spear"]
	for index in 32:
		var offers := generator.roll_paid_offers(generator.get_shop_rarity_weights(0), {"new_weapon": 1}, weapons, 3, index, previous, "", true)
		check(offers.size() == 1 and offers[0].candidate_id not in previous, "previous-page exclusions and one weapon per shelf retained")
	context.current_load = 75
	weapons = generator._filter_candidates_by_type(generator.build_shop_candidate_pool(context), ShopOfferGenerator.OFFER_NEW_WEAPON)
	check(weapons.size() == 1 and weapons[0].target_id == "weapon_plasma_cannon", "weapon must fit remaining load")
	context.current_load = 100
	check(generator._filter_candidates_by_type(generator.build_shop_candidate_pool(context), ShopOfferGenerator.OFFER_NEW_WEAPON).is_empty(), "full load excludes all new weapons")
	context.current_load = 42
	context.unlocked_weapon_ids = ["weapon_kunyu_ritual_tome"]
	weapons = generator._filter_candidates_by_type(generator.build_shop_candidate_pool(context), ShopOfferGenerator.OFFER_NEW_WEAPON)
	check(weapons.size() == 1 and weapons[0].target_id == "weapon_kunyu_ritual_tome", "weapon unlock filter retained")
	context.equipped_weapons[0].level = 3
	var upgrades := generator._filter_candidates_by_type(generator.build_shop_candidate_pool(context), ShopOfferGenerator.OFFER_WEAPON_UPGRADE)
	check(not upgrades.any(func(c): return c.target_id == "weapon_void_blade"), "epic upgrade remains gated by luck")
	context.luck = 100
	upgrades = generator._filter_candidates_by_type(generator.build_shop_candidate_pool(context), ShopOfferGenerator.OFFER_WEAPON_UPGRADE)
	check(upgrades.any(func(c): return c.target_id == "weapon_void_blade"), "luck still unlocks eligible weapon upgrades")


func _test_offer_ownership_and_prices() -> void:
	var pool := generator.build_shop_candidate_pool({"load_capacity": 100, "luck": 0})
	var original := pool.duplicate(true)
	for mode in ["free", "shop"]:
		seed(221022)
		var offers := generator.roll_shop_offers({"common": 1}, {"relic": 1}, pool, 3) if mode == "free" else generator.roll_paid_offers({"common": 1}, {"relic": 1}, pool, 3, 1)
		check(offers.size() == 3 and pool == original, mode + " selection leaves candidate stock unchanged")
		var untouched := offers[1].duplicate(true)
		offers[0].effects.append({"id": "ownership_probe"})
		offers[0].runtime_effects.append({"id": "runtime_probe"})
		offers[0].tags.append("test_tag")
		offers[0].price_breakdown.base = -999
		offers[0].shop_cost = -999
		check(pool == original and offers[1] == untouched, mode + " returned nested offer data cannot mutate stock or another offer")
	var rebuilt := generator.build_shop_candidate_pool({"load_capacity": 100, "luck": 0})
	check(rebuilt == original, "editing returned rewards does not change registry-backed future pools")
	var contexts: Array[Dictionary] = [
		{"shop_wave_number": 4, "paid_purchase_count": 2, "wave_gold_earned": 10000, "humanity": 0, "shop_price_discounts": [25.0, 50.0]},
		{"shop_wave_number": 2, "humanity": 150, "shop_price_percent": -25.0},
	]
	for index in contexts.size():
		var context: Dictionary = contexts[index]
		var priced := generator.build_shop_candidate_pool(context)
		var common: Dictionary = priced.filter(func(c): return c.offer_type == "relic" and c.rarity == "common")[0]
		# Base 15, then wave/purchases/income, then each discount, then humanity.
		var basis := 9.375 if index == 0 else 21.25
		check(is_equal_approx(common.shop_price_basis, basis) and common.shop_cost_without_humanity == ceili(basis) and common.shop_cost == (12 if index == 0 else 22), "candidate pool returns complete layered prices: " + str(index))
		check(common.shop_base_price == 15 and common.price_breakdown.wave == (6 if index == 0 else 2) and common.price_breakdown.income == (2 if index == 0 else 0), "price breakdown keeps its original basis and context: " + str(index))
		check(HumanityEconomy.purchase_tooltip(common).contains(str(common.shop_cost)), "price tooltip can consume candidates before they are selected")
	var shared := {"offer_type": "relic", "rarity": "common", "offer_id": "shared", "effects": [{"nested": [1]}]}
	var repeated := generator.roll_shop_offers({"common": 1}, {"relic": 1}, [shared, shared], 2)
	check(repeated.size() == 2, "equal entries preserve the original pool multiplicity")
	repeated[0].effects[0].nested[0] = 2
	check(repeated[1].effects[0].nested[0] == 1 and shared.effects[0].nested[0] == 1, "separately selected equal candidates own independent nested copies")


func _test_validation() -> void:
	for value in [0, -1, 1.5, "invalid"]:
		var record := DataRegistry.get_record("weapons", "weapon_void_blade").duplicate(true)
		record.shop_weight = value
		var validator := DataValidator.new()
		validator._validate_weapon_runtime_fields(record, "test")
		check(not validator.errors.is_empty(), "reject invalid shop weight")
