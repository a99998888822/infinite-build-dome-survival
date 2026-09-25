extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func make_player() -> PlayerController:
	var p := PlayerController.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.initialize_from_character("character_void_hunter")
	p.set_physics_process(false)
	return p


func make_bank(p: PlayerController) -> BattleFinanceSystem:
	var bank := BattleFinanceSystem.new()
	var wallet := {"value": 2000}
	bank.initialize(p, func(): return wallet.value, func(delta, _reason): wallet.value += delta; return true)
	p.relic_added.connect(bank.on_relic_added)
	bank.prepare_wave(1)
	return bank


func hit_expectation(w: WeaponInstance) -> float:
	var chance := w.get_stat("crit_chance") / 100.0
	var original: float = w.runtime_stats.get("crit_chance", 0.0)
	w.runtime_stats["crit_chance"] = -1000.0
	var normal := w.calculate_damage_events()[0].damage
	var critical := w.calculate_damage_events(true)[0].damage
	w.runtime_stats["crit_chance"] = original
	return normal * (1.0 - chance) + critical * chance


func _run() -> void:
	_test_revive_consumption()
	_test_contract()
	_test_combat_and_limits()
	_test_validation()
	print("RELIC_BALANCE_COMPLETE checks=%d failures=%d" % [checks, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _test_revive_consumption() -> void:
	var p := make_player()
	var bank := make_bank(p)
	p.add_relic("relic_costly_seed_of_life")
	check(p.remaining_revives == 1, "seed grants one available revive")
	p.take_damage(99999)
	check(p.alive and p.remaining_revives == 0 and p.get_stat("divinity") == 20, "seed revive is consumed and still costs erosion")
	for id in ["relic_piggy_bank", "relic_coin_heart", "relic_compound_interest_tome", "relic_high_yield_contract"]:
		var prediction := StatPreviewBuilder.build_offer_stat_preview({"offer_type": "relic", "target_id": id}, p, bank)
		check(not prediction.has("revive_count") and p.remaining_revives == 0, "preview cannot replenish spent revive: " + id)
		p.add_relic(id)
		check(p.remaining_revives == 0, "purchase cannot replenish spent revive: " + id)
	p.sync_relic_weapon_ids(["weapon_void_blade", "weapon_plasma_cannon"])
	check(p.remaining_revives == 0, "weapon and bond refresh cannot replenish spent revive")
	bank.apply_finance_operation("deposit", 50)
	bank.begin_wave(1)
	bank.settle_interest()
	check(p.remaining_revives == 0, "finance and derived-stat refresh cannot replenish spent revive")
	# A genuinely new source must still grant its charge after the seed is spent.
	bank.prepare_wave(2)
	p.add_relic("relic_bankruptcy_reorg")
	bank.apply_finance_operation("withdraw", bank.principal)
	check(p.remaining_revives == 1, "new bankruptcy reward grants one new revive")
	p._invincibility_timer = 0.0
	p.take_damage(99999)
	check(p.alive and p.remaining_revives == 0 and p.get_stat("divinity") == 40, "second genuine charge is consumed normally")
	p.relic_system.refresh_effects()
	check(p.remaining_revives == 0, "refresh preserves both spent charges")
	p._invincibility_timer = 0.0
	p.take_damage(99999)
	check(not p.alive, "no unearned third revive")
	p.free()
	p = make_player()
	p.add_relic("relic_costly_seed_of_life")
	check(p.remaining_revives == 1, "new run can acquire a fresh seed charge")
	p.free()


func _test_contract() -> void:
	for amount in [0, 49, 50]:
		var p := make_player()
		var bank := make_bank(p)
		bank.deposit(1000, true, "gift")
		p.add_relic("relic_high_yield_contract")
		check(bank.get_interest_rate() == 5 and bank.get_estimated_interest() == 50, "gift principal never qualifies contract")
		var preview_player := p.create_stat_preview_copy()
		var preview := bank.create_preview_copy(preview_player)
		if amount > 0:
			preview.apply_finance_operation("deposit", amount)
			bank.apply_finance_operation("deposit", amount)
		check(preview.get_interest_rate() == bank.get_interest_rate() and preview.principal == bank.principal, "deposit preview matches committed conditional rate")
		preview_player.free()
		var payload := bank.build_finance_popup_payload()
		check(payload.has_high_yield_contract and payload.deposit_bonus_rate == 6 and payload.deposit_bonus_active == (amount >= 50), "contract UI exposes bonus eligibility")
		check(bank.get_interest_rate() == (11 if amount >= 50 else 5), "contract exact 49/50 boundary")
		var popup := load("res://scenes/ui/finance/finance_popup.tscn").instantiate() as FinancePopup
		add_child(popup)
		popup.configure(payload)
		check(popup._contract.text.contains("已 +6") if amount >= 50 else popup._contract.text.contains("仍正常结息"), "finance UI describes the actual bonus rule")
		popup.free()
		bank.begin_wave(1)
		var result := bank.settle_interest()
		check(result.success and not result.blocked and result.gain == (116 if amount >= 50 else (53 if amount == 49 else 50)), "qualified bonus or ordinary interest pays correctly")
		bank.prepare_wave(2)
		check(bank.get_interest_rate() == 5 and not bank.build_finance_popup_payload().deposit_bonus_active, "new wave clears conditional bonus without changing permanent rates")
		bank.begin_wave(2)
		bank.deposit(50)
		check(bank.get_interest_rate() == 5, "deposit after combat starts cannot qualify retroactively")
		p.free()
	var p := make_player()
	var bank := make_bank(p)
	bank.apply_finance_operation("deposit", 50)
	p.add_relic("relic_high_yield_contract")
	check(bank.get_interest_rate() == 11, "buying contract after a valid preparatory deposit qualifies")
	p.free()


func _test_combat_and_limits() -> void:
	for record in DataRegistry.get_table("weapons"):
		var p := make_player()
		var w := WeaponInstance.new()
		w.initialize(str(record.id), p)
		var before := hit_expectation(w)
		p.add_relic("relic_judgment_eye_pendant")
		check(hit_expectation(w) > before, "judgment eye improves base expected hit: " + str(record.id))
		p.free()
		p = make_player()
		w = WeaponInstance.new()
		w.initialize(str(record.id), p)
		before = hit_expectation(w)
		var interval := w.get_actual_attack_interval_seconds()
		p.add_relic("relic_gale_roulette")
		check(w.get_stat("damage_percent") == -8 and w.get_actual_attack_interval_seconds() < interval, "gale cost reaches every damage type: " + str(record.id))
		check(hit_expectation(w) / w.get_actual_attack_interval_seconds() > before / interval, "gale retains positive base attack throughput: " + str(record.id))
		p.free()
	var p := make_player()
	var bank := make_bank(p)
	bank.prepare_wave(10)
	p.add_relic("relic_fixed_deposit_certificate")
	check(bank.principal == 200 and not p.add_relic("relic_fixed_deposit_certificate") and bank.principal == 200, "certificate pays 200 at wave ten only once")
	check(bank.apply_finance_operation("withdraw", 200).success, "certificate principal remains normally withdrawable")
	check(p.add_relic("relic_split_crystal_warhead") and not p.add_relic("relic_split_crystal_warhead"), "split warhead cannot accumulate damage penalties through extra copies")
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool({"owned_relic_counts": p.get_relic_counts()})
	check(pool.all(func(offer): return offer.get("target_id", "") not in ["relic_split_crystal_warhead", "relic_fixed_deposit_certificate"]), "both new limits remove owned relics from shop candidates")
	p.free()


func _test_validation() -> void:
	for bad in [
		{"trigger": "derived", "effect": "interest_rate_on_wave_deposit", "value": 6},
		{"trigger": "derived", "effect": "interest_rate_on_wave_deposit", "minimum_deposit": 0, "value": 6},
		{"trigger": "wave_end", "effect": "interest_rate_on_wave_deposit", "minimum_deposit": 50, "value": 6},
	]:
		var validator := DataValidator.new()
		validator._validate_relic_runtime_effect(bad, "contract")
		check(not validator.errors.is_empty(), "reject malformed conditional interest configuration")
