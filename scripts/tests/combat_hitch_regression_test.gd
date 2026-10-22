extends Node

const REACTION = preload("res://scripts/effects/element_reaction_text.gd")
var checks := 0
var failures := 0
var captures := ""
var legacy_path := ""
var selections: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): captures = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--legacy-reaction="): legacy_path = arg.trim_prefix("--legacy-reaction=")
	_run.call_deferred()


func frames(count := 3) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("COMBAT_HITCH_REGRESSION " + message)


func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(captures.path_join(name + ".png"))


func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().size = Vector2i(1152, 648)
	get_window().content_scale_size = Vector2i(1152, 648)
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	await _cards()
	await _weapon_row()
	await _reactions()
	await _damage()
	if not legacy_path.is_empty(): await _compare_reaction_pixels()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("COMBAT_HITCH_REGRESSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _cards() -> void:
	var popup := preload("res://scenes/ui/shop/shop_popup.tscn").instantiate() as ShopPopup
	add_child(popup)
	popup.offer_selected.connect(func(offer): selections.append(offer))
	var generator := ShopOfferGenerator.new()
	var pool := generator.build_shop_candidate_pool({"load_capacity": 100, "current_load": 0})
	var relics := pool.filter(func(c): return c.offer_type == "relic")
	var weapons := pool.filter(func(c): return c.offer_type == "new_weapon")
	await frames()
	await _card_layout(relics[0], weapons[0])
	check(popup._card_pool.size() == 4 and popup._offer_cards.is_empty(), "cards prepared without active offers")
	popup.configure({"mode": "free", "offers": relics.slice(0, 3)})
	popup.show_popup()
	var reused := popup._offer_cards[0]
	await get_tree().create_timer(0.5).timeout
	await capture("reward_free")
	reused._set_card_hovered(true)
	reused.play_claim_animation(true)
	popup.hide_popup()
	check(reused.offer_data.is_empty() and reused._bond_player == null and reused._icon_float_tween == null, "closing releases data and animation")
	popup.configure({"mode": "shop", "offers": [weapons[0], relics[5]], "gold": 999, "refresh_cost": 10})
	popup.show_popup()
	await get_tree().create_timer(0.5).timeout
	check(popup._offer_cards.size() == 2 and popup._offer_cards[0] == reused, "same card reused across reward and shop")
	check(not reused.select_button.disabled and reused.mouse_filter == Control.MOUSE_FILTER_STOP, "claimed slot regains interaction")
	check(reused.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(reused.modulate.a, 1.0) and reused.z_index == 0, "claim and hover cannot animate the next offer")
	check(reused.offer_data == weapons[0] and reused.select_button.icon != null, "new offer and shop button replace previous contents")
	check(ItemIconArt.source_path(reused.icon_texture.texture) == str(weapons[0].icon), "relic card restores weapon icon")
	check(reused.selected.get_connections().size() == 1, "reuse does not multiply selection callbacks")
	reused.select_button.pressed.emit()
	check(selections.size() == 1 and selections[0] == weapons[0], "selection submits the new offer exactly once")
	popup.reset_submission()
	await capture("reward_reused_shop")
	for count in [8, 1, 3, 8, 2]:
		popup.configure({"mode": "free", "offers": relics.slice(0, count)})
		popup.show_popup()
		check(popup._offer_cards.size() == count and popup._card_pool.size() == 8, "bounded pool handles page size %d" % count)
		popup.hide_popup()
	popup.reset_run()
	await frames()
	check(popup.offer_grid.get_child_count() == 4 and popup._card_pool.size() == 4, "run reset retains only the prepared first page")
	check(popup._card_pool[0] == reused, "run reset preserves the prepared card instance")
	for card in popup._card_pool:
		check(card.offer_data.is_empty() and card._bond_player == null and not card.visible and card._icon_float_tween == null, "retained card releases run data and animation")
	var locale := L10n.locale
	L10n.set_locale("en" if locale == "zh_CN" else "zh_CN", false)
	await frames()
	check(popup._offer_cards.is_empty() and popup.payload.is_empty(), "locale change cannot revive old offers")
	L10n.set_locale(locale, false)
	popup.configure({"mode": "free", "offers": relics.slice(1, 4)})
	popup.show_popup()
	await frames()
	check(popup._offer_cards[0] == reused and reused.offer_data == relics[1], "next run uses prepared card with new offer")
	check(not reused.select_button.disabled and reused.selected.get_connections().size() == 1, "next run restores interaction without duplicate callbacks")
	popup.reset_run()
	popup.queue_free()
	await frames()
	check(FinanceUIStyle._pending_item_icons.is_empty(), "background icon requests finish")
	await _prepared_popup_layout(relics)


func _prepared_popup_layout(relics: Array) -> void:
	var previous_size := get_window().size
	var previous_canvas := get_window().content_scale_size
	var popup := preload("res://scenes/ui/shop/shop_popup.tscn").instantiate() as ShopPopup
	add_child(popup)
	# Exercise first open, hidden resize in both directions, and reset/re-entry.
	for canvas in [Vector2i(1920, 1080), Vector2i(1152, 648), Vector2i(1920, 1080)]:
		popup.reset_run()
		get_window().size = canvas
		get_window().content_scale_size = canvas
		await frames(8)
		var card := popup._card_pool[0]
		var prepared_font := card.name_label.get_theme_font_size("font_size")
		var prepared_spacing := card.content.get_theme_constant("separation")
		check(prepared_font == (18 if canvas.x == 1920 else 10), "hidden preparation uses current canvas typography: " + str(canvas))
		check(not popup.visible and popup._offer_cards.is_empty() and card.offer_data.is_empty() and not card.visible, "layout preparation leaves rewards inactive")
		popup.configure({"mode": "free", "offers": relics.slice(0, 3)})
		popup.show_popup()
		await frames(8)
		check(card.name_label.get_theme_font_size("font_size") == prepared_font and card.content.get_theme_constant("separation") == prepared_spacing, "first visible layout retains prepared typography: " + str(canvas))
		# At small sizes, native artwork can impose a larger content minimum.
		if canvas.x == 1920:
			check(absf(card.size.y - floorf((popup.offer_scroll.size.y - 20) / 2)) <= 1, "native canvas cards follow the settled scroll area")
		check(card.offer_data == relics[0] and not card.select_button.disabled, "prepared layout displays current selectable reward")
	# A visible error consumes space; hiding/reopening clears it and refits.
	popup.show_error("insufficient_gold")
	await frames(8)
	var error_height := popup.offer_scroll.size.y
	check(popup.error_label.visible, "purchase error remains visible")
	popup.hide_popup()
	popup.set_safe_rect(Rect2(16, 16, 1408, 1048))
	await frames(8)
	popup.configure({"mode": "shop", "offers": relics.slice(0, 8), "gold": 999})
	popup.show_popup()
	await frames(8)
	check(not popup.error_label.visible and popup.offer_scroll.size.y > error_height, "reopening restores the area previously occupied by an error")
	check(popup._offer_cards.size() == 8 and not popup.offer_scroll.get_v_scroll_bar().visible, "expanded pool still fits two complete rows")
	popup.reset_run()
	popup.queue_free()
	get_window().size = previous_size
	get_window().content_scale_size = previous_canvas
	await frames(8)


func _card_layout(relic: Dictionary, weapon: Dictionary) -> void:
	var card := preload("res://scenes/ui/rewards/reward_option.tscn").instantiate() as RewardOption
	card.hide()
	card.set_available_size(170, 260)
	card.set_layout_width(170)
	card.configure(relic)
	add_child(card)
	await frames()
	check(card.name_label.get_theme_font_size("font_size") == 10 and card.content.get_theme_constant("separation") == 5, "size set before ready applies small card typography")
	card.set_available_size(170, 260)
	var style := card.get_theme_stylebox("panel")
	for repeat in 3:
		card.set_available_size(170, 260)
		card.set_layout_width(170)
	check(card.get_theme_stylebox("panel") == style, "unchanged cell size preserves style resources")
	card.set_available_size(170, 250)
	check(card.custom_minimum_size == Vector2(170, 250) and card.get_theme_stylebox("panel") == style, "height-only resize updates geometry without restyling")
	card.set_layout_width(168)
	check(card.custom_minimum_size.x == 168 and card.select_button.custom_minimum_size.x == floorf((168 - 12) * 0.8), "width-only resize updates button and card minimums")
	card.set_available_size(200, 300)
	check(card.name_label.get_theme_font_size("font_size") == 18 and card.content.get_theme_constant("separation") == 8, "crossing compact threshold restores compact typography")
	card.set_available_height(400)
	card.set_layout_width(240)
	check(card.content.get_theme_constant("separation") == 10 and card.custom_minimum_size == Vector2(240, 400), "height-only API restores normal density")
	card.set_compact(true)
	check(card.content.get_theme_constant("separation") == 8, "explicit compact API still changes density")
	card.set_compact(false)
	card.configure(weapon, RewardOption.ENTRY_SHOP)
	check(card.offer_data == weapon and card.select_button.icon != null and ItemIconArt.source_path(card.icon_texture.texture) == str(weapon.icon), "new content refreshes at unchanged density")
	await _card_style_transitions(card, relic, weapon)
	var locale := L10n.locale
	L10n.set_locale("en" if locale == "zh_CN" else "zh_CN", false)
	check(card.name_label.text == L10n.record_text(weapon, "display_name", str(weapon.target_id)) and card.name_label.get_theme_font_size("font_size") == 18, "locale refresh updates current offer without losing density")
	L10n.set_locale(locale, false)
	card.queue_free()
	await frames()


func _card_style_transitions(card: RewardOption, relic: Dictionary, weapon: Dictionary) -> void:
	var panel := card.get_theme_stylebox("panel")
	var button := card.select_button.get_theme_stylebox("normal")
	card.configure(relic, RewardOption.ENTRY_FREE)
	check(card.get_theme_stylebox("panel") == panel and card.select_button.get_theme_stylebox("normal") == button, "new offer at same density retains skins")
	check(card.name_label.text == L10n.record_text(relic, "display_name", str(relic.target_id)) and card.description_label.text == L10n.source(str(relic.description)), "retained skins do not retain old title or description")
	check(card.select_button.icon == null and not card.select_button.has_theme_constant_override("icon_max_width"), "shop to free removes coin and width override")
	card.configure(weapon, RewardOption.ENTRY_SHOP, 123)
	check(card.select_button.text == "123" and card.select_button.get_theme_constant("icon_max_width") == 11, "explicit price and coin layout update without restyling")
	card.show()
	await frames()
	card._set_card_hovered(true)
	var warm_panel := card.get_theme_stylebox("panel") as NativeHudTextureStyle
	var warm_button := card.select_button.get_theme_stylebox("normal") as NativeHudTextureStyle
	check(warm_panel.texture == RewardOption.PALETTE.WARM_FRAME and warm_button.texture == RewardOption.PALETTE.WARM.BUTTON_SELECTED, "hover updates both panel and button art")
	check(card.name_label.get_theme_color("font_color") == RewardOption.PALETTE.WARM_TEXT and card.description_label.get_theme_color("default_color") == RewardOption.PALETTE.WARM_TEXT, "hover updates text colors")
	card.select_button.grab_focus()
	card._set_card_hovered(false)
	check(card.get_theme_stylebox("panel") == warm_panel and card.select_button.get_theme_stylebox("normal") == warm_button, "keyboard focus retains highlight after pointer exits")
	card.select_button.release_focus()
	check((card.get_theme_stylebox("panel") as NativeHudTextureStyle).texture == RewardOption.PALETTE.FRAME, "focus exit restores neutral art")
	card._set_card_hovered(true)
	card.release_offer()
	card.configure(relic)
	check(not card.select_button.disabled and (card.get_theme_stylebox("panel") as NativeHudTextureStyle).texture == RewardOption.PALETTE.FRAME, "reusing a hovered card restores neutral unlocked state")
	card.set_interaction_locked(true)
	card._set_card_hovered(true)
	check(not card._hovered and card.select_button.disabled and (card.select_button.get_theme_stylebox("disabled") as NativeHudTextureStyle).modulate_color == Color(0.65, 0.65, 0.65), "locked offer keeps disabled art and rejects hover")
	card.set_interaction_locked(false)
	card.set_available_size(170, 250)
	var small_panel := card.get_theme_stylebox("panel")
	var native_height := card.icon_frame.custom_minimum_size.y
	check(small_panel.get_content_margin(SIDE_TOP) == 6 and card.name_label.get_theme_font_size("font_size") == 10, "density change updates padding and fonts together")
	var empty_icon := relic.duplicate(true)
	empty_icon.icon = ""
	card.configure(empty_icon)
	check(card.icon_frame.custom_minimum_size.y == 50 and card.icon_placeholder.visible and not card.icon_texture.visible, "missing icon restores small placeholder height")
	card.configure(relic)
	check(card.icon_frame.custom_minimum_size.y == native_height and card.icon_texture.visible and not card.icon_placeholder.visible, "same-density artwork change restores native icon height")
	check(card.get_theme_stylebox("panel") == small_panel, "artwork height changes preserve panel skin")
	card.set_available_height(400)
	card.configure(weapon, RewardOption.ENTRY_SHOP)
	check(card.get_theme_stylebox("panel").get_content_margin(SIDE_TOP) == 14 and card.name_label.get_theme_font_size("font_size") == 18, "restoring normal density restores padding and fonts")
	var probe := Button.new()
	add_child(probe)
	await frames()
	var changed := [0]
	probe.theme_changed.connect(func(): changed[0] += 1)
	RewardOption.HUD_STYLE.apply_button(probe)
	await frames()
	check(changed[0] == 1, "button skin batch emits one theme change")
	check(probe.has_theme_stylebox_override("focus") and probe.has_theme_stylebox_override("hover_pressed") and probe.get_theme_color("font_disabled_color") == RewardOption.PALETTE.MUTED, "batched skin preserves keyboard, pressed and disabled states")
	probe.queue_free()


func _weapon_row() -> void:
	var loadout := WeaponLoadout.new()
	add_child(loadout)
	for id in ["weapon_void_blade", "weapon_copper_lamp"]:
		var weapon := WeaponInstance.new()
		weapon.initialize(id, null)
		loadout.weapon_instances.append(weapon)
	var popup := preload("res://scenes/ui/shop/shop_popup.tscn").instantiate() as ShopPopup
	add_child(popup)
	popup.set_loadout(loadout)
	await frames()
	var strip := popup.weapon_strip
	var buttons := strip._weapon_buttons.duplicate()
	var modes := strip._cast_mode_buttons.duplicate()
	for repeat in 3:
		popup.set_loadout(loadout)
		popup.refresh_gold(200 + repeat)
		popup.show_popup()
		popup.hide_popup()
	check(strip._weapon_buttons == buttons and strip._cast_mode_buttons == modes, "reward reopen and gold refresh preserve weapon and cast controls")
	var connections := loadout.loadout_changed.get_connections().filter(func(c): return c.callable.get_object() == strip)
	check(connections.size() == 1, "repeated binding keeps exactly one loadout callback")
	loadout.upgrade_weapon("weapon_void_blade")
	check(strip._weapon_buttons == buttons and (buttons[0] as WeaponSlotButton).weapon.level == 2, "weapon upgrade updates the live instance without rebuilding controls")
	var item: Dictionary = DataRegistry.get_table("augmentations")[0].duplicate(true)
	item.item_instance_id = "row_regression_attachment"
	var weapon := loadout.weapon_instances[0]
	check(weapon.attach_item_instance(item), "row fixture attaches a real augmentation")
	loadout.weapon_attachment_changed.emit(weapon.weapon_id, str(item.item_instance_id))
	check(strip._weapon_buttons == buttons and (buttons[0] as WeaponSlotButton).weapon.get_attached_item_instances().size() == 1, "attachment signal retains controls and live attachment contents")
	popup.show_popup()
	await frames()
	strip._show_weapon_tooltip(weapon, buttons[0])
	check(strip.weapon_tooltip_label.text == weapon.build_full_stats_text() and strip._tooltip_attachment_rows.size() == 1, "reused button opens current stats and attachment details")
	weapon.detach_item_instance(str(item.item_instance_id))
	loadout.weapon_attachment_changed.emit(weapon.weapon_id, "")
	await frames(1)
	check(strip._weapon_buttons == buttons and strip._tooltip_attachment_rows.is_empty() and strip.weapon_tooltip_label.text == weapon.build_full_stats_text(), "detachment refreshes the open tooltip without stale attachment rows")
	strip._hide_weapon_tooltip()
	var automatic := CombatSettings.prefers_auto_cast(weapon.weapon_id, weapon.is_mobility_weapon())
	CombatSettings.set_weapon_auto_cast(weapon.weapon_id, not automatic, false)
	check(strip._cast_mode_buttons == modes and modes[0].automatic == not automatic, "retained cast control follows setting changes")
	CombatSettings.set_weapon_auto_cast(weapon.weapon_id, automatic, false)
	if DisplayServer.get_name() == "headless":
		modes[0].pressed.emit()
	else:
		var point: Vector2 = modes[0].get_global_transform_with_canvas() * (modes[0].size * 0.5)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		get_viewport().push_input(motion, true)
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			get_viewport().push_input(click, true)
			await frames(2)
	check(CombatSettings.prefers_auto_cast(weapon.weapon_id, weapon.is_mobility_weapon()) == not automatic, "reused cast control toggles the preference exactly once")
	CombatSettings.set_weapon_auto_cast(weapon.weapon_id, automatic, false)
	var locale := L10n.locale
	L10n.set_locale("en" if locale == "zh_CN" else "zh_CN", false)
	check(strip._weapon_buttons == buttons and modes[0].tooltip_text.contains(L10n.source(str(weapon.weapon_data.display_name))), "language change refreshes retained cast tooltip")
	L10n.set_locale(locale, false)
	strip._move_weapon(weapon.weapon_id, 1)
	check((strip._weapon_buttons[1] as WeaponSlotButton).weapon == weapon and strip._weapon_buttons != buttons, "reorder rebuilds the row in the new live order")
	strip.slot_size += 8
	strip._refresh_weapon_strip()
	check(strip._weapon_buttons[0].custom_minimum_size == Vector2.ONE * strip.slot_size, "layout size changes invalidate retained geometry")
	strip.set_loadout(loadout, true, false, false)
	check(strip._cast_mode_buttons.is_empty() and (strip._weapon_buttons[0] as WeaponSlotButton).attachment_editing_enabled, "editing mode switch updates controls and drag permissions")
	var fresh := WeaponInstance.new()
	fresh.initialize(weapon.weapon_id, null)
	loadout.weapon_instances[1] = fresh
	strip.set_loadout(loadout, true, false, false)
	check((strip._weapon_buttons[1] as WeaponSlotButton).weapon == fresh, "same weapon id with a new instance cannot reuse the old run binding")
	loadout.weapon_instances.remove_at(1)
	strip.set_loadout(loadout, true, false, false)
	check(strip._weapon_buttons.size() == 1, "explicit binding notices list changes even without a loadout signal")
	var replacement := WeaponLoadout.new()
	add_child(replacement)
	popup.set_loadout(replacement)
	loadout.loadout_changed.emit()
	check(strip._loadout == replacement and strip._weapon_buttons.is_empty() and not loadout.loadout_changed.is_connected(strip._on_loadout_changed), "switching loadouts disconnects old callbacks and clears old controls")
	replacement.weapon_instances.append(fresh)
	popup.set_loadout(replacement)
	popup.reset_run()
	check(strip._loadout == null and strip._weapon_buttons.is_empty() and strip._cast_mode_buttons.is_empty(), "run reset releases retained weapon controls")
	popup.queue_free()
	loadout.queue_free()
	replacement.queue_free()
	await frames()


func _reactions() -> void:
	var arena := Node2D.new()
	add_child(arena)
	var identities: Array[int] = []
	for index in 160:
		var text := REACTION.spawn(arena, "thunder_fire", Vector2(index * 3, 100))
		identities.append(text.get_instance_id())
	check(get_tree().get_nodes_in_group(REACTION.GROUP).size() == 160, "all simultaneous reaction contacts retain their text")
	var first = arena.get_child(0)
	var age: float = first.age
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	first._physics_process(0.4)
	check(is_equal_approx(first.age, age), "reaction animation respects battle pause")
	var previous_line: TextLine = first._line
	var locale := L10n.locale
	L10n.set_locale("en" if locale == "zh_CN" else "zh_CN", false)
	check(first._line != previous_line and is_equal_approx(first.age, age), "paused reaction updates language without restarting")
	L10n.set_locale(locale, false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for text in get_tree().get_nodes_in_group(REACTION.GROUP):
		text.cancel()
		text.cancel()
	await frames()
	check(arena.get_child_count() == 128 and get_tree().get_nodes_in_group(REACTION.GROUP).is_empty(), "idle pool bounded and cancellation idempotent")
	var second = REACTION.spawn(arena, "conduct", Vector2(50, 80))
	check(second.get_instance_id() in identities and second.kind == "conduct" and second.age == 0.0, "pooled reaction resets kind and lifetime")
	check(second.get_index() == arena.get_child_count() - 1, "reused contact draws after older contacts")
	check(second.global_position == (Vector2(50, 80) - second._line.get_size() * 0.5).round(), "pooled reaction starts at new contact")
	second._physics_process(1.0)
	check(not second.visible and not second.is_physics_processing(), "expired reaction stops processing")
	arena.queue_free()
	await frames()
	check(get_tree().get_nodes_in_group(REACTION.GROUP).is_empty(), "encounter cleanup leaves no reaction nodes")


func _damage() -> void:
	var arena := Node2D.new()
	add_child(arena)
	EnemyController.prepare_damage_number_pool(arena)
	EnemyController.prepare_damage_number_pool(arena)
	check(arena.get_children().filter(func(child): return child is Label).size() == 160 and arena.get_child_count() == 161 and EnemyController.active_damage_numbers == 0, "battle preparation is idempotent and reserves no active budget")
	var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.current_hp = 10000
	for index in 400: enemy.take_damage(1, "hitch_regression")
	check(enemy.current_hp == 9600, "display optimization preserves every damage event")
	check(EnemyController.active_damage_numbers == 128, "ordinary display budget unchanged")
	for index in 40: enemy.take_damage(2, "hitch_regression", true)
	check(enemy.current_hp == 9520 and EnemyController.active_damage_numbers == 160, "critical reserve does not cap damage")
	await get_tree().create_timer(1.2).timeout
	check(EnemyController.active_damage_numbers == 0, "numbers recycle after animation")
	enemy.take_damage(9, "hitch_regression", true)
	arena.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 0, "scene cleanup releases active number budget")


func _compare_reaction_pixels() -> void:
	if DisplayServer.get_name() == "headless": return
	var legacy := GDScript.new()
	legacy.source_code = FileAccess.get_file_as_string(legacy_path)
	check(legacy.reload() == OK, "load pre-change reaction for visual comparison")
	for kind in ["thunder_fire", "conduct"]:
		var images: Array[Image] = []
		for script in [legacy, REACTION]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(160, 80)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var text = script.spawn(viewport, kind, Vector2(80, 50))
			text.age = 0.2
			text._paint()
			text.set_physics_process(false)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			images.append(viewport.get_texture().get_image())
			viewport.queue_free()
			await frames()
		if not captures.is_empty():
			images[0].save_png(captures.path_join(kind + "_before.png"))
			images[1].save_png(captures.path_join(kind + "_after.png"))
		check(images[0].get_data() == images[1].get_data(), "reaction appearance matches original pixels: " + kind)
