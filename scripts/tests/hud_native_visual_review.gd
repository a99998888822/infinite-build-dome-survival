extends Node
## Same production states, fixed frame timing and transient saves on both sides.

var output := "res://artifacts/reviews/hud_native_1920/before"
var shots: Array[Dictionary] = []
var game: GameRoot
var battle: BattleRoot
var flow: MainFlowCoordinator
var menu: MainMenuUIController
var hud: BattleHud


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 45) -> void:
	for i in count: await get_tree().process_frame


func capture(id: String) -> void:
	await frames()
	if id == "10_stats": hud._set_drawer_open(true, false)
	menu.set_process(false)
	menu.title_art.position = menu._title_base_position
	menu.character_view.reset_animation()
	menu.character_view.set_process(false)
	for card in game.find_children("*", "RewardOption", true, false): card._stop_icon_float()
	for counter in game.find_children("CombatPerformanceLine", "Label", true, false):
		counter.set_process(false)
		counter.text = "FPS 60 | Enemies 0 | Particles 0"
	var controls: Array[Dictionary] = []
	_collect(game, "game", controls)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(output.path_join(id + ".png")) == OK)
	shots.append({"id": id, "controls": controls})
	print("HUD_NATIVE_CAPTURE ", id, " controls=", controls.size())


func _collect(node: Node, path: String, controls: Array[Dictionary]) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is CanvasLayer and not node.visible: return
	if node is Control:
		var rect: Rect2 = node.get_global_rect()
		var record := {"path": path, "type": node.get_class(), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "scale": [node.scale.x, node.scale.y]}
		if node is Label or node is Button or node is RichTextLabel:
			record["text"] = str(node.text)
			record["font_size"] = node.get_theme_font_size("normal_font_size" if node is RichTextLabel else "font_size")
		controls.append(record)
	var index := 0
	for child in node.get_children():
		_collect(child, path + "/" + str(index) + ":" + child.get_class(), controls)
		index += 1


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	CampProgression.state = CampProgression._build_default_state()
	CombatSettings.set_option("keyboard_movement", true, false)
	CombatSettings.set_option("quick_cast", true, false)
	CombatSettings.set_option("show_hints", false, false)
	L10n.set_locale("zh_CN", false)
	seed(19102026)
	get_tree().root.size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(15)
	flow = game.get_main_flow_coordinator()
	menu = game.get_node("UiRoot/MainMenuUIController")
	await capture("01_menu")
	menu._on_settings_pressed()
	await capture("02_settings_basic")
	menu._settings_panel.select_page(1)
	await capture("03_settings_combat")
	menu._close_settings()
	await frames()
	menu._on_talents_pressed()
	await capture("04_talents")
	var talents := game.get_node("UiRoot/CampBlueprintUIController") as CampBlueprintUIController
	var first: Dictionary = CampProgression.get_building_records()[0]
	talents.select_node(str(first.id))
	await capture("05_talent_selected")
	talents._on_back_pressed()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade", "weapon_camp_dagger"])
	await capture("06_character_hunter")
	menu._on_character_selected("character_capitalist")
	await capture("07_character_capitalist")
	menu._on_character_selected("character_void_hunter")
	assert(flow.confirm_character_selection())
	await frames(15)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	hud = battle.hud as BattleHud
	while flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP: flow.close_shared_reward_shop_popup()
	if flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		await capture("08_combat_guide")
		battle.combat_guide.skip_button.pressed.emit()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	battle.set_process(false)
	battle.loadout.set_physics_process(false)
	battle.active_controller.set_process(false)
	battle.active_controller.set_physics_process(false)
	# A neutral background isolates HUD pixels from independent world animation.
	game._world_viewport_container.hide()
	battle.wave_manager.current_gold = 500
	hud._refresh_all()
	await capture("09_battle")
	hud._set_drawer_open(true, false)
	await capture("10_stats")
	hud._set_drawer_open(false, false)
	flow.request_battle_utility("settings")
	await capture("11_battle_settings")
	flow.close_battle_utility()
	flow.request_battle_utility("encyclopedia")
	await capture("12_encyclopedia")
	flow.close_battle_utility()
	flow.request_esc_overlay()
	await capture("13_inventory")
	flow.close_esc_overlay()
	flow.request_shared_reward_shop_popup(4)
	await capture("14_reward")
	battle.player.modifier_stack.set_base_stat("shop_offer_count_bonus", 5)
	assert(bool(flow.request_shop_refresh().get("success", false)))
	await capture("14b_reward_grid")
	battle.player.modifier_stack.set_base_stat("shop_offer_count_bonus", 0)
	flow.close_shared_reward_shop_popup()
	battle.wave_manager._on_relic_choice_collected("hud_review")
	await capture("15_miniboss")
	flow.close_shared_reward_shop_popup()
	flow.finish_current_wave()
	await frames(30)
	var finance := game.find_child("FinancePopup", true, false) as FinancePopup
	assert(finance != null and finance.visible)
	finance.interest_arrival.skip()
	battle.wave_manager.goblin_trades.cancel()
	finance.cancel_trade("review")
	finance.portrait.set_process(false)
	await capture("16_finance")
	finance._select_tab("enchant")
	await capture("17_enchant")
	finance._select_tab("bank")
	game.find_child("FinanceUIController", true, false).set_process(false)
	var receipt := {"wave": 1, "combat": 120, "total": 50, "special": true, "steps": [
		{"kind": "base", "icon": "", "label": "波次利息", "amount": "+40", "target": 40},
		{"kind": "bonus", "icon": "res://assets/ui/icons/relics/relic_piggy_bank.png", "label": "遗物加成", "amount": "+10", "target": 50},
	]}
	finance.interest_arrival.present(receipt)
	finance.interest_arrival.set_process(false)
	finance.interest_arrival.seek(finance.interest_arrival.final_time)
	await capture("18_interest")
	finance.interest_arrival.stop()
	finance.present_trade("钱不够？先拿去，后面再还！", "获得金币，下一波开始后结算。", "交易条件保持不变。")
	finance.trade_presentation.set_process(false)
	finance.trade_presentation.seek(1.2)
	await capture("19_trade")
	finance.cancel_trade("review")
	var loans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/goblin_loans.json"))
	var options: Array = loans.offers.duplicate(true)
	for option in options: option["due"] = roundi(option.amount * (1.0 + option.rate_percent / 100.0))
	finance.loan_presentation.configure({"state": "offered", "gold": 500, "dialog_open": true, "quote": {"speech": loans.speech, "due_wave": 3, "options": options}})
	finance.loan_presentation.set_process(false)
	finance.loan_presentation.elapsed = 2.0
	finance.loan_presentation._seek()
	await capture("20_loan")
	finance.loan_presentation.configure({"state": "hidden"})
	flow.present_battle_result(false, {"reason": "retreat"})
	await frames()
	menu.battle_result_panel.skip()
	menu.battle_result_panel.set_process(false)
	await capture("21_settlement")
	flow.confirm_battle_result()
	hud = null
	await frames()
	L10n.set_locale("en", false)
	menu._on_settings_pressed()
	await capture("22_settings_basic_en")
	menu._settings_panel.select_page(1)
	await capture("23_settings_combat_en")
	menu._close_settings()
	await frames()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade", "weapon_camp_dagger"])
	await capture("24_character_en")
	var file := FileAccess.open(output.path_join("layout.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"canvas": [1920, 1080], "shots": shots}, "\t"))
	file.close()
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("HUD_NATIVE_REVIEW_COMPLETE shots=", shots.size())
	get_tree().quit()
