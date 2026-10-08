extends Node

var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var chinese := RegEx.new()
var exposed_key := RegEx.new()


func _ready() -> void:
	chinese.compile("[\\x{3400}-\\x{9fff}]")
	exposed_key.compile("(?:ui|stat|log|content|error)\\.[a-z_]+\\.")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", description)


func frames(count := 5) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh-CN", false)
	check(L10n.locale == "zh_CN", "Chinese locale normalization")
	check(L10n.text("ui.bank.deposit.confirm") == "确认存入", "Chinese semantic key")
	var raw := DataRegistry.get_record("weapons", "weapon_void_blade")
	L10n.set_locale("en-US", false)
	check(L10n.text("ui.bank.deposit.confirm") == "Confirm Deposit", "English semantic key")
	check(L10n.source(raw.display_name) == "Wooden Bow", "display data lookup")
	check(DataRegistry.get_record("weapons", "weapon_void_blade") == raw, "registry remains locale independent")
	var message := L10n.message("log.finance.deposit", [12, 100, 112])
	check(L10n.render_message(message).contains("12"), "message preserves numeric arguments")
	var english := L10n.render_message(message)
	L10n.set_locale("zh_CN", false)
	check(L10n.render_message(message) != english, "stored message rerenders in the selected language")
	L10n.set_locale("en", false)
	var english_settings := GameSettingsPanel.new()
	add_child(english_settings)
	L10n.set_locale("zh_CN", false)
	var chinese_settings := GameSettingsPanel.new()
	add_child(chinese_settings)
	check(rendered_texts(english_settings) == rendered_texts(chinese_settings), "English-created controls return fully to Chinese")
	english_settings.free()
	chinese_settings.free()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	check(game.find_children("LanguageOption", "OptionButton", true, false).size() == 1, "exactly one language dropdown")
	check(menu._language_option.get_parent().get_parent() == menu.start_page, "dropdown belongs only to the start page")
	check(menu._language_option.item_count == 2, "dropdown has Chinese and English")
	var chinese_language_rect := menu._language_option.get_global_rect()
	await capture("main_menu_zh")
	menu._language_option.item_selected.emit(1)
	await frames()
	check(L10n.locale == "en" and menu._language_option.selected == 1, "dropdown changes language immediately")
	check(menu._language_option.get_global_rect() == chinese_language_rect, "language dropdown keeps its position and width across locales")
	check(menu.title_art.texture.resource_path.ends_with("title_main_menu_en.png"), "English title asset selected")
	audit_visible(menu, "main menu")
	await capture("main_menu_en")
	for bounds in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		get_tree().root.size = bounds
		get_tree().root.content_scale_size = bounds
		await frames()
		check(Rect2(Vector2.ZERO, Vector2(bounds)).encloses(menu._language_option.get_global_rect()), "language control fits " + str(bounds))
		await capture("main_menu_en_%dx%d" % [bounds.x, bounds.y])
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames()
	menu._language_option.show_popup()
	await capture("language_dropdown_en")
	menu._language_option.get_popup().hide()
	menu._on_settings_pressed()
	await get_tree().create_timer(0.3).timeout
	audit_visible(menu, "settings")
	check(menu._settings_panel.quick_cast != null, "English settings preserve quick-cast control")
	await capture("settings_en")
	menu._settings_panel.select_page(1)
	await frames()
	audit_visible(menu._settings_panel, "combat settings")
	await capture("combat_settings_en")
	menu._close_settings()
	await frames(25)
	menu._on_start_battle_pressed()
	await frames()
	audit_visible(menu, "character selection")
	await capture("character_select_en")
	menu._on_character_selected("character_capitalist")
	await frames()
	audit_visible(menu.character_view, "capitalist selection")
	await capture("capitalist_select_en")
	menu.show_start_page()
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start a localized run")
	await frames()
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(300, "localization_test")
	flow.finish_current_wave()
	await frames(12)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	var trades := manager.goblin_trades
	var definitions: Array = trades.config.trades
	trades.config.trades = [trades.definition("spending_money")]
	trades.preparation_wave = -1
	trades.prepare({"wave": 1, "has_next_wave": true, "gold": 300, "principal": 0, "sanity": 90})
	trades.config.trades = definitions
	popup.configure(flow.get_preparation_payload())
	check(not trades.offer.is_empty(), "prepared a concrete trade")
	var before := snapshot()
	var arrival_elapsed: float = popup.interest_arrival._elapsed
	var arrival_delivered: bool = popup.interest_arrival._arrived
	seed(76543)
	var expected_random := randi()
	seed(76543)
	L10n.set_locale("zh_CN", false)
	L10n.set_locale("en", false)
	check(randi() == expected_random, "language changes do not consume gameplay RNG")
	check(snapshot() == before, "offers, token, balances, inventory and journal stay unchanged")
	check(popup.interest_arrival._elapsed == arrival_elapsed and popup.interest_arrival._arrived == arrival_delivered, "receipt language refresh preserves playback and payout notification")
	check(chinese.search(L10n.record_text(trades.offer, "body")) == null, "prepared trade renders in English")
	popup.trade_presentation.sound_enabled = false
	popup.trade_presentation.seek(20)
	await frames()
	audit_visible(popup, "bank")
	await capture("bank_en")
	manager.player.add_relic("relic_steel_vault")
	var principal_preview := flow.get_bank_stat_preview("deposit", 100)
	check(principal_preview.contains("Armor") and chinese.search(principal_preview) == null, "bank preview translates principal-linked stat names")
	for loan_state in ["borrowed", "compound"]:
		popup.loan_presentation.configure({"state": loan_state, "gold": 300, "debt": {"amount": 200, "due": 260, "due_wave": 2}})
		var loan_status: String = popup.loan_presentation._strip_detail.text
		check(chinese.search(loan_status) == null and exposed_key.search(loan_status) == null, "loan status resolves nested translation keys: " + loan_state)
	popup.loan_presentation.configure({})
	var tooltip: String = flow.get_bound_loadout().get_weapon_instances()[0].build_full_stats_text()
	if not tooltip.is_empty():
		check(chinese.search(tooltip) == null and exposed_key.search(tooltip) == null, "English weapon tooltip")
	var encyclopedia := BattleUtilityOverlay.new()
	check(not "bonds" in BattleUtilityOverlay.TABLES, "encyclopedia has no bond category")
	for table in BattleUtilityOverlay.TABLES:
		for record: Dictionary in DataRegistry.get_table(table):
			var description := encyclopedia._describe_record(table, record)
			check(chinese.search(description) == null and exposed_key.search(description) == null, "English encyclopedia " + str(record.id))
			var bond_text := BondDisplay.build_item_bond_text(record)
			if not bond_text.is_empty():
				check(not description.contains(bond_text), "encyclopedia omits bond details " + str(record.id))
	encyclopedia.free()
	for record: Dictionary in DataRegistry.get_table("weapons"):
		var weapon := WeaponInstance.new()
		weapon.initialize(str(record.id), manager.player)
		var details := weapon.build_full_stats_text()
		check(chinese.search(details) == null and exposed_key.search(details) == null, "English weapon details " + str(record.id))
	for record: Dictionary in DataRegistry.get_table("augmentations"):
		var card := ItemInventoryCard.new()
		card.item_instance = record
		var details := card._build_tooltip()
		check(chinese.search(details) == null and exposed_key.search(details) == null, "English enchantment tooltip " + str(record.id))
		card.free()
	game.queue_free()
	await frames(5)
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await get_tree().create_timer(0.3).timeout
	print("LOCALIZATION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func snapshot() -> String:
	return JSON.stringify({"gold": manager.current_gold, "principal": manager.finance_system.principal,
		"action_used": manager.finance_system.manual_operation_used,
		"trade": manager.goblin_trades.offer, "trade_rng": manager.goblin_trades._rng.state,
		"offers": flow.get_preparation_payload().get("offers", []),
		"items": manager.player.item_inventory._items, "journal": manager.economy_journal.get_entries()})


func audit_visible(node: Node, screen: String) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is CanvasLayer and not node.visible: return
	if node is Label or node is RichTextLabel or node is Button:
		if node.name != "LanguageOption":
			var rendered := node.tr(str(node.text))
			check(chinese.search(rendered) == null and exposed_key.search(rendered) == null, screen + ": " + str(node.get_path()) + " = " + rendered.replace("\n", " ").left(90))
	for child in node.get_children():
		audit_visible(child, screen)


func rendered_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label or node is RichTextLabel or node is Button:
		texts.append(node.tr(str(node.text)))
	for child in node.get_children():
		texts.append_array(rendered_texts(child))
	return texts


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(6)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)
