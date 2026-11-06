extends Node
## Open talent branches and retained weapon restrictions, including existing saves.
const LOCKED_WEAPONS := ["weapon_iron_grenade_cannon", "weapon_copper_lamp", "weapon_camp_dagger", "weapon_rentier_purse", "weapon_mutant_tentacle", "weapon_star_tome"]
const OPEN_BUILDINGS := ["camp_blade_arena", "camp_farstar_range", "camp_dome_shelter", "camp_council_hall"]
var checks := 0
var failures := 0
var capture_dir := ""

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", note)

func frames(count := 4) -> void:
	for index in count: await get_tree().process_frame

func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	get_viewport().push_input(event, true)

func click(point: Vector2) -> void:
	move_pointer(point)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
	await frames()

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)

func _run() -> void:
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	check(DataRegistry.get_load_errors().is_empty(), "configuration validates")
	_test_weapons()
	CampProgression.set_camp_currency(100000)
	for id in OPEN_BUILDINGS:
		check(not CampProgression.is_building_release_locked(id), "talent branch is available: " + id)
		check(CampProgression.can_purchase_building_unlock(id) and CampProgression.purchase_building_unlock(id), "talent branch can unlock: " + id)
		# Existing progress remains usable after removing the release restriction.
		CampProgression.state.building_levels[id] = 2
		for option in CampProgression.get_building_record(id).upgrade_options:
			CampProgression.state.upgrade_levels[str(option.id)] = 1
		for option in CampProgression.get_building_record(id).upgrade_options:
			check(CampProgression.is_upgrade_visible(str(option.id)), "saved descendant remains available: " + str(option.id))
			check(CampProgression.can_purchase_upgrade(str(option.id)) == (int(option.max_level) > 1), "saved descendant respects maximum level: " + str(option.id))
	var saved := CampProgression.get_state()
	var window := get_tree().root
	window.unfocusable = true
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = window.size
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	window.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_talents_flow()
	await frames(8)
	var page := game.get_node("UiRoot/CampBlueprintUIController") as CampBlueprintUIController
	for id in OPEN_BUILDINGS:
		var node: TalentNodeButton = page._nodes[id]
		check(node.visible and not node.disabled and node.lit and page._node_levels[id].visible, "opened branch reflects saved level: " + id)
		move_pointer(Vector2(10, 10))
		move_pointer(node.get_global_rect().get_center())
		check(not page._upgrade_tooltip.visible, "opened branch has no release restriction hint: " + id)
		await capture(id)
		await click(node.get_global_rect().get_center())
		check(page._selected_id == id and page._detail_panel.visible, "opened branch remains selectable: " + id)
	check(CampProgression.get_state() == saved, "viewing branches preserves currency and progression")
	for id in ["camp_armory_workshop", "camp_relic_archive"]:
		check(not page._nodes[id].disabled and page._nodes[id].lit, "initial building stays available: " + id)
		await click(page._nodes[id].get_global_rect().get_center())
		check(page._selected_id == id and page._upgrade_button.visible, "initial building remains selectable: " + id)
	page.select_node("")
	await capture("overview")
	L10n.set_locale("en", false)
	move_pointer(page._nodes[OPEN_BUILDINGS[0]].get_global_rect().get_center())
	check(not page._upgrade_tooltip.visible, "opened branch stays available in English")
	L10n.set_locale("zh_CN", false)
	page._on_back_pressed()
	_test_stale_purchases(flow)
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	print("RELEASE_CONTENT_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_weapons() -> void:
	check(DataRegistry.get_record_count("weapons") == 16, "all sixteen weapon definitions retained")
	var generator := ShopOfferGenerator.new()
	var context := {"load_capacity": 1000, "luck": 1000, "unlocked_weapon_ids": LOCKED_WEAPONS}
	var locked_pool := generator.build_shop_candidate_pool(context)
	check(not locked_pool.any(func(c): return c.offer_type == "new_weapon"), "unlock lists cannot override release locks")
	context.unlocked_weapon_ids = []
	context.equipped_weapons = []
	for id in LOCKED_WEAPONS:
		var record := DataRegistry.get_record("weapons", id)
		check(bool(record.get("release_locked", false)) and ResourceLoader.exists(str(record.icon)) and not record.level_upgrades.is_empty(), "locked weapon keeps art and upgrades: " + id)
		context.equipped_weapons.append({"weapon_id": id, "level": 1})
	var pool := generator.build_shop_candidate_pool(context)
	check(pool.filter(func(c): return c.offer_type == "new_weapon").size() == 10, "exactly ten weapons remain available")
	check(not pool.any(func(c): return str(c.target_id) in LOCKED_WEAPONS), "locked weapons and their upgrade offers absent")
	var valid := true
	for index in 100:
		for mode in ["shop", "free"]:
			var rarity := generator.get_shop_rarity_weights(1000)
			var types := {"new_weapon": 100, "relic": 60, "weapon_upgrade": 100}
			var offers := generator.roll_paid_offers(rarity, types, pool, 8, index, [], "epic", true) if mode == "shop" else generator.roll_shop_offers(rarity, types, pool, 8, true)
			valid = valid and offers.size() == 8 and not offers.any(func(c): return str(c.target_id) in LOCKED_WEAPONS)
	check(valid, "paid, free and guaranteed refreshes never show locked weapons")

func _test_stale_purchases(flow: MainFlowCoordinator) -> void:
	for mode in ["shop", "free"]:
		flow.current_state = MainFlowCoordinator.STATE_SHOP_POPUP if mode == "shop" else MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP
		for id in LOCKED_WEAPONS:
			for kind in ["new_weapon", "weapon_upgrade"]:
				var offer := {"offer_id": "stale", "offer_type": kind, "target_id": id, "rarity": "common", "from_level": 1, "to_level": 2}
				ShopPricing.apply(offer, flow._build_shop_context())
				flow._active_shop_offers.stale = offer
				var result := flow.submit_shop_purchase(offer, mode)
				check(not result.success and result.reason == "release_locked" and not flow._transaction_busy, mode + " rejects stale " + kind + ": " + id)
