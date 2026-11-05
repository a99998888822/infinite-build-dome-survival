extends Node
## Phones skip the 1920x1080 bank composition and use the compact popup instead.
## This fixture guards that the popup fits the lifted viewport and stays tappable.

var checks := 0
var failures := 0
var popup: FinancePopup
var flow: MainFlowCoordinator


func _ready() -> void:
	_run.call_deferred()


func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + note)


func frames(count: int = 6) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start live run")
	await frames()
	var manager := flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.apply_gold_delta(20 - manager.current_gold, "test")
	flow.finish_current_wave()
	await frames(14)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.is_visible_in_tree(), "bank popup opens")
	if popup == null:
		_finish()
		return

	var viewport := get_tree().root.get_visible_rect()
	var expect_popup := not FinanceSceneLayout.supports(viewport.size)
	check(expect_popup if MobileProfile.is_mobile() else not expect_popup, "bank layout matches the platform")
	check(viewport.encloses(popup.get_global_rect()), "popup stays inside the viewport")

	# Every interactive anchor has to be on screen and tappable.
	for control in [popup.start_button, popup._tabs, popup.shop_grid, popup._refresh]:
		var button := control as Control
		check(button != null and button.is_visible_in_tree(), "control visible: " + ("start" if button == null else str(button.name)))
		if button != null:
			check(viewport.encloses(button.get_global_rect()), "control inside the viewport: " + str(button.name))

	# A phone has no room for text that overflows its own panel.
	var clipped: Array[String] = []
	for node in popup.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.is_visible_in_tree() or label.text.is_empty():
			continue
		if label.get_combined_minimum_size().x > label.size.x + 1.0:
			clipped.append("%s(%s)" % [label.name, label.text.left(12)])
	check(clipped.is_empty(), "no label overflows its box: " + ", ".join(clipped))

	# The enchantment tab shares the popup; its workbench has to fit as well.
	popup._select_tab("enchant")
	await frames(8)
	check(popup.workbench.is_visible_in_tree(), "workbench visible on the enchant tab")
	check(viewport.encloses(popup._enchant_scroll.get_global_rect()), "enchantment scroll stays inside the viewport")
	var enchant_clipped := 0
	for node in popup.workbench.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.is_visible_in_tree() or label.text.is_empty():
			continue
		if label.get_combined_minimum_size().x > label.size.x + 1.0:
			enchant_clipped += 1
	check(enchant_clipped == 0, "no workbench label overflows its box (%d)" % enchant_clipped)

	_finish()


func _finish() -> void:
	print("MOBILE_BANK_TEST checks=%d failures=%d mobile=%s" % [checks, failures, MobileProfile.is_mobile()])
	get_tree().quit(0)
