extends Node
## Exercise real viewport input and wave transitions without saving progression.

var failures := 0
var capture_dir := ""
var flow: MainFlowCoordinator
var popup: FinancePopup
var manager: WaveManager
@onready var window := get_window()


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(99))


func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	window.push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		window.push_input(event)
		await frames(2)


func next_finance() -> void:
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE, "next wave opens its challenge")
	if flow.current_state != MainFlowCoordinator.STATE_WAVE_CHALLENGE: return
	flow.decide_wave_challenge(str(manager.wave_challenges.offer.token), false)
	await frames()
	manager.clear_enemies()
	flow.finish_current_wave()
	await frames(20)
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("notice_test")
	manager.wave_challenges.pressure = {"comfortable": true}
	check(popup.visible and not popup._enchantment_notice.visible, "new finance visit starts without a visible notice")


func capture(id: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(capture_dir.path_join(id + ".png"))


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	seed(20102026)
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = window.size
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	window.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	check(flow.confirm_character_selection(), "production battle starts")
	await frames(12)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	flow.finish_current_wave()
	await frames(20)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("notice_test")
	manager.wave_challenges.pressure = {"comfortable": true}
	var inventory := manager.player.item_inventory
	var weapon := flow.get_bound_loadout().get_weapon_instances()[0]
	for item in weapon.get_attached_item_instances():
		flow.submit_enchantment_operation("detach", weapon.weapon_id, str(item.item_instance_id))
	inventory.clear()
	popup.workbench.refresh()
	check(weapon.has_available_attachment_slot() and inventory.get_available_items().is_empty(), "fixture has a free slot and no spells")
	await click(popup.start_button.get_global_rect().get_center())
	check(not popup._enchantment_notice.visible, "empty inventory proceeds without a warning")
	await next_finance()
	while weapon.has_available_attachment_slot():
		var item := inventory.add_item_from_base("scroll_fire", "notice_test")
		check(flow.submit_enchantment_operation("attach", weapon.weapon_id, str(item.item_instance_id)).success, "fill a real enchantment slot")
	var spare := inventory.add_item_from_base("scroll_water", "notice_test")
	await click(popup.start_button.get_global_rect().get_center())
	check(not popup._enchantment_notice.visible, "full slots proceed despite a spare spell")
	await next_finance()
	inventory.take_unequipped_item_for_trade(str(spare.item_instance_id))
	weapon.weapon_data = weapon.weapon_data.duplicate(true)
	weapon.weapon_data.attachment_slots = int(weapon.weapon_data.attachment_slots) + 1
	check(not popup._has_unused_enchantments(), "equipped spells do not count as unused even with a free slot")
	inventory.add_item_from_base("scroll_water", "notice_test")
	popup.workbench.refresh()
	var wave_before := manager.finance_system.wave_counter
	await click(popup.start_button.get_global_rect().get_center())
	check(popup._enchantment_notice.visible and flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "first click shows notice and holds finance")
	check(manager.finance_system.wave_counter == wave_before, "notice does not start a wave")
	await click(popup._enchantment_notice.get_global_rect().get_center())
	check(not popup._enchantment_notice.visible and flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "clicking the notice only dismisses it")
	await click(popup.start_button.get_global_rect().get_center())
	await next_finance()
	await click(popup.start_button.get_global_rect().get_center())
	check(popup._enchantment_notice.visible, "next finance visit warns again")
	popup.start_button.grab_focus()
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.pressed = down
		window.push_input(event)
		await frames(2)
	check(not popup._enchantment_notice.visible and flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "space dismisses without activating the focused start button")
	await click(popup.start_button.get_global_rect().get_center())
	await next_finance()
	await click(popup.start_button.get_global_rect().get_center())
	var generation := popup._generation
	await click(popup._refresh.get_global_rect().get_center())
	check(not popup._enchantment_notice.visible and popup._generation == generation, "outside click dismisses without buying or rerolling")
	await click(popup.start_button.get_global_rect().get_center())
	await next_finance()
	await click(popup.start_button.get_global_rect().get_center())
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(640, 360)]:
		window.size = dimensions
		window.content_scale_size = dimensions
		await frames(20)
		var notice := popup._enchantment_notice.get_global_rect()
		var button := popup.start_button.get_global_rect()
		check(window.get_visible_rect().encloses(notice) and notice.end.y <= button.position.y - 12, "notice fits above the button at " + str(dimensions))
		var body := popup._enchantment_notice.get_child(0) as VBoxContainer
		check(body.global_position.x - notice.position.x >= 18 and notice.end.x - body.get_global_rect().end.x >= 18, "notice preserves horizontal padding")
		check(body.global_position.y - notice.position.y >= 14 and notice.end.y - body.get_global_rect().end.y >= 14, "notice preserves vertical padding")
		var message := body.get_child(0) as Label
		var hint := body.get_child(1) as Label
		check(message.tr(message.text) == "注意，有未装备的附魔法术", "warning text matches")
		check(hint.tr(hint.text) == "点击/空格关闭提示" and hint.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and hint.get_theme_color("font_color") == Color("8b9089"), "dismissal hint is gray and right aligned")
		await capture("enchantment_notice_%d" % dimensions.x)
	await click(popup.start_button.get_global_rect().get_center())
	check(not popup._enchantment_notice.visible and flow.current_state == MainFlowCoordinator.STATE_WAVE_CHALLENGE, "clicking next wave directly dismisses notice and opens challenge")
	print("FINANCE_ENCHANTMENT_NOTICE_TEST failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
