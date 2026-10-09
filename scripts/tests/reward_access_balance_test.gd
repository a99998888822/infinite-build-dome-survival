extends Node

var checks := 0
var failures := 0
var report := {}
const LUCK_VALUES := {
	"relic_incomplete_divination_dice": 18, "relic_defiled_blessing_coin": 36,
	"relic_stargazers_lens": 36, "relic_gift_mark": 84,
	"relic_void_storage_casket": 36, "relic_reincarnation_hellfire_candle": 150,
	"relic_guarding_heart_copper_mirror": 36,
}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)


func make_player() -> PlayerController:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	return player


func _run() -> void:
	CampProgression.begin_transient_session()
	_test_luck()
	_test_shop()
	_test_boss_health()
	print("REWARD_ACCESS_REPORT ", JSON.stringify(report))
	print("REWARD_ACCESS_BALANCE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_luck() -> void:
	var generator := ShopOfferGenerator.new()
	var rows: Array = []
	for id: String in LUCK_VALUES:
		var player := make_player()
		var before := player.get_stat("luck")
		player.add_relic(id)
		check(player.get_stat("luck") - before == LUCK_VALUES[id], "real relic acquisition applies increased luck: " + id)
		var rarity := generator.get_shop_rarity_weights(int(player.get_stat("luck")))
		check((int(rarity.epic) > 0) == (int(player.get_stat("luck")) > 40), "doubled luck preserves the epic rarity gate")
		rows.append({"id": id, "luck": player.get_stat("luck"), "rarity_weights": rarity})
		player.free()
	var player := make_player()
	player.add_relic("relic_incomplete_divination_dice")
	player.add_relic("relic_defiled_blessing_coin")
	check(player.get_stat("luck") == 54 and generator.get_shop_rarity_weights(54).epic > 0 and generator.get_shop_rarity_weights(54).mythic == 0, "common plus uncommon luck relics open epic rarity")
	player.add_relic("relic_gift_mark")
	check(player.get_stat("luck") == 138 and generator.get_shop_rarity_weights(138).mythic == 0, "one gift mark does not skip the mythic gate")
	player.add_relic("relic_gift_mark")
	check(player.get_stat("luck") == 222 and generator.get_shop_rarity_weights(222).mythic > 0, "stacked gift marks open mythic rarity")
	player.add_relic("relic_reincarnation_hellfire_candle")
	check(player.get_stat("luck") == 372 and generator.get_shop_rarity_weights(372).legendary > 0, "continued investment opens legendary rarity")
	var before := player.get_stat("luck")
	player.add_relic("relic_amulet_of_humanity")
	check(player.get_stat("luck") == before - 5, "negative luck tradeoff remains five points")
	player.free()
	report.luck_relics = rows


func context_for(load_value: int, mode: String = "shop") -> Dictionary:
	return {"owned_weapon_ids": ["weapon_void_blade", "weapon_nightwatch_spear", "weapon_rentier_purse"],
		"equipped_weapons": [{"weapon_id": "weapon_void_blade", "level": 1}, {"weapon_id": "weapon_nightwatch_spear", "level": 1}, {"weapon_id": "weapon_rentier_purse", "level": 1}],
		"load_capacity": 100, "current_load": load_value, "luck": 0, "offer_mode": mode}


func _test_shop() -> void:
	var generator := ShopOfferGenerator.new()
	var rarity := generator.get_shop_rarity_weights(0)
	for used in [49, 50, 70, 80, 84, 85, 100, 110]:
		for mode in ["shop", "free"]:
			var context := context_for(used, mode)
			context.candidate_pool = generator.build_shop_candidate_pool(context)
			var weapons: Array = context.candidate_pool.filter(func(c): return c.offer_type == "new_weapon")
			check(weapons.all(func(w): return used + int(w.load_cost) <= 100 and not context.owned_weapon_ids.has(w.target_id)), "high-load pool only includes unowned fitting weapons")
			var weights := generator.get_shop_type_weights(context)
			if weapons.is_empty():
				check(weights.new_weapon == 0, "no fitting weapon means no weapon draw")
			elif used >= 50:
				var original := (3 if used <= 70 else 2) if mode == "shop" else 1
				check(weights.new_weapon == original * 2, "high-load weight is exactly twice the original after both penalties")
			else:
				check(weights.new_weapon == (3 if mode == "shop" else 1), "below fifty retains existing type weights")
	var rows: Array = []
	for mode in ["shop", "free"]:
		var context := context_for(70, mode)
		var pool := generator.build_shop_candidate_pool(context)
		context.candidate_pool = pool
		var after := generator.get_shop_type_weights(context)
		var before := after.duplicate()
		# Previous production weights at three owned weapons and 70/100 load.
		before.new_weapon = 3 if mode == "shop" else 1
		var probabilities: Array[float] = []
		for weights in [before, after]:
			seed(20261010)
			var hits := 0
			var batches_valid := true
			for sample in 2500:
				var offers := generator.roll_paid_offers(rarity, weights, pool, 3, sample) if mode == "shop" else generator.roll_shop_offers(rarity, weights, pool, 3)
				var weapons: Array = offers.filter(func(o): return o.offer_type == "new_weapon")
				batches_valid = batches_valid and offers.size() == 3 and weapons.size() <= 1
				if not weapons.is_empty(): hits += 1
			check(batches_valid, "real rolls preserve full shelves and at most one new weapon")
			probabilities.append(float(hits) / 2500.0)
		var ratio := probabilities[1] / probabilities[0]
		check(ratio >= 1.6 and ratio <= 2.3, "doubled weights give a moderate batch-probability increase")
		check(probabilities[1] < (0.30 if mode == "shop" else 0.12), "revised probabilities stay below the rejected boost")
		rows.append({"mode": mode, "current_load": 70, "owned_weapons": 3, "slots": 3,
			"samples_each": 2500, "before": probabilities[0], "after": probabilities[1]})
	report.high_load_batches = rows


func _test_boss_health() -> void:
	var rows: Array = []
	for tier in BattleDifficulty.IDS:
		var player := make_player()
		var manager := WaveManager.new()
		add_child(manager)
		manager.set_process(false)
		manager.initialize(player, tier)
		for wave in [2, 5, 20]:
			manager.current_wave_index = wave - 1
			for erosion in [0, 100]:
				manager._wave_erosion_pressure = manager.calculate_enemy_erosion_pressure(erosion)
				for id in ["enemy_elite_rusher", "enemy_underworld_wolf"]:
					var old_base := 200.0 if id == "enemy_elite_rusher" else 240.0
					var enemy := manager.spawn_enemy(id, Vector2(1000, 0))
					var factor := float(manager._difficulty.health) * pow(1.24, wave - 1) * float(manager._wave_erosion_pressure.max_hp_multiplier)
					var expected := roundi(old_base * 3.0 * factor)
					check(enemy.current_hp == expected and int(enemy.get_stat("max_hp")) == expected, "tripled boss HP survives difficulty, wave growth and erosion")
					if tier == "1" and erosion == 0:
						rows.append({"id": id, "wave": wave, "before": roundi(old_base * factor), "after": enemy.current_hp})
					enemy.free()
		manager.free()
		player.free()
	report.boss_hp = rows
