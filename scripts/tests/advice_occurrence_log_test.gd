extends "res://scripts/tests/finance_preparation_test.gd"

var log_file := AdviceOccurrenceLog.new()


func _counts(kind: String, id: String) -> Array:
	var rows := log_file._empty_rows()
	check(log_file._read(rows), "CSV can be read back")
	var row: Dictionary = rows[kind + ":" + id]
	return [int(row.appeared), int(row.selected)]


func _run() -> void:
	CampProgression.begin_transient_session()
	log_file.storage_path = "user://tmp/advice_counts_%d.csv" % Time.get_ticks_usec()
	var before := FileAccess.get_file_as_bytes(AdviceOccurrenceLog.SAVE_PATH) if FileAccess.file_exists(AdviceOccurrenceLog.SAVE_PATH) else PackedByteArray()
	var isolated := RunStatistics.new()
	isolated.show_advice("trade", "test", "weapon_buyout")
	isolated.decide_advice("trade", "test", true)
	var after := FileAccess.get_file_as_bytes(AdviceOccurrenceLog.SAVE_PATH) if FileAccess.file_exists(AdviceOccurrenceLog.SAVE_PATH) else PackedByteArray()
	check(before == after, "transient review cannot change the player's cumulative log")
	var stats := RunStatistics.new()
	stats.advice_log = log_file
	stats.show_advice("trade", "1:weapon_buyout", "weapon_buyout")
	stats.show_advice("trade", "1:weapon_buyout", "weapon_buyout")
	check(_counts("trade", "weapon_buyout") == [1, 0], "reopening one offer counts only one appearance")
	stats.decide_advice("trade", "stale", true)
	stats.decide_advice("trade", "1:weapon_buyout", false)
	stats.decide_advice("trade", "1:weapon_buyout", true)
	check(_counts("trade", "weapon_buyout") == [1, 0], "stale and rejected choices do not increment selections")
	stats.show_advice("trade", "2:weapon_buyout", "weapon_buyout")
	stats.decide_advice("trade", "2:weapon_buyout", true)
	stats.decide_advice("trade", "2:weapon_buyout", true)
	check(_counts("trade", "weapon_buyout") == [2, 1], "successful choice is counted once")
	stats.freeze()
	stats.show_advice("trade", "3:weapon_buyout", "weapon_buyout")
	check(_counts("trade", "weapon_buyout") == [2, 1], "finished run cannot add appearances")
	stats.reset()
	stats.show_advice("trade", "1:weapon_buyout", "weapon_buyout")
	stats.decide_advice("trade", "1:weapon_buyout", true)
	check(_counts("trade", "weapon_buyout") == [3, 2], "new runs accumulate even when wave tokens repeat")
	var reopened := AdviceOccurrenceLog.new()
	reopened.storage_path = log_file.storage_path
	var rows := reopened._empty_rows()
	check(reopened._read(rows) and rows.size() == 18 and int(rows["trade:weapon_buyout"].selected) == 2, "fresh logger restores totals and keeps zero-count entries")
	await _test_real_flow()
	var artifact := "res://artifacts/reviews/advice_occurrence_log_20261012/sample_counts.csv"
	DirAccess.copy_absolute(log_file.storage_path, artifact)
	DirAccess.remove_absolute(log_file.storage_path)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("ADVICE_OCCURRENCE_LOG failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func _test_real_flow() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(10)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "start a real run for event hooks")
	await frames(10)
	player = flow.get_bound_player()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	player.set_physics_process(false)
	manager.run_statistics.advice_log = log_file
	manager.goblin_trades.config.trades = [manager.goblin_trades.definition("interest_pact")]
	flow.finish_current_wave()
	await frames(12)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	var trade := manager.goblin_trades.offer.duplicate(true)
	check(not trade.is_empty() and _counts("trade", "interest_pact") == [1, 0], "actual finance presentation records the trade ID")
	popup.configure(flow.get_preparation_payload())
	check(not flow.accept_goblin_trade("stale").success and _counts("trade", "interest_pact") == [1, 0], "refresh and failed actual purchase do not inflate counts")
	check(flow.accept_goblin_trade(str(trade.token)).success and _counts("trade", "interest_pact") == [1, 1], "successful actual trade records one selection")
	var challenges := manager.wave_challenges
	challenges.config.challenges = [challenges.definition("extra_elites")]
	challenges.pressure.struggling = true
	flow.close_finance_popup()
	await frames(5)
	var offer := challenges.offer.duplicate(true)
	check(flow.current_state == flow.STATE_WAVE_CHALLENGE and _counts("challenge", "extra_elites") == [1, 0], "actual challenge presentation records its ID")
	flow.return_from_wave_challenge()
	flow.close_finance_popup()
	check(_counts("challenge", "extra_elites") == [1, 0], "returning to finance and reopening challenge is not another appearance")
	check(not flow.decide_wave_challenge("stale", true) and _counts("challenge", "extra_elites") == [1, 0], "failed actual challenge choice does not count")
	check(flow.decide_wave_challenge(str(offer.token), true) and _counts("challenge", "extra_elites") == [1, 1], "accepting an actual challenge records one selection")
	manager.set_process(false)
	game.queue_free()
	await frames(4)
