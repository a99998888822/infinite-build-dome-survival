extends Node

var checks := 0
var failures := 0
var capture_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count: int = 5) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text: return child
		var nested := find_button(child, text)
		if nested != null: return nested
	return null


func check_talents() -> void:
	var stats: Dictionary = {}
	var count := 0
	for building in CampProgression.get_building_records():
		for option in building.get("upgrade_options", []):
			check(not stats.has(option.stat), "unique purchasable talent stat: " + str(option.stat))
			stats[option.stat] = option.id
			count += 1
	check(count == 29, "thirty-five purchase options reduce to twenty-nine unique attributes")
	check(stats.luck == "camp_upgrade_relic_luck" and stats.drop_rate_percent == "camp_upgrade_drop_rate_percent", "retain designated luck and drop-rate paths")
	var old := {"currencies": {"camp_currency": 1234}, "upgrade_levels": {"camp_upgrade_relic_luck": 3}}
	for retired in CampProgression.RETIRED_UPGRADE_OPTIONS: old.upgrade_levels[retired] = 2
	var migrated := CampProgression._sanitize_state(old)
	check(migrated.currencies.camp_currency == 8134, "all six retired level-two routes refund their historical escalating cost: 6900")
	check(migrated.upgrade_levels == {"camp_upgrade_relic_luck": 3}, "retired levels removed and surviving talent level preserved")
	check(CampProgression._sanitize_state(migrated) == migrated, "reloading migrated save cannot refund twice")
	check(old.currencies.camp_currency == 1234 and old.upgrade_levels.size() == 7, "migration does not mutate source save or backup")
	for retired in CampProgression.RETIRED_UPGRADE_OPTIONS:
		check(CampProgression.get_upgrade_option_record(retired).is_empty() and not CampProgression.can_purchase_upgrade(retired), "retired route cannot be repurchased: " + str(retired))
	var validator := DataValidator.new()
	check(validator.validate_all(DataRegistry.tables, DataRegistry.records_by_id), "current configuration passes full validation")
	var duplicate_tables := DataRegistry.tables.duplicate(true)
	var duplicate: Dictionary = duplicate_tables.camp_buildings[0].upgrade_options[0].duplicate(true)
	duplicate.id = "test_duplicate_talent"
	duplicate_tables.camp_buildings[-1].upgrade_options.append(duplicate)
	check(not validator.validate_all(duplicate_tables, DataRegistry.records_by_id)
		and validator.errors.any(func(message): return message.contains("duplicates upgrade stat")), "validator rejects future duplicates across buildings")


func _run() -> void:
	CampProgression.begin_transient_session()
	check_talents()
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1152, 768)
	window.content_scale_size = Vector2i(1152, 768)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(2)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start real game for bank regression")
	await frames(8)
	var manager := flow._bound_wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(5000, "test")
	var player := flow.get_bound_player()
	for relic_id in ["relic_steel_vault", "relic_quant_trading", "relic_hostile_takeover", "relic_merger_reorg"]:
		player.add_relic(relic_id)
	flow.finish_current_wave()
	await frames(12)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.visible, "actual finance panel opens")
	popup.amount_input.text = ""
	popup._choose_bank_action("deposit")
	await frames()
	check(popup.portrait.is_visible_in_tree(), "banker is visible before entering amount")
	var portrait_rect := popup.portrait.get_global_rect()
	await capture("bank_before_all")
	for label in ["1/4", "1/2", "全部"]:
		var quick := find_button(popup, label)
		check(quick != null, "quick amount button exists: " + label)
		quick.pressed.emit()
		await frames(10)
		check(popup._bank_preview.is_visible_in_tree() and popup.portrait.is_visible_in_tree(), "preview and banker coexist after " + label)
		check(popup.portrait.get_global_rect() == portrait_rect, "amount preview does not move or clip banker after " + label)
	check(popup.amount_input.text.to_int() == manager.get_current_gold(), "all button selects complete available balance")
	check(popup.portrait.get_global_rect().end.y <= popup._bank.get_global_rect().position.y, "portrait occupies pinned header outside form scrolling")
	await capture("bank_after_all")
	popup._bank.ensure_control_visible(popup.bank_confirm)
	await frames()
	check(popup.portrait.get_global_rect() == portrait_rect and popup.portrait.is_visible_in_tree(), "scrolling to confirmation keeps banker visible")
	var deposit := popup.amount_input.text.to_int()
	popup.bank_confirm.pressed.emit()
	await frames(10)
	check(manager.finance_system.manual_operation_used and manager.get_current_gold() == 0, "all deposit still completes normally")
	check(popup.portrait.is_visible_in_tree() and popup.portrait.expression in [3, 4], "successful deposit keeps visible banker reaction")
	check(int(manager.finance_system.last_manual_operation.get("amount", 0)) == deposit, "deposit amount is unchanged by layout")
	await capture("bank_after_deposit")
	# Compact layouts keep the bank header bound to its tab; very short windows
	# retain scrollable forms instead of sacrificing access to the confirmation.
	window.size = Vector2i(660, 720)
	window.content_scale_size = Vector2i(660, 720)
	await frames(10)
	popup.set_safe_rect(Rect2(8, 70, 644, 630))
	popup._select_tab("bank")
	await frames()
	check(popup.portrait.is_visible_in_tree(), "tall compact bank shows portrait")
	popup._select_tab("shop")
	check(not popup.portrait.is_visible_in_tree(), "compact shop does not leave banker over the merchandise")
	popup.set_safe_rect(Rect2(8, 70, 644, 280))
	popup._select_tab("bank")
	check(not popup.portrait.is_visible_in_tree() and popup._bank.visible, "short bank preserves form access")

	flow.request_battle_utility("settings")
	flow.return_to_main_menu_from_settings()
	await frames()
	check(not popup.visible, "finance closes before returning to talents")
	window.size = Vector2i(1152, 768)
	window.content_scale_size = Vector2i(1152, 768)
	for building in CampProgression.get_building_records():
		CampProgression.state.building_levels[building.id] = 5
	CampProgression.state_changed.emit()
	flow.enter_talents_flow()
	await frames(15)
	var talents := game.find_child("CampBlueprintUIController", true, false) as CampBlueprintUIController
	talents.show_talents_page()
	talents._refresh_options(false)
	await frames()
	check(talents._options_count_label.text.contains("29"), "actual talents page displays twenty-nine available upgrades")
	await capture("talents_deduplicated")
	CampProgression.end_transient_session()
	game.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.1).timeout
	print("FINANCE_TALENT_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
