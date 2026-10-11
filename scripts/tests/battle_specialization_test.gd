extends Node

class RejectingPlayer extends PlayerController:
	var reject_armor := false
	func add_runtime_modifier(data: Dictionary) -> bool:
		if reject_armor and data.get("stat") == "armor": return false
		return super.add_runtime_modifier(data)

var checks := 0
var failures := 0
var capture_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func make_player(character := "character_void_hunter") -> RejectingPlayer:
	var p := RejectingPlayer.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.initialize_from_character(character)
	p.set_physics_process(false)
	return p


func make_bank(p: PlayerController) -> BattleFinanceSystem:
	var bank := BattleFinanceSystem.new()
	var wallet := {"gold": 420}
	bank.initialize(p, func(): return wallet.gold, func(delta, _reason): wallet.gold += delta; return true)
	p.relic_added.connect(bank.on_relic_added)
	bank.deposit(20000, true, "test")
	return bank


func guaranteed(choice_index := 0) -> BattleSpecializationSystem:
	var service := BattleSpecializationSystem.new()
	service.config.offer_chance = 1.0
	service.config.choices = [service.config.choices[choice_index]]
	return service


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	_test_offers()
	_test_effects()
	_test_prices_and_atomicity()
	_test_reorganization_and_capitalist()
	await _test_formal_ui()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await frames()
	print("BATTLE_SPECIALIZATION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_offers() -> void:
	var service := BattleSpecializationSystem.new()
	var prices: Array[int] = []
	prices.assign(service.config.prices)
	check(prices == [300, 600, 1200, 2000, 3600, 5600] and service.config.offer_chance == 0.5, "formal prices and probability")
	service.config.offer_chance = 1.0
	service.prepare(2, 2999, true)
	check(service.offer.is_empty() and service.decided_wave == -1, "below threshold can qualify after a deposit")
	service.prepare(2, 3000, true)
	check(service.offer.choices.size() == 3, "threshold grants three distinct choices")
	var seen: Array = []
	for choice: Dictionary in service.offer.choices:
		check(choice.id not in seen and choice.id not in ["projectile", "revival"], "early choices unique and wave-gated")
		seen.append(choice.id)
	var frozen := service.snapshot()
	for principal in [0, 100, 3000, 100000]: service.prepare(2, principal, true)
	check(service.snapshot() == frozen, "balance and repeated payloads never reroll")
	service.config.offer_chance = 0.0
	service.prepare(3, 3000, true)
	service.config.offer_chance = 1.0
	service.prepare(3, 300000, true)
	check(service.offer.is_empty(), "unsuccessful draw is final for the wave")
	service.prepare(4, 3000, false)
	check(service.offer.is_empty(), "no next wave has no offer")
	for index in [4, 5]:
		var gated := guaranteed(index)
		gated.prepare(3, 6000, true)
		check(gated.offer.is_empty(), "late group unavailable before wave four")
		gated.prepare(4, 6000, true)
		check(not gated.offer.is_empty(), "late group enters at wave four")
	# Compare the first draw with an independent RNG at the configured probability.
	for rng_seed in range(1, 9):
		var reference := RandomNumberGenerator.new()
		reference.seed = rng_seed
		var expected := reference.randf() < 0.5
		var random_service := BattleSpecializationSystem.new()
		random_service._rng.seed = rng_seed
		random_service.prepare(4, 6000, true)
		check(not random_service.offer.is_empty() == expected, "configured probability uses one stable draw " + str(rng_seed))
	service.reset()
	check(service.purchase_count == 0 and service.offer.is_empty() and service.decided_wave == -1, "new run clears all progress")


func _test_effects() -> void:
	var expected := [{"max_hp": 5, "armor": 15}, {"melee_damage": 5, "ranged_damage": 5, "element_damage": 5},
		{"area_size": 12, "damage_area_size": 12, "attack_speed": 12},
		{"currency_gain_percent": 12, "exp_gain_percent": 12, "pickup_radius": 12},
		{"projectile_count": 1}, {"revive_count": 1}]
	for i in expected.size():
		var p := make_player()
		var bank := make_bank(p)
		var service := guaranteed(i)
		bank.prepare_wave(4)
		service.prepare(4, bank.principal, true)
		var before: Dictionary = {}
		for stat: String in expected[i]: before[stat] = p.get_stat(stat)
		var hp := p.current_hp
		var gold := bank.get_current_gold()
		var result := service.purchase(str(service.offer.token), str(service.offer.choices[0].id), bank)
		check(result.success and bank.principal == 19700 and bank.get_current_gold() == gold and not bank.manual_operation_used, "group direct payment " + str(i))
		for stat: String in expected[i]:
			check(p.get_stat(stat) == before[stat] + expected[i][stat], "grants exact full group stat " + stat)
		check(p.current_hp == hp, "maximum health purchase never heals")
		if i == 5:
			check(p.remaining_revives >= 1, "revival is usable immediately")
			p.remaining_revives -= 1
			var remaining := p.remaining_revives
			for j in 3: bank._emit_changed()
			check(p.remaining_revives == remaining, "spent revival never returns during stat refresh")
		bank.begin_wave(4)
		check(p.get_stat(str(expected[i].keys()[0])) == before[expected[i].keys()[0]] + expected[i].values()[0], "specialization persists into combat")
		p.free()


func _test_prices_and_atomicity() -> void:
	var p := make_player()
	var bank := make_bank(p)
	var service := guaranteed()
	var initial := bank.principal
	var previous_token := ""
	for i in 6:
		bank.prepare_wave(i + 2)
		service.prepare(i + 2, bank.principal, true)
		var token := str(service.offer.token)
		if not previous_token.is_empty(): check(not service.purchase(previous_token, "survival", bank).success, "previous wave token is rejected")
		check(int(service.offer.price) == [300, 600, 1200, 2000, 3600, 5600][i], "shared price step " + str(i))
		var before := bank.principal
		check(not service.purchase(token, "injected_choice", bank).success and bank.principal == before, "unknown group is rejected without payment")
		check(service.purchase(token, "survival", bank).success, "purchase price step " + str(i))
		check(not service.purchase(token, "survival", bank).success and service.purchase_count == i + 1, "duplicate purchase is rejected")
		previous_token = token
	check(initial - bank.principal == 13300, "six purchases cost exactly 13300")
	bank.prepare_wave(8)
	service.prepare(8, bank.principal, true)
	check(service.offer.is_empty(), "six-purchase cap removes future offers")
	p.free()
	p = make_player()
	bank = make_bank(p)
	service = guaranteed()
	bank.prepare_wave(2)
	service.prepare(2, bank.principal, true)
	var token := str(service.offer.token)
	bank.withdraw(bank.principal - 299)
	check(not service.purchase(token, "survival", bank).success and bank.principal == 299 and service.purchase_count == 0, "shortfall does not spend or advance price")
	bank.deposit(1, true, "test")
	var max_hp := p.get_stat("max_hp")
	p.reject_armor = true
	check(not service.purchase(token, "survival", bank).success and p.get_stat("max_hp") == max_hp and bank.principal == 300 and service.purchase_count == 0, "blocked second stat rolls back the complete group")
	p.reject_armor = false
	var reentrant: Array = []
	var reenter := func(_snapshot): reentrant.append(service.purchase(token, "survival", bank))
	bank.finance_changed.connect(reenter)
	check(service.purchase(token, "survival", bank).success and bank.principal == 0 and service.purchase_count == 1, "exact balance is a valid service payment")
	check(not reentrant.is_empty() and reentrant.all(func(r): return not r.success), "synchronous callbacks cannot buy twice")
	bank.finance_changed.disconnect(reenter)
	p.free()


func _test_reorganization_and_capitalist() -> void:
	var p := make_player("character_capitalist")
	var bank := make_bank(p)
	var service := guaranteed()
	bank.prepare_wave(2)
	service.prepare(2, bank.principal, true)
	check(not bank.withdraw(1).success and service.purchase(str(service.offer.token), "survival", bank).success, "capitalist can buy directly despite withdrawal restriction")
	p.free()
	p = make_player()
	bank = make_bank(p)
	service = guaranteed()
	bank.prepare_wave(2)
	service.prepare(2, bank.principal, true)
	p.add_relic("relic_bankruptcy_reorg")
	bank.withdraw(bank.principal - 300)
	var gold := bank.get_current_gold()
	var revives := p.remaining_revives
	check(bank.project_specialization_principal(300) == gold * 2 and bank.principal == 300 and p.remaining_revives == revives and not bank._bankruptcy_triggered, "principal quote includes reorganization without consuming it")
	check(service.purchase(str(service.offer.token), "survival", bank).success, "service can trigger reorganization")
	check(bank.principal == gold * 2 and bank.get_current_gold() == gold and p.remaining_revives == revives + 1, "reorganization uses pre-payment wallet then deducts principal")
	p.free()


func click(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	await frames(2)
	check(get_viewport().gui_get_hovered_control() == button, "real pointer reaches " + button.name)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = motion.position
		get_viewport().push_input(event, true)
		await frames(2)


func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)


func _test_formal_ui() -> void:
	var root := get_tree().root
	root.unfocusable = true
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "formal UI starts transient run")
	await frames()
	var manager := flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	var service := manager.battle_specialization
	# Deterministic fixture changes only this run's random selection, not formal data.
	service.config.offer_chance = 1.0
	service.config.choices = service.config.choices.slice(0, 3)
	manager.finance_system.deposit(6000 - manager.finance_system.principal, true, "test")
	flow.finish_current_wave()
	await frames(24)
	check(flow._request_wave_end_finance(), "enter real preparation")
	await frames(12)
	manager.apply_gold_delta(420 - manager.current_gold, "test")
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.stop()
	popup.cancel_trade("test")
	popup.configure(flow.get_preparation_payload())
	popup.interest_arrival.stop()
	popup.portrait.set_process(false)
	await frames()
	check(popup._specialization_tab.visible and popup._active_tab == "shop", "formal entry appears without automatic navigation")
	await capture("01_entry_1152")
	await click(popup._specialization_tab)
	var panel := popup.specialization_panel
	await frames()
	check(panel.visible and panel.confirm.disabled and not popup._shop.visible, "formal tab opens with selection required")
	for i in service.offer.choices.size():
		if str(service.offer.choices[i].id) == "survival": await click(panel.cards[i])
	await frames()
	check(panel.confirm.text == L10n.text("ui.bank.specialization.confirm") % 300, "approved purchase button wording")
	await capture("02_selected_1152")
	var token := str(service.offer.token)
	flow.request_esc_overlay()
	await frames()
	check(not flow.purchase_battle_specialization(token, "survival").success, "inspection cannot purchase")
	flow.close_esc_overlay()
	await frames()
	check(popup._active_tab == "specialization" and panel.selected >= 0 and str(service.offer.token) == token, "inspection retains selection and quote")
	for dimensions in [Vector2i(1152, 648), Vector2i(1000, 540), Vector2i(640, 360)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames(12)
		check(panel.get_global_rect().encloses(panel.confirm.get_global_rect()), "purchase fits workspace " + str(dimensions))
		check(panel.quote.get_global_rect().position.y >= panel.cards[0].get_global_rect().end.y, "quote does not overlap choices")
		check(not panel.confirm.get_global_rect().intersects(popup.start_button.get_global_rect()), "purchase does not overlap next wave")
		await capture("03_selected_%d" % dimensions.x)
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	await frames(12)
	var hp := manager.player.current_hp
	var maximum := manager.player.get_stat("max_hp")
	var armor := manager.player.get_stat("armor")
	await click(panel.confirm)
	await frames()
	check(manager.finance_system.principal == 5700 and manager.current_gold == 420, "UI purchase changes real principal only")
	check(manager.player.get_stat("max_hp") == maximum + 5 and manager.player.get_stat("armor") == armor + 15 and manager.player.current_hp == hp, "UI purchase grants real full group without healing")
	check(int(popup.payload.principal) == 5700 and panel.confirm.disabled and bool(panel.offer.purchased), "UI summary and purchase state update together")
	await capture("04_purchased_1152")
	L10n.set_locale("en", false)
	await frames()
	check(panel.heading.text.begins_with("Purchased") and panel.confirm.text == "Purchased this visit", "formal panel supports language switching")
	await capture("05_purchased_en")
	L10n.set_locale("zh_CN", false)
	# Next-wave layout with no opportunity removes the tab and returns to shop.
	manager.finance_system.prepare_wave(3)
	service.config.offer_chance = 0.0
	service.prepare(3, manager.finance_system.principal, true)
	popup.configure(flow.get_preparation_payload())
	await frames()
	check(not popup._specialization_tab.visible and not panel.visible and popup._shop.visible, "absent next-wave offer leaves original shop")
	game.queue_free()
	await frames(12)
