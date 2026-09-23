extends Node

class RejectingPayout extends WaveManager:
	func apply_gold_delta(_delta: int, _reason: String = "") -> bool:
		return false

# Run in a project copy with isolated user data; optional -- --capture-dir=<absolute path>.
var failures := 0
var capture_dir := ""
var flow: MainFlowCoordinator
var player: PlayerController
var loadout: WeaponLoadout
var manager: WaveManager
var popup: FinancePopup
@onready var root: Window = get_tree().root


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(90).timeout
	push_error("FINANCE_TEST_TIMEOUT")
	get_tree().quit(99)


func frames(count: int = 5) -> void:
	for _index in count: await get_tree().process_frame


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition: failures += 1


func modifier(stat: String, value: float) -> void:
	player.add_runtime_modifier({"id": "finance_test_" + stat, "source_type": "test", "source_id": "finance_test", "target_scope": "player", "stat": stat, "operation": "add_flat", "value": value, "duration": -1, "stack_rule": "replace_same_source"})


func capture(name: String) -> void:
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))


func _run() -> void:
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	flow = game.get_main_flow_coordinator()
	var starting: Array[String] = ["weapon_void_blade"]
	flow.enter_battle_selection("character_void_hunter", starting)
	await frames()
	check(flow.confirm_character_selection(), "start real battle")
	await frames(8)
	player = flow.get_bound_player()
	loadout = flow.get_bound_loadout()
	var hud := game.find_child("HUD", true, false) as BattleHud
	manager = hud._wave_manager
	manager.set_process(false)
	manager.clear_enemies()
	player.set("_invincibility_timer", 1000.0)
	modifier("load_capacity", 100)
	manager.apply_gold_delta(500, "test")
	flow.finish_current_wave()
	await frames(20)
	popup = game.find_child("FinancePopup", true, false) as FinancePopup
	check(flow.current_state == flow.STATE_FINANCE_POPUP and popup.visible, "wave end opens unified page")
	check(popup.shop_grid.offers.size() >= 3, "paid shelf minimum three")
	await get_tree().create_timer(.3).timeout
	await capture("01_purchase_1152")
	await _test_finance_esc_round_trip(game)
	_test_withdrawal_limits()
	_test_bank_and_trades()
	await frames(10)
	popup._select_tab("enchant")
	await frames(10)
	await _test_inventory_inspection()
	await capture("02_enchantment_1152")
	popup._open_sale("weapon", "weapon_plasma_cannon")
	await frames()
	await capture("03_sale_confirmation")
	popup._sale_layer.hide()
	await _test_large_shelf()
	await _test_finance_esc_round_trip(game)
	popup._open_sale("weapon", "weapon_plasma_cannon")
	await _press_escape()
	check(not popup._sale_layer.visible and flow.current_state == flow.STATE_FINANCE_POPUP, "Escape cancels sale confirmation before opening inspection")
	await _test_resolutions(hud)
	_test_wave_start_and_free_rewards()
	await frames(10)
	var overlay := game.find_child("EscOverlay", true, false) as EscOverlay
	flow.request_esc_overlay()
	await frames(10)
	check(not overlay.weapon_strip._attachment_editing_enabled, "ESC weapon strip read only")
	for child in overlay.item_grid.get_children():
		if child is ItemInventoryCard: check(not child.drag_enabled, "ESC item drag disabled")
	check(not loadout.request_manual_attachment("weapon_void_blade", str(player.item_inventory.get_items()[0].get("item_instance_id", ""))), "manual attachment rejected outside finance")
	flow.close_esc_overlay()
	print("FINANCE_PREPARATION_DONE failures=", failures)
	game.queue_free()
	await frames()
	get_tree().quit(failures)


func _press_escape(echo: bool = false) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	key.echo = echo
	Input.parse_input_event(key)
	await frames(3)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	await frames(3)


