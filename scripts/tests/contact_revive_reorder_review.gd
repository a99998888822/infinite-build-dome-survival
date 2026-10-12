extends "res://scripts/tests/active_combat_integration_test.gd"

func capture(name: String) -> void:
	await mouse(Vector2(14, get_viewport().get_visible_rect().size.y - 14))
	await super.capture(name)

func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(12)
	await boot()
	player.set_physics_process(false)
	player.modifier_stack.set_base_stat("max_hp", 100)
	player.modifier_stack.set_base_stat("armor", 0)
	player.current_hp = 100
	player.current_shield = 0
	await _contact_checks()
	_revive_checks()
	await _reorder_checks()
	await _drag_checks()
	await _revive_capture()
	flow.enter_start_page()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	print("CONTACT_REVIVE_REORDER checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _contact_checks() -> void:
	var enemy := manager.spawn_enemy("enemy_mutated_grub", player.global_position)
	enemy.set_physics_process(false)
	enemy.modifier_stack.set_base_stat("melee_damage", 3)
	enemy.modifier_stack.set_base_stat("damage_percent", 0)
	check(enemy._is_touching_player(), "real enemy and player collision shapes overlap")
	var hp := player.current_hp
	enemy._process_contact_damage()
	var first := hp - player.current_hp
	enemy._process_contact_damage()
	check(first > 0 and hp - player.current_hp == first * 2, "same enemy can damage twice without any cooldown advance")
	check(not player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a, 1), "ordinary contact does not start revive blink")
	check(enemy._knockback_timer > 0, "existing physical contact recoil is retained")
	enemy.global_position += Vector2(300, 0)
	hp = player.current_hp
	enemy._process_contact_damage()
	check(player.current_hp == hp, "separated enemy cannot deal contact damage")
	enemy.queue_free()
	await frames()

func _revive_checks() -> void:
	player.current_hp = 100
	player.remaining_revives = 1
	player.take_damage(10000, "review_lethal_contact")
	check(player.alive and player.current_hp > 0 and player.remaining_revives == 0, "real lethal damage consumes a revive")
	check(is_equal_approx(player._invincibility_timer, 1) and player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a, 0.25), "revival starts exactly one second of immunity and blink")
	check(player._revive_wings.active and is_zero_approx(player._revive_wings.opening) and player._revive_wings.z_index < 0, "revival starts folded wings behind the player")
	var hp := player.current_hp
	check(player.take_damage(3) == 0 and player.current_hp == hp, "revival immunity blocks immediate damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	player._physics_process(2)
	check(is_equal_approx(player._invincibility_timer, 1) and is_equal_approx(player.sprite.self_modulate.a, 0.25), "pause freezes both immunity and blink")
	check(is_zero_approx(player._revive_wings.elapsed), "pause also freezes the wing animation")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	player._physics_process(0.11)
	check(is_equal_approx(player.sprite.self_modulate.a, 1), "revival alternates back to full opacity")
	player._physics_process(0.1)
	check(is_equal_approx(player.sprite.self_modulate.a, 0.25), "revival alternates to dim opacity again")
	player._physics_process(0.78)
	check(player.take_damage(3) == 0 and player._revive_blink_active, "immunity remains at 0.99 seconds")
	check(player._revive_wings.opening > 0.99, "wings gradually reach full spread near one second")
	player._physics_process(0.011)
	check(not player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a, 1) and player.take_damage(3) > 0, "blink and immunity end together after one second")
	check(player._revive_wings.active, "visual feather fade does not extend immunity")
	player._physics_process(0.51)
	check(not player._revive_wings.active and not player._revive_wings.visible, "wing effect cleans up after its short fade")
	player.current_hp = 0
	check(player.revive_from_lethal_damage(50), "paid-protection revive path also starts the shared effect")
	check(player._revive_wings.active and is_zero_approx(player._revive_wings.elapsed), "subsequent revival restarts the same wing effect")
	player._invincibility_timer = 0
	player.remaining_revives = 0
	player.take_damage(10000, "review_cleanup")
	check(not player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a, 1), "death clears blink opacity")
	check(not player._revive_wings.active, "death clears remaining wings")
	# Use a fresh run for the visual review after the destructive death assertion.
	player.initialize_from_character("character_void_hunter")
	player.modifier_stack.set_base_stat("max_hp", 100)
	player.current_hp = 100
	check(not player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a, 1), "new initialization restores the normal player visual")
	check(not player._revive_wings.visible, "new initialization has no stale wing effect")

