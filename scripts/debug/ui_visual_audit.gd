extends Node

# Run with:
# godot --path <project> res://scenes/debug/ui_visual_audit.tscn -- --audit-resolution=1152x648

const GAME_ROOT_SCENE: PackedScene = preload("res://scenes/core/game_root.tscn")

const OUTPUT_ROOT := "res://artifacts/ui_visual_audit"
const VIEWPORT_MARGIN := 1.0

var _resolution := Vector2i(1152, 648)
var _output_directory := ""
var _report_lines: Array[String] = []
var _failure_count := 0
var _root_window: Window = null
var _initial_scene: Node = null
var _audit_game_root: GameRoot = null


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	print("[UIAudit] starting")
	_root_window = get_tree().root
	if _root_window == null:
		push_error("[UIAudit] root window is missing")
		get_tree().quit(1)
		return
	_initial_scene = get_tree().current_scene
	_resolution = _read_resolution_argument()
	await _wait_frames(3)
	_configure_window()
	await _wait_frames(8)
	_prepare_output_directory()

	var game_root := GAME_ROOT_SCENE.instantiate() as GameRoot
	if game_root == null:
		_record_failure("game_root", "could not instantiate GameRoot")
		await _finish()
		return
	_audit_game_root = game_root
	_root_window.add_child(game_root)
	get_tree().current_scene = game_root
	await _wait_frames(12)

	await _capture_main_menu(game_root)
	await _capture_talents_and_camp(game_root)
	await _capture_battle_pages(game_root)
	await _capture_popup_pages(game_root)
	await _finish()


func _read_resolution_argument() -> Vector2i:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--audit-resolution="):
			continue
		var raw_size := argument.trim_prefix("--audit-resolution=")
		var parts := raw_size.split("x", false)
		if parts.size() != 2:
			continue
		var width := int(parts[0])
		var height := int(parts[1])
		if width > 0 and height > 0:
			return Vector2i(width, height)
	return _resolution


func _configure_window() -> void:
	_root_window.mode = Window.MODE_WINDOWED
	_root_window.borderless = false
	_root_window.size = _resolution
	_root_window.position = Vector2i(32, 32)


func _prepare_output_directory() -> void:
	_output_directory = "%s/%dx%d" % [OUTPUT_ROOT, _resolution.x, _resolution.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_directory))
	_report_lines.append("resolution=%dx%d" % [_resolution.x, _resolution.y])


func _capture_main_menu(game_root: GameRoot) -> void:
	var menu := game_root.get_node_or_null("UiRoot/MainMenuUIController") as CanvasLayer
	if menu == null:
		_record_failure("main_menu", "MainMenuUIController is missing")
		return
	await _wait_frames(8)
	await _capture("main_menu", [
		_assert_title_below_rule(menu),
		_assert_control_in_viewport("quit_button", menu.get_node_or_null("StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/QuitButton") as Control),
		_assert_button_uses_full_shell(menu, "StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell", "StartPage/ContentMargin/ContentColumn/ButtonArea/ButtonCenter/ButtonRow/QuitShell/QuitButton"),
	])

	menu.call("_on_settings_pressed")
	await _wait_frames(24)
	await _capture("main_menu_settings", [_assert_visible_controls_in_viewport("main_menu_settings", menu)])
	menu.call("_close_settings")
	await _wait_frames(16)

	menu.call("_on_start_battle_pressed")
	await _wait_frames(24)
	await _capture("main_menu_character_select", [_assert_visible_controls_in_viewport("main_menu_character_select", menu)])
	menu.call("show_start_page")
	await _wait_frames(12)

	var start_page := menu.get_node_or_null("StartPage") as Control
	var character_page := menu.get_node_or_null("CharacterSelectPage") as Control
	var result_page := menu.get_node_or_null("BattleResultPanel") as Control
	if start_page != null:
		start_page.visible = false
	if character_page != null:
		character_page.visible = false
	if result_page != null:
		result_page.visible = true
	menu.call("_refresh_result_text")
	await _wait_frames(12)
	await _capture("main_menu_battle_result", [_assert_visible_controls_in_viewport("main_menu_battle_result", menu)])
	menu.call("show_start_page")
	await _wait_frames(8)


