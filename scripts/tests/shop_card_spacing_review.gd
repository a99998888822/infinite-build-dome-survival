extends "res://scripts/tests/finance_preparation_test.gd"
## Visual fixture using real item names, icons and upgrade descriptions.

func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	root.borderless = true
	root.size = Vector2i(2400, 1080)
	MobileProfile.apply_to_window(root)
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start review run")
	await frames(10)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(999, "review")
	flow.finish_current_wave()
	await frames(20)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	popup.cancel_trade("review")
	popup._select_tab("shop")
	var offers: Array = [
		_relic("relic_finance_manager"),
		_relic("relic_defiled_blessing_coin"),
		_upgrade("weapon_plasma_cannon"),
		_upgrade("weapon_hand_cannon"),
		_relic("relic_goblin_central_bank_printer"),
		_upgrade("weapon_kunyu_ritual_tome"),
	]
	if not MobileProfile.is_mobile():
		offers.append_array(offers.duplicate(true))
	popup.shop_grid.flow = null
	popup.shop_grid.set_offers(offers, true)
	await frames(20)
	check(not popup.shop_grid.scroll.get_v_scroll_bar().visible, "shop scrollbar is hidden")
	for card: PreparationOfferCard in popup.shop_grid._pool:
		if not card.visible: continue
		var heading := card._icon_frame.get_parent() as Control
		var gap := card._description.global_position.y - heading.get_global_rect().end.y
		check(is_equal_approx(gap, 4.0), "heading to description is four pixels: " + str(card.offer.target_id))
		check(card._kind_label.custom_minimum_size.y == 0, "quality label uses natural height")
		print("CARD_REVIEW ", card.offer.target_id, " title_lines=", card._name_label.get_line_count(), " gap=", gap, " kind=", card._kind_label.text, " rect=", card._kind_label.get_global_rect(), " title_rect=", card._name_label.get_global_rect())
	await capture("01_shop_spacing_top")
	popup.shop_grid.scroll.scroll_vertical = 10000
	await frames(15)
	check(popup.shop_grid.scroll.scroll_vertical > 0, "hidden scrollbar retains vertical scrolling")
	await capture("02_shop_spacing_bottom")
	root.size = Vector2i(1920, 1080)
	MobileProfile.apply_to_window(root)
	popup.shop_grid.scroll.scroll_vertical = 0
	await frames(20)
	await capture("03_shop_spacing_narrow_top")
	popup.shop_grid.scroll.scroll_vertical = 10000
	await frames(15)
	await capture("04_shop_spacing_narrow_bottom")
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("SHOP_CARD_SPACING_REVIEW failures=", failures)
	get_tree().quit(1 if failures else 0)


func _relic(id: String) -> Dictionary:
	var record := DataRegistry.get_record("relics", id).duplicate(true)
	record.merge({"offer_id": "review:" + id, "offer_type": "relic", "target_id": id, "shop_cost": 21})
	return record


func _upgrade(id: String) -> Dictionary:
	var record := DataRegistry.get_record("weapons", id)
	var upgrade: Dictionary = record.level_upgrades["2"]
	return {
		"offer_id": "review:" + id, "offer_type": "weapon_upgrade", "target_id": id,
		"display_name_message": L10n.message("ui.shop.upgrade_to_level", [str(record.display_name), 2]),
		"description": upgrade.description, "rarity": upgrade.get("rarity", "common"),
		"icon": record.icon, "shop_cost": 24,
	}
