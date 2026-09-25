extends Node

var checks := 0
var failures := 0
const IDS := ["relic_coin_heart", "relic_hoarders_ring", "relic_golden_sarcophagus"]


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func make_player() -> PlayerController:
	var p := PlayerController.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.initialize_from_character("character_void_hunter")
	# Isolate principal tiers and revive rounding from the starting-health balance.
	p.modifier_stack.set_base_stat("max_hp", 10)
	p.restore_full_health()
	p.set_physics_process(false)
	return p


func make_bank(p: PlayerController) -> BattleFinanceSystem:
	var bank := BattleFinanceSystem.new()
	var gold := {"value": 2000}
	bank.initialize(p, func(): return gold.value, func(delta, _reason): gold.value += delta; return true)
	p.relic_added.connect(bank.on_relic_added)
	return bank


func fatal_hit(p: PlayerController) -> void:
	p._invincibility_timer = 0.0
	p.take_damage(1000000, "principal_relic_test")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_catalog()
	_test_heart()
	_test_ring()
	_test_protection()
	_test_revive_priority_and_preview()
	_test_validator()
	await _test_bank_ui()
	print("PRINCIPAL_RELIC_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_catalog() -> void:
	check(DataRegistry.get_load_errors().is_empty(), "catalog loads with signed principal scaling and lethal event")
	var p := make_player()
	var generator := ShopOfferGenerator.new()
	var pool := generator.build_shop_candidate_pool({})
	for id in IDS:
		check(pool.any(func(offer): return offer.get("target_id", "") == id), id + " enters offer pool")
		check(p.add_relic(id) and not p.add_relic(id), id + " accepts one copy")
		check(ResourceLoader.exists(str(DataRegistry.get_record("relics", id).icon)), id + " has imported icon")
	pool = generator.build_shop_candidate_pool({"owned_relic_counts": p.get_relic_counts()})
	check(pool.all(func(offer): return offer.get("target_id", "") not in IDS), "owned capped relics leave offers")
	p.free()


func _test_heart() -> void:
	var p := make_player()
	var bank := make_bank(p)
	p.add_relic("relic_coin_heart")
	bank.deposit(99, true)
	check(p.get_stat("max_hp") == 10, "heart only awards full principal tiers")
	bank.deposit(1, true)
	check(p.get_stat("max_hp") == 11 and p.current_hp == 10, "heart increases maximum without healing")
	bank.deposit(900, true)
	check(p.get_stat("max_hp") == 20 and p.current_hp == 10, "heart grows through multiple tiers")
	p.restore_full_health()
	bank.withdraw(101)
	check(p.get_stat("max_hp") == 18 and p.current_hp == 18, "withdrawal removes tiers and clamps excess current HP")
	bank.deposit(101, true)
	check(p.get_stat("max_hp") == 20 and p.current_hp == 18, "redeposit cannot refill lost HP")
	p.current_hp = 7
	bank.withdraw(1000)
	check(p.get_stat("max_hp") == 10 and p.current_hp == 7, "principal removal preserves injured HP below new cap")
	bank.deposit(100000, true)
	check(p.get_stat("max_hp") == 1010 and p.current_hp == 7, "heart principal scaling has no additional cap")
	p.add_relic("relic_piggy_bank")
	check(p.current_hp == 7 and p.get_stat("max_hp") == 1010, "unrelated relic rebuild does not damage or heal heart owner")
	p.free()


func _test_ring() -> void:
	var p := make_player()
	var bank := make_bank(p)
	p.add_relic("relic_hoarders_ring")
	bank.deposit(499, true)
	check(p.get_stat("currency_gain_percent") == 0 and p.get_stat("humanity") == 100, "ring has no incomplete-tier bonus or penalty")
	bank.deposit(1, true)
	check(p.get_stat("currency_gain_percent") == 10 and p.get_stat("humanity") == 98, "ring first tier grants ten percent gold and removes two sanity")
	for i in 4: bank._emit_changed()
	check(p.get_stat("humanity") == 98, "ring refresh never accumulates sanity cost")
	var factors := HumanityEconomy.get_multipliers(p.get_stat("humanity"))
	check(factors.purchase > 1 and factors.sale < 1 and factors.interest < 1, "ring sanity affects all three economic rates")
	check(bank.settle_interest().gain == 24, "ring reduces actual interest payout")
	bank.withdraw(bank.principal)
	check(p.get_stat("humanity") == 100 and p.get_stat("currency_gain_percent") == 0, "zero principal revokes both sides of ring")
	bank.deposit(490, true)
	var settled := bank.settle_interest()
	check(settled.gain == 25 and bank.principal == 490 and p.get_stat("humanity") == 100, "cash interest cannot cross a principal tier or add ring sanity cost")
	bank.deposit(50000 - bank.principal, true)
	check(p.get_stat("humanity") == -100 and p.get_stat("currency_gain_percent") == 1000, "ring penalty and bonus keep growing past negative sanity")
	bank.withdraw(bank.principal - 1000)
	check(p.get_stat("humanity") == 96 and p.get_stat("currency_gain_percent") == 20, "withdrawal restores exact reversible ring tiers")
	p.add_relic("relic_reincarnation_hellfire_candle")
	bank.withdraw(1000)
	check(p.get_stat("humanity") == 96 and p.get_stat("currency_gain_percent") == 0, "candle blocks ring sanity recovery but removes gold bonus")
	bank.deposit(500, true)
	check(p.get_stat("humanity") == 96, "ring cannot recover blocked sanity by refreshing lower tier")
	bank.deposit(1000, true)
	check(p.get_stat("humanity") == 94, "ring can still deepen sanity cost under candle")
	p.free()
	for reverse_order in [false, true]:
		p = make_player()
		bank = make_bank(p)
		bank.deposit(500, true)
		p.modifier_stack.set_base_stat("humanity", 61)
		var order := ["relic_hoarders_ring", "relic_lost_wayfarer_greave", "relic_shadowless_greave"]
		if reverse_order: order.reverse()
		for id in order: p.add_relic(id)
		var slow_speed := p.get_stat("move_speed")
		bank.withdraw(1)
		check(p.get_stat("humanity") == 61 and p.get_stat("move_speed") == slow_speed + 18, "ring tiers refresh dependent movement regardless of acquisition order")
		p.free()


func _test_protection() -> void:
	for principal in [0, 999]:
		var p := make_player()
		var bank := make_bank(p)
		p.add_relic("relic_golden_sarcophagus")
		if principal > 0: bank.deposit(principal, true)
		fatal_hit(p)
		check(not p.is_alive() and bank.principal == principal and bank.get_principal_revive_state().remaining_uses == 1, "insufficient principal cannot revive or consume charge at %d" % principal)
		p.free()
	var p := make_player()
	var bank := make_bank(p)
	for id in IDS + ["relic_steel_vault", "relic_quant_trading", "relic_hostile_takeover", "relic_merger_reorg"]: p.add_relic(id)
	bank.deposit(1000, true)
	bank.interest_remainder = 0.75
	var wallet := bank.get_current_gold()
	var load_before := p.get_stat("load_capacity")
	var events := {"revived": 0, "died": 0, "interest": 0}
	p.revived.connect(func(_charges): events.revived += 1)
	p.died.connect(func(): events.died += 1)
	bank.interest_settled.connect(func(_result): events.interest += 1)
	# A synchronous observer attempting another hit must not consume protection twice.
	bank.finance_changed.connect(func(_snapshot):
		if p.current_hp == 0: p.take_damage(1000000, "reentrant_observer")
	)
	check(bank.get_principal_revive_state().available, "coffin ready at exact 1000 threshold")
	check(p.take_damage(1) > 0 and bank.principal == 1000, "nonlethal damage spends no principal")
	check(bank.get_principal_revive_state().remaining_uses == 1, "nonlethal damage spends no charge")
	fatal_hit(p)
	check(p.is_alive() and p.current_hp == 8 and p.get_stat("max_hp") == 15, "coffin restores half of post-payment maximum health rounded up")
	check(bank.principal == 500 and bank.get_current_gold() == wallet, "coffin spends principal without crediting wallet")
	check(p.get_stat("armor") == 10 and p.get_stat("attack_speed") == 10 and p.get_stat("damage_percent") == 5 and p.get_stat("load_capacity") == load_before - 5, "coffin cost recalculates armor speed damage and load")
	check(p.get_stat("humanity") == 98 and p.get_stat("currency_gain_percent") == 10, "coffin cost revokes ring tier as well as heart tier")
	check(events == {"revived": 1, "died": 0, "interest": 0}, "one lethal hit emits one revive and no death or interest")
	check(not bank.manual_operation_used and bank.interest_remainder == 0.75, "automatic protection preserves manual banking and interest carry")
	check(not bank.get_principal_revive_state().available and bank.get_principal_revive_state().remaining_uses == 0, "coffin charge recorded as spent")
	check(p.take_damage(1000000) == 0 and p.current_hp == 8, "coffin receives normal revive invulnerability")
	bank.deposit(1000, true)
	p.sync_relic_weapon_ids(p.get_start_weapon_ids())
	fatal_hit(p)
	check(not p.is_alive() and bank.principal == 1500 and events.died == 1, "refunding principal and rebuilding stats cannot rearm coffin")
	p.free()


func _test_revive_priority_and_preview() -> void:
	var p := make_player()
	var bank := make_bank(p)
	p.add_relic("relic_golden_sarcophagus")
	p.add_relic("relic_costly_seed_of_life")
	bank.deposit(1500, true)
	fatal_hit(p)
	check(p.is_alive() and bank.principal == 1500 and p.remaining_revives == 0 and bank.get_principal_revive_state().available, "ordinary revive runs before paid coffin")
	check(p.get_stat("divinity") == 20, "ordinary revive still applies seed erosion")
	var preview_player := p.create_stat_preview_copy()
	var preview_bank := bank.create_preview_copy(preview_player)
	fatal_hit(preview_player)
	check(preview_player.is_alive() and preview_bank.principal == 1000 and preview_bank.get_principal_revive_state().remaining_uses == 0, "preview protection binds only to preview bank")
	check(bank.principal == 1500 and bank.get_principal_revive_state().remaining_uses == 1 and p.get_stat("divinity") == 20, "preview revive preserves all live state")
	preview_player.free()
	fatal_hit(p)
	check(p.is_alive() and bank.principal == 1000 and p.get_stat("divinity") == 40, "coffin fallback fires shared on-revive effects once")
	preview_player = p.create_stat_preview_copy()
	preview_bank = bank.create_preview_copy(preview_player)
	check(preview_bank.get_principal_revive_state().remaining_uses == 0, "preview preserves spent one-shot state")
	preview_player.free()
	p.initialize_from_character("character_void_hunter")
	var wallet := {"value": 1000}
	bank.initialize(p, func(): return wallet.value, func(delta, _reason): wallet.value += delta; return true)
	p.add_relic("relic_golden_sarcophagus")
	bank.deposit(1000, true)
	check(bank.get_principal_revive_state().available and p.lethal_damage.get_connections().size() == 1, "new run resets coffin charge without duplicating death handler")
	fatal_hit(p)
	check(p.is_alive() and bank.principal == 500, "coffin works again in a new run")
	p.free()


func _test_validator() -> void:
	var effect: Dictionary = DataRegistry.get_record("relics", "relic_golden_sarcophagus").runtime_effects[0]
	for patch in [{"minimum_principal": 499}, {"principal_cost": 0}, {"health_percent": 101}, {"max_uses": 0}, {"max_uses": 0.5}, {"health_percent": "invalid"}, {"trigger": "wave_end"}]:
		var invalid := effect.duplicate(true)
		invalid.merge(patch, true)
		var validator := DataValidator.new()
		validator._validate_relic_runtime_effect(invalid, "principal_revive_test")
		check(not validator.errors.is_empty(), "reject invalid protection config " + str(patch))
	var validator := DataValidator.new()
	validator._validate_relic_runtime_effect(DataRegistry.get_record("relics", "relic_hoarders_ring").runtime_effects[1], "ring_test")
	check(validator.errors.is_empty(), "negative principal stat conversion is valid")


func frames(count: int = 5) -> void:
	for i in count: await get_tree().process_frame


func _test_bank_ui() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	var weapons: Array[String] = ["weapon_void_blade"]
	flow.enter_battle_selection("character_void_hunter", weapons)
	await frames()
	check(flow.confirm_character_selection(), "start actual game for principal UI")
	await frames()
	var p := flow.get_bound_player()
	var hud := game.find_child("HUD", true, false) as BattleHud
	var manager := hud._wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(2000, "test")
	flow.finish_current_wave()
	await frames(15)
	var bank := manager.finance_system
	var base_max_hp := 5 + manager.player_level - 1
	check(p.get_stat("max_hp") == base_max_hp, "actual game UI uses five starting HP plus level growth")
	var funded_max_hp := base_max_hp + 10
	var withdrawn_max_hp := base_max_hp + 4
	for id in IDS: p.add_relic(id)
	bank.deposit(1000 - bank.principal, true)
	p.restore_full_health()
	await frames()
	var before := bank.get_state_snapshot()
	var text := flow.get_bank_stat_preview("withdraw", 501)
	check(text.contains("最大生命") and text.contains("%d → %d" % [funded_max_hp, withdrawn_max_hp]) and text.contains("当前生命"), "bank preview exposes lost max and current HP")
	check(text.contains("货币获取加成") and text.contains("理智") and text.contains("购买价格"), "bank preview exposes ring attributes and economic changes")
	check(text.contains("黄金棺椁") and text.contains("本金不足"), "withdrawal warns when coffin protection is lost")
	check(bank.get_state_snapshot() == before and p.current_hp == funded_max_hp and not bank.manual_operation_used, "bank preview preserves live protection and health")
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.configure(flow.get_preparation_payload())
	popup._choose_bank_action("withdraw")
	popup.amount_input.text = "501"
	popup._update_bank_confirm()
	check(popup._principal_protection.visible and popup._principal_protection.text.contains("可触发"), "bank displays available coffin state")
	check(popup._bank_preview.text.contains("黄金棺椁"), "actual bank renders protection preview")
	for size in [Vector2i(960, 540), Vector2i(640, 360)]:
		get_tree().root.size = size
		get_tree().root.content_scale_size = size
		await frames()
		if popup._compact: popup._select_tab("bank")
		await frames()
		popup._bank.ensure_control_visible(popup.bank_confirm)
		await frames()
		var center := popup.bank_confirm.get_global_rect().get_center()
		check(popup._bank.get_global_rect().has_point(center), "expanded principal preview keeps confirmation reachable at %s" % size)
	var result := flow.submit_finance_operation("withdraw", 501)
	await frames()
	check(result.success and bank.principal == 499 and p.current_hp == withdrawn_max_hp and p.get_stat("humanity") == 100, "actual withdrawal matches preview across all three relics")
	check(popup._principal_protection.text.contains("本金不足"), "bank refreshes coffin status after withdrawal")
	bank.deposit(501, true)
	fatal_hit(p)
	await frames()
	check(popup._principal_protection.text.contains("本局已使用"), "bank displays spent coffin after activation")
	game.queue_free()
	await frames(3)
