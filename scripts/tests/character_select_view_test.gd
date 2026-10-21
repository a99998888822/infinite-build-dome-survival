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
	get_tree().root.push_input(event, true)
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
		get_tree().root.push_input(event, true)
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
	window.content_scale_size = Vector2i(1920, 1080)
	await frames(8)
	menu = game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	view = menu.character_view
	await click(menu.start_battle_button)
	await frames(8)
	await move_pointer(Vector2(10,10))
	check(menu.character_select_page.visible and not menu.start_page.visible, "start button opens production character selection")
	for row in view.stats_list.get_children():
		check(row.tooltip_text.is_empty(), "starting attribute row has no hover tooltip")
		for label in row.get_children():
			check(label.tooltip_text.is_empty(), "starting attribute label has no hover tooltip")
	check(view.background.texture.get_size() == Vector2(2752,1536) and view.canvas.size == Vector2(1920,1080) and view.canvas.scale == Vector2.ONE, "approved art uses the native 1920 canvas")
	var used := view._idle.get_image().get_used_rect()
	var foot := view.character_icon.position + Vector2(view.character_icon.size.x * 0.5, used.end.y * view.character_icon.size.y / view._idle.get_height())
	check(foot.distance_to(view.FOOT_ANCHOR) <= 1.0, "new sprite soles retain the approved platform anchor")
	check(view.character_icon.size == Vector2(288, 288) and view.character_icon.position == view.character_icon.position.round(), "novice preview retains the full 96px canvas at exactly 3x with integer placement")
	view.set_process(false)
	view.reset_animation()
	var hover_bounds := view.hover_target.get_rect()
	var name_position := view.name_label.position
	view._process(0.75)
	check(view.character_icon.position == view._character_rest_position and is_zero_approx(float(view._breath_material.get_shader_parameter("breath_amount"))), "novice idle keeps a fixed 3x pixel grid")
	await capture("character_select_breath_in")
	var inhale: Image = null
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		inhale = get_tree().root.get_texture().get_image()
	view._process(1.5)
	check(view.character_icon.position == view._character_rest_position and is_zero_approx(float(view._breath_material.get_shader_parameter("breath_amount"))), "novice idle never compresses the source pixels")
	check(view.hover_target.get_rect() == hover_bounds and view.name_label.position == name_position, "breathing leaves name and hover bounds still")
	await capture("character_select_breath_out")
	if inhale != null:
		await RenderingServer.frame_post_draw
		var exhale := get_tree().root.get_texture().get_image()
		var rect := view.character_icon.get_global_rect()
		var image_scale := Vector2(inhale.get_size()) / view.get_viewport_rect().size
		rect = Rect2(rect.position * image_scale, rect.size * image_scale)
		var waist_y := ceili(rect.position.y + rect.size.y * 36.0 / 64.0)
		var foot_y := floori(rect.position.y + rect.size.y * float(view._breath_material.get_shader_parameter("foot_y")))
		var sole := Rect2i(int(rect.position.x), foot_y - 1, int(rect.size.x), 1)
		var upper := Rect2i(int(rect.position.x), int(rect.position.y), int(rect.size.x), waist_y - int(rect.position.y))
		check(inhale.get_region(sole).get_data() == exhale.get_region(sole).get_data(), "GPU: soles remain planted through breathing")
		check(inhale.get_region(upper).get_data() == exhale.get_region(upper).get_data(), "GPU: upper body retains identical pixels through idle")
	view._process(0.75)
	check(is_zero_approx(float(view._breath_material.get_shader_parameter("breath_amount"))), "three seconds completes one breathing cycle")
	view.reset_animation()
	check(view.character_icon.position == view._character_rest_position and is_zero_approx(float(view._breath_material.get_shader_parameter("breath_amount"))), "animation reset clears breathing deformation")
	view.set_process(true)
	check(view.stats_list.get_child_count() == 5 and view.character_list.get_child_count() == 14, "beginner dossier, two named characters and twelve release slots")
	await _test_release_roster()
	for row in view.stats_list.get_children():
		check(row.size.y < 33.488372 and row.size.y >= view._font.get_height(20), "compact stat rows retain room for the full text line")
		for label in row.get_children():
			check(label.get_theme_font_size("font_size") == 20, "compact dossier uses native font metrics")
	var beginner_weapon := view.weapon_list.get_child(0)
	var beginner_enchantments := _enchantment_icons(beginner_weapon)
	check(beginner_enchantments.size() == 1 and str(beginner_enchantments[0].get_meta("enchantment_id")) == "scroll_lightning", "beginner weapon shows its configured lightning enchantment")
	var lightning_icon := beginner_enchantments[0] as TextureRect
	check(ItemIconArt.source_path(lightning_icon.texture) == str(DataRegistry.get_record("augmentations", "scroll_lightning").icon), "enchantment uses the actual augmentation icon")
	check(lightning_icon.texture.logical_size == Vector2(32, 32) and lightning_icon.texture.texture.get_size() == Vector2(32, 32), "starting enchantment displays the complete 32px source at 1x")
	check(lightning_icon.size.x < beginner_weapon.get_node("WeaponIcon").size.x and lightning_icon.size.y < beginner_weapon.get_node("WeaponIcon").size.y, "enchantment icon is smaller than its weapon icon")
	check(view.hover_target.tooltip_text.is_empty(), "hover animation has no tooltip text")
	for button in [view.back_button, view.confirm_button]:
		check(button.size.is_equal_approx(Vector2(156.27907,64.186047)) and button.has_node("NavigationContent"), "approved narrow navigation frames and labels remain intact")
	await click(view.character_list.get_child(0))
	check((view.character_list.get_child(0) as Button).button_pressed, "selected character cannot be toggled off")
	await move_pointer(Vector2(10,10))
	check(not view.walking and view.character_icon.texture.resource_path.ends_with("novice_96/idle.png"), "selection uses approved beginner idle")
	check(view._walk_frames == 8 and view._walk_frame_size == Vector2(96,96) and view._walk_fps == 8, "selection uses all eight full 96px movement frames")
	check(view._walk.atlas.resource_path.ends_with("novice_96/move.png"), "selection and battle share the same movement sheet")
	await capture("character_select_installed_1280x720")
	await move_pointer(view.hover_target.get_global_rect().get_center())
	await get_tree().create_timer(0.38).timeout
	check(view.walking and view.walk_frame > 0 and view.character_icon.texture is AtlasTexture, "real pointer hover advances walk sprite frames")
	check(view._walk.region == Rect2(Vector2(view.walk_frame * 96,0),Vector2(96,96)), "hover crops the entire current frame without adjacent-frame bleed")
	check(view.character_icon.position == view._character_rest_position, "walking does not retain idle breathing deformation")
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
	check(view.confirm_button.disabled and view.error_label.visible and view.error_label.text == "ui.character.release_locked", "capitalist preview explains its unavailable start button")
	check(bool(view._breath_material.get_shader_parameter("release_locked")), "capitalist full-body preview is gray during idle and walk")
	await click(view.confirm_button)
	var previous_state := menu._main_flow_coordinator.current_state
	menu._on_character_confirm_pressed()
	check(menu.character_select_page.visible and menu._main_flow_coordinator.current_state == previous_state, "click and direct confirm cannot start the capitalist")
	check(view._walk_frames == 7 and view._walk_frame_size == Vector2(80,80), "switching characters restores the capitalist sheet dimensions")
	check(_enchantment_icons(view.weapon_list.get_child(0)).is_empty(), "unenchanted weapon has no stale enchantment icons")
	var intro := view.passive_list.get_child(1) as Label
	check(view.passive_list.get_child_count() == 3 and intro.tr(intro.text) == L10n.text("ui.character.four_starting_relics"), "capitalist traits contain withdrawal restriction, relic intro and icon row")
	check((view.passive_list.get_child(0) as Label).tr(view.passive_list.get_child(0).text) == L10n.text("ui.character.no_withdrawal"), "selection explains withdrawal restriction without displaying level health growth")
	var relic_icons := view.passive_list.get_node("StartingRelicIcons")
	check(relic_icons.get_child_count() == 4, "all four starting relic icons remain available")
	for card in relic_icons.get_children():
		check(card.get_child_count() == 1 and card.get_child(0) is TextureRect, "relic card shows only its icon")
		var relic_icon := card.get_child(0) as TextureRect
		check(relic_icon.size == Vector2(36, 36) and relic_icon.texture.get_size() == Vector2(36, 36) and not relic_icon.texture is AtlasTexture, "starting relic uses the uncropped 36px source at 1x")
	await _test_relic_tooltips()
	await move_pointer(Vector2(10,10))
	await capture("character_select_capitalist")
	check(view.details_scroll.scroll_vertical == 0, "simplified dossier starts at its top")
	await _test_weapon_attachment_mapping()
	await _test_dossier_padding_and_scroll()
	await click(view.character_list.get_child(0))
	check(view.details_scroll.scroll_vertical == 0 and view.stats_list.get_child_count() == 5, "selection resets scroll and removes previous character rows")
	check(not view.confirm_button.disabled and not view.error_label.visible and not bool(view._breath_material.get_shader_parameter("release_locked")), "returning to novice restores color and enables starting")
	for dimensions in [Vector2i(1024,576), Vector2i(1152,768), Vector2i(1920,1080)]:
		window.size = dimensions
		window.content_scale_size = Vector2i(1920, 1080)
		await frames(10)
		check(view.canvas.scale == Vector2.ONE, "native composition at window size " + str(dimensions))
		check(view.get_global_rect().encloses(view.background.get_global_rect()), "art stays within logical viewport " + str(dimensions))
		await click(view.character_list.get_child(1))
		await _test_relic_tooltips()
		await click(view.character_list.get_child(0))
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
	if menu.dungeon_loading.active:
		await menu.dungeon_loading.finished
	var flow := game.get_main_flow_coordinator()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and flow._bound_wave_manager.difficulty_id == "3", "continue starts combat with chosen difficulty")
	var loadout := flow.get_bound_loadout()
	check(loadout.get_weapon_instances().size() == 2 and loadout.get_weapon_instance("weapon_dash_blade") != null, "confirming beginner equips the additional dash blade in live combat")
	check(loadout.get_weapon_instance("weapon_void_blade").get_attached_item_instances().size() == 1 and loadout.get_weapon_instance("weapon_dash_blade").get_attached_item_instances().is_empty(), "bow retains lightning and dash blade starts without an enchantment")
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await frames(4)
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	print("CHARACTER_SELECT_VIEW_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_release_roster() -> void:
	var novice := view.character_list.get_child(0) as Button
	var capitalist := view.character_list.get_child(1) as Button
	check(not capitalist.disabled and capitalist.focus_mode != Control.FOCUS_NONE, "capitalist remains clickable and keyboard focusable")
	var capitalist_portrait := (capitalist.get_node("Portrait") as TextureRect).texture.get_image()
	var gray := true
	for y in capitalist_portrait.get_height():
		for x in capitalist_portrait.get_width():
			var pixel := capitalist_portrait.get_pixel(x, y)
			if pixel.a > 0 and (not is_equal_approx(pixel.r, pixel.g) or not is_equal_approx(pixel.g, pixel.b)): gray = false
	check(gray, "capitalist portrait pixels are desaturated")
	var portraits := {}
	for index in range(2, view.character_list.get_child_count()):
		var card := view.character_list.get_child(index) as Button
		check(card.disabled and card.focus_mode == Control.FOCUS_NONE and card.get_node("CharacterName").text == "ui.character.release_locked", "release slot is disabled with release-only title " + str(index))
		check(card.size.is_equal_approx(novice.size) and card.get_theme_stylebox("disabled").texture == load(view.ART + "roster_normal.png"), "release slot shares the novice frame and size " + str(index))
		var texture := (card.get_node("Portrait") as TextureRect).texture
		portraits[texture.get_image().get_data().hex_encode()] = true
	check(portraits.size() == 12, "all twelve silhouette portraits differ")
	await click(view.character_list.get_child(2))
	check(menu._selected_character_id == "character_void_hunter", "clicking a release slot leaves the current selection intact")
	var scroll := view.roster_scroll
	var bar := scroll.get_v_scroll_bar()
	check(bar.visible and bar.max_value > bar.page, "release slots overflow and expose the roster scrollbar")
	var point := scroll.get_global_rect().get_center()
	await _drag_roster(point, Vector2(0, -220))
	check(scroll.scroll_vertical > 150 and menu._selected_character_id == "character_void_hunter", "mouse drag scrolls over disabled cards without selecting them")
	await _drag_roster(point - Vector2(0, 180), Vector2(0, 200))
	check(scroll.scroll_vertical < 40, "mouse drag scrolls back upward")
	scroll.scroll_vertical = 100000
	await frames()
	var last := view.character_list.get_child(view.character_list.get_child_count() - 1) as Button
	check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "last release card is fully reachable")
	await click(last)
	check(menu._selected_character_id == "character_void_hunter", "last release slot cannot select a character")
	await move_pointer(Vector2(10, 10))
	await capture("character_roster_bottom")
	scroll.scroll_vertical = 0
	await frames()
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	get_tree().root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_tree().root.push_input(event, true)
	await frames()
	check(scroll.scroll_vertical > 0, "mouse wheel also scrolls over disabled cards")
	scroll.scroll_vertical = 0
	await frames()
	# Dragging a clickable card must not select it when the pointer is released.
	await _drag_roster(capitalist.get_global_rect().get_center(), Vector2(0, -65))
	check(menu._selected_character_id == "character_void_hunter", "dragging the capitalist card does not activate it")
	scroll.scroll_vertical = 0
	var flow := menu._main_flow_coordinator
	flow.enter_battle_selection("character_capitalist")
	check(not flow.confirm_character_selection() and flow.current_state == MainFlowCoordinator.STATE_CHARACTER_SELECT, "run coordinator independently rejects the locked capitalist")
	flow.enter_start_page()
	await frames()
	await click(menu.start_battle_button)
	await frames(8)


