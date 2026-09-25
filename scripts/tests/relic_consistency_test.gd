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
	# Fixed health fixture for relic interactions; actual level growth has its own suite.
	p.modifier_stack.set_base_stat("max_hp", 10)
	p.restore_full_health()
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
	_test_confirmed_balance()
	_test_limited_conversion_relics()
	_test_lethal_shield_break()
	_test_sanity_tradeoff_relics()
	_test_conditional_event_validation()
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
	check(p.get_stat("max_hp") == 13, "MD turtle max HP +3")
	p.add_relic("relic_stargazers_lens")
	check(p.get_stat("luck") == 18, "MD stargazer luck +18")
	p.free()
	p = make_player()
	p.add_relic("relic_worn_hemostatic_cloth")
	p.restore_full_health()
	p.add_relic("relic_piggy_bank")
	check(p.current_hp == 14 and p.get_stat("max_hp") == 14, "relic rebuild preserves full HP")
	p.sync_relic_weapon_ids(p.get_start_weapon_ids())
	check(p.current_hp == 14, "weapon refresh preserves HP")
	p.current_hp = 8
	p.add_relic("relic_finance_manager")
	check(p.current_hp == 8, "rebuild never heals injured player")
	p.restore_full_health()
	p.add_relic("relic_welfare_cutback")
	check(p.current_hp == 11 and p.get_stat("max_hp") == 11, "real max HP loss clamps to final cap")
	p.free()
	p = make_player()
	p.add_relic("relic_costly_seed_of_life")
	p.take_damage(999)
	check(p.remaining_revives == 0 and p.get_stat("divinity") == 20, "seed consumes revive and adds erosion")
	p.add_relic("relic_piggy_bank")
	check(p.remaining_revives == 0, "relic rebuild never restores a spent seed revive")
	p.free()


func _test_projectiles() -> void:
	for weapon_id in ["weapon_void_blade", "weapon_plasma_cannon"]:
		var p := make_player()
		var weapon := WeaponInstance.new()
		weapon.initialize(weapon_id, p)
		for count in range(1, 4):
			check(weapon.get_projectile_angles().size() == count, "projectile count %s %d" % [weapon_id, count])
			modify(p, "projectile_count", count)
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
		check(not p.add_relic("relic_perpetual_annuity_scroll"), "annuity rejects a second copy")
		p.add_relic("relic_periodic_dividend_clock")
		p.add_relic("relic_frenzied_dividend")
		bank.begin_wave(1)
		bank.begin_wave(2)
		bank.prepare_wave(3)
		bank.deposit(100, true)
		if deposited > 0: bank.deposit(deposited)
		bank.begin_wave(3)
		var results := bank.process_wave_end_settlements()
		var correct := results.size() == 3
		for result in results:
			correct = correct and not bool(result.blocked) and int(result.gain) > 0
		check(correct, "contract always preserves normal periodic and annuity interest deposit=%d" % deposited)
		check(is_equal_approx(float(results[0].interest_rate), 6.0 if deposited < 50 else 12.0), "contract grants six rate points only at the deposit threshold")
		check(is_equal_approx(bank.interest_rate_bonus, 0.6), "tome grows once per successful settlement deposit=%d" % deposited)
		check(p.get_stat("damage_percent") == 6 and p.get_stat("humanity") == 94, "all positive settlements apply frenzy growth and cost deposit=%d" % deposited)
		if deposited == 0:
			var manual := bank.trigger_manual_interest()
			check(manual.gain > 0 and not manual.blocked and is_equal_approx(bank.interest_rate_bonus, 0.8), "manual positive interest also grows tome")
		p.free()
	var p := make_player()
	var bank := make_finance(p)
	p.add_relic("relic_divine_fusion")
	bank.deposit(1000, true)
	modify(p, "divinity", 5)
	check(is_equal_approx(bank.get_interest_rate(), 7.5), "fusion combines two base points with immediate erosion scaling")
	check(bank.settle_interest().gain == 75, "first settlement uses current fusion rate")
	p.add_relic("relic_compound_interest_tome")
	bank.settle_interest()
	check(is_equal_approx(StatPreviewBuilder.get_display_stat_value(p, "interest_rate", bank), 8.7), "HUD rate includes static and growing tome plus fusion")
	p.add_relic("relic_void_tentacle")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_START)
	modify(p, "divinity", 9)
	p.take_damage(20)
	check(p.get_stat("divinity") == 10 and is_equal_approx(bank.get_interest_rate(), 9.2), "shield-break erosion refreshes fusion immediately")
	p.free()


