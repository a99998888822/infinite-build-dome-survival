extends "res://scripts/tests/active_combat_integration_test.gd"
## Follow the actual question-mark button through combat and stacked modals.
var hud: BattleHud
var utility: BattleUtilityOverlay
var finance: FinancePopup


func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		await frames(2)


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	await frames(12)
	await boot()
	hud = battle.get_node("HUD") as BattleHud
	utility = battle.utility_overlay
	finance = game.find_child("FinancePopup", true, false) as FinancePopup
	player.set_physics_process(false)
	for id in ["relic_piggy_bank", "relic_perpetual_annuity_scroll", "relic_goblin_trade_charter"]:
		manager.add_relic(id)
	for id in ["scroll_lightning", "scroll_fire", "scroll_water"]:
		player.item_inventory.add_item_from_base(id, "review")
	loadout.equip_weapon("weapon_plasma_cannon")
	await _round_trip("combat", true)
	flow.request_esc_overlay()
	await frames(20)
	await mouse(Vector2(800, 950))
	await capture("01_inventory")
	await _round_trip("inventory")
	check(battle.esc_overlay.visible, "inventory remains open after encyclopedia")
	flow.close_esc_overlay()
	await frames(20)
	flow.request_shared_reward_shop_popup(2)
	await frames(20)
	var offers := flow._active_shop_offers.duplicate(true)
	await _round_trip("reward", true)
	check(flow._active_shop_offers == offers, "encyclopedia leaves queued reward offers unchanged")
	flow.close_shared_reward_shop_popup()
	manager.apply_gold_delta(500, "test")
	flow.finish_current_wave()
	await frames(20)
	finance.interest_arrival.skip()
	await frames(8)
	await _round_trip("finance")
	check(finance.visible, "finance remains visible after encyclopedia")
	flow.request_esc_overlay()
	await frames(20)
	await _round_trip("finance_inventory", true)
	flow.close_esc_overlay()
	await frames(20)
	check(flow.current_state == flow.STATE_FINANCE_POPUP and finance.visible, "nested inventory returns to original finance page")
	for resolution in [Vector2i(1152, 648), Vector2i(640, 360)]:
		get_tree().root.size = resolution
		# Normal play retains the native design canvas at smaller window sizes.
		await frames(12)
		await _round_trip("finance_" + str(resolution.x), true)
	get_tree().root.size = Vector2i(1920, 1080)
	await frames(12)
	manager.wave_challenges.config.challenges = [manager.wave_challenges.definition("extra_elites")]
	manager.wave_challenges.pressure = {"struggling": true, "comfortable": false}
	flow.close_finance_popup()
	await frames(12)
	var challenge := game.find_child("WaveChallengePopup", true, false) as WaveChallengePopup
	check(flow.current_state == flow.STATE_WAVE_CHALLENGE, "real next-wave challenge opens")
	var token := str(challenge.proposal.get("token", ""))
	challenge.presentation.seek(4.6)
	challenge.presentation.set_process(false)
	await capture("03_challenge")
	# Challenge shade covers the HUD, so exercise the same flow request directly.
	await _round_trip("challenge", true, false)
	check(challenge.visible and str(challenge.proposal.get("token", "")) == token, "challenge proposal survives encyclopedia round trip")
	flow.return_from_wave_challenge()
	await frames(8)
	flow.enter_start_page()
	await frames(8)
	check(not flow.can_open_battle_utility("encyclopedia"), "main menu cannot open battle encyclopedia")
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("ENCYCLOPEDIA_ENTRY_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _round_trip(label: String, escape_close: bool = false, pointer: bool = true) -> void:
	var source := flow.current_state
	var paused := bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	var time_left := manager.wave_time_left
	var gold := manager.current_gold
	var bank_locked := manager.finance_system.manual_operation_used
	var prior_return := flow._resume_state_after_modal
	check(flow.can_open_battle_utility("encyclopedia") and not hud.encyclopedia_button.disabled, label + " question button enabled")
	if pointer and DisplayServer.get_name() != "headless":
		await click(hud.encyclopedia_button)
	else:
		hud.encyclopedia_button.pressed.emit()
	await frames(8)
	check(flow.current_state == flow.STATE_BATTLE_UTILITY and utility.visible and utility._panel.visible, label + " opens actual encyclopedia")
	check(utility._entries.item_count > 0 and not utility._entry_details.text.is_empty(), label + " catalog and detail populated")
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)), label + " encyclopedia keeps battle paused")
	if label == "finance":
		check(utility._close_button.text == "ui.common.back", "encyclopedia return label respects paused source page")
		await capture("02_encyclopedia_from_finance")
		utility._category.select(1)
		utility._category.item_selected.emit(1)
		await frames()
		check(utility._records.size() == DataRegistry.get_table("weapons").size(), "weapon category shows actual catalog")
		var query := utility._entries.get_item_text(0)
		utility._search.text = query
		utility._search.text_changed.emit(query)
		check(utility._entries.item_count > 0 and utility._entries.get_item_text(0) == query, "search returns matching weapon")
		utility._search.text = "no_matching_weapon_12345"
		utility._search.text_changed.emit(utility._search.text)
		check(utility._entries.item_count == 0, "empty search results handled")
		utility._search.clear()
		utility._search.text_changed.emit("")
		utility._category.select(0)
		utility._category.item_selected.emit(0)
	if escape_close:
		await key(KEY_ESCAPE)
		await key(KEY_ESCAPE, false)
	elif DisplayServer.get_name() != "headless":
		await click(utility._close_button)
	else:
		utility._close_button.pressed.emit()
	await frames(8)
	check(flow.current_state == source and not utility.visible, label + " returns to exact source")
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) == paused, label + " restores original pause state")
	check(manager.current_gold == gold and manager.finance_system.manual_operation_used == bank_locked and manager.wave_time_left == time_left, label + " preserves gold bank lock and wave time")
	check(flow._resume_state_after_modal == prior_return, label + " preserves outer return state")