func _test_finance_esc_round_trip(game: GameRoot) -> void:
	var overlay := game.find_child("EscOverlay", true, false) as EscOverlay
	var bank_used := manager.finance_system.manual_operation_used
	var wave := flow.current_wave_index
	var gold := manager.current_gold
	var principal := manager.finance_system.principal
	var generation := int(flow.get_preparation_payload().get("offer_generation", -1))
	var shelf := JSON.stringify(flow._preparation_offers)
	popup.amount_input.text = "77"
	for tab in ["shop", "enchant"]:
		popup._select_tab(tab)
		await frames()
		popup.shop_grid.scroll.scroll_vertical = 200
		await frames()
		var scroll_before := popup.shop_grid.scroll.scroll_vertical
		var selected_weapon := popup.workbench.selected_weapon_id
		var selected_item := popup.workbench.selected_item_id
		popup.amount_input.grab_focus()
		popup._tooltip.show()
		await _press_escape()
		check(flow.current_state == flow.STATE_ESC_OVERLAY and overlay.visible and not popup.visible, "Escape opens inspection from finance despite amount focus " + tab)
		var list_panel := overlay.center_container.get_node("RelicPanel") as Control
		check(list_panel.get_global_rect().end.y <= root.get_visible_rect().end.y and overlay.center_container.size.y <= 461.0, "inspection panel stays inside viewport " + tab)
		check(not overlay.weapon_strip._attachment_editing_enabled and not flow.submit_finance_operation("deposit", 1).success, "inspection is read only and hides finance actions " + tab)
		if tab == "shop":
			await _press_escape()
		else:
			overlay.back_button.pressed.emit()
			await frames(5)
		check(flow.current_state == flow.STATE_FINANCE_POPUP and popup.visible and bool(root.get_node("GameGlobal").get_runtime_flag("battle_runtime_paused", false)), "inspection returns to paused finance " + tab)
		check(popup._active_tab == tab and popup.amount_input.text == "77" and popup.shop_grid.scroll.scroll_vertical == scroll_before and popup.workbench.selected_weapon_id == selected_weapon and popup.workbench.selected_item_id == selected_item, "finance widgets and scroll survive inspection " + tab)
		check(manager.finance_system.manual_operation_used == bank_used and manager.current_gold == gold and manager.finance_system.principal == principal and flow.current_wave_index == wave and int(flow.get_preparation_payload().get("offer_generation", -1)) == generation and JSON.stringify(flow._preparation_offers) == shelf, "inspection preserves transactions and exact shelf " + tab)
		await _press_escape(true)
		check(flow.current_state == flow.STATE_FINANCE_POPUP, "Escape key repeat does not reopen inspection")
	popup.amount_input.release_focus()
	popup._select_tab("shop")


func _test_withdrawal_limits() -> void:
	var finance := manager.finance_system
	var initial_principal := finance.principal
	var initial_gold := manager.current_gold
	var had_principal := finance.has_principal_ever
	finance.principal = 120
	popup.configure(flow.get_preparation_payload())
	popup._choose_bank_action("withdraw")
	for amount in [121, 999999999999]:
		popup.amount_input.text = str(amount)
		popup.amount_input.text_changed.emit(popup.amount_input.text)
		check(popup.bank_confirm.disabled, "overdraft disables confirmation " + str(amount))
		popup.amount_input.text_submitted.emit(popup.amount_input.text)
		var result := flow.submit_finance_operation("withdraw", amount)
		check(not result.success and result.reason == "amount_exceeds_principal", "authoritative overdraft rejected " + str(amount))
		check(finance.principal == 120 and manager.current_gold == initial_gold and not finance.manual_operation_used, "overdraft preserves money and banking opportunity")
	var stale := flow.get_preparation_payload().duplicate(true)
	stale["principal"] = 1000
	popup.configure(stale)
	popup.amount_input.text = "500"
	popup._submit_bank()
	check(finance.principal == 120 and manager.current_gold == initial_gold and not finance.manual_operation_used, "stale displayed balance cannot mint gold")
	popup.configure(flow.get_preparation_payload())
	popup.amount_input.text = "120"
	popup.amount_input.text_changed.emit("120")
	check(not popup.bank_confirm.disabled, "exact principal can be withdrawn")
	popup._submit_bank()
	check(finance.principal == 0 and manager.current_gold == initial_gold + 120 and finance.manual_operation_used, "withdrawal conserves total gold and principal")
	popup._submit_bank()
	check(manager.current_gold == initial_gold + 120 and finance.principal == 0, "repeated withdrawal cannot mint gold")
	# Restore the fixture before the existing deposit/trading sequence.
	finance.principal = initial_principal
	finance.has_principal_ever = had_principal
	finance.manual_operation_used = false
	finance.last_manual_operation.clear()
	manager.apply_gold_delta(initial_gold - manager.current_gold, "test_restore")
	popup.configure(flow.get_preparation_payload())
	popup.amount_input.clear()
	popup._choose_bank_action("deposit")