func _drag_roster(point: Vector2, delta: Vector2) -> void:
	await move_pointer(point)
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	get_tree().root.push_input(press, true)
	for step in range(1, 6):
		var motion := InputEventMouseMotion.new()
		motion.position = point + delta * float(step) / 5.0
		motion.relative = delta / 5.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(motion, true)
		await frames(1)
	var release := press.duplicate() as InputEventMouseButton
	release.position = point + delta
	release.pressed = false
	get_tree().root.push_input(release, true)
	await frames()


func _test_relic_tooltips() -> void:
	var cards := view.passive_list.get_node("StartingRelicIcons").get_children()
	var relics: Array = DataRegistry.get_record("characters", "character_capitalist").start_relics
	for index in cards.size():
		var card := cards[index] as Control
		await move_pointer(Vector2(10, 10))
		var event := InputEventMouseMotion.new()
		event.position = card.get_global_rect().get_center()
		event.global_position = event.position
		get_tree().root.push_input(event, true)
		check(view._item_tooltip.visible, "relic tooltip opens in the hover event without a timer")
		await frames(2)
		var record := DataRegistry.get_record("relics", str(relics[index]))
		check(view._item_tooltip_label.text.contains(record.description), "relic tooltip retains the full description")
		check(view._item_tooltip.size.x <= 340 and view._item_tooltip_label.get_line_count() > 3, "relic tooltip wraps long Chinese text within its fixed width")
		check(view.get_viewport_rect().encloses(view._item_tooltip.get_global_rect()), "relic tooltip stays inside the viewport")
		if index == 0: await capture("relic_tooltip_%d" % int(view.get_viewport_rect().size.x))
	await move_pointer(Vector2(10, 10))
	check(not view._item_tooltip.visible, "leaving relic icons immediately hides the tooltip")
	await move_pointer((cards[0] as Control).get_global_rect().get_center())
	menu.character_select_page.hide()
	check(not view._item_tooltip.is_visible_in_tree(), "hidden character page cannot leave its tooltip on screen")
	menu.character_select_page.show()
	check(not view._item_tooltip.visible, "reopening character page does not restore a stale tooltip")
	await move_pointer(Vector2(10, 10))


func _test_dossier_padding_and_scroll() -> void:
	var body := view.canvas.get_node("DossierBody") as MarginContainer
	var viewport_box := view.details_scroll.get_global_rect()
	check(body.get_theme_constant("margin_top") == 4 and body.get_theme_constant("margin_bottom") == 4, "dossier retains its native safe padding")
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
	get_tree().root.push_input(event, true)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	get_tree().root.push_input(release, true)
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
