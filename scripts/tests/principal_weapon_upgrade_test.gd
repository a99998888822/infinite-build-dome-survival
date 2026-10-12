extends "res://scripts/tests/finance_compact_review.gd"

class PreviousUpgradeRoller extends ShopOfferGenerator:
	func _gate_weapon_upgrades(candidates: Array) -> Array:
		return candidates
	func get_shop_type_weights(context: Dictionary) -> Dictionary:
		var weights := super.get_shop_type_weights(context)
		if int(weights.get(OFFER_WEAPON_UPGRADE, 0)) > 0:
			weights[OFFER_WEAPON_UPGRADE] = mini(20, 8 + int(context.get("weapon_upgrade_miss_count", 0)) * 2)
		return weights


func _run() -> void:
	CampProgression.begin_transient_session()
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	if DisplayServer.get_name() == "headless": _test_probabilities()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start actual battle")
	await frames(10)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	manager = (game.find_child("HUD", true, false) as BattleHud)._wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	player.set_physics_process(false)
	player.modifier_stack.set_base_stat("load_capacity", 150)
	player.modifier_stack.set_base_stat("luck", 200)
	check(loadout.equip_weapon("weapon_plasma_cannon"), "equip second weapon")
	check(loadout.equip_weapon("weapon_hand_cannon"), "equip third weapon")
	manager.apply_gold_delta(1000, "test")
	flow.finish_current_wave()
	await frames(25)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	popup._select_tab("enchant")
	var finance := manager.finance_system
	finance.principal = 1500
	finance._emit_changed()
	for id in ["scroll_fire", "scroll_water", "scroll_lightning", "scroll_giant", "scroll_wisdom", "scroll_multishot"]:
		if not DataRegistry.get_record("augmentations", id).is_empty(): player.item_inventory.add_item_from_base(id, "test")
	await frames(10)
	_test_prices_and_resale()
	await _test_principal_purchase()
	await _test_gold_and_free_purchase()
	await _test_wave_reset()
	_test_buyout_transaction()
	flow.enter_start_page()
	check(flow._principal_weapon_upgrade_wave == -1, "new run clears the principal upgrade quota")
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("PRINCIPAL_WEAPON_UPGRADE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_probabilities() -> void:
	var pool: Array = []
	for i in 5:
		pool.append({"offer_id": "relic:%d" % i, "offer_type": "relic", "target_id": "relic_piggy_bank", "rarity": "common", "weight": 100})
	for i in 2:
		pool.append({"offer_id": "weapon:%d" % i, "offer_type": "new_weapon", "target_id": "weapon_void_blade", "rarity": "common", "weight": 100})
	for i in 3:
		pool.append({"offer_id": "upgrade:%d" % i, "offer_type": "weapon_upgrade", "target_id": "weapon_void_blade", "rarity": "common", "weight": 100})
	var previous := PreviousUpgradeRoller.new()
	var current := ShopOfferGenerator.new()
	for scenario in [["free", 3, 0], ["free", 6, 99], ["shop", 3, 0], ["shop", 6, 99], ["free", 3, -1], ["shop", 3, -1]]:
		var context := {"candidate_pool": pool, "owned_weapon_ids": ["weapon_void_blade"], "load_capacity": 100, "current_load": 22, "offer_mode": scenario[0]}
		var totals := [0, 0]
		for version in 2:
			seed(20261012 + version)
			var generator: ShopOfferGenerator = previous if version == 0 else current
			var misses := 0
			for attempt in 6000:
				context.weapon_upgrade_miss_count = misses if int(scenario[2]) < 0 else int(scenario[2])
				var weights := generator.get_shop_type_weights(context)
				var offers := generator.roll_paid_offers({"common": 10000}, weights, pool, int(scenario[1]), attempt) if scenario[0] == "shop" else generator.roll_shop_offers({"common": 10000}, weights, pool, int(scenario[1]))
				var found := offers.any(func(offer): return offer.offer_type == "weapon_upgrade")
				if found: totals[version] += 1
				misses = 0 if found else misses + 1
		var ratio := float(totals[1]) / maxf(1, totals[0])
		print("UPGRADE_ROLL_SAMPLE scenario=%s previous=%d current=%d ratio=%.4f" % [str(scenario), totals[0], totals[1], ratio])
		check(ratio <= 1.0 / 3.0, "upgrade page occurrence at most one third: " + str(scenario))
	var context := {"candidate_pool": pool, "owned_weapon_ids": ["weapon_void_blade"], "offer_mode": "free", "weapon_upgrade_miss_count": 99}
	var old_weights := previous.get_shop_type_weights(context)
	var new_weights := current.get_shop_type_weights(context)
	check(old_weights.new_weapon == new_weights.new_weapon and old_weights.relic == new_weights.relic, "new weapon and relic weights preserved")
	for mode in ["free", "shop"]:
		var offers := current.roll_shop_offers({"common": 10000}, new_weights, pool, 3, true) if mode == "free" else current.roll_paid_offers({"common": 10000}, new_weights, pool, 3, 0, [], "", true)
		check(offers.any(func(offer): return offer.offer_type == "new_weapon"), "early weapon guarantee survives in " + mode)


func _test_prices_and_resale() -> void:
	var service := InventoryTradeService.new()
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_rentier_purse", player)
	weapon.upgrade(100, "principal")
	weapon.upgrade(200, "principal")
	weapon.upgrade(350, "principal")
	weapon.upgrade(500, "principal")
	var quote := service.quote_weapon(weapon)
	check(int(quote.cost_basis.total_cost) == 1170 and int(quote.total) == 585, "principal upgrades resell at half of complete 1170 cost")
	check(int(GoblinSpecialTrades.weapon_quote(weapon, player, 1.5).amount) == 1755, "special buyout uses 1.5 times full cost")
	var free := WeaponInstance.new()
	free.initialize("weapon_rentier_purse", player)
	for i in 4: free.upgrade()
	check(int(service.weapon_costs(free).upgrade_cost) == 180 and int(service.quote_weapon(free).total) == 100, "free upgrades use doubled standard gold costs, not principal prices")
	var mixed := WeaponInstance.new()
	mixed.initialize("weapon_rentier_purse", player)
	mixed.trade_base_basis = 80
	mixed.upgrade(25, "gold")
	mixed.upgrade()
	mixed.upgrade(350, "principal")
	check(int(service.weapon_costs(mixed).total_cost) == 495 and int(service.quote_weapon(mixed).total) == 247, "mixed acquisition costs and discounts are recorded, with one final rounding")
	check(int(GoblinSpecialTrades.weapon_quote(mixed, player, 1.5).amount) == 742, "special buyout rounds full mixed cost only once")
	check(int(service.quote_weapon(mixed, 0).total) == floori(247.0 / 1.2), "existing sanity sale modifier remains in effect")
	var generator := ShopOfferGenerator.new()
	for rarity in ["uncommon", "rare", "epic", "mythic"]:
		var candidate := {"offer_type": "weapon_upgrade", "rarity": rarity}
		var old_cost := 10 + ["common", "uncommon", "rare", "epic", "mythic"].find(rarity) * 5
		check(generator._calculate_shop_cost(candidate, []) == old_cost * 2, "gold upgrade price doubled: " + rarity)
	check(generator._calculate_shop_cost({"offer_type": "new_weapon", "rarity": "common"}, []) == 15 and generator._calculate_shop_cost({"offer_type": "relic", "rarity": "rare"}, []) == 25, "other base shop prices unchanged")


func _test_principal_purchase() -> void:
	var finance := manager.finance_system
	var bow := loadout.get_weapon_instance("weapon_void_blade")
	var quote := flow.get_principal_weapon_upgrade_quote(bow.weapon_id)
	check(quote.success and int(quote.price) == 100, "level two costs exactly 100 principal")
	check(not flow.purchase_principal_weapon_upgrade(bow.weapon_id, "stale").success and bow.level == 1, "stale principal upgrade quote cannot charge or upgrade")
	finance._deducting_principal = true
	var failed := flow.purchase_principal_weapon_upgrade(bow.weapon_id, str(quote.quote_token))
	finance._deducting_principal = false
	check(not failed.success and bow.level == 1 and bow.trade_upgrade_basis.is_empty() and finance.principal == 1500 and flow._principal_weapon_upgrade_wave == -1, "payment failure restores level, costs and quota")
	finance.principal = 99
	check(not flow.purchase_principal_weapon_upgrade(bow.weapon_id, str(quote.quote_token)).success and finance.principal == 99, "insufficient principal does not consume quota or balance")
	finance.principal = 1500
	finance._emit_changed()
	popup.workbench.refresh()
	await frames(8)
	var work := popup.workbench
	check(work._upgrade_weapon.get_global_rect().end.x <= work._sell_weapon.get_global_rect().position.x, "upgrade button is left of sell weapon")
	await capture("01_principal_upgrade_available")
	var hovered: Array = []
	var observe_tooltip := func(content): hovered.append(content)
	work.tooltip_requested.connect(observe_tooltip)
	if DisplayServer.get_name() == "headless": work._upgrade_weapon.mouse_entered.emit()
	else: await _hover_control(work._upgrade_weapon)
	await frames(6)
	check(not hovered.is_empty() and str(hovered.back()) == L10n.source(str(bow.weapon_data.level_upgrades["2"].description)), "hover matches the upgrade shop description exactly")
	await capture("02_principal_upgrade_tooltip")
	work.tooltip_requested.disconnect(observe_tooltip)
	var observations: Array = []
	var observe_finance := func(_snapshot):
		observations.append([bow.level, bow.trade_upgrade_sources.get(2, ""), flow.purchase_principal_weapon_upgrade("weapon_plasma_cannon", "ignored").success])
	finance.finance_changed.connect(observe_finance)
	var gold_before := manager.current_gold
	var bank_used := finance.manual_operation_used
	if DisplayServer.get_name() == "headless": work._upgrade_weapon.pressed.emit()
	else: await _click_control(work._upgrade_weapon)
	await frames(8)
	finance.finance_changed.disconnect(observe_finance)
	check(bow.level == 2 and finance.principal == 1400 and manager.current_gold == gold_before, "actual UI click upgrades once and charges principal only")
	check(finance.manual_operation_used == bank_used, "principal upgrade does not consume bank transaction")
	check(not observations.is_empty() and observations[0] == [2, "principal", false], "finance callback sees complete upgrade and cannot reenter purchase")
	check(not flow.purchase_principal_weapon_upgrade(bow.weapon_id, str(quote.quote_token)).success, "duplicate upgrade submission is rejected")
	check(str(flow.get_principal_weapon_upgrade_quote("weapon_plasma_cannon").reason) == "principal_upgrade_used", "all weapons share the same wave quota")
	work._select_weapon("weapon_plasma_cannon")
	popup._select_tab("shop")
	flow._build_shop_payload("shop", 0)
	popup._select_tab("enchant")
	work.refresh()
	check(work._upgrade_weapon.disabled and str(flow.get_principal_weapon_upgrade_quote(bow.weapon_id).reason) == "principal_upgrade_used", "weapon, tab and shop refresh cannot reset quota")
	await capture("03_principal_upgrade_used")


func _test_gold_and_free_purchase() -> void:
	var plasma := loadout.get_weapon_instance("weapon_plasma_cannon")
	var offer := _activate_upgrade_offer(plasma.weapon_id)
	var gold_before := manager.current_gold
	check(flow.submit_shop_purchase(offer, "shop").success, "gold upgrade remains purchasable after principal upgrade")
	check(plasma.level == 2 and int(plasma.trade_upgrade_basis[2]) == int(offer.shop_cost) and plasma.trade_upgrade_sources[2] == "gold", "paid upgrade records actual gold cost")
	check(manager.current_gold == gold_before - int(offer.shop_cost), "gold upgrade charges its doubled price")
	flow._set_state(flow.STATE_SHARED_REWARD_SHOP_POPUP)
	flow._resume_state_after_modal = flow.STATE_FINANCE_POPUP
	offer = _activate_upgrade_offer(plasma.weapon_id)
	gold_before = manager.current_gold
	check(flow.submit_shop_purchase(offer, "free").success and manager.current_gold == gold_before, "free reward upgrade remains free")
	check(plasma.trade_upgrade_sources[3] == "free" and int(plasma.trade_upgrade_basis[3]) == WeaponUpgradeRules.gold_cost(plasma.weapon_data.level_upgrades["3"]), "free reward records standard gold cost for resale")
	await frames(8)
	flow._active_relic_choice = "boss_test"
	var boss := flow._build_shop_payload("free", 0)
	check(not boss.offers.is_empty() and boss.offers.all(func(row): return row.offer_type == "relic"), "boss-specific rewards remain relic-only")
	flow._active_relic_choice = ""


func _activate_upgrade_offer(weapon_id: String) -> Dictionary:
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool(flow._build_shop_context())
	for candidate in pool:
		if candidate.offer_type == "weapon_upgrade" and candidate.target_id == weapon_id:
			candidate.weapon_instance_id = loadout.get_weapon_instance(weapon_id).instance_id
			flow._active_shop_offers = {str(candidate.offer_id): candidate}
			flow._active_shop_offer_ids.assign([str(candidate.offer_id)])
			return candidate
	check(false, "upgrade fixture candidate exists")
	return {}


func _test_wave_reset() -> void:
	flow._set_state(flow.STATE_FINANCE_POPUP)
	flow.close_finance_popup()
	await frames(8)
	manager.set_process(false)
	manager.clear_enemies()
	player.set_physics_process(false)
	flow.finish_current_wave()
	await frames(20)
	popup.interest_arrival.skip()
	popup._select_tab("enchant")
	var bow := loadout.get_weapon_instance("weapon_void_blade")
	var quote := flow.get_principal_weapon_upgrade_quote(bow.weapon_id)
	check(quote.success and int(quote.price) == 200, "next actual wave restores quota at level-three price")
	var plasma := loadout.get_weapon_instance("weapon_plasma_cannon")
	player.modifier_stack.set_base_stat("luck", 0)
	check(str(flow.get_principal_weapon_upgrade_quote(plasma.weapon_id).reason) == "principal_upgrade_luck", "principal upgrade preserves luck eligibility")
	player.modifier_stack.set_base_stat("luck", 200)
	check(flow.purchase_principal_weapon_upgrade(bow.weapon_id, str(quote.quote_token)).success and bow.level == 3, "new wave principal upgrade succeeds")
	check(flow._principal_weapon_upgrade_wave == manager.finance_system.current_wave_number, "quota is keyed to the actual preparation wave")


func _test_buyout_transaction() -> void:
	var weapon := loadout.get_weapon_instance("weapon_void_blade")
	var definition := manager.goblin_trades.definition("weapon_buyout")
	check(is_equal_approx(float(definition.price_multiplier), 1.5), "production buyout multiplier is 1.5")
	var offer := GoblinSpecialTrades.weapon_quote(weapon, player, float(definition.price_multiplier))
	offer.price_multiplier = float(definition.price_multiplier)
	var before := manager.current_gold
	var expected := int(offer.amount)
	check(GoblinSpecialTrades.accept_weapon(offer, player, manager.finance_system, loadout), "special buyout accepts full-cost quote including attachments")
	check(manager.current_gold == before + expected and loadout.get_weapon_instance(weapon.weapon_id) == null, "special buyout grants quoted gold and removes weapon once")
	check(not GoblinSpecialTrades.accept_weapon(offer, player, manager.finance_system, loadout), "duplicate special buyout cannot pay twice")
