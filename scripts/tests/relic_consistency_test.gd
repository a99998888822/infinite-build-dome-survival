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
	_test_health_pickup_and_spawn_relics()
	_test_new_attribute_relics()
	_test_combat_attribute_relics()
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
	check(is_equal_approx(p.get_stat("hp_regen"), 0.25), "vitality relic regeneration halved")
	check(p.get_stat("divinity") == 5, "vitality applies fixed erosion on acquisition")
	for i in 3: p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("divinity") == 5, "vitality no longer accumulates erosion at wave end")
	p.add_relic("relic_vitality_potion")
	check(p.get_stat("divinity") == 10, "stacked vitality applies five erosion per copy")
	p.relic_system.remove_relic("relic_vitality_potion")
	check(p.get_stat("divinity") == 5, "removing vitality removes only its fixed erosion")
	p.add_relic("relic_turtle_shell_pendant")
	check(p.get_stat("max_hp") == 12, "confirmed turtle max HP +2")
	p.add_relic("relic_stargazers_lens")
	check(p.get_stat("luck") == 36, "stargazer luck is twice the original +18")
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


func _collect_health_pack(p: PlayerController) -> int:
	var pack := HealthPack.new()
	add_child(pack)
	pack.set_physics_process(false)
	pack.initialize(3)
	pack.set_target_player(p)
	var previous_hp := p.current_hp
	pack.collect()
	pack.collect()
	return p.current_hp - previous_hp


func _test_health_pickup_and_spawn_relics() -> void:
	var p := make_player()
	p.current_hp = 1
	check(_collect_health_pack(p) == 3, "ordinary health pack restores its authored amount only once")
	p.add_relic("relic_worn_hemostatic_cloth")
	p.current_hp = 1
	check(_collect_health_pack(p) == 4, "cloth increases actual pickup healing without altering base pack data")
	p.add_relic("relic_worn_hemostatic_cloth")
	p.current_hp = 1
	check(_collect_health_pack(p) == 5, "two cloths stack through actual health pickup collection")
	p.add_relic("relic_medical_cutback")
	p.current_hp = 1
	check(_collect_health_pack(p) == 4, "medical cutback subtracts one from the same pickup bonus")
	p.relic_system.remove_relic("relic_worn_hemostatic_cloth")
	p.current_hp = 1
	check(_collect_health_pack(p) == 3, "removing one cloth removes exactly one healing bonus")
	p.current_hp = int(p.get_stat("max_hp")) - 1
	check(_collect_health_pack(p) == 1, "boosted health packs still respect maximum health")
	p.free()
	p = make_player()
	var manager := WaveManager.new()
	manager.player = p
	var baseline := manager.calculate_enemy_spawn_count(6)
	p.add_relic("relic_harvest_sacrificial_vessel")
	check(is_equal_approx(manager.calculate_enemy_spawn_count(6), baseline * 1.05), "harvest increases the live scheduler count by five percent")
	p.add_relic("relic_harvest_sacrificial_vessel")
	check(is_equal_approx(manager.calculate_enemy_spawn_count(6), baseline * 1.10), "two harvest relics add ten points rather than multiplying each other")
	manager._wave_erosion_pressure = manager.calculate_enemy_erosion_pressure(20.0)
	var spawned := 0
	for index in 100: spawned += manager._take_enemy_spawn_count(6)
	check(spawned == roundi(baseline * 1.10 * 1.20 * 100), "fractional scheduled batches preserve both harvest and erosion multipliers")
	p.relic_system.remove_relic("relic_harvest_sacrificial_vessel")
	check(is_equal_approx(manager.calculate_enemy_spawn_count(6), baseline * 1.05 * 1.20), "removing harvest reduces the actual spawn supply while retaining erosion")
	manager.free()
	p.free()


