extends Node
## Real progression and UI exercise. All currency changes are transient.
var checks := 0
var failures := 0
var capture_dir := ""
var page: CampBlueprintUIController
var game: GameRoot
var ids: Dictionary = {}
const CHAINS := {
	"armory": {"damage": "", "crit": "damage", "load": "crit", "crit_damage": "damage", "speed": ""},
	"archive": {"luck": "", "offers": "luck", "drop": ""},
	"blade": {"melee": "", "move": "melee", "frequency": "move", "control": "melee"},
	"range": {"ranged": "", "reach": "ranged", "projectiles": "reach", "area": "ranged", "element": ""},
	"shelter": {"hp": "", "armor": "hp", "revive": "armor", "shield": "hp", "regen": ""},
	"council": {"pickup": "", "exp": "pickup", "principal": "exp", "interest": "exp", "currency": "pickup", "bargain": ""},
}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ", label)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames(8)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)

func click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = down
		get_viewport().push_input(event, true)
	await frames()

func check_node_clearance() -> void:
	# Check real caption bounds, including each possible adjacent purchase arrow.
	var collisions := PackedStringArray()
	var keys: Array = page._nodes.keys()
	var badges_fit := true
	for i in keys.size():
		var a: Control = page._nodes[keys[i]]
		if not a.visible: continue
		badges_fit = badges_fit and a.get_global_rect().encloses(page._node_levels[keys[i]].get_global_rect())
		var a_regions := node_regions(keys[i])
		for j in range(i + 1, keys.size()):
			var b: Control = page._nodes[keys[j]]
			if not b.visible: continue
			var b_regions := node_regions(keys[j])
			var gap := 8.0 * page._zoom
			var overlaps := false
			for a_region: Rect2 in a_regions:
				for b_region: Rect2 in b_regions:
					overlaps = overlaps or a_region.grow(gap).intersects(b_region)
			if overlaps:
				collisions.append(str(keys[i]) + "/" + str(keys[j]))
	check(collisions.is_empty(), "all 34 nodes, labels and purchase arrows have clearance at zoom " + str(page._zoom) + ": " + ", ".join(collisions))
	check(badges_fit, "all level labels fit on their icon lower edge at zoom " + str(page._zoom))

func node_regions(id: String) -> Array[Rect2]:
	var node: Control = page._nodes[id]
	var icon := node.get_global_rect()
	var scale_factor := page._zoom
	var arrow := Rect2(Vector2(icon.end.x + 6 * scale_factor, icon.get_center().y - 8.5 * scale_factor), Vector2(16, 17) * scale_factor)
	return [icon, page._node_labels[id].get_global_rect(), arrow]

func move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)

func drag_from(point: Vector2, button: MouseButton, delta: Vector2) -> void:
	move_pointer(point)
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = button
	press.pressed = true
	get_viewport().push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point + delta
	motion.relative = delta
	get_viewport().push_input(motion, true)
	press.position = motion.position
	press.pressed = false
	get_viewport().push_input(press, true)