func _press(control: Button) -> void:
	if DisplayServer.get_name() == "headless":
		control.pressed.emit()
		await frames()
	else:
		await click(control)

func _reorder_checks() -> void:
	# Restart the actual flow after the death case; no dead battle state is reused.
	await boot()
	player.set_physics_process(false)
	player.modifier_stack.set_base_stat("load_capacity", 100)
	for id in ["weapon_plasma_cannon", "weapon_hand_cannon", "weapon_camp_dagger"]:
		check(loadout.equip_weapon(id), "equip review weapon " + id)
	var cannon := loadout.get_weapon_instance("weapon_hand_cannon")
	loadout.upgrade_weapon(cannon.weapon_id)
	var item := player.item_inventory.add_item_from_base("scroll_lightning", "reorder_review")
	check(loadout.attach_item_to_weapon(cannon.weapon_id, str(item.item_instance_id)), "attach a real enchantment before reordering")
	var level := cannon.level
	var attachments := cannon.get_attached_item_instances().duplicate(true)
	var cast_state := loadout.active_casting.state_for(cannon)
	flow.request_esc_overlay()
	await get_tree().create_timer(0.45).timeout
	var strip := battle.esc_overlay.weapon_strip
	cast_state.remaining = 3.25
	cast_state.total = 6.0
	check(strip._selected_weapon_id != cannon.weapon_id, "cannon is not preselected before clicking its own arrow")
	check(is_equal_approx(strip.size.y, 62), "weapon strip retains its original height")
	var panel := strip.get_node("StripPanel") as Control
	check(is_zero_approx(panel.offset_left) and is_zero_approx(panel.offset_right), "weapon frame retains its full width")
	_check_arrow_layout(strip)
	var first_weapon: WeaponInstance = loadout.weapon_instances[0]
	await _press(strip._reorder_buttons[0].right)
	check(loadout.weapon_instances[1] == first_weapon, "first weapon own right button moves it one slot")
	await _press(strip._reorder_buttons[1].left)
	check(loadout.weapon_instances[0] == first_weapon and strip._reorder_buttons[0].left == null, "moving back to first omits its left button")
	await capture("01_esc_selected")
	await _press(strip._reorder_buttons[2].right)
	check(loadout.weapon_instances[3] == cannon and strip._reorder_buttons[3].right == null, "own right arrow directly moves cannon one slot and disappears at last slot")
	check(strip._weapon_buttons[3].button_pressed and not strip._weapon_buttons[3].flat, "moved weapon retains a visible highlight")
	_check_arrow_layout(strip)
	await capture("02_esc_moved_right")
	await _press(strip._reorder_buttons[3].left)
	check(loadout.weapon_instances[2] == cannon, "left arrow swaps back one position")
	await _press(strip._reorder_buttons[2].left)
	check(loadout.weapon_instances[1] == cannon, "same selected weapon follows repeated moves")
	await capture("03_esc_moved_left")
	await _press(strip._cast_mode_buttons[1])
	check(CombatSettings.prefers_auto_cast(cannon.weapon_id, false) and loadout.weapon_instances[1] == cannon, "mode button toggles without triggering either corner arrow")
	await _press(strip._cast_mode_buttons[1])
	check(not CombatSettings.prefers_auto_cast(cannon.weapon_id, true), "mode button can restore manual casting")
	check(cannon.level == level and cannon.get_attached_item_instances() == attachments and is_equal_approx(cast_state.remaining, 3.25), "reordering preserves level attachments and cooldown")
	check(loadout.get_total_load_cost() == 96 and not CombatSettings.prefers_auto_cast(cannon.weapon_id, true), "reordering preserves load and manual cast policy")
	check(not loadout.move_weapon(loadout.weapon_instances[0].weapon_id, -1) and not loadout.move_weapon(cannon.weapon_id, 2), "invalid and out-of-bounds moves do not wrap")
	flow.close_esc_overlay()
	await get_tree().create_timer(0.3).timeout
	check(battle.hud.combat_bar.weapons == loadout.weapon_instances, "battle bar follows the new order")
	controller.select_slot(1)
	check(controller.selected_weapon == cannon, "number slot two targets the moved weapon instance")
	controller.cancel_aim()
	await capture("04_battle_order")
	flow.request_esc_overlay()
	await get_tree().create_timer(0.4).timeout
	check(strip._selected_weapon_id == cannon.weapon_id and loadout.weapon_instances[1] == cannon, "reopening Esc preserves selection and order")
	get_tree().root.size = Vector2i(960, 540)
	get_tree().root.content_scale_size = Vector2i(960, 540)
	await frames(12)
	check(get_viewport().get_visible_rect().encloses(strip._weapon_buttons[1].get_parent().get_global_rect()), "compact viewport keeps weapon and both adjacent arrows reachable")
	_check_arrow_layout(strip)
	await capture("05_esc_compact")
	player.modifier_stack.set_base_stat("load_capacity", 1000)
	for record: Dictionary in DataRegistry.get_table("weapons"):
		if not loadout.has_weapon(str(record.id)): loadout.equip_weapon(str(record.id))
	await frames(10)
	var scroll := strip.weapon_list.get_parent() as ScrollContainer
	var last := strip._weapon_buttons.back() as Button
	scroll.ensure_control_visible(last.get_parent() as Control)
	await frames(10)
	var last_id := (last as WeaponSlotButton).weapon.weapon_id
	await _press(strip._reorder_buttons[-1].left)
	check(loadout.weapon_instances[-2].weapon_id == last_id and scroll.scroll_horizontal > 0, "overflowing row moves a scrolled weapon without losing selection")
	check(scroll.get_global_rect().encloses(strip._weapon_buttons[-2].get_parent().get_global_rect()), "scrolling keeps moved icon and both of its arrows visible: %s inside %s" % [strip._weapon_buttons[-2].get_parent().get_global_rect(), scroll.get_global_rect()])
	_check_arrow_layout(strip)
	await capture("06_esc_overflow")
	for weapon in loadout.get_weapon_instances():
		if weapon.weapon_id not in ["weapon_void_blade", "weapon_plasma_cannon", "weapon_hand_cannon", "weapon_camp_dagger"]: loadout.remove_weapon(weapon.weapon_id)
	player.modifier_stack.set_base_stat("load_capacity", 100)
	var shop_strip := preload("res://scenes/ui/common/weapon_strip.tscn").instantiate() as WeaponStrip
	add_child(shop_strip)
	shop_strip.hide()
	shop_strip.set_loadout(loadout)
	check(shop_strip._reorder_buttons.is_empty(), "shared shop strip does not gain Esc reorder controls")
	shop_strip.queue_free()
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	flow.close_esc_overlay()
	await get_tree().create_timer(0.35).timeout