func _test_new_attribute_relics() -> void:
	var p := make_player()
	check(p.add_relic("relic_crimson_coagulation_vial"), "acquire coagulation vial")
	p.current_hp = 1
	check(_collect_health_pack(p) == 4, "vial adds one actual pickup healing")
	check(p.add_relic("relic_crimson_coagulation_vial"), "vial accepts a second copy")
	check(is_equal_approx(p.get_stat("hp_regen"), 0.2), "two vials grant two tenths health per second")
	p.current_hp = 1
	p._process_regeneration(10.0)
	check(p.current_hp == 3, "two vials regenerate two actual health over ten seconds")
	p.add_relic("relic_worn_hemostatic_cloth")
	p.current_hp = 1
	check(_collect_health_pack(p) == 6, "two vials and cloth stack their actual pickup healing")
	p.add_relic("relic_vitality_potion")
	check(is_equal_approx(p.get_stat("hp_regen"), 0.45), "two vials stack with other positive regeneration")
	p.relic_system.remove_relic("relic_crimson_coagulation_vial")
	p.current_hp = 1
	check(_collect_health_pack(p) == 5, "removing one vial retains the other vial and cloth healing")
	check(is_equal_approx(p.get_stat("hp_regen"), 0.35), "removing one vial retains the other regeneration sources")
	p.relic_system.remove_relic("relic_crimson_coagulation_vial")
	check(is_equal_approx(p.get_stat("hp_regen"), 0.25), "removing both vials retains the original regeneration source")
	p.current_hp = int(p.get_stat("max_hp")) - 1
	check(_collect_health_pack(p) == 1, "new healing relics still respect maximum health")
	p.free()
	p = make_player()
	var manager := WaveManager.new()
	manager.player = p
	var baseline := manager.calculate_enemy_spawn_count(6)
	var pickup_baseline := p.get_stat("pickup_radius")
	for count in range(1, 6):
		check(p.add_relic("relic_hunting_bone_whistle"), "bone whistle copy %d is accepted" % count)
	check(is_equal_approx(p.get_stat("pickup_radius"), pickup_baseline + 75), "five whistles increase pickup range by seventy-five")
	check(p.get_stat("armor") == 25, "five whistles also grant twenty-five armor")
	check(p.add_relic("relic_hungry_tide_bell"), "acquire rusted ritual bell")
	check(p.add_relic("relic_hungry_tide_bell"), "rusted bell accepts a second copy")
	check(p.get_stat("drop_rate_percent") == 24 and p.get_stat("max_hp") == 20, "two rusted bells stack drop rate and maximum health")
	p.add_relic("relic_harvest_sacrificial_vessel")
	check(is_equal_approx(manager.calculate_enemy_spawn_count(6), baseline * 1.50), "five whistles two bells and harvest add fifty spawn percentage points")
	manager._wave_erosion_pressure = manager.calculate_enemy_erosion_pressure(20.0)
	var spawned := 0
	for index in 100: spawned += manager._take_enemy_spawn_count(6)
	check(spawned == roundi(baseline * 1.50 * 1.20 * 100), "new spawn bonuses preserve fractional batches and erosion multiplication")
	p.relic_system.remove_relic("relic_hungry_tide_bell")
	p.relic_system.remove_relic("relic_hunting_bone_whistle")
	check(is_equal_approx(manager.calculate_enemy_spawn_count(6), baseline * 1.35 * 1.20), "removal subtracts one bell and one whistle from live spawn supply")
	check(p.get_stat("armor") == 20 and p.get_stat("max_hp") == 13, "removal withdraws only one bell health and one whistle armor bonus")
	manager.free()
	p.free()
	p = make_player()
	var bank := make_finance(p)
	bank.prepare_wave(1)
	bank.deposit(1000, true)
	var base_rate := bank.get_interest_rate()
	var base_sanity := p.get_stat("humanity")
	p.add_relic("relic_void_market_key")
	check(is_equal_approx(bank.get_interest_rate(), base_rate + 2.0), "market key increases live bank rate by two percentage points")
	check(bank.settle_interest().gain == 70, "market key pays seventy interest on one thousand principal")
	check(p.add_relic("relic_void_market_key"), "market key accepts a second copy")
	check(is_equal_approx(bank.get_interest_rate(), base_rate + 4.0) and bank.settle_interest().gain == 90, "two market keys pay ninety interest on one thousand principal")
	check(p.get_stat("humanity") == base_sanity, "market key no longer costs sanity")
	p.relic_system.remove_relic("relic_void_market_key")
	check(is_equal_approx(bank.get_interest_rate(), base_rate + 2.0), "removing one market key retains the other key rate bonus")
	p.relic_system.remove_relic("relic_void_market_key")
	check(is_equal_approx(bank.get_interest_rate(), base_rate), "removing both market keys restores the original interest rate")
	p.free()
	# Extra choices remain rare to obtain, while owned copies can now stack.
	for record: Dictionary in DataRegistry.get_table("relics"):
		for effect: Dictionary in record.get("effects", []):
			if str(effect.get("stat", "")) == "shop_offer_count_bonus" and float(effect.get("value", 0)) > 0:
				check(str(record.get("rarity", "")) in ["mythic", "legendary"], "extra shop choices remain high rarity: " + str(record.id))
	var new_ids := ["relic_crimson_coagulation_vial", "relic_goblin_trade_charter", "relic_void_market_key", "relic_hunting_bone_whistle", "relic_hungry_tide_bell"]
	var many_owned := {}
	var generator := ShopOfferGenerator.new()
	var pool := generator.build_shop_candidate_pool({"luck": 350})
	for id: String in new_ids:
		check(pool.any(func(offer): return str(offer.get("target_id", "")) == id), "new relic is available in normal shop pool: " + id)
		check(int(DataRegistry.get_record("relics", id).max_stack) == 0, "confirmed relic has no stack cap: " + id)
		many_owned[id] = 100
	var repeated_pool := generator.build_shop_candidate_pool({"luck": 350, "owned_relic_counts": many_owned})
	for id: String in new_ids:
		check(repeated_pool.any(func(offer): return str(offer.get("target_id", "")) == id), "relic stays in the pool after one hundred copies: " + id)


