extends Node

var checks := 0
var failures := 0
var flow: MainFlowCoordinator
var popup: FinancePopup
var manager: WaveManager
var reasons: Array[String] = []
var baseline := Rect2()


func _ready() -> void:
	_run.call_deferred()


func frames(count: int = 4) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func present() -> void:
	popup.present_trade("Review", "Sample offer", "Visual only")
	popup.trade_presentation.sound_enabled = false


func check_cancelled(reason: String) -> void:
	var trade := popup.trade_presentation
	check(not trade.is_active() and not trade.visible and not trade._speech.visible and not trade._audio.playing, reason + " stops the card, bubble and sound")
	check(reasons.back() == reason and popup._bank.get_rect() == baseline, reason + " releases all reserved bank space")
	trade.seek(1.0)
	popup.configure(flow.get_preparation_payload())
	popup.set_safe_rect(popup._safe_rect)
	check(not trade.is_active() and not trade.visible and not trade._speech.visible and popup._bank.get_rect() == baseline, reason + " stays closed after animation ticks, refresh and relayout")


func seed_offer(target: String) -> Dictionary:
	var pool := ShopOfferGenerator.new().build_shop_candidate_pool(flow._build_shop_context())
	for candidate in pool:
		if str(candidate.target_id) != target: continue
		var offer: Dictionary = candidate.duplicate(true)
		offer.offer_id = "trade_cancel_test_" + target
		flow._active_shop_offers = {offer.offer_id: offer}
		flow._active_shop_offer_ids = [str(offer.offer_id)]
		flow._preparation_offers = [offer]
		flow._shop_generation += 1
		flow._notify_preparation_changed()
		return offer
	check(false, "candidate exists: " + target)
	return {}


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 768)
	get_tree().root.content_scale_size = Vector2i(1152, 768)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start real finance session")
	await frames(8)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(5000, "test")
	# This suite supplies visual fixtures; live offer selection has its own tests.
	manager.goblin_trades.preparation_wave = 1
	flow.finish_current_wave()
	await frames(12)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	baseline = popup._bank.get_rect()
	check(popup.trade_presentation == null, "presentation stays lazy without an eligible live offer")
	popup.trade_cancelled.connect(func(reason: String): reasons.append(reason))
	present()
	check(popup._bank.position.y > baseline.position.y and popup._bank.size.y < baseline.size.y, "active trade reserves only its own height")
	check(not popup.trade_presentation._no.disabled and not popup.trade_presentation._yes.disabled, "both trade buttons are enabled on the first frame")
	check(popup.trade_presentation._card.modulate.a == 1.0 and popup.trade_presentation._card.scale == Vector2.ONE and popup.trade_presentation._body.visible_characters == -1 and popup.trade_presentation._detail.modulate.a == 1.0, "complete card and all terms appear immediately")
	popup.trade_presentation.seek(0.5)
	check(popup.trade_presentation._speech_text.visible_characters > 0 and popup.trade_presentation._speech_text.visible_characters < popup.trade_presentation._speech_text.text.length(), "only goblin speech keeps typing")
	popup.trade_presentation._no.pressed.emit()
	check_cancelled("rejected")
	var count := reasons.size()
	popup.cancel_trade("duplicate")
	check(reasons.size() == count, "cancel is idempotent")

	var offer := seed_offer("relic_worn_hemostatic_cloth")
	present()
	var wallet := manager.get_current_gold()
	manager.apply_gold_delta(-wallet, "test")
	popup._buy(offer.duplicate(true))
	check(popup.trade_presentation.is_active() and reasons.size() == count, "insufficient funds do not cancel an offer")
	manager.apply_gold_delta(wallet, "test")
	popup._buy(offer.duplicate(true))
	check(flow.get_bound_player().get_relic_count("relic_worn_hemostatic_cloth") == 1, "purchase really succeeds")
	check_cancelled("purchase")

	present()
	wallet = manager.get_current_gold()
	manager.apply_gold_delta(-wallet, "test")
	popup._refresh_shop()
	check(popup.trade_presentation.is_active(), "failed refresh preserves trade")
	manager.apply_gold_delta(wallet, "test")
	popup._refresh_shop()
	check_cancelled("refresh")

	present()
	popup._choose_bank_action("deposit")
	popup.amount_input.text = str(manager.get_current_gold() + 1)
	popup._submit_bank()
	check(popup.trade_presentation.is_active(), "invalid deposit preserves trade")
	popup.amount_input.text = "200"
	popup._submit_bank()
	check(manager.finance_system.principal == 200, "deposit really transfers funds")
	check_cancelled("deposit")
	# The next bank visit allows a separate withdrawal operation.
	manager.finance_system.prepare_wave(manager.finance_system.current_wave_number + 1)
	popup.configure(flow.get_preparation_payload())
	present()
	popup._choose_bank_action("withdraw")
	popup.amount_input.text = "50"
	popup._submit_bank()
	check(manager.finance_system.principal == 150, "withdrawal really transfers funds")
	check_cancelled("withdraw")

	var item := flow.get_bound_player().item_inventory.add_item_from_base("scroll_fire", "test")
	var item_id := str(item.item_instance_id)
	present()
	popup._open_sale("enchantment", item_id)
	check(popup.trade_presentation.is_active(), "opening a sale quote does not cancel the trade")
	popup.handle_back_request()
	check(popup.trade_presentation.is_active() and not popup._sale_layer.visible, "cancelling sale confirmation preserves trade")
	popup._open_sale("enchantment", item_id)
	popup._quote.quote_token = "stale"
	popup._confirm_sale()
	check(popup.trade_presentation.is_active(), "rejected sale preserves trade")
	popup._open_sale("enchantment", item_id)
	popup._confirm_sale()
	check(flow.get_bound_player().item_inventory.find_item(item_id).is_empty(), "enchantment sale really removes the item")
	check_cancelled("sale")
	check(flow.get_bound_loadout().equip_weapon("weapon_plasma_cannon"), "second weapon fixture is available")
	present()
	popup._open_sale("weapon", "weapon_plasma_cannon")
	popup._confirm_sale()
	check(flow.get_bound_loadout().get_weapon_instance("weapon_plasma_cannon") == null, "weapon sale really removes the weapon")
	check_cancelled("sale")

	for viewport_size in [Vector2i(640, 360), Vector2i(1152, 768)]:
		get_tree().root.size = viewport_size
		get_tree().root.content_scale_size = viewport_size
		await frames(10)
		baseline = popup._bank.get_rect()
		var header := popup._bank_header.get_rect()
		present()
		await frames()
		popup.trade_presentation._no.pressed.emit()
		await frames()
		check_cancelled("rejected")
		check(popup._bank_header.get_rect() == header and popup.portrait.is_visible_in_tree(), "responsive cancellation restores header and keeps goblin visible: " + str(viewport_size))
	present()
	popup.hide_popup()
	check_cancelled("finance_closed")
	popup.show_popup()
	check(not popup.trade_presentation.is_active(), "returning to finance cannot resurrect cancelled offer")
	CampProgression.end_transient_session()
	game.queue_free()
	await frames()
	print("TRADE_CANCELLATION_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