func _test_confirmed_balance() -> void:
	var p := make_player()
	p.add_relic("relic_nightmare_healing_urn")
	p.current_hp = 5
	p._physics_process(1.25)
	check(is_equal_approx(p.get_stat("hp_regen"), 0.8) and p.current_hp == 6, "urn regenerates one HP in 1.25 seconds")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 99, "urn retains one sanity loss per wave")
	p.add_relic("relic_guarding_heart_copper_mirror")
	check(p.get_stat("luck") == 18 and p.get_stat("currency_gain_percent") == 20, "mirror keeps luck and grants twenty percent gold")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 99, "mirror recovery offsets urn decay")
	p.free()
	p = make_player()
	var bank := make_finance(p)
	p.add_relic("relic_sleepless_ledger")
	check(is_equal_approx(bank.get_interest_rate(), 9), "ledger adds four percentage points")
	check(not p.add_relic("relic_sleepless_ledger"), "ledger capped at one copy")
	bank.deposit(500, true)
	bank.begin_wave(1)
	check(bank.settle_interest().gain == 45 and p.get_stat("humanity") == 100, "ledger first settlement pays before wave-end sanity loss")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 97, "ledger wave-end sanity minus three")
	modify(p, "humanity", -98)
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == -4, "ledger decay continues below zero")
	p.free()
	p = make_player()
	bank = make_finance(p)
	p.add_relic("relic_frenzied_dividend")
	check(not p.add_relic("relic_frenzied_dividend"), "frenzy capped at one copy")
	bank.settle_interest()
	check(p.get_stat("damage_percent") == 0 and p.get_stat("humanity") == 100, "no principal grants no frenzy growth or cost")
	bank.deposit(500, true)
	p.add_relic("relic_perpetual_annuity_scroll")
	var results := bank.process_wave_end_settlements()
	check(results.size() == 2 and results[0].gain == 25 and results[1].gain == 24 and bank.principal == 500, "second annuity payout uses unchanged principal and sanity lost after first payout")
	check(p.get_stat("damage_percent") == 4 and p.get_stat("humanity") == 96, "two successful payouts grant damage four and sanity minus four")
	bank.trigger_manual_interest()
	check(p.get_stat("damage_percent") == 6 and p.get_stat("humanity") == 94, "manual positive settlement triggers frenzy once")
	p.add_relic("relic_high_yield_contract")
	bank.process_wave_end_settlements()
	check(p.get_stat("damage_percent") == 10 and p.get_stat("humanity") == 90, "unqualified contract still permits positive settlements and frenzy")
	bank.principal = 1
	bank.interest_remainder = 0
	modify(p, "humanity", -300)
	var zero_gain := bank.trigger_manual_interest()
	check(zero_gain.gain == 0 and p.get_stat("damage_percent") == 10 and p.get_stat("humanity") == -210, "zero integer payout accrues fractions without triggering frenzy")
	var candidates := ShopOfferGenerator.new().build_shop_candidate_pool({"owned_relic_counts": p.get_relic_counts()})
	check(candidates.all(func(offer): return str(offer.get("target_id", "")) not in ["relic_frenzied_dividend", "relic_perpetual_annuity_scroll"]), "capped relics leave the candidate pool")
	p.free()


func _test_limited_conversion_relics() -> void:
	var ids := ["relic_divine_fusion", "relic_soul_keeper_face_stone", "relic_guarding_heart_copper_mirror", "relic_reincarnation_hellfire_candle"]
	var generator := ShopOfferGenerator.new()
	for id in ids:
		var p := make_player()
		var bank := make_finance(p)
		check(generator.build_shop_candidate_pool({}).any(func(offer): return offer.get("target_id", "") == id), id + " available before acquisition")
		check(p.add_relic(id), id + " accepts first copy")
		var before := snapshot(p, bank)
		check(not p.add_relic(id) and p.get_relic_count(id) == 1 and snapshot(p, bank) == before, id + " rejects duplicates without changing effects")
		var pool := generator.build_shop_candidate_pool({"owned_relic_counts": p.get_relic_counts()})
		check(pool.all(func(offer): return offer.get("target_id", "") != id), id + " removed from shop and reward candidates")
		check(StatPreviewBuilder.build_offer_stat_preview({"offer_type": "relic", "target_id": id}, p, bank).is_empty(), id + " capped preview cannot add another contribution")
		p.free()


