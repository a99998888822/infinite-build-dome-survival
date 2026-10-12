extends "res://scripts/tests/active_combat_integration_test.gd"
## Capture the actual Esc hover path at native and fractional viewport scales.

var _samples: Array[Dictionary] = []

func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	await frames(12)
	await boot()
	player.set_physics_process(false)
	for id in ["weapon_hand_cannon", "weapon_copper_lamp"]:
		check(loadout.equip_weapon(id), "equip " + id)
	var item := player.item_inventory.add_item_from_base("scroll_lightning", "tooltip_review")
	check(loadout.attach_item_to_weapon("weapon_hand_cannon", str(item.item_instance_id)), "attach lightning")
	flow.request_esc_overlay()
	await get_tree().create_timer(0.5).timeout
	var strip := battle.esc_overlay.weapon_strip
	for dimensions in [Vector2i(1152, 648), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = dimensions
		await frames(10)
		await _review_hover(strip, "%dx%d" % [dimensions.x, dimensions.y])
	get_tree().root.size = Vector2i(1600, 900)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(10)
	await _review_hover(strip, "1600x900_scale125")
	await _hover(Vector2(10, 500))
	check(not strip.weapon_tooltip.visible and not strip._attachment_tooltip.visible, "leaving closes both tooltips")
	if not capture_dir.is_empty():
		var report := FileAccess.open(capture_dir.path_join("metrics.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify(_samples, "\t"))
	flow.enter_start_page()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("WEAPON_TOOLTIP_PIXEL_REVIEW checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	get_tree().root.push_input(event, true)
	await frames(5)

func _review_hover(strip: WeaponStrip, suffix: String) -> void:
	for index in strip._weapon_buttons.size():
		var button := strip._weapon_buttons[index] as WeaponSlotButton
		await _hover(button.get_global_rect().get_center())
		if DisplayServer.get_name() == "headless":
			strip._tooltip_mouse_position = button.get_global_rect().get_center()
			strip._show_weapon_tooltip(button.weapon, button)
			await frames()
		check(strip.weapon_tooltip.visible and strip._tooltip_weapon_id == button.weapon.weapon_id, "hover opens " + button.weapon.weapon_id + " " + suffix)
		check(strip.weapon_tooltip_label.text == button.weapon.build_full_stats_text(), "complete stats retained")
		check(strip.weapon_tooltip_label.get_theme_font_size("normal_font_size") == 16, "weapon font remains 16px")
		check(get_viewport().get_visible_rect().encloses(strip.weapon_tooltip.get_global_rect()), "weapon tooltip stays in viewport")
		var name := button.weapon.weapon_id + "_" + suffix
		await capture(name)
		var bounds := strip.weapon_tooltip.get_global_rect()
		var font := strip.weapon_tooltip_label.get_theme_font("normal_font") as FontFile
		_samples.append({"name": name, "rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "font_size": strip.weapon_tooltip_label.get_theme_font_size("normal_font_size"), "fixed_size": font.fixed_size, "oversampling": font.oversampling, "scale": get_tree().root.get_final_transform().get_scale().x})
		if button.weapon.weapon_id == "weapon_hand_cannon":
			check(strip._tooltip_attachment_rows.size() == 1, "attachment hover row retained")
			var row: Rect2 = strip._tooltip_attachment_rows[0].rect
			await _hover(strip.weapon_tooltip_label.global_position + row.get_center())
			check(strip._attachment_tooltip.visible, "real pointer opens attachment details")
			check(strip._attachment_tooltip_label.get_theme_font_size("font_size") == 16, "attachment font remains 16px")
			check(get_viewport().get_visible_rect().encloses(strip._attachment_tooltip.get_global_rect()), "attachment tooltip stays in viewport")
			await capture("attachment_" + suffix)
		await _hover(Vector2(10, 500))