func _test_combat_attribute_relics() -> void:
	var p := make_player()
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", p)
	var base_chance := weapon.get_stat("crit_chance")
	var base_interval := weapon.get_actual_attack_interval_seconds()
	p.add_relic("relic_falcon_sighting_pin")
	check(is_equal_approx(weapon.get_stat("crit_chance"), base_chance + 10), "pin adds ten crit percentage points to real weapon")
	check(weapon.get_actual_attack_interval_seconds() < base_interval, "sighting pin reduces actual weapon cooldown")
	p.add_relic("relic_falcon_sighting_pin")
	p.relic_system.remove_relic("relic_falcon_sighting_pin")
	check(is_equal_approx(weapon.get_stat("crit_chance"), base_chance + 10), "removing one stacked pin retains the other pin")
	for i in 10: p.add_relic("relic_falcon_sighting_pin")
	check(weapon.get_stat("crit_chance") == 100 and weapon.calculate_damage_events()[0].is_critical, "unlimited pins still respect crit cap and trigger actual critical hit")
	p.free()
	p = make_player()
	weapon = WeaponInstance.new()
	weapon.initialize("weapon_void_blade", p)
	var base_damage := weapon.get_base_attack_damage()
	p.add_relic("relic_executioner_whetstone")
	check(weapon.get_stat("crit_damage") == 170, "whetstone increases default crit multiplier to 170 percent")
	check(weapon.calculate_damage_events(true)[0].damage == roundi(base_damage * 1.7), "whetstone increases actual critical damage without adding melee bonus to ranged weapon")
	p.add_relic("relic_crimson_execution_seal")
	check(weapon.get_stat("crit_damage") == 200 and weapon.calculate_damage_events(true)[0].damage == roundi(base_damage * 1.1 * 2.0), "confirmed seal adds thirty crit points and combines general damage in real hit")
	check(p.get_stat("max_hp") == 7 and p.current_hp == 7, "seal health cost trims current health to reduced maximum")
	p.relic_system.remove_relic("relic_crimson_execution_seal")
	check(p.get_stat("max_hp") == 10 and p.current_hp == 7 and weapon.get_stat("crit_damage") == 170, "removing seal restores cap and retains whetstone without healing")
	p.free()
	p = make_player()
	p.add_relic("relic_faded_ward_talisman")
	check(p.current_shield == 0, "acquiring initial-shield relics does not refill current shield")
	p.reset_wave_shield()
	check(p.current_shield == 4 and p.current_shield_capacity == 4, "next wave initializes talisman shield to four")
	p.current_shield = 3
	p.add_relic("relic_faded_ward_talisman")
	check(p.current_shield == 3, "stacking talisman mid-wave does not refill spent shield")
	p.reset_wave_shield()
	check(p.current_shield == 8, "stacked talismans apply on following wave")
	p.relic_system.remove_relic("relic_faded_ward_talisman")
	p.reset_wave_shield()
	check(p.current_shield == 4, "removing one talisman retains the other talisman shield")
	p.free()
	for weapon_id in ["weapon_void_blade", "weapon_plasma_cannon"]:
		p = make_player()
		weapon = WeaponInstance.new()
		weapon.initialize(weapon_id, p)
		var original_count := weapon.get_projectile_angles().size()
		base_interval = weapon.get_actual_attack_interval_seconds()
		base_damage = weapon.get_base_attack_damage()
		p.add_relic("relic_twin_chamber_magazine")
		check(weapon.get_projectile_angles().size() == original_count + 1 and weapon.get_actual_attack_interval_seconds() > base_interval, "magazine adds actual shot and lengthens cooldown: " + weapon_id)
		p.add_relic("relic_twin_chamber_magazine")
		check(weapon.get_projectile_angles().size() == original_count + 2 and weapon.get_stat("attack_speed") == -30, "two magazines stack projectile outputs and attack speed cost: " + weapon_id)
		check(weapon._build_damage_event(weapon.get_attack_kind(), false, false).damage == maxi(1, roundi(base_damage)), "magazine affects cooldown but retains per-hit damage: " + weapon_id)
		p.relic_system.remove_relic("relic_twin_chamber_magazine")
		check(weapon.get_projectile_angles().size() == original_count + 1 and weapon.get_stat("attack_speed") == -15, "removing one magazine retains the other magazine output and cost: " + weapon_id)
		p.free()
	p = make_player()
	weapon = WeaponInstance.new()
	weapon.initialize("weapon_plasma_cannon", p)
	p.add_relic("relic_stilltime_amber")
	var event := weapon.calculate_damage_events(true)[0]
	check(event.control_power == 20, "amber propagates twenty control power into damage event")
	var enemy := EnemyController.new()
	enemy.initialize("enemy_mutated_grub", p)
	enemy.apply_slow(2.0, 0.5, event.control_power)
	check(is_equal_approx(enemy._slowed_remaining, 2.4), "amber extends actual two-second slow to 2.4 seconds")
	enemy.apply_freeze(1.0, {}, event.control_power)
	check(is_equal_approx(enemy._frozen_remaining, 1.2), "amber extends actual one-second freeze to 1.2 seconds")
	p.relic_system.remove_relic("relic_stilltime_amber")
	check(weapon.calculate_damage_events(true)[0].control_power == 0 and event.control_power == 20, "removing amber updates new hits while in-flight hit retains its control snapshot")
	enemy.initialize("enemy_mutated_grub", p)
	enemy.apply_freeze(1.0)
	check(is_equal_approx(enemy._frozen_remaining, 1.0), "removal restores base duration for next control")
	for i in 6: p.add_relic("relic_stilltime_amber")
	enemy.initialize("enemy_mutated_grub", p)
	enemy.apply_freeze(1.0)
	check(p.get_stat("control_power") == 100 and is_equal_approx(enemy._frozen_remaining, 2.0), "unlimited amber respects control cap and doubles base duration")
	enemy.free()
	p.free()
	var ids := ["relic_falcon_sighting_pin", "relic_executioner_whetstone", "relic_crimson_execution_seal", "relic_faded_ward_talisman", "relic_twin_chamber_magazine", "relic_stilltime_amber"]
	var owned := {}
	for id: String in ids: owned[id] = 100
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool({"luck": 350, "owned_relic_counts": owned})
	for id: String in ids:
		check(int(DataRegistry.get_record("relics", id).max_stack) == 0 and pool.any(func(offer): return str(offer.get("target_id", "")) == id), "combat relic remains available beyond one hundred copies: " + id)


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
		check(p.get_stat("damage_percent") == 6 and p.get_stat("humanity") == 97, "all positive settlements apply frenzy growth and cost deposit=%d" % deposited)
		if deposited == 0:
			var manual := bank.trigger_manual_interest()
			check(manual.gain > 0 and not manual.blocked and is_equal_approx(bank.interest_rate_bonus, 0.8), "manual positive interest also grows tome")
		p.free()
	var p := make_player()
	var bank := make_finance(p)
	p.add_relic("relic_divine_fusion")
	bank.deposit(1000, true)
	modify(p, "divinity", 5)
	check(is_equal_approx(bank.get_interest_rate(), 7.2), "fusion combines two base points with immediate erosion scaling")
	check(bank.settle_interest().gain == 72, "first settlement uses current fusion rate")
	p.add_relic("relic_compound_interest_tome")
	bank.settle_interest()
	check(is_equal_approx(StatPreviewBuilder.get_display_stat_value(p, "interest_rate", bank), 8.4), "HUD rate includes static and growing tome plus fusion")
	p.add_relic("relic_void_tentacle")
	p.reset_wave_shield()
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_START)
	modify(p, "divinity", 9)
	p.take_damage(20)
	check(p.get_stat("divinity") == 10 and is_equal_approx(bank.get_interest_rate(), 8.6), "shield-break erosion refreshes fusion immediately")
	p.free()


