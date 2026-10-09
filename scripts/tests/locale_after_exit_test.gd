extends Node
## Regression for retained reward UI after a battle is destroyed.

var checks := 0
var failures := 0
var game: GameRoot
var flow: MainFlowCoordinator
var menu: MainMenuUIController
var shop: ShopPopup
var capture_dir := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(120).timeout
	push_error("LOCALE_AFTER_EXIT_TEST_TIMEOUT")
	get_tree().quit(99)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func frames(count := 6) -> void:
	for index in count:
		await get_tree().process_frame


func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	menu = game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	flow = game.get_main_flow_coordinator()
	shop = game.find_child("ShopPopup", true, false) as ShopPopup
	for exit_mode in ["reward_open", "reward_closed", "flow_reset"]:
		await _exercise_run(exit_mode)
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	print("LOCALE_AFTER_EXIT_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _exercise_run(exit_mode: String) -> void:
	menu.start_battle_button.pressed.emit()
	await frames()
	if exit_mode == "reward_closed": menu._on_character_selected("character_capitalist")
	menu.character_confirm_button.pressed.emit()
	await frames(20)
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	check(battle != null and flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, exit_mode + " starts a fresh battle")
	if battle == null: return
	var player := flow.get_bound_player()
	var loadout := flow.get_bound_loadout()
	battle.wave_manager.add_exp_and_gold(battle.wave_manager.get_required_exp_for_next_level(), 0)
	await frames(16)
	check(shop.visible and not shop._offer_cards.is_empty(), exit_mode + " real level-up opens rewards")
	check(shop._bond_player == player and shop._loadout == loadout and shop.weapon_strip._loadout == loadout, exit_mode + " rewards bind only the current player and loadout")
	var reward_payload := shop.payload.duplicate(true)
	var hp := player.current_hp
	# A temporary visit to settings must preserve the current run's rewards.
	battle.hud.settings_button.pressed.emit()
	await frames()
	battle.utility_overlay._return_button.pressed.emit()
	await frames()
	check(flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and shop.visible and shop.payload == reward_payload, exit_mode + " returning from settings preserves rewards")
	L10n.set_locale("zh_CN" if L10n.locale == "en" else "en", false)
	await frames()
	check(shop.payload == reward_payload and player.current_hp == hp and not shop._offer_cards.is_empty(), exit_mode + " live language refresh preserves rewards and health")
	if exit_mode == "reward_closed":
		shop.skip_button.pressed.emit()
		await frames()
		check(not shop.visible and flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "reward can close before abandoning the run")
	if exit_mode == "flow_reset":
		flow.reset_flow()
	else:
		battle.hud.settings_button.pressed.emit()
		await frames()
		battle.utility_overlay._menu_button.pressed.emit()
	await frames(12)
	check(menu.start_page.visible and flow.current_state == MainFlowCoordinator.STATE_START_PAGE and not is_instance_valid(battle), exit_mode + " releases the battle and returns to main menu")
	check(shop.payload.is_empty() and shop._bond_player == null and shop._loadout == null and shop.weapon_strip._loadout == null, exit_mode + " clears retained reward data and battle references")
	check(shop._offer_cards.is_empty() and shop.offer_grid.get_child_count() == 0 and shop.weapon_strip.weapon_list.get_child_count() == 0, exit_mode + " removes reward and weapon widgets")
	for locale in ["en", "zh_CN", "en"]:
		menu._language_option.item_selected.emit(L10n.supported_locales.find(locale))
		await frames(8)
		check(L10n.locale == locale and menu._language_option.selected == L10n.supported_locales.find(locale), exit_mode + " switches main-menu language to " + locale)
		check(shop.payload.is_empty() and shop._offer_cards.is_empty() and shop.offer_grid.get_child_count() == 0 and shop.weapon_strip.weapon_list.get_child_count() == 0, exit_mode + " language refresh cannot resurrect old reward widgets")
		await capture(exit_mode + "_" + locale)
