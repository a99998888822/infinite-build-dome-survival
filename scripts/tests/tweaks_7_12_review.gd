extends "res://scripts/tests/night_evacuation_test.gd"

func run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN",false)
	get_tree().root.size = Vector2i(2400,1080)
	MobileProfile.apply_to_window(get_tree().root)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	await snap("01_menu")
	if "--menu-only" in OS.get_cmdline_user_args():
		CampProgression.end_transient_session()
		get_tree().quit()
		return
	await boot()
	flow.request_esc_overlay()
	await frames(12)
	var strip := game.find_child("EscOverlay",true,false).weapon_strip as WeaponStrip
	check(strip._weapon_buttons[0].get_node_or_null("WeaponLoadCost") != null,"ESC weapons show their load cost")
	if MobileProfile.is_mobile(): strip._load_help.pressed.emit()
	else: strip._load_help.mouse_entered.emit()
	check(strip._load_help_popup.visible,"load help opens through platform interaction")
	await snap("02_load_help")
	flow.close_esc_overlay()
	await frames()
	flow.request_shared_reward_shop_popup(2)
	await frames(12)
	var rewards := game.find_child("ShopPopup",true,false) as ShopPopup
	check(not rewards._offer_cards.is_empty(),"real upgrade offers are available")
	if not rewards._offer_cards.is_empty():
		var offer: Dictionary = rewards._offer_cards[0].offer_data
		check(bool(flow.submit_shop_purchase(offer,"free").get("success",false)),"select actual upgrade reward")
	check(player._invincibility_timer >= 1.49 and player._revive_blink_active,"upgrade selection grants short invincibility and blinking")
	check(player._revive_wings == null,"upgrade protection creates no wings")
	var hp := player.current_hp
	player.take_damage(100,"review")
	check(player.current_hp == hp,"upgrade protection blocks damage")
	player._invincibility_timer = 1.35
	player._update_revive_blink()
	await snap("03_upgrade_blink")
	player._invincibility_timer = 1.50
	player._update_revive_blink()
	await snap("04_upgrade_visible")
	manager.wave_time_left = 0.0
	manager._process(0.01)
	await move_foot(evacuation.ring_center)
	evacuation.try_enter_shelter()
	for i in 120:
		await get_tree().physics_frame
		if flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP: break
	await frames(20)
	var bank := game.find_child("FinancePopup",true,false) as FinancePopup
	bank.interest_arrival.skip()
	bank.cancel_trade("review")
	bank._select_tab("enchant")
	await frames(12)
	bank._tooltip_mouse_position = bank.workbench._weapon_row.get_child(0).get_global_rect().get_center()
	bank.workbench._weapon_row.get_child(0).pressed.emit()
	await frames(12)
	if MobileProfile.is_mobile(): check(bank._tooltip.visible,"mobile weapon tap shows detailed stats")
	await snap("05_enchant_weapon_details")
	var outside := InputEventScreenTouch.new()
	outside.pressed = true
	outside.position = Vector2(20,150)
	bank.workbench._input(outside)
	check(not bank._tooltip.visible,"outside touch dismisses weapon details")
	await snap("06_enchant_dismissed")
	var loadout := flow.get_bound_loadout()
	player.modifier_stack.set_base_stat("load_capacity",100)
	if not loadout.has_weapon("weapon_camp_dagger"):
		check(loadout.equip_weapon("weapon_camp_dagger"),"add reserve fixture")
	var reserve := loadout.get_weapon_instance("weapon_camp_dagger")
	loadout.weapon_instances.erase(reserve)
	loadout.reserve_weapons.append(reserve)
	player.modifier_stack.set_base_stat("load_capacity",loadout.get_total_load_cost())
	loadout.auto_equip_available_reserves()
	check(loadout.reserve_weapons.has(reserve),"auto equip keeps overweight reserves stored")
	player.modifier_stack.set_base_stat("load_capacity",100)
	flow._pending_wave_start_after_finance = true
	check(flow._start_prepared_wave(),"start next battle after shop")
	check(loadout.is_weapon_equipped(reserve.weapon_id) and not loadout.reserve_weapons.has(reserve),"auto equip moves fitting reserve into equipped weapons")
	player._invincibility_timer = 0.0
	player._update_revive_blink()
	check(not player._revive_blink_active and is_equal_approx(player.sprite.self_modulate.a,1.0),"upgrade blink clears when protection expires")
	print("TWEAKS_7_12 checks=",checks," failures=",failures.size())
	flow.enter_start_page()
	CampProgression.end_transient_session()
	game.queue_free()
	await frames()
	get_tree().quit(0 if failures.is_empty() else 1)

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