func _capture_talents_and_camp(game_root: GameRoot) -> void:
	var flow := game_root.get_main_flow_coordinator()
	var menu := game_root.get_node_or_null("UiRoot/MainMenuUIController") as CanvasLayer
	if menu == null:
		_record_failure("camp_talents", "MainMenuUIController is missing")
		return
	menu.call("_on_talents_pressed")
	await _wait_frames(20)
	var talents := game_root.get_node_or_null("UiRoot/CampBlueprintUIController") as Control
	await _capture("camp_talents", [_assert_visible_controls_in_viewport("camp_talents", talents)])
	flow.enter_start_page()
	await _wait_frames(12)


func _capture_battle_pages(game_root: GameRoot) -> void:
	var flow := game_root.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await _wait_frames(16)
	var battle_root := game_root.get_node_or_null("WorldRoot/BattleRoot")
	if battle_root != null:
		battle_root.set_process(false)
		for runtime_node_name in ["Player", "Loadout", "WaveManager"]:
			var runtime_node := battle_root.get_node_or_null(runtime_node_name)
			if runtime_node != null:
				runtime_node.set_process(false)
	if not flow.confirm_character_selection():
		_record_failure("battle_hud", "could not initialize the battle audit fixture")
		return
	await _wait_frames(20)
	var hud: Node = battle_root.get_node_or_null("HUD") if battle_root != null else null
	await _capture("battle_hud", _battle_hud_assertions(hud, false, false))

	if hud != null:
		hud.call("_on_drawer_toggle_pressed")
		await _wait_frames(16)
		await _capture("battle_hud_stats_drawer", _battle_hud_assertions(hud, true, false))
		hud.call("_on_drawer_toggle_pressed")

	var joystick := battle_root.get_node_or_null("MobileControls/MobileJoystick") as Control if battle_root != null else null
	if joystick != null:
		joystick.call("set_mobile_input_enabled", true)
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = true
		touch.position = Vector2(120.0, float(_resolution.y) - 120.0)
		joystick.call("_handle_screen_touch", touch)
		await _wait_frames(8)
		await _capture("battle_mobile_joystick", [_assert_visible_controls_in_viewport("battle_mobile_joystick", joystick)])
		joystick.call("set_mobile_input_enabled", false)

	flow.request_esc_overlay()
	await _wait_frames(24)
	var overlay := battle_root.get_node_or_null("EscLayer/EscOverlay") as Control if battle_root != null else null
	await _capture("battle_esc_overlay", [
		_assert_visible_controls_in_viewport("battle_esc_overlay", overlay),
		_assert_drawer_open("battle_esc_drawer", hud),
	])
	flow.close_esc_overlay()
	await _wait_frames(12)


