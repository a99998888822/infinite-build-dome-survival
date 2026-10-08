extends Node
## Real production scenes with isolated, deterministic review state. No save writes.

var output := "res://artifacts/localization/review"
var section := "all"
var shots: Array[Dictionary] = []
var findings: Array[Dictionary] = []
var game: GameRoot
var flow: MainFlowCoordinator
var manager: WaveManager
var menu: MainMenuUIController
var popup: FinancePopup
var hud
var utility: BattleUtilityOverlay
var chinese := RegEx.new()
var exposed := RegEx.new()


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--review-section="): section = arg.trim_prefix("--review-section=")
	chinese.compile("[\\x{3400}-\\x{9fff}]")
	exposed.compile("(?:ui|stat|content|error|log)\\.[a-z_]+\\.")
	_run.call_deferred()


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func settle() -> void:
	await get_tree().create_timer(0.38).timeout
	await frames()


func wants(value: String) -> bool:
	return section == "all" or value in section.split(",")


func _run() -> void:
	CampProgression.begin_transient_session()
	seed(10082026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	menu = game.get_node("UiRoot/MainMenuUIController")
	flow = game.get_main_flow_coordinator()
	if wants("menus"): await menus()
	await start_run()
	if wants("battle"): await battle()
	if wants("encyclopedia"): await encyclopedia()
	await open_bank()
	if wants("bank"): await bank()
	if wants("events"): await events()
	DirAccess.make_dir_recursive_absolute(output)
	var manifest = {"locale": L10n.locale, "section": section, "resolution": [1280, 720],
		"source": "Godot GPU viewport, production scenes, transient review state", "shots": shots, "findings": findings}
	var file = FileAccess.open(output.path_join("manifest_%s_%s.json" % [L10n.locale, section]), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	game.queue_free()
	await frames(5)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await get_tree().create_timer(0.4).timeout
	CampProgression.end_transient_session()
	print("VISUAL_REVIEW_COMPLETE locale=%s shots=%d findings=%d" % [L10n.locale, shots.size(), findings.size()])
	get_tree().quit(1 if not findings.is_empty() else 0)


func capture(id: String, title: String, category: String, scope: Node = null) -> void:
	await frames(6)
	var texts: Array[String] = []
	audit(scope if scope != null else game, id, texts)
	var path = L10n.locale.path_join(id + ".png")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output.path_join(L10n.locale))
		await RenderingServer.frame_post_draw
		var error = get_tree().root.get_texture().get_image().save_png(output.path_join(path))
		if error != OK:
			push_error("Capture failed: " + path)
			get_tree().quit(2)
	shots.append({"id": id, "title": title, "category": category, "file": path, "texts": texts})
	print("CAPTURE ", L10n.locale, " ", id)


func audit(node: Node, id: String, texts: Array[String]) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is CanvasLayer and not node.visible: return
	if node is Label or node is RichTextLabel or node is Button or node is LineEdit:
		var text = node.tr(str(node.text))
		if node is LineEdit and text.is_empty(): text = node.tr(node.placeholder_text)
		if not text.is_empty():
			texts.append(text)
			if node.name != "LanguageOption" and ((L10n.locale == "en" and chinese.search(text) != null) or exposed.search(text) != null):
				findings.append({"shot": id, "node": str(node.get_path()), "kind": "untranslated", "text": text})
	for child in node.get_children(): audit(child, id, texts)


func menus() -> void:
	await capture("menu", "主界面", "menus", menu)
	menu._language_option.show_popup()
	await capture("language_dropdown", "语言下拉框", "menus", menu)
	menu._language_option.get_popup().hide()
	menu._on_settings_pressed()
	await settle()
	await capture("menu_settings", "主菜单设置 / 常规", "menus", menu)
	menu._settings_panel.resolution.show_popup()
	await capture("resolution_dropdown", "分辨率列表", "menus", menu)
	menu._settings_panel.resolution.get_popup().hide()
	menu._settings_panel.select_page(1)
	await capture("menu_combat_settings", "主菜单设置 / 战斗", "menus", menu)
	menu._close_settings()
	await settle()
	menu._on_start_battle_pressed()
	await settle()
	for character: Dictionary in DataRegistry.get_table("characters"):
		menu._on_character_selected(str(character.id))
		for difficulty in BattleDifficulty.IDS:
			menu._on_difficulty_selected(difficulty)
			await capture("select_%s_%s" % [character.id, difficulty], "角色选择 / %s / %s" % [character.display_name, difficulty], "menus", menu)
	menu.show_start_page()
	menu._on_talents_pressed()
	await settle()
	var talents = game.find_child("CampBlueprintUIController", true, false)
	if talents == null:
		for node in game.find_children("*", "Control", true, false):
			if node.get_script() == load("res://scripts/ui/camp_blueprint_ui_controller.gd"): talents = node
	assert(talents != null)
	for record: Dictionary in CampProgression.get_building_records():
		talents._selected_building_id = str(record.id)
		talents._refresh_all(false, false)
		await capture("camp_initial_" + str(record.id), "营地 / 初始状态 / " + str(record.name), "camp", talents)
	CampProgression.set_camp_currency(10000)
	for record: Dictionary in CampProgression.get_building_records():
		CampProgression.set_building_level(str(record.id), CampProgression.get_building_max_level(str(record.id)))
	for record: Dictionary in CampProgression.get_building_records():
		talents._selected_building_id = str(record.id)
		talents._refresh_all(false, false)
		await capture("camp_unlocked_" + str(record.id), "营地 / 全部升级选项 / " + str(record.name), "camp", talents)
		talents._options_list.get_parent().scroll_vertical = 10000
		await capture("camp_options_bottom_" + str(record.id), "营地 / 升级选项末页 / " + str(record.name), "camp", talents)
		talents._options_list.get_parent().scroll_vertical = 0
	for page in range(1, 6):
		talents._options_list.get_parent().scroll_vertical = page * 270
		await capture("camp_all_upgrades_page_%d" % page, "营地 / 全部升级列表 / 第 %d 页" % (page + 1), "camp", talents)
	talents._on_back_pressed()
	CampProgression.state = CampProgression._build_default_state()
	await frames()


func start_run() -> void:
	menu.show_start_page()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	assert(flow.confirm_character_selection())
	await frames(15)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.player.item_inventory._random.seed = 10082026
	manager.goblin_trades._rng.seed = 10082026
	hud = game.find_child("HUD", true, false)
	utility = game.find_child("BattleUtilityOverlay", true, false)
	assert(hud != null and utility != null)
	for id in ["relic_piggy_bank", "relic_steel_vault", "relic_dividend_check", "relic_compound_interest_tome"]:
		manager.player.add_relic(id)
	for record: Dictionary in DataRegistry.get_table("augmentations"):
		manager.player.item_inventory.add_item_from_base(str(record.id), "review")
	manager.apply_gold_delta(500, "review")
	manager.finance_system.deposit(1000, true, "review")
	await frames()


func battle() -> void:
	for i in 8:
		var enemy = manager.spawn_enemy("enemy_mutated_grub", manager.player.global_position + Vector2.from_angle(float(i) * TAU / 8) * 150)
		if enemy != null: enemy.set_physics_process(false)
	await capture("battle_hud", "战斗主界面", "battle")
	manager.clear_enemies()
	hud._set_drawer_open(true, false)
	await capture("stats_top", "属性面板 / 上部", "battle")
	hud.stats_scroll.scroll_vertical = 10000
	await capture("stats_bottom", "属性面板 / 下部", "battle")
	for id in hud._stat_name_labels:
		var anchor = hud._stat_name_labels[id]
		hud.stats_scroll.ensure_control_visible(anchor)
		await frames(2)
		hud._show_stat_tooltip(anchor, str(id))
		await capture("stat_" + str(id), "属性说明 / " + StatDefinitions.get_display_name(str(id)), "stats")
		hud._hide_stat_tooltip()
	hud._set_drawer_open(false, false)
	flow.request_esc_overlay()
	await settle()
	await capture("inventory", "战斗背包 / 武器、遗物与附魔", "battle")
	flow.close_esc_overlay()
	flow.request_battle_utility("settings")
	await settle()
	await capture("battle_settings", "战斗内设置 / 常规", "battle", utility)
	utility._settings_view.select_page(1)
	await capture("battle_combat_settings", "战斗内设置 / 操作", "battle", utility)
	flow.close_battle_utility()
	await frames()


func encyclopedia() -> void:
	flow.request_battle_utility("encyclopedia")
	await settle()
	for table_index in utility.TABLES.size():
		var table = utility.TABLES[table_index]
		utility._category.select(table_index)
		utility._refresh_entries()
		for i in utility._records.size():
			var record: Dictionary = utility._records[i]
			utility._entries.select(i)
			utility._entries.ensure_current_is_visible()
			utility._show_entry(i)
			await capture("encyclopedia_" + str(record.id), "图鉴 / " + str(record.get("display_name", record.get("name", record.id))), table, utility)
	utility._category.show_popup()
	await capture("encyclopedia_categories", "图鉴 / 全部分类", "menus", utility)
	utility._category.get_popup().hide()
	utility._search.text = "zzzz_no_matching_entry"
	utility._refresh_entries()
	await capture("encyclopedia_empty", "图鉴 / 无匹配结果", "menus", utility)
	utility._search.clear()
	flow.close_battle_utility()


func open_bank() -> void:
	flow.finish_current_wave()
	await frames(15)
	popup = game.find_child("FinancePopup", true, false)
	assert(popup != null)
	popup.interest_arrival.sound_enabled = false
	popup.interest_arrival.set_process(false)
	popup.interest_arrival.seek(popup.interest_arrival.duration)
	if wants("bank"):
		await capture("interest_receipt", "银行 / 结息到账明细", "bank")
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("review")
	popup.configure(flow.get_preparation_payload())
	await settle()


func bank() -> void:
	hud.stats_scroll.scroll_vertical = 0
	await capture("bank_shop", "银行 / 商品货架", "bank")
	for action in ["deposit", "withdraw"]:
		popup._choose_bank_action(action)
		popup.amount_input.text = "100"
		popup._update_bank_confirm()
		popup._reveal_bank_preview()
		await capture("bank_" + action, "银行 / " + action + " / 预览", "bank")
	popup.amount_input.text = "999999"
	popup._update_bank_confirm()
	await capture("bank_invalid_amount", "银行 / 金额校验", "bank")
	popup.amount_input.clear()
	popup._choose_bank_action("deposit")
	popup.economy_log.set_open(true)
	await capture("bank_log", "银行 / 收支日志", "bank")
	popup.economy_log.set_open(false)
	assert(flow.get_bound_loadout().equip_weapon("weapon_hand_cannon"))
	popup._select_tab("enchant")
	popup.workbench.refresh()
	await capture("enchantment_workbench", "附魔工坊 / 全部库存", "enchantments")
	for page in range(1, 5):
		popup.workbench._inventory_scroll.scroll_vertical = page * 120
		await capture("enchantment_inventory_page_%d" % page, "附魔库存 / 第 %d 页" % (page + 1), "enchantments")
	popup.workbench._inventory_scroll.scroll_vertical = 0
	for item: Dictionary in manager.player.item_inventory.get_items():
		popup.workbench._select_item(str(item.item_instance_id))
		var card = ItemInventoryCard.new()
		card.item_instance = item
		popup._tooltip_mouse_position = Vector2(770, 220)
		popup._show_tooltip(card._build_tooltip())
		await capture("enchantment_" + str(item.base_item_id), "附魔详情 / " + str(item.display_name), "enchantments")
		popup._tooltip.hide()
		card.free()
	for record: Dictionary in DataRegistry.get_table("weapons"):
		var weapon = WeaponInstance.new()
		weapon.initialize(str(record.id), manager.player)
		popup._tooltip_mouse_position = Vector2(770, 130)
		popup._show_tooltip(weapon.build_full_stats_text())
		await capture("weapon_stats_" + str(record.id), "武器完整属性 / " + str(record.display_name), "weapons")
		popup._tooltip.hide()
	popup._open_sale("weapon", "weapon_void_blade")
	assert(popup._sale_layer.visible)
	await capture("sell_weapon", "出售武器 / 确认与价格明细", "bank")
	popup._sale_text.get_v_scroll_bar().value = popup._sale_text.get_v_scroll_bar().max_value
	await capture("sell_weapon_bottom", "出售武器 / 完整明细末页", "bank")
	popup._sale_layer.hide()
	var first_item: Dictionary = manager.player.item_inventory.get_available_items()[0]
	popup._open_sale("enchantment", str(first_item.item_instance_id))
	assert(popup._sale_layer.visible)
	await capture("sell_enchantment", "出售附魔 / 确认与价格明细", "bank")
	popup._sale_text.get_v_scroll_bar().value = popup._sale_text.get_v_scroll_bar().max_value
	await capture("sell_enchantment_bottom", "出售附魔 / 完整明细末页", "bank")
	popup._sale_layer.hide()
	popup.workbench._select_weapon("weapon_hand_cannon")
	popup.workbench._select_item(str(first_item.item_instance_id))
	popup.workbench._apply_selected()
	await frames()
	await capture("enchantment_equipped", "附魔工坊 / 已装备与卸下操作", "enchantments")
	popup._open_sale("weapon", "weapon_hand_cannon")
	assert(popup._sale_layer.visible)
	await capture("sell_weapon_with_enchantment", "出售武器 / 附魔返还说明", "bank")
	popup._sale_text.get_v_scroll_bar().value = popup._sale_text.get_v_scroll_bar().max_value
	await capture("sell_weapon_with_enchantment_bottom", "出售武器 / 附魔返还完整明细末页", "bank")
	popup._sale_layer.hide()
	popup._select_tab("shop")
	var trades = manager.goblin_trades
	var definitions: Array = trades.config.trades
	for definition: Dictionary in definitions:
		trades.config.trades = [definition]
		trades.preparation_wave = -1
		var context = {"wave": 5, "has_next_wave": true, "gold": 500, "principal": 0, "sanity": 100,
			"struggling": true, "can_bank": true, "epic_available": true, "earned": 200}
		if str(definition.id) == "cash_price": context.principal = 5000
		trades.prepare(context)
		trades.config.trades = definitions
		assert(not trades.offer.is_empty(), str(definition.id))
		popup.configure(flow.get_preparation_payload())
		popup.trade_presentation.sound_enabled = false
		popup.trade_presentation.set_process(false)
		popup.trade_presentation.seek(20)
		await capture("trade_" + str(definition.id), "哥布林交易 / " + str(definition.id), "trades")
		popup.cancel_trade("review")
	trades.config.trades = definitions
	trades.cancel()
	var loans = manager.goblin_loans
	loans.prepare(5)
	for i in 3: loans.record_attempt(manager.finance_system, manager.run_statistics)
	popup.configure(flow.get_preparation_payload())
	popup.loan_presentation.elapsed = 20
	popup.loan_presentation._seek()
	await capture("loan_quote", "借贷 / 三档报价与条款", "trades")
	loans.dismiss()
	popup.configure(flow.get_preparation_payload())
	await capture("loan_available", "借贷 / 可再次打开报价", "trades")
	var quote: Dictionary = loans.quote.duplicate(true)
	loans.dialog_open = true
	loans.accept(str(quote.token), 1, manager.finance_system, manager.run_statistics)
	popup.configure(flow.get_preparation_payload())
	await capture("loan_borrowed", "借贷 / 债务与还款", "trades")
	manager.apply_gold_delta(-manager.current_gold, "review_rollover")
	loans.settle_wave(5, manager.finance_system)
	popup.configure(flow.get_preparation_payload())
	await capture("loan_compounded", "借贷 / 逾期复利", "trades")
	manager.apply_gold_delta(1000, "review_repayment")
	popup.configure(flow.get_preparation_payload())
	await capture("loan_ready_to_repay", "借贷 / 资金充足可还款", "trades")
	assert(bool(loans.repay(manager.finance_system).get("success", false)))
	popup.configure(flow.get_preparation_payload())
	await capture("loan_repaid", "借贷 / 已还清", "trades")
	flow.submit_finance_operation("deposit", 100)
	popup.configure(flow.get_preparation_payload())
	await capture("bank_operation_complete", "银行 / 本次操作已完成", "bank")
	popup.economy_log.set_open(true)
	await capture("bank_log_transactions", "银行 / 存款、借贷与还款记录", "bank")
	popup.economy_log.set_open(false)


func events() -> void:
	popup.hide_popup()
	var layer = CanvasLayer.new()
	layer.layer = 90
	game.add_child(layer)
	var challenge = WaveChallengePopup.new()
	layer.add_child(challenge)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/wave_challenges.json"))
	for definition: Dictionary in config.challenges:
		var proposal: Dictionary = definition.duplicate(true)
		proposal["wave"] = 5
		proposal["token"] = "review:" + str(definition.id)
		challenge.present(proposal)
		challenge.presentation.sound_enabled = false
		challenge.presentation.set_process(false)
		challenge.presentation.seek(20)
		await capture("challenge_" + str(definition.id), "波次挑战 / " + str(definition.id), "trades", challenge)
	challenge.queue_free()
	await frames()
	var rewards = load("res://scenes/ui/shop/shop_popup.tscn").instantiate()
	layer.add_child(rewards)
	rewards.set_loadout(flow.get_bound_loadout())
	rewards.set_bond_player(manager.player)
	for mode in ["free", "shop"]:
		rewards.configure(flow._build_shop_payload(mode, 3))
		rewards.show_popup()
		await settle()
		await capture("reward_" + mode, "奖励选择 / " + mode, "battle", rewards)
	rewards.queue_free()
	await frames()
	var result = RunSettlementPanel.new()
	layer.add_child(result)
	result.sound_enabled = false
	result.set_process(false)
	var monster_counts: Dictionary = {}
	var count = 800
	for enemy: Dictionary in DataRegistry.get_table("enemies"):
		monster_counts[str(enemy.id)] = count
		count -= 50
	for victory in [false, true]:
		for followed in [false, true]:
			var example = {"run_id": "review_%s_%s" % [victory, followed], "kills": 1800, "gold": 2500,
				"waves": 8, "interest": 1600, "has_advice": true, "followed": followed,
				"monsters": monster_counts}
			var report = RunSettlement.build(example, victory, "hard")
			report["paid"] = true
			result.present(report)
			result.seek(30)
			await capture("settlement_" + str(report.reaction), "结算 / " + str(report.reaction), "settlement", result)
	await capture("settlement_all_enemies", "结算 / 全部击杀记录同屏", "settlement", result)
	layer.queue_free()
	await frames()
