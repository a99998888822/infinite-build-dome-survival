extends "res://scripts/tests/weapon_workbench_review.gd"


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.unfocusable = true
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "battle starts for art review")
	await frames()
	var player := flow.get_bound_player()
	var loadout := flow.get_bound_loadout()
	player.set_physics_process(false)
	flow._bound_wave_manager.set_process(false)
	flow._bound_wave_manager.clear_enemies()
	var weapon := loadout.get_weapon_instance("weapon_void_blade")
	for initial in weapon.get_attached_item_instances():
		loadout.detach_item_from_weapon(weapon.weapon_id, str(initial.item_instance_id))
	player.item_inventory.clear()
	var unique_icons := {}
	for data: Dictionary in DataRegistry.get_table("augmentations"):
		var item := player.item_inventory.add_item_from_base(str(data.id), "art_review")
		var texture := FinanceUIStyle.item_icon(str(item.icon))
		check(texture != null and texture.get_size() == Vector2(32, 32), "imported 32px icon: " + str(data.id))
		unique_icons[str(item.icon)] = true
		var card := ItemInventoryCard.new()
		add_child(card)
		card.configure(item, false)
		check(card.icon == texture and not card.expand_icon, "ESC card retains native pixels: " + str(data.id))
		card.free()
	check(unique_icons.size() == DataRegistry.get_table("augmentations").size() - 1, "only the two lightning records share an icon")
	check(DataRegistry.get_record("augmentations", "scroll_lightning").icon == DataRegistry.get_record("augmentations", "scroll_electric_spark").icon, "lightning sharing preserved")
	for id in ["scroll_might", "scroll_multishot"]:
		for attempt in 10:
			if weapon.has_available_attachment_slot(): break
			if not weapon.upgrade(): break
		var item := player.item_inventory.add_item_from_base(id, "art_review_slot")
		check(loadout.attach_item_to_weapon(weapon.weapon_id, str(item.item_instance_id)), "new PNG reference attaches: " + id)
	flow.finish_current_wave()
	await frames(30)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.stop()
	popup.cancel_trade("augmentation_art_review")
	popup._select_tab("enchant")
	var bench := popup.workbench
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1152, 768), Vector2i(1024, 576)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = dimensions
		await frames(20)
		check(bench._inventory.get_child_count() == DataRegistry.get_table("augmentations").size(), "all enchantment records remain reachable")
		for card in bench._inventory.get_children():
			if card is EnchantmentInventoryCard:
				check(card._art.size == Vector2(32, 32), "workbench icon uses 32px area")
				check(card.get_global_rect().encloses(card._art.get_global_rect()), "inventory icon is not cropped")
		for slot in bench._slots.get_children():
			if slot is EnchantmentSlotCard and not slot.item_instance.is_empty():
				check(slot._art.size.y == 32 and slot.get_global_rect().encloses(slot._art.get_global_rect()), "equipped icon and caption fit the card")
		bench._inventory_scroll.scroll_vertical = 0
		popup._enchant_scroll.scroll_vertical = 0
		await frames()
		await capture("augmentations_%dx%d" % [dimensions.x, dimensions.y])
		bench._inventory_scroll.scroll_vertical = int(bench._inventory_scroll.get_v_scroll_bar().max_value)
		popup._enchant_scroll.scroll_vertical = int(popup._enchant_scroll.get_v_scroll_bar().max_value)
		await frames()
		var last := bench._inventory.get_child(bench._inventory.get_child_count() - 1) as EnchantmentInventoryCard
		check(bench._inventory_scroll.get_global_rect().encloses(last.get_global_rect()), "last item can be scrolled fully into view")
		last.pressed.emit()
		check(bench.selected_item_id == str(last.item_instance.item_instance_id), "last item remains selectable")
		await capture("augmentations_end_%dx%d" % [dimensions.x, dimensions.y])
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("AUGMENTATION_ART_REVIEW checks=", checks, " failures=", failures)
	weapon = null
	get_tree().quit.call_deferred(0 if failures == 0 else 1)