func _check_arrow_layout(strip: WeaponStrip) -> void:
	check(strip._reorder_buttons.size() == strip._weapon_buttons.size(), "every weapon owns its own arrow group")
	for i in strip._weapon_buttons.size():
		var arrows: Dictionary = strip._reorder_buttons[i]
		var icon: Rect2 = strip._weapon_buttons[i].get_global_rect()
		var icon_minimum: Vector2 = strip._weapon_buttons[i].get_combined_minimum_size()
		# Headless font/viewport metrics may enlarge the existing icon minimum.
		# The overlay must add no space beyond that original icon requirement.
		var group_size: Vector2 = strip._weapon_buttons[i].get_parent().size
		check(icon.size.ceil() == icon_minimum.ceil() and group_size.ceil() == icon_minimum.ceil(), "corner arrows add no width or height beyond pixel-rounded icon minimum at slot %d: icon %s, group %s, minimum %s" % [i, icon.size, group_size, icon_minimum])
		check((arrows.left == null) == (i == 0) and (arrows.right == null) == (i == strip._weapon_buttons.size() - 1), "only out-of-bounds arrows are omitted at slot %d" % i)
		if arrows.left != null:
			check(icon.encloses(arrows.left.get_global_rect()) and arrows.left.global_position == icon.position + Vector2(0, icon.size.y - 14), "left button sits inside the lower-left corner %d" % i)
		if arrows.right != null:
			check(icon.encloses(arrows.right.get_global_rect()) and arrows.right.get_global_rect().end == icon.end, "right button sits inside the lower-right corner %d" % i)
		check(icon.end.y <= strip._cast_mode_buttons[i].global_position.y, "corner button hit areas clear the cast-mode control %d" % i)
		check(is_equal_approx(strip._cast_mode_buttons[i].get_global_rect().get_center().x, icon.get_center().x), "mode glyph remains centered under its own icon %d" % i)

