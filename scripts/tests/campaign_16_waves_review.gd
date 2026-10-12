extends "res://scripts/tests/run_settlement_test.gd"


func _run() -> void:
	CampProgression.begin_transient_session()
	get_tree().create_timer(160).timeout.connect(func(): get_tree().quit(99))
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	flow = game.get_main_flow_coordinator()
	await _start()
	var waves := DataRegistry.get_table("waves")
	check(waves.size() == 16, "campaign has exactly sixteen waves")
	var total_time := 0
	for entry in waves: total_time += int(entry.duration_seconds)
	check(total_time == 935, "campaign combat time is fifteen minutes thirty-five seconds")
	for index in waves.size():
		manager.set_process(false)
		manager.clear_enemies()
		manager.player.set_physics_process(false)
		check(manager.current_wave_index == index and int(manager.current_wave.duration_seconds) == mini(35 + index * 5, 65), "actual wave and duration " + str(index + 1))
		if index in [0, 15]: await _capture(null, "01_first_wave" if index == 0 else "02_final_wave")
		if index == 15: _sample_income(15)
		flow.finish_current_wave()
		await frames(10)
		if index < 15:
			check(flow.current_state == flow.STATE_FINANCE_POPUP, "preparation follows wave " + str(index + 1))
			var bank := game.find_child("FinancePopup", true, false) as FinancePopup
			bank.interest_arrival.skip()
			flow.close_finance_popup()
			if flow.current_state == flow.STATE_WAVE_CHALLENGE:
				flow.decide_wave_challenge(str(manager.wave_challenges.offer.token), false)
			await frames(5)
	check(flow.current_state == flow.STATE_BATTLE_RESULT and flow.current_victory and flow.current_battle_summary.waves == 16, "sixteenth wave ends in a paid victory receipt")
	check(not manager.start_next_wave() and not flow.request_next_wave(), "no seventeenth wave can start")
	var victory := flow.current_battle_summary.duplicate(true)
	check(int(victory.camp_currency) == roundi(int(victory.base_camp_currency) * 2.5), "victory pays the increased reward")
	await _capture_result("03_victory")
	flow.confirm_battle_result()
	await frames(6)
	await _start()
	_sample_income(8)
	flow.current_wave_index = 8
	var balance := CampProgression.get_camp_currency()
	manager.player.set("_invincibility_timer", 0.0)
	manager.player.take_damage(999999, "review_death")
	await frames(12)
	var defeat := flow.current_battle_summary.duplicate(true)
	check(flow.current_state == flow.STATE_BATTLE_RESULT and not flow.current_victory and defeat.camp_currency == 596, "actual death uses the twenty-percent increase")
	check(CampProgression.get_camp_currency() == balance + 596, "defeat receipt pays the displayed amount")
	await _capture_result("04_defeat")
	flow.confirm_battle_result()
	await frames(6)
	await _start()
	_sample_income(8)
	flow.current_wave_index = 8
	var expected := RunSettlement.build(manager.run_statistics.snapshot(), false)
	balance = CampProgression.get_camp_currency()
	flow.request_battle_utility("settings")
	await frames(6)
	var overlay := game.find_child("BattleUtilityOverlay", true, false) as BattleUtilityOverlay
	check(overlay != null and overlay._menu_button.is_visible_in_tree(), "actual settings expose the return-to-menu action")
	await click_at(overlay._menu_button.get_global_rect().get_center())
	await frames(8)
	var retreat := flow.current_battle_summary.duplicate(true)
	check(flow.current_state == flow.STATE_BATTLE_RESULT and retreat.outcome == "retreat" and retreat.paid, "settings button opens and persists the retreat receipt")
	check(retreat.camp_currency == floori(int(expected.camp_currency) * 0.5) and retreat.camp_currency == 298, "retreat pays exactly half of the corresponding defeat")
	check(retreat.waves == 8 and manager.run_statistics.frozen and not manager.running, "retreat freezes stats without crediting an unfinished wave")
	check(CampProgression.get_camp_currency() == balance + 298, "retreat pays the displayed amount")
	flow.return_to_main_menu_from_settings()
	flow.present_battle_result(true)
	check(flow.current_battle_summary == retreat and CampProgression.get_camp_currency() == balance + 298, "repeat return and late outcomes cannot pay twice")
	await _capture_result("05_retreat")
	var panel := game.find_child("BattleResultPanel", true, false) as RunSettlementPanel
	check(panel._subtitle.text.contains("撤离") and panel._conversion.text.contains("596 ×50% = 298"), "retreat UI explains the half-reward calculation")
	await click_at(panel.back_button.get_global_rect().get_center())
	await frames(8)
	check(flow.current_state == flow.STATE_START_PAGE and flow.get_bound_player() == null, "receipt confirmation returns to menu and releases combat")
	game.queue_free()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await frames(4)
	print("CAMPAIGN_16_WAVES checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _start() -> void:
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "start actual campaign")
	await frames(8)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.player.set_physics_process(false)


func _sample_income(completed_waves: int) -> void:
	# Fixed review earnings make defeat/retreat comparison readable and repeatable.
	manager.run_statistics.kills = 1800
	manager.run_statistics.combat_gold = 2500
	manager.run_statistics.interest = 1600
	manager.run_statistics.completed_waves = completed_waves
	manager.run_statistics.monsters = {"enemy_mutated_grub": 1700, "enemy_echo_bat": 80, "enemy_elite_rusher": 15, "enemy_underworld_wolf": 5}


func _capture_result(name: String) -> void:
	var panel := game.find_child("BattleResultPanel", true, false) as RunSettlementPanel
	panel.sound_enabled = false
	panel.skip()
	await frames(4)
	await _capture(panel, name)