func _capture_popup_pages(game_root: GameRoot) -> void:
	var flow := game_root.get_main_flow_coordinator()
	var battle_root := game_root.get_node_or_null("WorldRoot/BattleRoot")
	var hud := battle_root.get_node_or_null("HUD") if battle_root != null else null
	var shop_popup := game_root.get_node_or_null("UiRoot/ShopUIController/PopupLayer/ShopPopup") as Control
	if shop_popup != null:
		flow.call("_set_state", MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP)
		await _wait_frames(12)
		shop_popup.call("configure", _build_offer_payload("free"))
		shop_popup.call("show_popup")
		await _wait_frames(24)
		var free_checks := _shop_assertions(shop_popup)
		free_checks.append(_assert_drawer_open("rewards_drawer", hud))
		await _capture("rewards_relic_cards", free_checks)
		shop_popup.call("hide_popup")
		await _wait_frames(8)
		flow.call("_set_state", MainFlowCoordinator.STATE_SHOP_POPUP)
		await _wait_frames(12)
		shop_popup.call("configure", _build_offer_payload("shop"))
		shop_popup.call("show_popup")
		await _wait_frames(24)
		var shop_checks := _shop_assertions(shop_popup)
		shop_checks.append(_assert_drawer_open("shop_drawer", hud))
		await _capture("shop_relic_cards", shop_checks)
		shop_popup.call("hide_popup")
	else:
		_record_failure("shop", "ShopPopup is missing")

	var finance_popup := game_root.get_node_or_null("UiRoot/FinanceUIController/PopupLayer/FinancePopup") as Control
	if finance_popup != null:
		flow.call("_set_state", MainFlowCoordinator.STATE_FINANCE_POPUP)
		await _wait_frames(12)
		finance_popup.call("configure", {
			"gold": 720,
			"principal": 480,
			"interest_rate": 12.5,
			"estimated_interest": 60,
			"requires_deposit_for_interest": true,
			"deposit_requirement": 50,
		})
		finance_popup.call("show_popup")
		await _wait_frames(24)
		await _capture("finance_popup", [
			_assert_visible_controls_in_viewport("finance_popup", finance_popup),
			_assert_drawer_open("finance_drawer", hud),
		])
		finance_popup.call("hide_popup")

	var interest_popup := game_root.get_node_or_null("UiRoot/FinanceUIController/PopupLayer/InterestSettlementPopup") as Control
	if interest_popup != null:
		flow.call("_set_state", MainFlowCoordinator.STATE_INTEREST_SETTLEMENT)
		await _wait_frames(12)
		interest_popup.call("configure", {
			"principal": 480,
			"interest_rate": 12.5,
			"settlement_results": [
				{"source": "wave_end", "success": true, "gain": 60, "interest_rate": 12.5},
				{"source": "annuity_extra", "success": true, "gain": 20, "interest_rate": 12.5},
			],
		})
		interest_popup.call("show_popup")
		await _wait_frames(72)
		await _capture("interest_settlement", [
			_assert_visible_controls_in_viewport("interest_settlement", interest_popup),
			_assert_drawer_open("interest_drawer", hud),
		])
		interest_popup.call("hide_popup")


func _build_offer_payload(mode: String) -> Dictionary:
	var offers: Array[Dictionary] = []
	var relic_ids := ["relic_piggy_bank", "relic_dividend_check", "relic_compound_interest_tome"]
	for relic_id in relic_ids:
		var relic := DataRegistry.get_record("relics", relic_id)
		offers.append({
			"offer_id": "audit_%s" % relic_id,
			"offer_type": "relic",
			"target_id": relic_id,
			"display_name": str(relic.get("display_name", relic_id)),
			"description": str(relic.get("description", "")),
			"icon": str(relic.get("icon", "")),
			"rarity": str(relic.get("rarity", "common")),
			"shop_cost": 36,
		})
	return {
		"mode": mode,
		"offers": offers,
		"gold": 999,
		"refresh_cost": 12,
	}


func _shop_assertions(shop_popup: Control) -> Array[Dictionary]:
	var results: Array[Dictionary] = [_assert_visible_controls_in_viewport("shop", shop_popup)]
	var panel := shop_popup.get_node_or_null("CenterContainer/MainPanel") as Control
	var scroll := shop_popup.get_node_or_null("CenterContainer/MainPanel/Content/OfferScroll") as Control
	results.append(_assert_control_in_viewport("shop_panel", panel))
	results.append(_assert_control_in_viewport("shop_skip", shop_popup.get_node_or_null("CenterContainer/MainPanel/Content/Footer/SkipButton") as Control))
	results.append(_assert_control_in_viewport("shop_refresh", shop_popup.get_node_or_null("CenterContainer/MainPanel/Content/Footer/RefreshButton") as Control))
	if scroll == null:
		results.append(_failure_result("shop_cards", "OfferScroll is missing"))
		return results
	for card in shop_popup.find_children("RewardOption", "PanelContainer", true, false):
		var select_button := card.get_node_or_null("Content/SelectButton") as Control
		results.append(_assert_control_inside("shop_card_button", select_button, scroll))
	return results


