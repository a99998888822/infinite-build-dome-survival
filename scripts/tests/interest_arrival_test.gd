extends Node

var checks := 0
var failures := 0
var capture_dir := ""
var flow: MainFlowCoordinator
var manager: WaveManager
var popup: FinancePopup


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count: int = 4) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start a real run")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.set_process(false)
	popup.interest_arrival.sound_enabled = false
	for id in ["relic_dividend_check", "relic_compound_interest_tome", "relic_perpetual_annuity_scroll"]:
		manager.player.add_relic(id)
	manager.finance_system.deposit(1000, true, "test")
	manager.apply_gold_delta(120, "test")
	manager.collected_gold_this_wave = 120
	_set_stat("humanity", 100)
	_set_stat("interest_rate", 8 - manager.finance_system.interest_rate_bonus)
	_seed_first_double()
	manager.goblin_trades.low_health_episodes = 3
	var before_gold := manager.current_gold
	flow.finish_current_wave()
	await frames(12)
	var arrival := popup.interest_arrival
	check(InterestArrivalPresentation.TICK.get_length() > 0 and InterestArrivalPresentation.BONUS.get_length() > 0 and InterestArrivalPresentation.ARRIVE.get_length() > 0, "all three payout sound assets are available")
	var results: Array = popup.payload.settlement_results
	var report := arrival.report
	var expected := 0
	for result: Dictionary in results: expected += int(result.gain)
	check(arrival.is_active() and results.size() == 2, "wave end automatically opens the receipt for both settlements")
	check(not manager.goblin_trades.offer.is_empty() and popup.trade_presentation != null and popup.trade_presentation.is_active(), "goblin trade appears together with the bank and receipt")
	check(not popup.trade_presentation._yes.disabled and not popup.trade_presentation._no.disabled, "both trade choices are available during interest animation")
	check(arrival._card.get_global_rect().get_center().distance_to(get_viewport().get_visible_rect().get_center()) < 1.0, "receipt is centered on the entire game viewport")
	await _check_trade_pointer()
	check(manager.current_gold == before_gold + expected and manager.finance_system.principal == 1000, "authoritative payout happens exactly once before animation")
	check(report.total == expected and report.combat == 120, "receipt uses recorded finance and combat income")
	check(report.steps.any(func(s): return s.kind == "bonus" and not s.icon.is_empty()), "double payout has its real relic icon")
	check(report.steps.any(func(s): return s.label.contains("额外结息") and not s.icon.is_empty()), "extra settlement retains its source relic")
	var first_receipt := InterestArrivalReport.build({"settlement_results": [results[0]]})
	check(report.steps.any(func(s): return s.kind == "growth" and s.amount == "+0.4%") and first_receipt.steps.any(func(s): return s.kind == "growth" and s.amount == "+0.2%"), "growth shows exact single and accumulated percentage bonuses")
	check(is_equal_approx(report.rate_after, 8.4) and not report.steps.any(func(s): return s.kind == "loss"), "full sanity gets the complete payout and actual ending rate")
	var snapshot_gold := manager.current_gold
	var snapshot_rate := manager.finance_system.get_interest_rate()
	var first_id := str(report.id)
	await _record("bonus")
	arrival.seek(arrival.duration)
	check(not arrival.is_active() and popup.trade_presentation.is_active(), "natural completion preserves the already visible trade")
	check(manager.current_gold == snapshot_gold and is_equal_approx(manager.finance_system.get_interest_rate(), snapshot_rate), "animation cannot grant gold or grow interest again")
	popup.configure(flow.get_preparation_payload())
	popup.show_popup()
	check(not arrival.is_active(), "configure and reopen cannot replay the same payout")
	check(not popup._feedback.text.is_empty(), "receipt leaves an income or purchasing-power reminder")
	flow.request_shop_refresh()
	check(not arrival.is_active(), "a new shop generation does not replay the payout")

	flow.close_finance_popup()
	manager.set_process(false)
	_set_stat("humanity", 50)
	_set_stat("interest_rate", 8 - manager.finance_system.interest_rate_bonus)
	manager.collected_gold_this_wave = 120
	_seed_first_double()
	manager.goblin_trades.low_health_episodes = 3
	flow.finish_current_wave()
	await frames(12)
	report = arrival.report
	check(arrival.is_active() and report.id != first_id, "next wave has a fresh receipt identity")
	check(report.steps.any(func(s): return s.kind == "loss") and not report.steps.any(func(s): return s.kind == "carry" or s.label.contains("小数")), "low sanity shows whole-coin losses without a fractional accrual row")
	expected = 0
	for result: Dictionary in popup.payload.settlement_results: expected += int(result.gain)
	check(report.total == expected, "displayed net amount matches the exact integer credited")
	var shown_total := 0
	for step: Dictionary in report.steps:
		if step.kind in ["base", "bonus"]: shown_total += str(step.amount).to_int()
		if step.kind == "loss": shown_total -= str(step.amount).trim_prefix("−").to_int()
	check(shown_total == expected, "integer receipt rows reconcile to actual credited gold")
	var decimal := RegEx.create_from_string("[0-9]+\\.[0-9]+")
	arrival.seek(arrival.final_time)
	check(report.steps.all(func(s): return s.kind == "growth" or decimal.search(str(s.label) + str(s.amount)) == null), "coin receipt rows remain integers while rate growth can show decimals")
	snapshot_gold = manager.current_gold
	await _record("sanity_loss")
	# Replay only the presentation for responsive visual QA; no finance code runs.
	get_tree().root.size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	await frames(8)
	arrival.present(report)
	arrival.seek(arrival.final_time + 0.15)
	await frames()
	check(get_viewport().get_visible_rect().encloses(arrival._card.get_global_rect()), "compact receipt stays inside the viewport")
	check(arrival._scroll.size.y > 0 and arrival._scroll.get_rect().end.y <= arrival._comparison.position.y, "compact details scroll without overlapping the footer")
	check(arrival._row_nodes.back().get_global_rect().end.y <= arrival._scroll.get_global_rect().end.y + 1, "compact receipt follows the last revealed detail")
	check(arrival._card.get_global_rect().get_center().distance_to(get_viewport().get_visible_rect().get_center()) < 1.0, "compact receipt remains centered on the entire game viewport")
	await _check_trade_pointer()
	await _screenshot("small_receipt")
	popup.trade_presentation.seek(1.5)
	await frames()
	check(arrival.z_index > popup.trade_presentation.z_index, "goblin speech cannot draw over the centered receipt")
	await _screenshot("small_speech")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arrival._gui_input(click)
	arrival.skip()
	check(not arrival.is_active() and manager.current_gold == snapshot_gold, "click-to-skip and repeated skip never change money")
	popup.configure(flow.get_preparation_payload())
	check(not arrival.is_active(), "skip consumes the visual replay for this wave")

	# Closing during the next receipt must not resurrect an unresolved offer.
	flow.close_finance_popup()
	manager.set_process(false)
	manager.goblin_trades.low_health_episodes = 3
	flow.finish_current_wave()
	await frames(12)
	check(arrival.is_active(), "third wave starts another receipt")
	var decline := InputEventMouseButton.new()
	decline.position = popup.trade_presentation._no.get_global_rect().get_center()
	decline.button_index = MOUSE_BUTTON_LEFT
	decline.pressed = true
	var receipt_covers_choice := arrival._card.get_global_rect().has_point(decline.position)
	Input.parse_input_event(decline)
	decline = decline.duplicate()
	decline.pressed = false
	Input.parse_input_event(decline)
	await frames()
	if receipt_covers_choice:
		check(not arrival.is_active() and popup.trade_presentation.is_active(), "clicking the centered receipt skips it without activating the trade behind it")
		decline = decline.duplicate()
		decline.pressed = true
		Input.parse_input_event(decline)
		decline = decline.duplicate()
		decline.pressed = false
		Input.parse_input_event(decline)
		await frames()
	check(manager.goblin_trades.offer.is_empty() and not popup.trade_presentation.is_active() and not arrival.is_active(), "actual click rejects trade during receipt and completes its presentation")
	flow.close_finance_popup()
	manager.set_process(false)
	manager.goblin_trades.low_health_episodes = 3
	flow.finish_current_wave()
	await frames(12)
	popup.hide_popup()
	arrival.seek(100)
	popup.configure(flow.get_preparation_payload())
	popup.show_popup()
	check(not arrival.is_active() and manager.goblin_trades.offer.is_empty(), "closing cancels the visible offer and suppresses late callbacks")
	var old_id := popup._last_arrival_id
	flow.enter_start_page()
	await frames(12)
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(12)
	check(flow.confirm_character_selection(), "restart through the normal game flow")
	await frames(8)
	manager = flow._bound_wave_manager
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	arrival = popup.interest_arrival
	arrival.set_process(false)
	arrival.sound_enabled = false
	manager.set_process(false)
	manager.clear_enemies()
	manager.finance_system.deposit(100, true, "test")
	flow.finish_current_wave()
	await frames(12)
	check(arrival.is_active() and arrival.report.id != old_id, "new run does not inherit previous receipt suppression")
	check(InterestArrivalReport.build({"settlement_results": [{"success": false, "principal_before": 0}]}).is_empty(), "no principal has no celebratory payout animation")
	arrival.skip()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("INTEREST_ARRIVAL_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _set_stat(stat: String, value: float) -> void:
	var source := "arrival_test_" + stat
	manager.player.remove_runtime_modifiers_by_source("goblin_trade", source)
	GoblinTradeSystem.apply_stat(manager.player, source, stat, value - manager.player.get_stat(stat))


func _seed_first_double() -> void:
	var rng := RandomNumberGenerator.new()
	for candidate in 1000:
		rng.seed = candidate
		if rng.randf() < 0.2 and rng.randf() >= 0.2:
			manager.finance_system._rng.seed = candidate
			return


func _record(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	var path := capture_dir.path_join(name)
	DirAccess.make_dir_recursive_absolute(path)
	var arrival := popup.interest_arrival
	var count := ceili((arrival.duration + 3.5) * 24)
	for index in count:
		var time := float(index) / 24.0
		arrival.seek(time)
		if popup.trade_presentation != null and popup.trade_presentation.is_active():
			popup.trade_presentation.set_process(false)
			popup.trade_presentation.sound_enabled = false
			popup.trade_presentation.seek(time)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_tree().root.get_texture().get_image().save_png(path.path_join("%03d.png" % index))
		if error != OK:
			check(false, "capture frame " + name)
			return
	check(true, "captured " + name)


func _screenshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func _check_trade_pointer() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = popup.trade_presentation._yes.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await frames()
	var covered := popup.interest_arrival._card.get_global_rect().has_point(motion.position)
	var expected: Control = popup.interest_arrival._card if covered else popup.trade_presentation._yes
	check(get_viewport().gui_get_hovered_control() == expected, "only the centered receipt intercepts clicks inside its frame")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(1, 1)
	Input.parse_input_event(motion)
	await frames()