func _test_lethal_shield_break() -> void:
	for row in [[6, 2, 8], [5, 1, 8], [10, 1, 10]]:
		var p := make_player()
		p.add_relic("relic_void_tentacle")
		p.current_hp = row[0]
		p.current_shield = 1
		p.take_damage(row[1], "nonlethal_shield_break")
		check(p.alive and p.current_hp == row[2] and p.current_shield == 0 and p.get_stat("divinity") == 1, "nonlethal shield break heals, caps at max HP and adds erosion " + str(row))
		p.free()
	for copies in [1, 2]:
		var p := make_player()
		for i in copies: p.add_relic("relic_void_tentacle")
		p.current_shield = 1
		p.take_damage(999, "lethal_shield_break")
		check(not p.alive and p.current_hp == 0 and p.get_stat("divinity") == copies, "lethal break cannot revive even with multiple tentacles copies=%d" % copies)
		check(p.heal(3) == 0 and p.current_hp == 0, "ordinary healing cannot revive a dead player")
		p.free()
	var p := make_player()
	var bank := make_finance(p)
	for id in ["relic_void_tentacle", "relic_costly_seed_of_life", "relic_golden_sarcophagus"]: p.add_relic(id)
	bank.deposit(1000, true)
	p.current_shield = 1
	p.take_damage(999, "shield_break_seed")
	check(p.alive and p.current_hp == 5 and p.remaining_revives == 0 and bank.principal == 1000 and p.get_stat("divinity") == 21, "lethal break consumes normal revive and applies break plus revive erosion")
	p._invincibility_timer = 0.0
	p._process_regeneration(1.0)
	p.take_damage(999, "shield_break_coffin")
	check(p.alive and p.current_hp == 5 and bank.principal == 500 and p.get_stat("divinity") == 42 and bank.get_principal_revive_state().remaining_uses == 0, "regenerated shield cannot bypass paid coffin or revive erosion")
	p._invincibility_timer = 0.0
	p._process_regeneration(1.0)
	p.take_damage(999, "shield_break_no_revives")
	check(not p.alive and p.current_hp == 0 and bank.principal == 500 and p.get_stat("divinity") == 43, "regenerated shield cannot save player after all revives are spent")
	p.free()
	p = make_player()
	bank = make_finance(p)
	for id in ["relic_void_tentacle", "relic_coin_heart", "relic_hoarders_ring", "relic_golden_sarcophagus"]: p.add_relic(id)
	bank.deposit(1000, true)
	p.restore_full_health()
	p.current_shield = 1
	p.take_damage(999, "shield_break_principal_attributes")
	check(p.alive and p.current_hp == 8 and p.get_stat("max_hp") == 15 and bank.principal == 500, "lethal break restores post-payment maximum health through coffin")
	check(p.get_stat("currency_gain_percent") == 10 and p.get_stat("humanity") == 98 and p.get_stat("divinity") == 1, "coffin following shield break updates revised ring tiers and retains erosion cost")
	p.free()


func _test_sanity_tradeoff_relics() -> void:
	var ids := ["relic_gilded_trigger", "relic_runaway_amplifier", "relic_lucid_vow"]
	var generator := ShopOfferGenerator.new()
	var candidates := generator.build_shop_candidate_pool({})
	var p := make_player()
	for id in ids:
		check(candidates.any(func(offer): return offer.get("target_id", "") == id), "%s available in shop" % id)
		check(p.add_relic(id) and not p.add_relic(id), "%s accepts only one copy" % id)
	candidates = generator.build_shop_candidate_pool({"owned_relic_counts": p.get_relic_counts()})
	check(candidates.all(func(offer): return offer.get("target_id", "") not in ids), "three owned tradeoff relics leave shop pool")
	check(p.get_stat("damage_percent") == 57 and p.get_stat("humanity") == 80, "tradeoff relic damage bonuses use additive damage stat")
	p.free()
	p = make_player()
	var bank := make_finance(p)
	bank.deposit(500, true)
	p.add_relic("relic_gilded_trigger")
	check(p.get_stat("damage_percent") == 25 and p.get_stat("humanity") == 80, "gilded trigger trades twenty sanity for twenty-five damage")
	var economy := HumanityEconomy.get_multipliers(p.get_stat("humanity"))
	check(is_equal_approx(economy.purchase, 1.04) and is_equal_approx(economy.sale, 1.0 / 1.04), "trigger immediately changes purchase and sale economics")
	var settlement := bank.settle_interest()
	check(settlement.gain == 20 and is_equal_approx(bank.interest_remainder, 5.0 / 6.0), "trigger reduces actual interest with fractional carry")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 80, "trigger sanity cost is not repeated at wave end")
	p.free()
	for row in [[100, 97, 94], [0, -3, -8], [-1, -6, -11]]:
		p = make_player()
		modify(p, "humanity", float(row[0]) - 100.0)
		p.add_relic("relic_runaway_amplifier")
		check(p.get_stat("damage_percent") == 40 and p.get_stat("humanity") == row[0], "amplifier grants damage without acquisition decay at %s" % row[0])
		p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
		check(p.get_stat("humanity") == row[1], "amplifier first wave uses pre-trigger sanity at %s" % row[0])
		p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
		check(p.get_stat("humanity") == row[2], "amplifier subsequent wave keeps negative sanity decay at %s" % row[0])
		p.free()
	for companion in ["relic_sleepless_ledger", "relic_lucid_vow"]:
		for starting_sanity in [-1, 0, 1]:
			for reversed in [false, true]:
				p = make_player()
				modify(p, "humanity", float(starting_sanity) - 100.0)
				var order := ["relic_runaway_amplifier", companion]
				if reversed: order.reverse()
				for id in order: p.add_relic(id)
				p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
				var expected: int = starting_sanity - (5 if starting_sanity < 0 else 3) + (-3 if companion == "relic_sleepless_ledger" else 2)
				check(p.get_stat("humanity") == expected, "wave-end condition snapshot companion=%s sanity=%s reversed=%s" % [companion, starting_sanity, reversed])
				p.free()
	p = make_player()
	p.add_relic("relic_runaway_amplifier")
	p.add_relic("relic_lucid_vow")
	for i in 5: p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("damage_percent") == 32 and p.get_stat("humanity") == 95, "vow offsets only part of amplifier decay while retaining thirty-two damage")
	p.free()
	p = make_player()
	modify(p, "humanity", -101)
	p.add_relic("relic_lucid_vow")
	check(p.get_stat("damage_percent") == -8 and p.get_stat("humanity") == -1, "vow pays damage immediately and waits for wave end")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 1, "vow restores sanity across zero")
	p.free()
	p = make_player()
	p.add_relic("relic_lucid_vow")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 102 and HumanityEconomy.get_multipliers(102) == HumanityEconomy.get_multipliers(100), "vow builds buffer above 100 without extra economic bonus")
	p.add_relic("relic_reincarnation_hellfire_candle")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 102, "candle blocks subsequent vow recovery")
	p.free()
	var effect: Dictionary = DataRegistry.get_record("relics", "relic_runaway_amplifier").runtime_effects[0]
	check(effect.value == -5 and effect.else_value == -3, "condition execution preserves shared relic definition")