func _battle_hud_assertions(hud: Node, drawer_open: bool, drawer_required: bool) -> Array[Dictionary]:
	if hud == null:
		return [_failure_result("battle_hud", "HUD is missing")]
	var results: Array[Dictionary] = [
		_assert_control_in_viewport("battle_hud_status", hud.get_node_or_null("StatusPanel") as Control),
		_assert_control_in_viewport("battle_hud_economy", hud.get_node_or_null("../EconomyOverlay/EconomyPanel") as Control),
		_assert_control_in_viewport("battle_hud_drawer_toggle", hud.get_node_or_null("StatsDrawer/ToggleButton") as Control),
	]
	if drawer_open:
		results.append(_assert_control_in_viewport("battle_hud_drawer", hud.get_node_or_null("StatsDrawer") as Control))
		results.append(_assert_control_in_viewport("battle_hud_stats_scroll", hud.get_node_or_null("StatsDrawer/DrawerPanel/DrawerBody/ContentMargin/Content/StatsScroll") as Control))
	if drawer_required:
		results.append(_assert_drawer_open("battle_hud_drawer", hud))
	return results


func _assert_drawer_open(label: String, hud: Node) -> Dictionary:
	if hud == null:
		return _failure_result(label, "HUD is missing")
	var drawer := hud.get_node_or_null("StatsDrawer") as Control
	if drawer == null:
		return _failure_result(label, "stats drawer is missing")
	var drawer_rect := _get_screen_rect(drawer)
	var open := bool(hud.get("_drawer_open"))
	return _result(label, open, "rect=(%.1f,%.1f %.1fx%.1f)" % [drawer_rect.position.x, drawer_rect.position.y, drawer_rect.size.x, drawer_rect.size.y])


func _assert_title_below_rule(menu: Node) -> Dictionary:
	var title := menu.get_node_or_null("StartPage/ContentMargin/ContentColumn/TitleArea/TitleCenter/TitleStack/TitleArt") as Control
	var top_rule := menu.get_node_or_null("StartPage/TopRule") as Control
	if title == null or top_rule == null:
		return _failure_result("main_menu_title", "title art or top rule is missing")
	var title_rect := _get_screen_rect(title)
	var rule_rect := _get_screen_rect(top_rule)
	return _result("main_menu_title", title_rect.position.y + VIEWPORT_MARGIN >= rule_rect.end.y, "title_top=%.1f rule_bottom=%.1f" % [title_rect.position.y, rule_rect.end.y])


func _assert_button_uses_full_shell(menu: Node, shell_path: String, button_path: String) -> Dictionary:
	var shell := menu.get_node_or_null(shell_path) as Control
	var button := menu.get_node_or_null(button_path) as Control
	if shell == null or button == null:
		return _failure_result("quit_button_hit_area", "button shell is missing")
	var shell_rect := _get_screen_rect(shell)
	var button_rect := _get_screen_rect(button)
	var covered := button_rect.position.y <= shell_rect.position.y + VIEWPORT_MARGIN and button_rect.end.y >= shell_rect.end.y - VIEWPORT_MARGIN
	return _result("quit_button_hit_area", covered, "shell_height=%.1f button_height=%.1f" % [shell_rect.size.y, button_rect.size.y])


func _assert_visible_controls_in_viewport(label: String, node: Node) -> Dictionary:
	if node == null:
		return _failure_result(label, "root control is missing")
	var issues: Array[String] = []
	for child in node.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null or not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if _is_scroll_content(control):
			continue
		var rect := _get_screen_rect(control)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if rect.position.x < -VIEWPORT_MARGIN or rect.position.y < -VIEWPORT_MARGIN or rect.end.x > float(_resolution.x) + VIEWPORT_MARGIN or rect.end.y > float(_resolution.y) + VIEWPORT_MARGIN:
			issues.append("%s=(%.0f,%.0f %.0fx%.0f)" % [control.get_path(), rect.position.x, rect.position.y, rect.size.x, rect.size.y])
			if issues.size() >= 4:
				break
	return _result(label, issues.is_empty(), "all visible interactive controls inside viewport" if issues.is_empty() else "; ".join(issues))


