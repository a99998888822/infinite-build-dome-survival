extends Node
## Runs production UI consumers with reviewed relics in a transient game.
var keys: Array = FinanceUIStyle.NATIVE_RELIC_ICONS.duplicate()
var failures := 0
var output := ""
var game: GameRoot
var captures: Array[Dictionary] = []
@onready var root: Window = get_tree().root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--relic-ids="): keys = Array(argument.trim_prefix("--relic-ids=").split(",", false))
	assert(not keys.is_empty())
	for key in keys: assert(key in FinanceUIStyle.NATIVE_RELIC_ICONS)
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(90).timeout
	push_error("RELIC_ART_TEST_TIMEOUT")
	get_tree().quit(99)


func frames(count: int = 8) -> void:
	for _i in count: await get_tree().process_frame


func check(value: bool, note: String) -> void:
	print("PASS " if value else "FAIL ", note)
	if not value: failures += 1


func _run() -> void:
	seed(20260929)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	root.unfocusable = true
	root.always_on_top = false
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	var flow := game.get_main_flow_coordinator()
	var starting: Array[String] = ["weapon_void_blade"]
	flow.enter_battle_selection("character_void_hunter", starting)
	await frames()
	check(flow.confirm_character_selection(), "entered real battle")
	await frames(12)
	var hud := game.find_child("HUD", true, false) as BattleHud
	hud._wave_manager.set_process(false)
	hud._wave_manager.clear_enemies()
	var player := flow.get_bound_player()
	player.set_physics_process(false)
	player.set("_invincibility_timer", 1000.0)
	flow.get_bound_loadout().set_process(false)
	hud._wave_manager.apply_gold_delta(500, "art_test")
	for key: String in keys: player.add_relic(key)
	var esc := game.find_child("EscOverlay", true, false) as EscOverlay
	esc.configure(player, flow.get_bound_loadout())
	esc.show_overlay()
	await get_tree().create_timer(0.6).timeout
	# Freeze rarity tint only in this fixture for exact source-pixel comparisons.
	for cell in esc._relic_pulse_tweens:
		esc._relic_pulse_tweens[cell].kill()
		cell.modulate = Color.WHITE
	await capture("relic_list", esc)
	root.size = Vector2i(1024, 576)
	root.content_scale_size = root.size
	await frames(12)
	await capture("relic_list_1024x576", esc)
	esc.hide_overlay()
	await get_tree().create_timer(0.3).timeout
	flow.request_battle_utility("encyclopedia")
	await frames()
	var utility := game.find_child("BattleUtilityOverlay", true, false) as BattleUtilityOverlay
	check(utility != null and utility.visible, "real encyclopedia opened")
	for key: String in keys:
		var index := -1
		for i in utility._records.size():
			if str(utility._records[i].get("id", "")) == key: index = i
		check(index >= 0, "encyclopedia contains " + key)
		if index >= 0:
			utility._show_entry(index)
			await capture("encyclopedia_" + key, utility)
	utility._category.select(1)
	utility._refresh_entries()
	check(utility._entry_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "encyclopedia restores legacy weapon layout")
	flow.close_battle_utility()
	flow.finish_current_wave()
	await frames(25)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	popup.interest_arrival.stop()
	popup.portrait.set_process(false)
	popup.portrait._elapsed = 0.0
	popup.portrait.queue_redraw()
	popup.cancel_trade("art_test")
	popup._select_tab("shop")
	var offers: Array = []
	for key: String in keys:
		var item := DataRegistry.get_record("relics", key).duplicate(true)
		item.merge({"offer_type": "relic", "target_id": key, "shop_cost": 10, "purchased": false}, true)
		offers.append(item)
	# Visual fixture only: offers are not registered for purchases or persisted.
	popup.shop_grid.set_offers(offers, true)
	for viewport_size in [Vector2i(1152, 648), Vector2i(1024, 576)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		popup.shop_grid.scroll.scroll_vertical = 0
		await frames(12)
		await capture("shop_%dx%d" % [viewport_size.x, viewport_size.y], popup.shop_grid)
		var shop_bar := popup.shop_grid.scroll.get_v_scroll_bar()
		popup.shop_grid.scroll.scroll_vertical = int((shop_bar.max_value - shop_bar.page) * 0.5)
		await frames(8)
		await capture("shop_middle_%dx%d" % [viewport_size.x, viewport_size.y], popup.shop_grid)
		popup.shop_grid.scroll.scroll_vertical = 10000
		await frames(8)
		await capture("shop_bottom_%dx%d" % [viewport_size.x, viewport_size.y], popup.shop_grid)
		for pooled in popup.shop_grid._pool:
			if not pooled.visible: continue
			check(pooled._icon.size == pooled._icon.texture.get_size() * 0.5, "shop relic draws at half size")
			check(pooled._icon_frame.get_global_rect().encloses(pooled._icon.get_global_rect()), "shop parent contains centered half-size icon")
			check(pooled._name_label.global_position.x >= pooled._icon.get_global_rect().end.x + 10, "shop title clear of icon")
			check(pooled.size.y <= popup.shop_grid._card_height, "shop card fits virtual row")
	var card: PreparationOfferCard = popup.shop_grid._pool[0]
	var old := DataRegistry.get_record("weapons", "weapon_void_blade").duplicate(true)
	old["offer_type"] = "new_weapon"
	card.configure(old, "", 500)
	check(card._icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and card._icon.custom_minimum_size == Vector2.ZERO, "pooled card restores legacy weapon size")
	check(card._icon_frame.custom_minimum_size == Vector2(36, 36), "pooled parent restores legacy size")
	card.configure(offers[0], "", 500)
	check(card._icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and card._icon.size == Vector2(32, 32), "pooled card returns to half-size relic")
	popup.shop_grid.set_offers([old], true)
	await frames()
	check(popup.shop_grid._card_height == VirtualShopGrid.CARD_HEIGHT, "legacy-only shop restores row height")
	popup.shop_grid.set_offers(offers, true)
	var steps: Array = []
	for i in keys.size():
		var item := DataRegistry.get_record("relics", keys[i])
		steps.append({"icon": item.icon, "label": item.display_name, "kind": "bonus", "amount": 10, "target": (i + 1) * 10})
	var receipt := popup.interest_arrival
	receipt.sound_enabled = false
	receipt.present({"wave": 1, "steps": steps, "total": steps.size() * 10, "combat": 10, "special": false})
	receipt.seek(receipt.duration)
	await frames()
	for row: Control in receipt._row_nodes: check(row.size.y >= 64, "receipt row accommodates native icon")
	receipt._scroll.scroll_vertical = 10000
	await frames()
	var bar := receipt._scroll.get_v_scroll_bar()
	check(is_equal_approx(bar.value, maxf(0, bar.max_value - bar.page)), "receipt last row reachable")
	await capture("receipt_1024x576", receipt)
	receipt.stop()
	# Exercise the actual reward scene at its narrowest layout, including reuse.
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var reward := load("res://scenes/ui/rewards/reward_option.tscn").instantiate() as RewardOption
	layer.add_child(reward)
	reward.position = Vector2(420, 130)
	reward.set_layout_width(160)
	reward.set_available_size(160, 200)
	for offer: Dictionary in offers:
		reward.configure(offer)
		reward.size = Vector2(160, 200)
		await frames()
		check(reward.icon_texture.size == Vector2(48, 48), "floating reward relic stays at forty-eight pixels")
		reward._stop_icon_float()
		check(reward.icon_texture.size == Vector2(48, 48), "stopping float preserves enlarged reward icon")
		check(reward.icon_frame.get_global_rect().encloses(reward.icon_texture.get_global_rect()), "small reward frame contains centered enlarged icon")
		check(reward.select_button.get_global_rect().end.y <= reward.get_global_rect().end.y, "reward action inside card")
		await capture("reward_" + str(offer.target_id), reward)
	reward.configure(old)
	check(reward.icon_frame.custom_minimum_size.y == 50, "reward restores legacy small frame")
	check(is_equal_approx(reward.icon_texture.anchor_left, 0.1) and is_equal_approx(reward.icon_texture.anchor_right, 0.9) and reward.icon_texture.custom_minimum_size == Vector2.ZERO, "reward reuse restores weapon inset without relic minimum")
	layer.queue_free()
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("capture_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"failures": failures, "captures": captures}, "\t") + "\n")
	print("RELIC_ART_TEST_DONE failures=", failures)
	game.queue_free()
	await frames(3)
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(failures)


func collect_icons(node: Node, found: Array[TextureRect]) -> void:
	if node is TextureRect:
		var rect := node as TextureRect
		if rect.texture != null and rect.texture.resource_path.get_file().get_basename() in keys:
			found.append(rect)
	for child in node.get_children(): collect_icons(child, found)


func capture(label: String, scope: Node) -> void:
	await frames(3)
	var found: Array[TextureRect] = []
	collect_icons(scope, found)
	check(not found.is_empty(), "production icons present: " + label)
	var icons: Array = []
	for rect in found:
		var list_icon := label.begins_with("relic_list") or label.begins_with("shop_") or label.begins_with("reward_")
		var icon_scale := 0.75 if label.begins_with("reward_") else (0.5 if list_icon else 1.0)
		var extent := rect.texture.get_size() * icon_scale
		var mode := TextureRect.STRETCH_KEEP_ASPECT_CENTERED if list_icon else TextureRect.STRETCH_KEEP_CENTERED
		check(rect.texture.get_size() == Vector2(64, 64) and rect.stretch_mode == mode and rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel filter and display mode: " + rect.texture.resource_path.get_file())
		check(rect.size == extent if list_icon else rect.size.x >= extent.x and rect.size.y >= extent.y, "slot fits expected icon size")
		var origin := rect.get_global_rect().get_center() - extent * 0.5
		var drawn := Rect2(origin, extent)
		if not fully_visible(rect, drawn): continue
		icons.append({"path": rect.texture.resource_path, "origin": [origin.x, origin.y], "size": [extent.x, extent.y]})
	check(not icons.is_empty(), "fully visible icons: " + label)
	if DisplayServer.get_name() != "headless" and not output.is_empty():
		await RenderingServer.frame_post_draw
		check(not root.always_on_top, "not topmost")
		root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	captures.append({"name": label, "icons": icons})


func fully_visible(rect: Control, drawn: Rect2) -> bool:
	if not rect.is_visible_in_tree() or not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(drawn): return false
	var parent := rect.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents and not parent.get_global_rect().encloses(drawn): return false
		parent = parent.get_parent()
	return true
