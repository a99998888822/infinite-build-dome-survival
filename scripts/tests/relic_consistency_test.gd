extends Node

# Run scenes/tests/relic_consistency_test.tscn in an isolated project copy.
var failures := 0
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", label)


func make_player() -> PlayerController:
	var p := PlayerController.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.set_physics_process(false)
	p.initialize_from_character("character_void_hunter")
	return p


func make_finance(p: PlayerController) -> BattleFinanceSystem:
	var bank := BattleFinanceSystem.new()
	var gold := {"value": 1000}
	bank.initialize(p, func(): return gold.value, func(delta, _reason): gold.value += delta; return true)
	p.relic_added.connect(bank.on_relic_added)
	return bank


func modify(p: PlayerController, stat: String, value: float, id: String = "test") -> void:
	p.add_runtime_modifier({"id": id + stat, "source_type": "test", "source_id": id, "target_scope": "player", "stat": stat, "operation": "add_flat", "value": value, "duration": -1, "stack_rule": "replace_same_source"})


func snapshot(p: PlayerController, bank: BattleFinanceSystem) -> Dictionary:
	var result := {}
	for stat in StatDefinitions.get_all_stat_ids():
		result[stat] = StatPreviewBuilder.get_display_stat_value(p, stat, bank)
	return result


func _run() -> void:
	_test_config_and_health()
	_test_projectiles()
	_test_interest()
	_test_sanity_and_dependencies()
	_test_reward_remainders()
	_test_previews()
	print("RELIC_TEST_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_config_and_health() -> void:
	var p := make_player()
	p.add_relic("relic_vitality_potion")
	check(is_equal_approx(p.get_stat("hp_regen"), 0.5), "MD vitality regen 0.5")
	p.add_relic("relic_turtle_shell_pendant")
	check(p.get_stat("max_hp") == 12, "MD turtle max HP +2")
	p.add_relic("relic_stargazers_lens")
	check(p.get_stat("luck") == 18, "MD stargazer luck +18")
	p.free()
	p = make_player()
	p.add_relic("relic_worn_hemostatic_cloth")
	p.restore_full_health()
	p.add_relic("relic_piggy_bank")
	check(p.current_hp == 13 and p.get_stat("max_hp") == 13, "relic rebuild preserves full HP")
	p.sync_relic_weapon_ids(p.get_start_weapon_ids())
	check(p.current_hp == 13, "weapon refresh preserves HP")
	p.current_hp = 8
	p.add_relic("relic_finance_manager")
	check(p.current_hp == 8, "rebuild never heals injured player")
	p.restore_full_health()
	p.add_relic("relic_welfare_cutback")
	check(p.current_hp == 8 and p.get_stat("max_hp") == 8, "real max HP loss clamps to final cap")
	p.free()
	p = make_player()
	p.add_relic("relic_costly_seed_of_life")
	p.take_damage(999)
	check(p.remaining_revives == 0 and p.get_stat("divinity") == 20, "seed consumes revive and adds erosion")
	p.add_relic("relic_piggy_bank")
	check(p.remaining_revives == 1, "DESIGN seed refresh restores spent revive")
	p.free()


func _test_projectiles() -> void:
	for weapon_id in ["weapon_void_blade", "weapon_plasma_cannon"]:
		var p := make_player()
		var weapon := WeaponInstance.new()
		weapon.initialize(weapon_id, p)
		for count in range(1, 4):
			check(weapon.get_projectile_angles().size() == count, "projectile count %s %d" % [weapon_id, count])
			p.add_relic("relic_split_crystal_warhead")
		p.free()
	var p := make_player()
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", p)
	var before := weapon.calculate_damage_events(true)[0].damage
	p.add_relic("relic_executioner_bracer")
	check(weapon.calculate_damage_events(true)[0].damage == before, "DESIGN ranged weapon ignores melee damage")
	p.free()


func _test_interest() -> void:
	for deposited in [0, 49, 50]:
		var p := make_player()
		var bank := make_finance(p)
		p.add_relic("relic_high_yield_contract")
		p.add_relic("relic_compound_interest_tome")
		p.add_relic("relic_perpetual_annuity_scroll")
		p.add_relic("relic_perpetual_annuity_scroll")
		p.add_relic("relic_periodic_dividend_clock")
		bank.begin_wave(1)
		bank.begin_wave(2)
		bank.prepare_wave(3)
		bank.deposit(100, true)
		if deposited > 0: bank.deposit(deposited)
		bank.begin_wave(3)
		var results := bank.process_wave_end_settlements()
		var correct := results.size() == 4
		for result in results:
			correct = correct and (bool(result.blocked) if deposited < 50 else int(result.gain) > 0)
		check(correct, "contract covers all four wave-end settlements deposit=%d" % deposited)
		check(is_equal_approx(bank.interest_rate_bonus, 0.0 if deposited < 50 else 0.8), "tome grows once per successful settlement deposit=%d" % deposited)
		if deposited == 0:
			var manual := bank.trigger_manual_interest()
			check(manual.gain > 0 and not manual.blocked and is_equal_approx(bank.interest_rate_bonus, 0.2), "manual interest outside wave-end restriction grows tome")
		p.free()
	var p := make_player()
	var bank := make_finance(p)
	p.add_relic("relic_divine_fusion")
	bank.deposit(1000, true)
	modify(p, "divinity", 5)
	check(is_equal_approx(bank.get_interest_rate(), 5.5), "fusion updates immediately after player erosion")
	check(bank.settle_interest().gain == 55, "first settlement uses current fusion rate")
	p.add_relic("relic_compound_interest_tome")
	bank.settle_interest()
	check(is_equal_approx(StatPreviewBuilder.get_display_stat_value(p, "interest_rate", bank), 5.7), "HUD rate includes tome and fusion")
	p.add_relic("relic_void_tentacle")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_START)
	modify(p, "divinity", 9)
	p.take_damage(20)
	check(p.get_stat("divinity") == 10 and is_equal_approx(bank.get_interest_rate(), 6.2), "shield-break erosion refreshes fusion immediately")
	p.free()