var _drag_pointer := Vector2.ZERO

func _drag_motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - _drag_pointer
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_drag_pointer = point
	Input.parse_input_event(motion)
	await frames(2)

func _begin_drag(button: Button) -> void:
	_drag_pointer = button.get_global_rect().get_center()
	await mouse(_drag_pointer, MOUSE_BUTTON_LEFT)
	await _drag_motion(_drag_pointer + Vector2(16, 0))
	check(get_viewport().gui_is_dragging(), "real pointer movement starts native weapon drag")

func _drag_between(strip: WeaponStrip, source: int, destination: int, shot: String = "") -> void:
	var weapon: WeaponInstance = loadout.weapon_instances[source]
	if DisplayServer.get_name() == "headless":
		strip._drop_weapon(Vector2.ZERO, {"type": WeaponStrip.WEAPON_DRAG_TYPE, "loadout": loadout, "weapon_id": weapon.weapon_id}, strip._weapon_buttons[destination])
		await frames(4)
		return
	var before := loadout.get_weapon_instances()
	await _begin_drag(strip._weapon_buttons[source])
	await _drag_motion(strip._weapon_buttons[destination].get_global_rect().get_center())
	check(loadout.weapon_instances == before and not strip.weapon_tooltip.visible, "drag preview keeps order unchanged and hides weapon tooltip until release")
	if not shot.is_empty(): await super.capture(shot)
	await mouse(_drag_pointer, MOUSE_BUTTON_LEFT, false)
	await frames(4)
	check(not get_viewport().gui_is_dragging(), "release completes native drag")

