extends Node
## Exercise the real menu and viewport input; GPU captures run on a private desktop.

var checks := 0
var failures := 0
var capture_dir := ""
var menu: MainMenuUIController
var view: CharacterSelectView


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count := 4) -> void:
	for index in count: await get_tree().process_frame


func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	get_tree().root.push_input(event)
	await frames(2)


func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	await move_pointer(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_tree().root.push_input(event)
	await frames()


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func _run() -> void:
	CampProgression.begin_transient_session()
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var window := get_window()
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	await frames(8)
	menu = game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	view = menu.character_view
	await click(menu.start_battle_button)
	await frames(8)
	await move_pointer(Vector2(10,10))
	check(menu.character_select_page.visible and not menu.start_page.visible, "start button opens production character selection")
	check(view.background.texture.get_size() == Vector2(2752,1536) and view.canvas.size == Vector2(2752,1536), "approved basement composition sizes")
	check(view.character_icon.size == Vector2(463,463) and view.character_icon.position == Vector2(1148,728), "sprite stands on the approved platform anchor")
	check(view.stats_list.get_child_count() == 5 and view.character_list.get_child_count() == 2, "beginner dossier and one row per character")
	for row in view.stats_list.get_children():
		check(row.size.y < 48 and row.size.y >= view._font.get_height(29), "compact stat rows retain room for the full text line")
		for label in row.get_children():
			check(label.get_theme_font_size("font_size") == 29, "compact dossier retains the approved font size")
	var beginner_weapon := view.weapon_list.get_child(0)
	var beginner_enchantments := _enchantment_icons(beginner_weapon)
	check(beginner_enchantments.size() == 1 and str(beginner_enchantments[0].get_meta("enchantment_id")) == "scroll_lightning", "beginner weapon shows its configured lightning enchantment")
	var lightning_icon := beginner_enchantments[0] as TextureRect
	check((lightning_icon.texture as AtlasTexture).atlas.resource_path == str(DataRegistry.get_record("augmentations", "scroll_lightning").icon), "enchantment uses the actual augmentation icon")
	check(lightning_icon.size.x < beginner_weapon.get_node("WeaponIcon").size.x and lightning_icon.size.y < beginner_weapon.get_node("WeaponIcon").size.y, "enchantment icon is smaller than its weapon icon")
	check(view.hover_target.tooltip_text.is_empty(), "hover animation has no tooltip text")
	for button in [view.back_button, view.confirm_button]:
		check(button.size == Vector2(224,92) and button.has_node("NavigationContent"), "approved narrow navigation frames and labels remain intact")
	await click(view.character_list.get_child(0))
	check((view.character_list.get_child(0) as Button).button_pressed, "selected character cannot be toggled off")
	await move_pointer(Vector2(10,10))
	check(not view.walking and view.character_icon.texture.resource_path.ends_with("void_hunter_idle_right.png"), "player starts idle")
	await capture("character_select_installed_1280x720")
	await move_pointer(view.hover_target.get_global_rect().get_center())
	await get_tree().create_timer(0.38).timeout
	check(view.walking and view.walk_frame > 0 and view.character_icon.texture is AtlasTexture, "real pointer hover advances walk sprite frames")
	await capture("character_select_walk")
	await click(view.hover_target)
	await move_pointer(Vector2(10,10))
	check(not view.walking and view.walk_frame == 0, "pointer click then leave resets to idle without sticky keyboard focus")
	view.hover_target.release_focus()
	view.hover_target.grab_focus()
	await frames()
	check(view.walking, "keyboard focus starts walking")
	view.hover_target.release_focus()
	await frames()
	check(not view.walking, "keyboard blur resets to idle")
	for index in 3:
		await click(view.difficulty_list.get_child(index))
		var id := str(index+1)
		check(menu._selected_difficulty_id == id and view.difficulty_title.text == str(BattleDifficulty.get_profile(id).title), "live difficulty click and description " + id)
	await capture("character_select_difficulty_3")
	await click(view.character_list.get_child(1))
	check(menu._selected_character_id == "character_capitalist" and view.stats_list.get_child_count() == 7, "roster hit target selects capitalist with actual stats")
	check(_enchantment_icons(view.weapon_list.get_child(0)).is_empty(), "unenchanted weapon has no stale enchantment icons")
	check(view.passive_list.get_child_count() == 2 and (view.passive_list.get_child(0) as Label).text == "开局获得如下四件遗物", "capitalist traits contain only the requested intro and icon row")
	var relic_icons := view.passive_list.get_node("StartingRelicIcons")
	check(relic_icons.get_child_count() == 4, "all four starting relic icons remain available")
	for card in relic_icons.get_children():
		check(card.get_child_count() == 1 and card.get_child(0) is TextureRect, "relic card shows only its icon")
	await move_pointer(Vector2(10,10))
	await capture("character_select_capitalist")
	check(view.details_scroll.scroll_vertical == 0, "simplified dossier starts at its top")
	await _test_weapon_attachment_mapping()
	await _test_dossier_padding_and_scroll()
	await click(view.character_list.get_child(0))
	check(view.details_scroll.scroll_vertical == 0 and view.stats_list.get_child_count() == 5, "selection resets scroll and removes previous character rows")
	for dimensions in [Vector2i(1024,576), Vector2i(1152,768), Vector2i(1920,1080)]:
		window.size = dimensions
		window.content_scale_size = dimensions
		await frames(10)
		check(is_equal_approx(view.canvas.scale.x, view.canvas.scale.y), "uniform layout scaling " + str(dimensions))
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(view.canvas.get_global_rect()), "composition stays within viewport " + str(dimensions))
		await click(view.difficulty_list.get_child(1))
		check(menu._selected_difficulty_id == "2", "scaled input selects difficulty " + str(dimensions))
		await move_pointer(Vector2(10,10))
		await capture("character_select_%dx%d" % [dimensions.x, dimensions.y])
	await click(view.back_button)
	check(menu.start_page.visible and not menu.character_select_page.visible and not view.walking, "back button returns to main menu and stops animation")
	await click(menu.start_battle_button)
	check(menu._selected_difficulty_id == "1" and menu._selected_character_id == "character_void_hunter", "new selection defaults to beginner and difficulty one")
	await click(view.difficulty_list.get_child(2))
	await click(view.confirm_button)
	var flow := game.get_main_flow_coordinator()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and flow._bound_wave_manager.difficulty_id == "3", "continue starts combat with chosen difficulty")
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	print("CHARACTER_SELECT_VIEW_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_dossier_padding_and_scroll() -> void:
	var body := view.canvas.get_node("DossierBody") as MarginContainer
	var viewport_box := view.details_scroll.get_global_rect()
	check(body.get_theme_constant("margin_top") == 6 and body.get_theme_constant("margin_bottom") == 6, "dossier padding is halved while its safe boundary remains")
	check(view.details_scroll.clip_contents and view.details_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "dossier clips overflowing contents and enables vertical scrolling")
	var icons := view.passive_list.get_node("StartingRelicIcons") as Control
	check(viewport_box.encloses(icons.get_global_rect()), "capitalist relic row fits inside the padded paper viewport")
	# A long future description must scroll without moving the fixed header.
	var record := DataRegistry.get_record("characters", "character_capitalist").duplicate(true)
	record["traits"] = [{"title": "Scroll coverage", "description": "Long dossier content for viewport overflow coverage. ".repeat(35)}]
	view.show_character(record, menu._get_character_starting_stats(record))
	await frames(6)
	var header_position := view._paper_name.global_position
	var bar := view.details_scroll.get_v_scroll_bar()
	check(bar.max_value > bar.page and bar.visible, "long content exposes a vertical scrollbar")
	var point := viewport_box.get_center()
	await move_pointer(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.position = point
	event.global_position = point
	event.pressed = true
	get_tree().root.push_input(event)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	get_tree().root.push_input(release)
	await frames()
	check(view.details_scroll.scroll_vertical > 0, "mouse wheel scrolls the overflowing dossier")
	view.details_scroll.scroll_vertical = 100000
	await frames()
	icons = view.passive_list.get_node("StartingRelicIcons") as Control
	check(viewport_box.encloses(icons.get_global_rect()), "last relic row is fully reachable above the lower padding")
	check(view._paper_name.global_position == header_position, "dossier header stays fixed while the body scrolls")
	await move_pointer(Vector2(10,10))
	await capture("dossier_long_content_scrolled")
	view.details_scroll.scroll_vertical = 0
	await frames()
	check(view.details_scroll.scroll_vertical == 0, "long dossier can return to the top")


func _enchantment_icons(card: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in card.get_node("WeaponContent").get_children():
		if child.has_meta("enchantment_id"): result.append(child)
	return result


func _test_weapon_attachment_mapping() -> void:
	var actual := DataRegistry.get_record("characters", "character_capitalist")
	var record := actual.duplicate(true)
	record["start_weapons"] = ["weapon_void_blade", "weapon_rentier_purse"]
	record["start_weapon_attachments"] = [
		{"weapon_id": "weapon_rentier_purse", "item_id": "scroll_lightning"},
		{"weapon_id": "weapon_void_blade", "item_id": "scroll_lightning"},
		{"weapon_id": "weapon_void_blade", "item_id": "scroll_lightning"},
	]
	view.show_character(record, menu._get_character_starting_stats(actual))
	await frames()
	check(_enchantment_icons(view.weapon_list.get_child(0)).size() == 2 and _enchantment_icons(view.weapon_list.get_child(1)).size() == 1, "multiple enchantments are grouped by weapon id, independent of attachment order")
	for card in view.weapon_list.get_children():
		for icon in _enchantment_icons(card):
			check(card.get_global_rect().encloses((icon as Control).get_global_rect()), "enchantment stays inside its weapon row")
	view.show_character(actual, menu._get_character_starting_stats(actual))
	await frames()
	check(_enchantment_icons(view.weapon_list.get_child(0)).is_empty(), "refresh removes previous weapons and attachments")