func _test_conditional_event_validation() -> void:
	var effect: Dictionary = DataRegistry.get_record("relics", "relic_runaway_amplifier").runtime_effects[0]
	var validator := DataValidator.new()
	validator._validate_relic_runtime_effect(effect, "test_amplifier")
	check(validator.errors.is_empty(), "conditional event accepts negative stat changes")
	for patch in [{"condition": "unknown"}, {"else_value": "invalid"}, {"threshold": "invalid"}]:
		var invalid := effect.duplicate(true)
		invalid.merge(patch, true)
		validator = DataValidator.new()
		validator._validate_relic_runtime_effect(invalid, "test_invalid_condition")
		check(not validator.errors.is_empty(), "conditional event rejects invalid config " + str(patch))
	var missing := effect.duplicate(true)
	missing.erase("condition")
	validator = DataValidator.new()
	validator._validate_relic_runtime_effect(missing, "test_missing_condition")
	check(not validator.errors.is_empty(), "conditional else amount requires a condition")


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
		check(p.get_stat("humanity") == 70 and p.get_stat("move_speed") == 290 and p.get_stat("armor") == 41, "dependency order independent " + str(ids))
		modify(p, "divinity", 0)
		check(p.get_stat("humanity") == 50 and p.get_stat("move_speed") == 272 and p.get_stat("armor") == 39, "dependency change recalculates condition and armor")
		p.free()


func _test_reward_remainders() -> void:
	var p := make_player()
	var manager := WaveManager.new()
	manager.player = p
	p.add_relic("relic_gold_compass")
	p.add_relic("relic_gold_digger_gloves")
	for i in 100: manager.add_exp_and_gold(1, 1)
	check(manager.collected_gold_this_wave == 110 and manager.collected_exp_this_wave == 108, "100 small pickups retain +10% gold and +8% XP")
	manager.free()
	manager = WaveManager.new()
	manager.player = p
	p.add_relic("relic_salary_adjustment")
	for i in 100: manager.add_exp_and_gold(1, 1)
	check(manager.current_gold == 100, "compass offsets the salary gold penalty")
	manager.free()
	manager = WaveManager.new()
	manager.player = p
	modify(p, "currency_gain_percent", -15)
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
	check(mismatches.is_empty(), "%d previews match real acquisition including finance, bonds and candle: " % (DataRegistry.get_table("relics").size() * 2) + JSON.stringify(mismatches))
	var p := make_player()
	var bank := make_finance(p)
	p.add_relic("relic_flyer_ad")
	p.add_relic("relic_flyer_ad")
	check(is_equal_approx(p.get_effective_shop_discount(), 15.36), "display two discounts as 15.36%")
	check(StatDefinitions.calculate_shop_cost_from_discounts(10000, p.get_shop_price_discount_layers()) == 8464, "discount display and price use same multiplier")
	p.add_relic("relic_salary_adjustment")
	check(is_equal_approx(p.get_effective_shop_discount(), 6.896), "display combined discount and surcharge")
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