func _test_inventory_inspection() -> void:
	var spare := player.item_inventory.add_item_from_base("scroll_fire", "test")
	var spare_id := str(spare.get("item_instance_id", ""))
	popup.workbench.refresh()
	await frames()
	var visible_ids: Array[String] = []
	var target: EnchantmentInventoryCard
	for card in popup.workbench._inventory.get_children():
		if not card is EnchantmentInventoryCard: continue
		visible_ids.append(str(card.item_instance.get("item_instance_id", "")))
		if str(card.item_instance.get("item_instance_id", "")) == spare_id: target = card
	var unequipped_ids: Array[String] = []
	for item in player.item_inventory.get_items():
		if str(item.get("equipped_weapon_id", "")).is_empty(): unequipped_ids.append(str(item.get("item_instance_id", "")))
	check(visible_ids == unequipped_ids and target != null, "backpack shows only unequipped instances")
	if target == null: return
	popup._tooltip.hide()
	await _hover_control(target)
	check(not popup._tooltip.visible, "card hover does not show enchantment details")
	await _hover_control(target._inspect)
	check(popup._tooltip.visible and popup._tooltip_text.text.contains(str(spare.get("display_name", ""))), "magnifier hover shows exact enchantment details")
	check(popup._tooltip_text.size.y >= popup._tooltip_text.get_content_height(), "enchantment details fit without clipping")
	await capture("02_enchantment_detail")
	await _hover_control(popup._title)
	check(not popup._tooltip.visible, "leaving magnifier hides details")
	var weapon := loadout.get_weapon_instance(popup.workbench.selected_weapon_id)
	check(flow.submit_enchantment_operation("attach", weapon.weapon_id, spare_id).success, "equip backpack instance")
	var still_in_backpack := false
	for card in popup.workbench._inventory.get_children():
		if card is EnchantmentInventoryCard and str(card.item_instance.get("item_instance_id", "")) == spare_id: still_in_backpack = true
	check(not still_in_backpack, "equipping immediately removes instance from backpack")
	check(flow.submit_enchantment_operation("detach", weapon.weapon_id, spare_id).success, "unequip returns instance to backpack")
	var returned := false
	for card in popup.workbench._inventory.get_children():
		if card is EnchantmentInventoryCard and str(card.item_instance.get("item_instance_id", "")) == spare_id: returned = true
	check(returned, "detached instance is visible again")