func _test_confirmed_balance() -> void:
	var p := make_player()
	p.add_relic("relic_nightmare_healing_urn")
	check(p.get_stat("humanity") == 92, "urn applies eight fixed sanity cost immediately")
	p.current_hp = 5
	p._physics_process(1.25)
	check(is_equal_approx(p.get_stat("hp_regen"), 0.4) and p.current_hp == 5, "urn keeps fractional half HP after 1.25 seconds")
	p._physics_process(1.25)
	check(p.current_hp == 6, "halved urn regenerates one HP in 2.5 seconds")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 92, "urn no longer loses sanity each wave")
	p.add_relic("relic_guarding_heart_copper_mirror")
	check(p.get_stat("luck") == 36 and p.get_stat("currency_gain_percent") == 20, "mirror grants doubled luck and twenty percent gold")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 93, "mirror recovers sanity without any urn decay")
	p.relic_system.remove_relic("relic_nightmare_healing_urn")
	check(p.get_stat("humanity") == 101, "removing urn reverses fixed cost and preserves earned recovery")
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
	check(p.get_stat("humanity") == 99, "ledger wave-end sanity minus one")
	modify(p, "humanity", -100)
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == -2, "ledger decay continues below zero")
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
	check(p.get_stat("damage_percent") == 4 and p.get_stat("humanity") == 98, "two successful payouts grant damage four and sanity minus two")
	bank.trigger_manual_interest()
	check(p.get_stat("damage_percent") == 6 and p.get_stat("humanity") == 97, "manual positive settlement triggers frenzy once")
	p.add_relic("relic_high_yield_contract")
	bank.process_wave_end_settlements()
	check(p.get_stat("damage_percent") == 10 and p.get_stat("humanity") == 95, "unqualified contract still permits positive settlements and frenzy")
	bank.principal = 1
	bank.interest_remainder = 0
	modify(p, "humanity", -300)
	var zero_gain := bank.trigger_manual_interest()
	check(zero_gain.gain == 0 and p.get_stat("damage_percent") == 10 and p.get_stat("humanity") == -205, "zero integer payout accrues fractions without triggering frenzy")
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
	for row in [[6, 2, 5], [5, 1, 5], [10, 1, 10]]:
		var p := make_player()
		p.add_relic("relic_void_tentacle")
		p.current_hp = row[0]
		p.current_shield = 1
		p.take_damage(row[1], "nonlethal_shield_break")
		check(p.alive and p.current_hp == row[2] and p.current_shield == 0 and p.get_stat("divinity") == 1, "nonlethal shield break adds erosion without healing " + str(row))
		p._invincibility_timer = 0.0
		p.take_damage(1, "already_empty_shield")
		check(p.get_stat("divinity") == 1 and p.current_hp == row[2] - 1, "damage while shield is already empty does not trigger another break")
		p._invincibility_timer = 0.0
		p._process_regeneration(1.0)
		p.take_damage(1, "regenerated_shield_break")
		check(p.get_stat("divinity") == 2 and p.current_hp == row[2] - 1, "regenerated shield triggers new erosion without healing when depleted again")
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
	check(p.get_stat("damage_percent") == 57 and p.get_stat("humanity") == 92, "tradeoff relic damage bonuses use additive damage stat")
	p.free()
	p = make_player()
	var bank := make_finance(p)
	bank.deposit(500, true)
	p.add_relic("relic_gilded_trigger")
	check(p.get_stat("damage_percent") == 25 and p.get_stat("humanity") == 92, "gilded trigger trades eight sanity for twenty-five damage")
	var economy := HumanityEconomy.get_multipliers(p.get_stat("humanity"))
	check(is_equal_approx(economy.purchase, 1.016) and is_equal_approx(economy.sale, 1.0 / 1.016), "trigger immediately changes purchase and sale economics")
	var settlement := bank.settle_interest()
	check(settlement.gain == 23 and is_equal_approx(bank.interest_remainder, 4.0 / 27.0), "trigger reduces actual interest with fractional carry")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 92, "trigger sanity cost is not repeated at wave end")
	p.free()
	for row in [[100, 99, 98], [0, -1, -3], [-1, -3, -5]]:
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
				var expected: int = starting_sanity - (2 if starting_sanity < 0 else 1) + (-1 if companion == "relic_sleepless_ledger" else 2)
				check(p.get_stat("humanity") == expected, "wave-end condition snapshot companion=%s sanity=%s reversed=%s" % [companion, starting_sanity, reversed])
				p.free()
	p = make_player()
	p.add_relic("relic_runaway_amplifier")
	p.add_relic("relic_lucid_vow")
	for i in 5: p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("damage_percent") == 32 and p.get_stat("humanity") == 105, "unchanged vow exceeds amplifier decay while retaining thirty-two damage")
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
	check(effect.value == -2 and effect.else_value == -1, "condition execution preserves shared relic definition")


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
	p.add_relic("relic_chain_of_hardship")
	for sample in [[0, 15], [1, 15], [2, 16], [3, 16], [12, 21], [25, 27]]:
		modify(p, "divinity", sample[0])
		check(p.get_stat("armor") == sample[1], "chain grants armor per full two erosion at %d" % sample[0])
	p.add_relic("relic_chain_of_hardship")
	check(p.get_stat("armor") == 54, "chain keeps existing stack rules for fixed and derived armor")
	p.free()
	p = make_player()
	p.add_relic("relic_soul_keeper_face_stone")
	for sample in [[0, 100], [1, 100], [2, 100], [3, 101], [5, 101], [6, 102], [299, 199], [300, 200], [1000, 433]]:
		modify(p, "divinity", sample[0])
		check(p.get_stat("humanity") == sample[1] and p.get_stat("max_hp") == 15, "soul stone grants sanity per three erosion at %d" % sample[0])
	p.free()
	p = make_player()
	p.add_relic("relic_amulet_of_humanity")
	p.add_relic("relic_reincarnation_hellfire_candle")
	check(p.get_stat("humanity") == 112, "candle preserves preexisting sanity bonus")
	p.add_relic("relic_amulet_of_humanity")
	p.add_relic("relic_guarding_heart_copper_mirror")
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("humanity") == 112 and p.get_stat("divinity") == 4, "candle blocks new static and wave-end sanity gains while adding four erosion")
	p.add_relic("relic_soul_keeper_face_stone")
	modify(p, "divinity", 20)
	check(p.get_stat("humanity") == 112, "new soul stone cannot bypass candle")
	p.free()
	p = make_player()
	modify(p, "divinity", 20)
	p.add_relic("relic_soul_keeper_face_stone")
	p.add_relic("relic_reincarnation_hellfire_candle")
	check(p.get_stat("humanity") == 106, "candle preserves existing derived sanity")
	modify(p, "divinity", 30)
	check(p.get_stat("humanity") == 106, "existing stone cannot gain more sanity")
	modify(p, "divinity", 10)
	check(p.get_stat("humanity") == 103, "blocked derived sanity can decrease")
	modify(p, "divinity", 30)
	check(p.get_stat("humanity") == 103, "blocked derived sanity cannot recover after decrease")
	p.free()
	var permutations := [
		["relic_lost_wayfarer_greave", "relic_soul_keeper_face_stone", "relic_shadowless_greave"],
		["relic_shadowless_greave", "relic_lost_wayfarer_greave", "relic_soul_keeper_face_stone"],
		["relic_soul_keeper_face_stone", "relic_shadowless_greave", "relic_lost_wayfarer_greave"],
	]
	for ids in permutations:
		p = make_player()
		modify(p, "humanity", -50)
		modify(p, "divinity", 60)
		for id in ids: p.add_relic(id)
		check(p.get_stat("humanity") == 70 and p.get_stat("move_speed") == 170 and p.get_stat("armor") == 29, "dependency order independent " + str(ids))
		modify(p, "divinity", 0)
		check(p.get_stat("humanity") == 50 and p.get_stat("move_speed") == 152 and p.get_stat("armor") == 27, "dependency change recalculates condition and armor")
		p.free()


func _test_reward_remainders() -> void:
	var p := make_player()
	var manager := WaveManager.new()
	manager.player = p
	p.add_relic("relic_gold_compass")
	p.add_relic("relic_gold_digger_gloves")
	for i in 100: manager.add_exp_and_gold(1, 1)
	check(manager.collected_gold_this_wave == 108 and manager.collected_exp_this_wave == 108, "100 small pickups retain +8% gold and +8% XP")
	manager.free()
	manager = WaveManager.new()
	manager.player = p
	p.add_relic("relic_salary_adjustment")
	for i in 100: manager.add_exp_and_gold(1, 1)
	check(manager.current_gold == 98, "compass leaves two percent of the salary gold penalty")
	manager.free()
	manager = WaveManager.new()
	manager.player = p
	modify(p, "currency_gain_percent", -15)
	manager.add_exp_and_gold(1, 1)
	manager.collected_gold_this_wave = 0
	for i in 19: manager.add_exp_and_gold(1, 1)
	check(manager.current_gold == 16, "fractional rewards survive wave counter reset")
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
	check(not preview.has("finance") and bank.principal == 0 and p.remaining_revives == 0 and not bank._bankruptcy_triggered, "buying bankruptcy at zero principal does not replay a previous withdrawal")
	p.free()