func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	for b in CampProgression.get_building_records():
		ids[str(b.icon).get_file().get_basename()] = str(b.id)
		for o in b.upgrade_options: ids[str(o.icon).get_file().get_basename()] = str(o.id)
	check(ids.size() == 34, "six buildings and twenty-eight unique upgrade icons")
	check(DataValidator.new().validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full data validation")
	for building in CHAINS:
		for key in CHAINS[building]:
			var parent: String = CHAINS[building][key]
			var record := CampProgression.get_upgrade_option_record(ids[key])
			check(CampProgression.get_upgrade_option_parent_building_id(ids[key]) == ids[building] and str(record.requires_upgrade) == str(ids.get(parent, "")), "accepted chain " + key)
	for mutation in ["missing", "cycle", "foreign", "level"]:
		var tables := DataRegistry.tables.duplicate(true)
		var options: Array = tables.camp_buildings[0].upgrade_options
		match mutation:
			"missing": options[0].requires_upgrade = "missing_id"
			"cycle": options[0].requires_upgrade = ids.crit
			"foreign": options[0].requires_upgrade = ids.luck
			"level": options[0].required_building_level = 99
		check(not DataValidator.new().validate_all(tables, DataRegistry.records_by_id), "validator rejects " + mutation)
	CampProgression.set_camp_currency(100000)
	for building in CHAINS:
		if not CampProgression.is_building_unlocked(ids[building]):
			for key in CHAINS[building]: check(not CampProgression.is_upgrade_visible(ids[key]), "locked root hides " + key)
			check(CampProgression.purchase_building_unlock(ids[building]), "unlock root " + building)
		for key in CHAINS[building]:
			if not str(CHAINS[building][key]).is_empty():
				var before := CampProgression.get_camp_currency()
				check(not CampProgression.is_upgrade_visible(ids[key]) and not CampProgression.purchase_upgrade(ids[key]) and CampProgression.get_camp_currency() == before, "cannot bypass " + key)
	for building in CHAINS:
		for key in CHAINS[building]:
			check(CampProgression.is_upgrade_visible(ids[key]) and CampProgression.purchase_upgrade(ids[key]), "buy one level reveals next: " + key)
			var visibility_correct := true
			for other in CHAINS[building]:
				var predecessor: String = CHAINS[building][other]
				var expected := predecessor.is_empty() or CampProgression.get_upgrade_option_level(ids[predecessor]) > 0
				visibility_correct = visibility_correct and CampProgression.is_upgrade_visible(ids[other]) == expected
			check(visibility_correct, "only bought prerequisites reveal children after " + key)
	var spent := 0
	for key in ids:
		var record := CampProgression.get_upgrade_option_record(ids[key])
		if not record.is_empty(): spent += int(record.cost)
	check(CampProgression.reset_upgrade_options_and_refund() == spent, "refund equals every purchased level")
	check(not CampProgression.is_upgrade_visible(ids.load), "reset hides deeper descendants")
	check(CampProgression.get_building_max_level(ids.armory) == 3 and CampProgression.get_building_max_level(ids.archive) == 3, "rarity-only levels removed")
	check(not CampProgression.has_unlock("weapon_pool_basic_fine") and not CampProgression.has_unlock("relic_pool_common_fine"), "rarity gates removed")
	CampProgression.state = CampProgression._build_default_state()
	CampProgression.set_camp_currency(10000)
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	await capture("00_main_menu")
	game.get_main_flow_coordinator().enter_talents_flow()
	await frames(8)
	page = game.find_child("CampBlueprintUIController", true, false) as CampBlueprintUIController
	check(page.visible and not page._detail_panel.visible, "real talent page opens with no selection")
	check(page._currency_label.text == "天赋点：10000" and page._currency_label.get_parent() == page._content, "talent points appear in a fixed top label")
	check(page._hint.text == "滚轮缩放 · 鼠标点击拖动", "navigation hint describes mouse dragging")
	var version: Label = game.get_node("UiRoot/MainMenuUIController/StartPage/VersionLabel")
	check(version.tr(version.text) == "版本 v.0106.261018", "main menu displays requested version")
	check(page._tree.edges.size() == 4 and visible_summary_count() == 0 and page._summary_empty.visible, "initial view: four direct branches and no unearned attributes")
	check(page._node_levels[ids.damage].text == "0/10" and page._node_levels[ids.armory].text == "1/3", "upgrade and building levels appear on node lower edges")
	check(not page._nodes[ids.damage].lit and not page._nodes[ids.crit].visible, "unbought node gray, successor hidden")
	var icons_valid := true
	var native_layout := true
	for node: TalentNodeButton in page._nodes.values():
		icons_valid = icons_valid and node.icon_texture.get_size() == Vector2(64, 64) and node.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		var icon_rect := node.get_icon_rect()
		native_layout = native_layout and icon_rect.size == Vector2(64, 64) and node.size == Vector2(104, 104)
		native_layout = native_layout and Rect2(Vector2.ZERO, node.size).encloses(icon_rect.grow(20)) and node.position == node.position.round()
	check(icons_valid, "all 34 production icons are 64px with nearest filtering")
	check(native_layout and page._zoom == 1.0 and page._tree.position == page._tree.position.round(), "all icons start at native 64px with 20px frame padding and integer positions")
	await capture("01_initial")
	var before := CampProgression.get_camp_currency()
	await click(page._nodes[ids.damage].get_global_rect().get_center())
	check(page._selected_id == ids.damage and CampProgression.get_camp_currency() == before, "left click selects without buying")
	check(page._detail_panel.visible and page._upgrade_button.visible, "selection shows detail and adjacent arrow")
	check(page._detail_effect.text == "已获得：伤害加成+0" and page._detail_next.text == "升级后：伤害加成+1", "unbought detail shows cumulative current and next benefit without level text")
	await capture("01_selected")
	move_pointer(page._upgrade_button.get_global_rect().get_center())
	check(page._upgrade_tooltip.visible and page._upgrade_tooltip_text.text == "花费 200 天赋点升级", "hover shows current upgrade cost immediately without waiting a frame")
	check(page.get_global_rect().encloses(page._upgrade_tooltip.get_global_rect()), "upgrade tooltip fits viewport")
	await capture("01_upgrade_hover")
	await click(page._upgrade_button.get_global_rect().get_center())
	check(CampProgression.get_upgrade_option_level(ids.damage) == 1 and page._nodes[ids.crit].visible and not page._nodes[ids.load].visible, "arrow buys one level and reveals only immediate children")
	check(page._summary_values.damage_percent.text.ends_with("+1"), "summary updates from real modifiers")
	check(visible_summary_count() == 1 and page._summary_values.damage_percent.position.is_equal_approx(Vector2(26.666667, 86.666667)) and not page._summary_empty.visible, "only acquired attribute appears at first summary row")
	check(page._node_levels[ids.damage].text == "1/10" and page._detail_effect.text == "已获得：伤害加成+1" and page._detail_next.text == "升级后：伤害加成+2", "purchase updates node level and cumulative benefit preview")
	check(CampProgression.get_upgrade_cost(ids.damage) == 400, "next cost scales with target level")
	check(page._upgrade_tooltip.visible and page._upgrade_tooltip_text.text == "花费 400 天赋点升级", "hover cost updates after purchase")
	var revealed_clear := true
	for child_id in [ids.crit, ids.crit_damage]:
		var child: Control = page._nodes[child_id]
		revealed_clear = revealed_clear and page.get_global_rect().encloses(child.get_global_rect())
		revealed_clear = revealed_clear and not child.get_global_rect().intersects(page._currency_label.get_global_rect())
	check(revealed_clear, "new upper nodes fit below the fixed currency label at default zoom")
	CampProgression.set_camp_currency(0)
	move_pointer(Vector2(300, 600))
	check(not page._upgrade_tooltip.visible, "tooltip hides immediately on pointer exit")
	move_pointer(page._upgrade_button.get_global_rect().get_center())
	check(page._upgrade_button.disabled and page._upgrade_tooltip.visible and page._upgrade_tooltip_text.text == "花费 400 天赋点升级", "unaffordable upgrade still shows cost immediately")
	CampProgression.set_camp_currency(10000)
	var pan_initial := page._pan
	drag_from(Vector2(300, 600), MOUSE_BUTTON_LEFT, Vector2(40, 30))
	check(page._pan.is_equal_approx(pan_initial + Vector2(40, 30)) and not page._dragging, "left drag on blank space pans by pointer delta and stops on release")
	var pan_released := page._pan
	var released_motion := InputEventMouseMotion.new()
	released_motion.position = Vector2(370, 650)
	released_motion.relative = Vector2(30, 20)
	get_viewport().push_input(released_motion, true)
	check(page._pan == pan_released, "moving after release does not keep dragging")
	page.select_node(ids.damage)
	var currency_before_drag := CampProgression.get_camp_currency()
	var summary_rect := page._summary_panel.get_global_rect()
	for target: Control in [page._summary_panel, page._detail_panel, page._reset_button, page._back_button, page._nodes[ids.damage], page._upgrade_button]:
		var pan_start := page._pan
		drag_from(target.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, Vector2(12, 6))
		check(page._pan.is_equal_approx(pan_start + Vector2(12, 6)) and not page._dragging, "right drag starts over " + target.get_class())
	check(page.visible and page._selected_id == ids.damage and CampProgression.get_camp_currency() == currency_before_drag and page._summary_panel.get_global_rect() == summary_rect, "right drag does not activate buttons or move HUD")
	check(not page._upgrade_tooltip.visible, "drag hides upgrade tooltip")
	page._pan = Vector2.ZERO
	page._apply_view()
	await capture("02_damage_selected")
	CampProgression.set_camp_currency(100000)
	for building in CHAINS:
		if not CampProgression.is_building_unlocked(ids[building]): CampProgression.purchase_building_unlock(ids[building])
	for building in CHAINS:
		for key in CHAINS[building]:
			if key != "offers" and CampProgression.get_upgrade_option_level(ids[key]) == 0: CampProgression.purchase_upgrade(ids[key])
	page.select_node(ids.offers)
	check(page._detail_title.text == "商店扩容选项：" and page._detail_effect.text == "已获得：商店选项+0" and page._detail_next.text == "升级后：商店选项+1" and page._detail_cost.text == "升级花费 1200天赋点", "shop detail separates obtained and next totals from node level")
	check(page._node_levels[ids.offers].text == "0/5" and visible_summary_count() == 27 and not page._summary_values.shop_offer_count_bonus.visible, "unbought shop attribute omitted from compact summary")
	await capture("03_expanded")
	for locale in ["zh_CN", "en"]:
		L10n.set_locale(locale, false)
		for zoom in [0.5, 1.0, 3.0]:
			page._zoom = zoom
			page._apply_view()
			await frames()
			check_node_clearance()
	L10n.set_locale("zh_CN", false)
	page.select_node("")
	page._zoom = 0.766667
	page._pan = Vector2(-166.666667, -16.666667)
	page._apply_view()
	await capture("03_overview")
	page.select_node(ids.offers)
	page._zoom = 1.0
	page._pan = Vector2.ZERO
	page._apply_view()
	# Pointer-anchored zoom and actual right-button drag leave HUD fixed.
	var hud_rect := page._summary_panel.get_global_rect()
	var center := page._tree.position
	var zoom_before := page._zoom
	await click(center, MOUSE_BUTTON_WHEEL_UP)
	check(page._zoom > zoom_before and page._summary_panel.get_global_rect() == hud_rect, "wheel zoom affects tree only")
	var right := InputEventMouseButton.new()
	right.position = Vector2(300, 600)
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	get_viewport().push_input(right, true)
	var pan_before := page._pan
	var drag := InputEventMouseMotion.new()
	drag.position = right.position + Vector2(50, 30)
	drag.relative = Vector2(50, 30)
	get_viewport().push_input(drag, true)
	right.pressed = false
	get_viewport().push_input(right, true)
	check(page._pan != pan_before and not page._dragging and page._summary_panel.get_global_rect() == hud_rect, "right drag pans and release stops without moving HUD")
	page._zoom = 1.25
	page._pan = Vector2(-200, 158.333333)
	page._apply_view()
	await capture("04_zoomed")
	CampProgression.set_camp_currency(100000)
	for i in 5: check(CampProgression.purchase_upgrade(ids.offers), "purchase shop expansion " + str(i+1))
	check(not CampProgression.purchase_upgrade(ids.offers), "cap cannot be exceeded")
	check(page._detail_cost.text == "已升满" and page._upgrade_button.disabled, "maxed node disables purchase arrow")
	check(page._upgrade_tooltip_text.text == "已升满", "maxed tooltip no longer advertises an upgrade cost")
	check(page._node_levels[ids.offers].text == "5/5" and page._detail_effect.text == "已获得：商店选项+5" and not page._detail_next.visible, "maxed detail retains owned total and removes unavailable next level")
	check(CampProgression.upgrade_building(ids.armory) and page._summary_values.damage_percent.text.ends_with("+5"), "summary includes retained building bonuses")
	page.select_node(ids.armory)
	check(page._detail_effect.text == "已获得：伤害加成+4" and page._detail_next.text == "升级后：伤害加成+4、攻击速度+10", "building preview accumulates only its own levels and retains previous bonuses")
	await capture("04_building_detail")
	page.select_node(ids.regen)
	check(page._detail_effect.text == "已获得：每秒回血+0.1" and page._detail_next.text == "升级后：每秒回血+0.2", "fractional cumulative benefits remain accurate")
	page.select_node(ids.shelter)
	check(page._detail_next.text == "升级后：开局随机遗物+1", "building preview includes non-stat starting reward")
	page.select_node(ids.offers)
	page._on_reset_pressed()
	check(not page._nodes[ids.offers].visible and page._selected_id.is_empty() and not page._detail_panel.visible, "reset hides descendants and clears hidden selection")
	check(page._summary_values.damage_percent.text.ends_with("+4"), "reset retains building bonus")
	check(visible_summary_count() == 1 and page._node_levels[ids.damage].text == "0/10" and page._summary_values.damage_percent.position.is_equal_approx(Vector2(26.666667, 86.666667)), "reset removes refunded summary entries and resets node levels")
	window.size = Vector2i(1152, 768)
	window.content_scale_size = Vector2i(1920, 1080)
	await frames(8)
	check(page.get_global_rect().encloses(page._summary_panel.get_global_rect()) and page.get_global_rect().encloses(page._back_button.get_global_rect()), "fixed controls fit smaller viewport")
	await capture("05_reset_small")
	page._on_back_pressed()
	await frames()
	check(not page.visible and game.get_node("UiRoot/MainMenuUIController").visible, "return button restores main menu")
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	print("TALENT_TREE_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func visible_summary_count() -> int:
	var count := 0
	for row: Label in page._summary_values.values():
		if row.visible: count += 1
	return count