func _drag_checks() -> void:
	flow.request_esc_overlay()
	await get_tree().create_timer(0.45).timeout
	var strip := battle.esc_overlay.weapon_strip
	var original := loadout.get_weapon_instances()
	var cannon: WeaponInstance = original[1]
	var level := cannon.level
	var attachments := cannon.get_attached_item_instances().duplicate(true)
	var state := loadout.active_casting.state_for(cannon)
	state.remaining = 3.25
	state.total = 6.0
	var changes := [0]
	var changed := func(): changes[0] += 1
	loadout.loadout_changed.connect(changed)
	check(strip._weapon_buttons[1].mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and strip._weapon_buttons[1].tooltip_text.is_empty(), "hover uses pointing hand without any new drag hint")
	await capture("07_drag_before")
	await _drag_between(strip, 1, 3, "08_drag_in_progress")
	check(loadout.weapon_instances == [original[0], original[2], original[3], cannon] and changes[0] == 1, "drag inserts at destination with one loadout update and stable intervening order")
	await capture("09_drag_after")
	await _drag_between(strip, 3, 0)
	check(loadout.weapon_instances == [cannon, original[0], original[2], original[3]] and changes[0] == 2, "reverse drag inserts at first slot")
	check(cannon.level == level and cannon.get_attached_item_instances() == attachments and is_equal_approx(state.remaining, 3.25) and loadout.get_total_load_cost() == 96, "drag retains weapon identity level enchantments cooldown and load")
	flow.close_esc_overlay()
	await get_tree().create_timer(0.35).timeout
	check(battle.hud.combat_bar.weapons == loadout.weapon_instances, "battle HUD synchronizes drag order")
	controller.select_slot(0)
	check(controller.selected_weapon == cannon, "hotkey slot follows dragged weapon")
	controller.cancel_aim()
	flow.request_esc_overlay()
	await get_tree().create_timer(0.45).timeout
	var before_cancel := loadout.get_weapon_instances()
	if DisplayServer.get_name() != "headless":
		await _begin_drag(strip._weapon_buttons[0])
		await _drag_motion(strip.global_position + Vector2(200, 150))
		await mouse(_drag_pointer, MOUSE_BUTTON_LEFT, false)
		check(not get_viewport().gui_is_dragging(), "outside release cancels native drag")
	var data := {"type": WeaponStrip.WEAPON_DRAG_TYPE, "loadout": loadout, "weapon_id": cannon.weapon_id}
	strip._drop_weapon(Vector2.ZERO, data, strip._weapon_buttons[0])
	check(loadout.weapon_instances == before_cancel and changes[0] == 2, "outside or same-slot drop does not reorder or emit a change")
	check(not strip._can_drop_weapon(Vector2.ZERO, {"type": "augmentation_item"}, strip._weapon_buttons[1]) and not strip._can_drop_weapon(Vector2.ZERO, {"type": WeaponStrip.WEAPON_DRAG_TYPE, "loadout": null, "weapon_id": cannon.weapon_id}, strip._weapon_buttons[1]), "drag rejects unrelated item payloads and another loadout")
	await _press(strip._reorder_buttons[0].right)
	check(loadout.weapon_instances == original, "corner arrow still works after drag and restores original order")
	loadout.loadout_changed.disconnect(changed)
	if DisplayServer.get_name() != "headless":
		player.modifier_stack.set_base_stat("load_capacity", 1000)
		for record: Dictionary in DataRegistry.get_table("weapons"):
			if not loadout.has_weapon(str(record.id)): loadout.equip_weapon(str(record.id))
		await frames(10)
		var scroll := strip.weapon_list.get_parent() as ScrollContainer
		scroll.scroll_horizontal = 0
		await frames(4)
		var first: WeaponInstance = loadout.weapon_instances[0]
		await _begin_drag(strip._weapon_buttons[0])
		await _drag_motion(Vector2(scroll.get_global_rect().end.x - 5, scroll.global_position.y + 20))
		await get_tree().create_timer(1.7).timeout
		check(scroll.scroll_horizontal > 0 and get_viewport().gui_is_dragging(), "dragging at edge scrolls the long weapon row")
		await _drag_motion(strip._weapon_buttons[-1].get_global_rect().get_center())
		await mouse(_drag_pointer, MOUSE_BUTTON_LEFT, false)
		check(loadout.weapon_instances[-1] == first, "edge-scrolled drag can reach the final weapon slot")
		for weapon in loadout.get_weapon_instances():
			if weapon not in original: loadout.remove_weapon(weapon.weapon_id)
		loadout.move_weapon_to_index(first.weapon_id, 0)
		player.modifier_stack.set_base_stat("load_capacity", 100)
	flow.close_esc_overlay()
	await get_tree().create_timer(0.35).timeout

func _revive_capture() -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	manager.clear_enemies()
	player.modifier_stack.set_base_stat("max_hp", 100)
	player.current_hp = 100
	player.remaining_revives = 1
	player.set_physics_process(true)
	player._clear_move_input()
	var enemy := manager.spawn_enemy("enemy_mutated_grub", player.global_position)
	enemy.set_physics_process(false)
	enemy.modifier_stack.set_base_stat("melee_damage", 10000)
	enemy._process_contact_damage()
	enemy.global_position += Vector2(110, 20)
	check(player._revive_blink_active, "actual enemy contact starts the captured revival")
	var samples: Array[Dictionary] = []
	var folder := capture_dir.path_join("revive_frames")
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 108:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := get_tree().root.get_texture().get_image()
		shot.save_png(folder.path_join("%03d.png" % i))
		samples.append({"frame": i, "remaining": player._invincibility_timer, "alpha": player.sprite.self_modulate.a, "hp": player.current_hp, "wing_opening": player._revive_wings.opening, "wing_active": player._revive_wings.active})
	var out := FileAccess.open(capture_dir.path_join("revive_samples.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(samples))
	check(not player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a, 1), "captured revival finishes fully visible")
	check(not player._revive_wings.active, "captured wings fade completely")