func _test_sanity_and_dependencies() -> void:
	var p := make_player()
	p.add_relic("relic_amulet_of_humanity")
	p.add_relic("relic_reincarnation_hellfire_candle")
	check(p.get_stat("humanity") == 110, "candle preserves preexisting sanity bonus")
	p.add_relic("relic_amulet_of_humanity")
	p.add_relic("relic_guarding_heart_copper_mirror")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 110, "candle blocks new static and wave-end sanity gains")
	p.add_relic("relic_soul_keeper_face_stone")
	modify(p, "divinity", 20)
	check(p.get_stat("humanity") == 110, "new soul stone cannot bypass candle")
	p.free()
	p = make_player()
	modify(p, "divinity", 20)
	p.add_relic("relic_soul_keeper_face_stone")
	p.add_relic("relic_reincarnation_hellfire_candle")
	check(p.get_stat("humanity") == 120, "candle preserves existing derived sanity")
	modify(p, "divinity", 30)
	check(p.get_stat("humanity") == 120, "existing stone cannot gain more sanity")
	modify(p, "divinity", 10)
	check(p.get_stat("humanity") == 110, "blocked derived sanity can decrease")
	modify(p, "divinity", 30)
	check(p.get_stat("humanity") == 110, "blocked derived sanity cannot recover after decrease")
	p.free()
	var permutations := [
		["relic_lost_wayfarer_greave", "relic_soul_keeper_face_stone", "relic_shadowless_greave"],
		["relic_shadowless_greave", "relic_lost_wayfarer_greave", "relic_soul_keeper_face_stone"],
		["relic_soul_keeper_face_stone", "relic_shadowless_greave", "relic_lost_wayfarer_greave"],
	]
	for ids in permutations:
		p = make_player()
		modify(p, "humanity", -50)
		modify(p, "divinity", 20)
		for id in ids: p.add_relic(id)
		check(p.get_stat("humanity") == 70 and p.get_stat("move_speed") == 284 and p.get_stat("armor") == 36, "dependency order independent " + str(ids))
		modify(p, "divinity", 0)
		check(p.get_stat("humanity") == 50 and p.get_stat("move_speed") == 272 and p.get_stat("armor") == 35, "dependency change recalculates condition and armor")
		p.free()