func _is_scroll_content(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _assert_control_in_viewport(label: String, control: Control) -> Dictionary:
	if control == null:
		return _failure_result(label, "control is missing")
	var rect := _get_screen_rect(control)
	var inside := rect.position.x >= -VIEWPORT_MARGIN and rect.position.y >= -VIEWPORT_MARGIN and rect.end.x <= float(_resolution.x) + VIEWPORT_MARGIN and rect.end.y <= float(_resolution.y) + VIEWPORT_MARGIN
	return _result(label, inside, "rect=(%.1f,%.1f %.1fx%.1f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y])


func _assert_control_inside(label: String, control: Control, container: Control) -> Dictionary:
	if control == null or container == null:
		return _failure_result(label, "control or container is missing")
	var child_rect := _get_screen_rect(control)
	var parent_rect := _get_screen_rect(container)
	var inside := child_rect.position.x >= parent_rect.position.x - VIEWPORT_MARGIN and child_rect.position.y >= parent_rect.position.y - VIEWPORT_MARGIN and child_rect.end.x <= parent_rect.end.x + VIEWPORT_MARGIN and child_rect.end.y <= parent_rect.end.y + VIEWPORT_MARGIN
	return _result(label, inside, "button=(%.1f,%.1f %.1fx%.1f) scroll=(%.1f,%.1f %.1fx%.1f)" % [child_rect.position.x, child_rect.position.y, child_rect.size.x, child_rect.size.y, parent_rect.position.x, parent_rect.position.y, parent_rect.size.x, parent_rect.size.y])


func _get_screen_rect(control: Control) -> Rect2:
	var logical_rect := control.get_global_rect()
	var viewport := control.get_viewport()
	if viewport == null or _root_window == null:
		return logical_rect
	var logical_size := viewport.get_visible_rect().size
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return logical_rect
	var scale := Vector2(_root_window.size) / logical_size
	return Rect2(logical_rect.position * scale, logical_rect.size * scale)


func _result(name: String, passed: bool, detail: String) -> Dictionary:
	return {"name": name, "passed": passed, "detail": detail}


func _failure_result(name: String, detail: String) -> Dictionary:
	return _result(name, false, detail)


func _capture(name: String, checks: Array[Dictionary]) -> void:
	await _wait_frames(6)
	var image := _root_window.get_texture().get_image()
	var image_path := "%s/%s.png" % [_output_directory, name]
	var save_error := image.save_png(ProjectSettings.globalize_path(image_path))
	if save_error != OK:
		_record_failure(name, "could not save screenshot: %s" % error_string(save_error))
	for check in checks:
		var passed := bool(check.get("passed", false))
		var line := "%s %s: %s" % ["PASS" if passed else "FAIL", str(check.get("name", name)), str(check.get("detail", ""))]
		_report_lines.append(line)
		if not passed:
			_failure_count += 1
	print("[UIAudit] %s saved" % image_path)


func _record_failure(name: String, detail: String) -> void:
	_report_lines.append("FAIL %s: %s" % [name, detail])
	_failure_count += 1
	push_error("[UIAudit] %s: %s" % [name, detail])


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _finish() -> void:
	if _audit_game_root != null and is_instance_valid(_audit_game_root):
		if get_tree().current_scene == _audit_game_root:
			get_tree().current_scene = _initial_scene
		_audit_game_root.queue_free()
		await _wait_frames(4)
		_audit_game_root = null
	_report_lines.append("failures=%d" % _failure_count)
	var report_path := "%s/report.txt" % _output_directory
	var report := FileAccess.open(ProjectSettings.globalize_path(report_path), FileAccess.WRITE)
	if report != null:
		report.store_string("\n".join(_report_lines) + "\n")
		report.close()
	print("[UIAudit] completed resolution=%dx%d failures=%d" % [_resolution.x, _resolution.y, _failure_count])
	get_tree().quit(0 if _failure_count == 0 else 1)