func _hover_control(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await frames(3)


func _test_bank_and_trades() -> void:
	var before_wave := flow.current_wave_index
	var failed := flow.submit_finance_operation("deposit", manager.current_gold + 1)
	check(not failed.success and not manager.finance_system.manual_operation_used, "failed bank attempt keeps opportunity")
	popup.amount_input.text = "50"
	popup.bank_confirm.pressed.emit()
	check(manager.finance_system.manual_operation_used and flow.current_state == flow.STATE_FINANCE_POPUP and flow.current_wave_index == before_wave, "UI deposit locks bank without starting wave")
	check(not popup._bank_form.visible and popup._receipt.visible and popup.portrait.expression == 3, "receipt and small deposit smile")
	check(not flow.submit_finance_operation("withdraw", 1).success, "cannot withdraw after depositing")
	check(loadout.equip_weapon("weapon_plasma_cannon"), "equip second weapon fixture")
	for existing in loadout.get_weapon_instance("weapon_void_blade").get_attached_item_instances():
		flow.submit_enchantment_operation("detach", "weapon_void_blade", str(existing.get("item_instance_id", "")))
	var inv := player.item_inventory
	var fire := inv.add_item_from_base("scroll_fire", "test")
	var fire_id := str(fire.get("item_instance_id", ""))
	var same_type := inv.add_item_from_base("scroll_fire", "test")
	var same_type_id := str(same_type.get("item_instance_id", ""))
	var cannon := loadout.get_weapon_instance("weapon_plasma_cannon")
	check(flow.submit_enchantment_operation("attach", cannon.weapon_id, fire_id).success, "attach selected instance to second weapon")
	check(not flow.get_inventory_sale_quote("enchantment", fire_id).success, "equipped enchantment cannot be sold")
	check(flow.submit_enchantment_operation("attach", "weapon_void_blade", fire_id).success, "transfer across weapons")
	check(str(inv.find_item(fire_id).get("equipped_weapon_id", "")) == "weapon_void_blade" and cannon.get_attached_item_instances().is_empty(), "transfer updates both ownership lists")
	check(flow.submit_enchantment_operation("detach", "weapon_void_blade", fire_id).success, "detach selected instance")
	flow.submit_enchantment_operation("attach", cannon.weapon_id, fire_id)
	var water := inv.add_item_from_base("scroll_water", "test")
	var water_id := str(water.get("item_instance_id", ""))
	flow.submit_enchantment_operation("attach", cannon.weapon_id, water_id)
	check(flow.submit_enchantment_operation("move", cannon.weapon_id, water_id, 0).success, "reorder works when every slot is occupied")
	check(str(cannon.get_attached_item_instances()[0].get("item_instance_id", "")) == water_id and str(inv.find_item(water_id).get("equipped_weapon_id", "")) == cannon.weapon_id, "slot order and ownership stay consistent")
	check(not flow.submit_enchantment_operation("move", cannon.weapon_id, water_id, 9).success and str(cannon.get_attached_item_instances()[0].get("item_instance_id", "")) == water_id, "invalid reorder keeps prior order")
	check(not flow.submit_enchantment_operation("attach", cannon.weapon_id, same_type_id).success and str(inv.find_item(same_type_id).get("equipped_weapon_id", "")).is_empty(), "full slots preserve original inventory")
	var quote := flow.get_inventory_sale_quote("weapon", cannon.weapon_id)
	var gold_before := manager.current_gold
	var rejecting_manager := RejectingPayout.new()
	flow._bound_wave_manager = rejecting_manager
	var failed_sale := flow.submit_inventory_sale("weapon", cannon.weapon_id, str(quote.quote_token))
	flow._bound_wave_manager = manager
	check(not failed_sale.success and loadout.get_weapon_instance(cannon.weapon_id) == cannon and inv.find_item(fire_id).equipped_weapon_id == cannon.weapon_id and manager.current_gold == gold_before, "failed weapon payout rolls back complete transaction")
	var taken := loadout.take_weapon_for_trade(cannon.weapon_id)
	loadout.restore_traded_weapon(taken, 1)
	check(loadout.get_weapon_instance(cannon.weapon_id) == cannon and inv.find_item(fire_id).equipped_weapon_id == cannon.weapon_id, "weapon removal rollback preserves identity and attachments")
	var sold := flow.submit_inventory_sale("weapon", cannon.weapon_id, str(quote.quote_token))
	check(sold.success and manager.current_gold == gold_before + int(quote.total), "weapon sale pays carried gold")
	check(str(inv.find_item(fire_id).get("equipped_weapon_id", "")).is_empty() and str(inv.find_item(water_id).get("equipped_weapon_id", "")).is_empty(), "sold weapon returns all enchantments")
	check(not flow.submit_inventory_sale("weapon", cannon.weapon_id, str(quote.quote_token)).success, "duplicate sale rejected")
	check(not flow.get_inventory_sale_quote("weapon", "weapon_void_blade").success, "last weapon protected")
	loadout.equip_weapon("weapon_plasma_cannon")
	check(not flow.submit_inventory_sale("weapon", "weapon_plasma_cannon", str(quote.quote_token)).success, "stale quote cannot sell replacement instance")
	var item_quote := flow.get_inventory_sale_quote("enchantment", same_type_id)
	flow._bound_wave_manager = rejecting_manager
	var failed_item_sale := flow.submit_inventory_sale("enchantment", same_type_id, str(item_quote.quote_token))
	flow._bound_wave_manager = manager
	check(not failed_item_sale.success and not inv.find_item(same_type_id).is_empty(), "failed item payout restores exact instance")
	rejecting_manager.free()
	var removed_item := inv.take_unequipped_item_for_trade(same_type_id)
	inv.restore_traded_item(removed_item)
	check(inv.find_item(same_type_id) == removed_item, "item rollback preserves exact rolled instance")
	check(flow.submit_inventory_sale("enchantment", same_type_id, str(item_quote.quote_token)).success and not inv.find_item(fire_id).is_empty() and inv.find_item(same_type_id).is_empty(), "sell one enchantment without removing same-type others")
	check(manager.finance_system.manual_operation_used, "buy sell and enchant never reset bank lock")
	cannon = loadout.get_weapon_instance("weapon_plasma_cannon")
	cannon.trade_base_basis = 1
	check(int(flow.get_inventory_sale_quote("weapon", cannon.weapon_id).total) == 0, "discounted weapon cannot resell above actual cost")
	cannon.battle_title = {"id": "test_title", "display_name": "Test title", "sale_bonus": 9}
	check(int(flow.get_inventory_sale_quote("weapon", cannon.weapon_id).total) == 9, "title bonus extension contributes to quote")
	cannon.battle_title.clear()
	cannon.trade_base_basis = -1
	flow.submit_enchantment_operation("attach", cannon.weapon_id, fire_id)
	flow.submit_enchantment_operation("attach", "weapon_void_blade", water_id)
	popup.workbench.selected_weapon_id = "weapon_plasma_cannon"
	popup.workbench.refresh()
	for amount_action in [["withdraw", 1, 200, 1], ["withdraw", 100, 200, 2], ["deposit", 1, 200, 3], ["deposit", 100, 200, 4]]:
		popup.portrait.react(amount_action[0], amount_action[1], amount_action[2])
		check(popup.portrait.expression == amount_action[3], "bank expression " + str(amount_action[3]))


func _test_large_shelf() -> void:
	modifier("shop_offer_count_bonus", 997)
	manager.apply_gold_delta(5000, "test")
	check(flow.request_shop_refresh().success, "refresh after banking remains available")
	await frames(15)
	var grid := popup.shop_grid
	check(grid.offers.size() == 1000, "one thousand goods without count cap")
	var ids := {}
	for offer in grid.offers: ids[offer.offer_id] = true
	check(ids.size() == 1000, "all shelf slots have unique identity")
	check(grid._pool.size() < 40, "only visible shop cards instantiated")
	for card in grid._pool:
		if card.visible: check(card._icon.texture != null, "visible goods retain actual item icons")
	popup._select_tab("shop")
	await frames(5)
	grid.scroll.scroll_vertical = 1000000
	await frames(10)
	var last_visible := false
	for card in grid._pool:
		if card.visible and int(card.get_meta("offer_index", -1)) == 999:
			last_visible = grid.scroll.get_global_rect().intersects(card.get_global_rect())
	check(last_visible, "last good reachable by scroll")
	print("SHOP_GEOMETRY scroll=", grid.scroll.scroll_vertical, " columns=", grid._columns, " viewport=", grid.scroll.get_global_rect(), " content=", grid.canvas.size, " pool=", grid._pool.size())
	var scroll_before := grid.scroll.scroll_vertical
	var last: Dictionary = grid.offers[999]
	var gold_before := manager.current_gold
	popup._buy(last)
	await frames()
	check(bool(last.get("purchased", false)) and manager.current_gold == gold_before - int(last.shop_cost), "UI purchase uses authoritative price")
	check(grid.scroll.scroll_vertical == scroll_before and grid.offers.size() == 1000, "purchase preserves slot and scroll")
	check(not flow.submit_shop_purchase(last, "shop").success, "duplicate purchase rejected")
	popup._select_tab("enchant")
	await frames()
	popup._select_tab("shop")
	await frames()
	check(grid.scroll.scroll_vertical == scroll_before, "tab switching preserves scroll")
	flow.submit_finance_operation("withdraw", 1)
	await frames()
	check(grid.scroll.scroll_vertical == scroll_before, "bank refresh preserves scroll")
	await capture("04_large_shelf_bottom")
	check(flow.request_shop_refresh().success, "refresh works after exhausting distinct catalog")
	await frames(10)
	check(grid.offers.size() == 1000 and grid.scroll.scroll_vertical == 0, "refresh resets scroll and retains bonus count")


func _test_resolutions(hud: BattleHud) -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(640, 360), Vector2i(1152, 648)]:
		root.size = resolution
		root.content_scale_size = resolution
		await frames(20)
		for tab in ["shop", "enchant", "bank"]:
			if tab == "bank" and not popup._compact: continue
			popup._select_tab(tab)
			await frames(10)
			var frame := popup.main_panel.get_global_rect()
			check(root.get_visible_rect().encloses(frame) and frame.encloses(popup.start_button.get_global_rect()), "frame and start fit " + str(resolution) + tab)
			if tab == "shop":
				check(not popup._refresh.get_global_rect().intersects(popup.start_button.get_global_rect()), "refresh clears start button " + str(resolution))
			if tab == "enchant":
				popup._enchant_scroll.scroll_vertical = 99999
				await frames()
				check(popup._enchant_scroll.get_global_rect().intersects(popup.workbench._apply.get_global_rect()), "enchant controls reachable " + str(resolution))
				for card in popup.workbench._inventory.get_children():
					if not card is EnchantmentInventoryCard: continue
					await _hover_control(card._inspect)
					check(popup._tooltip.visible and popup._tooltip_text.size.y >= popup._tooltip_text.get_content_height(), "magnifier details fit " + str(resolution))
					await capture("detail_" + str(resolution.x))
					await _hover_control(popup._title)
					break
				popup._enchant_scroll.scroll_vertical = 0
			await capture("layout_" + str(resolution.x) + "_" + tab)
		if resolution.x < 1000:
			hud._on_drawer_toggle_pressed()
			await frames()
			check(not popup.main_panel.visible, "compact drawer gets clear inspection space")
			hud._on_drawer_toggle_pressed()
			await frames()
			check(popup.main_panel.visible, "return from drawer preserves preparation")


func _test_wave_start_and_free_rewards() -> void:
	var principal_before := manager.finance_system.principal
	manager.add_relic("relic_piggy_bank")
	check(manager.finance_system.principal == principal_before, "new wave-start relic waits for start")
	var wave_before := manager.finance_system.wave_counter
	popup.start_button.pressed.emit()
	check(flow.current_state == flow.STATE_WAVE_COMBAT and manager.finance_system.wave_counter == wave_before + 1 and manager.finance_system.principal > principal_before, "start button runs newly acquired wave-start relic once")
	check(manager.finance_system.wave_start_deposit_amount == 50, "preparation deposit survives real start")
	flow.close_finance_popup()
	check(manager.finance_system.wave_counter == wave_before + 1, "double start rejected")
	flow.request_shared_reward_shop_popup(2, "test")
	check(flow.current_state == flow.STATE_SHARED_REWARD_SHOP_POPUP and not popup.visible, "free reward retains separate screen")
	flow.close_shared_reward_shop_popup()
	check(flow.current_state == flow.STATE_WAVE_COMBAT, "free reward resumes same combat")