func _test_reward_remainders() -> void:
	var p := make_player()
	var manager := WaveManager.new()
	manager.player = p
	p.add_relic("relic_gold_compass")
	p.add_relic("relic_gold_digger_gloves")
	for i in 100: manager.add_exp_and_gold(1, 1)
	check(manager.collected_gold_this_wave == 105 and manager.collected_exp_this_wave == 108, "100 small pickups retain +5% gold and +8% XP")
	manager.free()
	manager = WaveManager.new()
	manager.player = p
	p.add_relic("relic_salary_adjustment")
	for i in 100: manager.add_exp_and_gold(1, 1)
	check(manager.current_gold == 85, "100 pickups retain net -15% gold penalty")
	manager.free()
	manager = WaveManager.new()
	manager.player = p
	manager.add_exp_and_gold(1, 1)
	manager.collected_gold_this_wave = 0
	for i in 19: manager.add_exp_and_gold(1, 1)
	check(manager.current_gold == 17, "fractional rewards survive wave counter reset")
	manager.initialize(p)
	check(manager._reward_remainders.is_empty(), "new run resets fractional rewards")
	manager.free()
	p.free()


func _test_previews() -> void:
	var mismatches: Array = []
	for blocked in [false, true]:
		for record in DataRegistry.get_table("relics"):
			var p := make_player()
			var bank := make_finance(p)
			modify(p, "humanity", -50)
			modify(p, "divinity", 20)
			bank.prepare_wave(4)
			bank.deposit(1000, true)
			p.add_relic("relic_flyer_ad")
			p.add_relic("relic_soul_keeper_face_stone")
			p.add_relic("relic_lost_wayfarer_greave")
			p.add_relic("relic_steel_vault")
			if blocked: p.add_relic("relic_reincarnation_hellfire_candle")
			var before := snapshot(p, bank)
			var counts := p.get_relic_counts()
			var hp_before := p.current_hp
			var rng_before := bank._rng.state
			var offer: Dictionary = record.duplicate(true)
			offer["offer_type"] = "relic"
			offer["target_id"] = record.id
			var prediction := StatPreviewBuilder.build_offer_stat_preview(offer, p, bank)
			if before != snapshot(p, bank) or counts != p.get_relic_counts() or hp_before != p.current_hp or rng_before != bank._rng.state:
				mismatches.append([record.id, "preview modified live state"])
			p.add_relic(record.id)
			var actual := snapshot(p, bank)
			for stat in actual:
				if not is_equal_approx(float(prediction.get(stat, before[stat])), float(actual[stat])):
					mismatches.append([record.id, blocked, stat, prediction.get(stat, before[stat]), actual[stat]])
			p.free()
	check(mismatches.is_empty(), "144 previews match real acquisition including finance, bonds and candle: " + JSON.stringify(mismatches))
	var p := make_player()
	var bank := make_finance(p)
	p.add_relic("relic_flyer_ad")
	p.add_relic("relic_flyer_ad")
	check(is_equal_approx(p.get_effective_shop_discount(), 15.36), "display two discounts as 15.36%")
	check(StatDefinitions.calculate_shop_cost_from_discounts(10000, p.get_shop_price_discount_layers()) == 8464, "discount display and price use same multiplier")
	p.add_relic("relic_salary_adjustment")
	check(is_equal_approx(p.get_effective_shop_discount(), -1.568), "display combined discount and surcharge")
	var hud := BattleHud.new()
	check(hud._format_stat_value("shop_price_percent", 15.36) == "15.36%", "fractional discount display format")
	hud.free()
	bank.deposit(100, true)
	bank.withdraw(bank.principal)
	var offer := {"offer_type": "relic", "target_id": "relic_bankruptcy_reorg"}
	var preview := StatPreviewBuilder.build_offer_stat_preview(offer, p, bank, 100)
	bank._apply_gold_delta(-100, "test_purchase")
	p.add_relic("relic_bankruptcy_reorg")
	check(preview.get("finance", -1) == bank.principal, "bankruptcy preview accounts for purchase cost")
	p.free()
