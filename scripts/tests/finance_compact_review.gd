extends "res://scripts/tests/finance_preparation_test.gd"

var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	super.check(condition, label)

func _run() -> void:
	CampProgression.begin_transient_session()
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start real battle")
	await frames(10)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	var hud := game.find_child("HUD", true, false) as BattleHud
	manager = hud._wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	player.set_physics_process(false)
	player.modifier_stack.set_base_stat("load_capacity", 100)
	for id in ["weapon_plasma_cannon", "weapon_hand_cannon", "weapon_camp_dagger"]:
		check(loadout.equip_weapon(id), "equip representative weapon " + id)
	check(loadout.upgrade_weapon("weapon_plasma_cannon"), "unlock second cannon slot for replacement fixture")
	manager.apply_gold_delta(450, "review")
	flow.finish_current_wave()
	await frames(25)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	popup._select_tab("enchant")
	for item in loadout.get_weapon_instance("weapon_void_blade").get_attached_item_instances():
		flow.submit_enchantment_operation("detach", "weapon_void_blade", str(item.item_instance_id))
	var fire := player.item_inventory.add_item_from_base("scroll_fire", "review")
	check(flow.submit_enchantment_operation("attach", "weapon_void_blade", str(fire.item_instance_id)).success, "attach actual enchantment")
	var records := DataRegistry.get_table("augmentations")
	for i in 24:
		player.item_inventory.add_item_from_base(str(records[i % records.size()].id), "review")
	popup.workbench.refresh()
	await get_tree().create_timer(0.4).timeout
	await _inspect_layout(Vector2i(1152, 648), "01_enchant_1152")
	await _test_weapon_scroll_controls()
	await _inspect_layout(Vector2i(1280, 720), "02_enchant_1280")
	var work := popup.workbench
	var first := work._inventory.get_child(0) as EnchantmentInventoryCard
	var selected_id := str(first.item_instance.item_instance_id)
	if DisplayServer.get_name() == "headless": first.pressed.emit()
	else: await _click_control(first)
	check(work.selected_item_id == selected_id, "smaller inventory card still selects its item")
	if DisplayServer.get_name() != "headless":
		var hover := InputEventMouseMotion.new()
		hover.position = first._inspect.get_global_rect().get_center()
		Input.parse_input_event(hover)
		await frames(8)
		check(popup._tooltip.visible, "small card inspection still opens item details")
		await capture("03_item_details")
	# Exercise the existing native drag/slot replacement integration on this layout.
	await _test_slot_replacement()
	popup.workbench.refresh()
	await _inspect_layout(Vector2i(960, 540), "04_enchant_960")
	await _inspect_layout(Vector2i(640, 360), "05_enchant_640")
	popup._feedback_message("Review feedback", true)
	check(not popup._summary.visible and not popup._feedback.get_global_rect().intersects(popup._tabs.get_global_rect()), "short-window feedback does not cover tabs or restore summary")
	popup._notice_timer.timeout.emit()
	check(not popup._summary.visible, "notice expiry cannot restore removed summary")
	L10n.set_locale("en_US", false)
	await frames(12)
	check(not popup._summary.visible and work._inventory.columns == 6, "locale refresh retains the compact layout")
	L10n.set_locale("zh_CN", false)
	await frames(12)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	popup._select_tab("shop")
	await frames(12)
	check(not popup._summary.visible and not popup._scene_summary_back.visible, "shop tab also removes central summary")
	await capture("06_shop_1280")
	flow.enter_start_page()
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("FINANCE_COMPACT_REVIEW checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _inspect_layout(viewport: Vector2i, shot: String) -> void:
	root.size = viewport
	root.content_scale_size = viewport
	popup._select_tab("enchant")
	await frames(18)
	var work := popup.workbench
	check(not work._weapon_scroll.get_h_scroll_bar().visible, "weapon scrollbar stays hidden " + str(viewport))
	popup._enchant_scroll.scroll_vertical = 0
	work._inventory_scroll.scroll_horizontal = 0
	work._inventory_scroll.scroll_vertical = 0
	await frames(8)
	check(not popup._summary.visible and not popup._scene_summary_back.visible, "summary absent " + str(viewport))
	check(work._inventory.columns == 6, "inventory fixed at six columns " + str(viewport))
	for child in work._weapon_row.get_children():
		check(child.get_theme_font_size("font_size") == 10 and child.custom_minimum_size.x == 120 and child.clip_text, "weapon card width and font " + str(viewport))
	var count := work._inventory.get_child_count()
	check(count >= 6, "review includes at least one full inventory row")
	var first := work._inventory.get_child(0) as EnchantmentInventoryCard
	check(first._caption.get_theme_font_size("font_size") == 9 and first.custom_minimum_size.x == 68, "inventory uses smaller cards and nine-point labels")
	check(is_equal_approx(first.position.y, work._inventory.get_child(5).position.y), "first six items occupy one row")
	if count > 6: check(work._inventory.get_child(6).position.y > first.position.y, "seventh item begins next row")
	for slot in work._slots.get_children():
		if slot is EnchantmentSlotCard: check(slot._caption.get_theme_font_size("font_size") == 8, "equipped slot label reduced by two")
	if viewport.x >= 1000:
		check(work._inventory_scroll.get_h_scroll_bar().max_value <= work._inventory_scroll.get_h_scroll_bar().page, "six columns fit without horizontal scrolling at standard size")
	var metrics := {"viewport": str(viewport), "workbench": str(work.size), "inventory_visible": str(work._inventory_scroll.size), "card": str(first.size), "columns": work._inventory.columns, "outer_scroll": popup._enchant_scroll.get_v_scroll_bar().max_value - popup._enchant_scroll.get_v_scroll_bar().page}
	print("LAYOUT_METRICS ", JSON.stringify(metrics))
	await capture(shot)


func _test_weapon_scroll_controls() -> void:
	var work := popup.workbench
	var scroll := work._weapon_scroll
	var bar := scroll.get_h_scroll_bar()
	var selected := work.selected_weapon_id
	var weapons_before := loadout.get_weapon_instances().duplicate()
	check(not work._weapon_scroll_left.visible and work._weapon_scroll_right.visible, "only right arrow is shown at the left boundary")
	check(scroll.get_global_rect().encloses(work._weapon_scroll_right.get_global_rect()), "right arrow is inside the weapon row at its edge")
	await _set_scroll_button(work._weapon_scroll_right, true)
	var after_press := scroll.scroll_horizontal
	check(after_press > 0 and after_press < roundi(bar.max_value - bar.page), "pressing right scrolls a small step")
	check(work._weapon_scroll_left.visible and work._weapon_scroll_right.visible, "both arrows show while between the list boundaries")
	await capture("10_weapon_scroll_middle")
	await _set_scroll_button(work._weapon_scroll_right, false)
	var after_release := scroll.scroll_horizontal
	await get_tree().create_timer(0.25).timeout
	check(scroll.scroll_horizontal == after_release and not work.is_processing(), "release immediately stops continuous scrolling")
	await _set_scroll_button(work._weapon_scroll_right, true)
	var hold_start := scroll.scroll_horizontal
	await get_tree().create_timer(0.5).timeout
	check(scroll.scroll_horizontal > hold_start, "holding right continues scrolling after the initial step")
	await _set_scroll_button(work._weapon_scroll_right, false)
	check(work.selected_weapon_id == selected, "release after an arrow disappears does not select the covered weapon")
	check(not work._weapon_scroll_right.visible and work._weapon_scroll_left.visible, "right arrow disappears at the right boundary")
	check(scroll.scroll_horizontal == roundi(bar.max_value - bar.page), "hold clamps precisely to the list boundary")
	await capture("07_weapon_scroll_right")
	await _set_scroll_button(work._weapon_scroll_left, true)
	await get_tree().create_timer(0.6).timeout
	await _set_scroll_button(work._weapon_scroll_left, false)
	check(scroll.scroll_horizontal == 0 and not work._weapon_scroll_left.visible, "holding left returns to the first weapon and hides the left arrow")
	await _set_scroll_button(work._weapon_scroll_right, true)
	popup._select_tab("shop")
	await frames(3)
	check(not work.is_processing(), "changing tabs cancels a held scroll")
	await _set_scroll_button(work._weapon_scroll_right, false)
	popup._select_tab("enchant")
	await frames(4)
	check(work.selected_weapon_id == selected and loadout.get_weapon_instances() == weapons_before, "list navigation preserves selection and weapon order")
	scroll.scroll_horizontal = 0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await frames(18)
	check(not work._weapon_scroll_left.visible and not work._weapon_scroll_right.visible, "both arrows hide when all weapons fit")


func _set_scroll_button(button: Button, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)

func _click_control(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(3)
