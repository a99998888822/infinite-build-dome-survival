extends Node
## Production UI captures with deterministic review inventory; progress is transient.
var output := "res://artifacts/previews/weapons_36/20261021-r01/screenshots"
var game: GameRoot
var battle: BattleRoot
var flow: MainFlowCoordinator
var checks := 0
var failures := 0
var captures: Array[Dictionary] = []
const REVIEW_IDS := ["weapon_plasma_cannon", "weapon_camp_dagger", "weapon_copper_lamp", "weapon_meteor_flail", "weapon_star_tome", "weapon_nightwatch_spear"]

func _ready() -> void:
	WindowSettings._startup_applied = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
	get_tree().create_timer(100).timeout.connect(func(): get_tree().quit(99))

func frames(count := 12) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func inspect_icon(control: Control, expected: int) -> Dictionary:
	var texture: Texture2D = control.texture if control is TextureRect else control.icon
	var source := ItemIconArt.source_path(texture)
	check(ItemIconArt.is_weapon(texture), "weapon source identity: " + str(control.name))
	check((load(source) as Texture2D).get_size() == Vector2(36, 36), "native source 36: " + source.get_file())
	var rect := Rect2(Vector2.ZERO, control.size)
	var modulate := Color.WHITE
	if texture is ItemIconArt.PIXEL_TEXTURE:
		check(texture.logical_size == Vector2.ONE * expected, "wrapper display tier " + str(expected))
		rect = texture.last_local_rect
		modulate = texture.last_modulate
	else:
		check(control.size == Vector2.ONE * expected, "fixed texture rectangle " + str(expected))
	var screen := ItemIconArt.PIXEL_TEXTURE.screen_transform(control) * rect
	if DisplayServer.get_name() != "headless":
		check(screen.size.is_equal_approx(Vector2.ONE * expected), "GPU drawing rectangle " + str(expected))
	return {"source": source, "rect": [screen.position.x, screen.position.y, screen.size.x, screen.size.y], "tier": expected, "modulate": [modulate.r, modulate.g, modulate.b, modulate.a]}

func capture(id: String, controls: Array, expected: int) -> void:
	await frames(16)
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var icons: Array = []
	for control: Control in controls: icons.append(inspect_icon(control, expected))
	if DisplayServer.get_name() != "headless":
		check(get_viewport().get_texture().get_image().save_png(output.path_join(id + ".png")) == OK, "capture " + id)
	captures.append({"name": id, "icons": icons})

func set_weapons(ids: Array) -> void:
	for source in battle.loadout.weapon_instances: battle.loadout._clear_weapon_runtime(source)
	battle.loadout.weapon_instances.clear()
	battle.loadout.active_casting.states.clear()
	for id in ids:
		var weapon := WeaponInstance.new()
		weapon.initialize(id, battle.player)
		weapon.use_active_range_rules = true
		battle.loadout.weapon_instances.append(weapon)
	battle.loadout.loadout_changed.emit()
	battle.hud._refresh_all()
	await frames()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.set_option("show_hints", false, false)
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(20)
	flow = game.get_main_flow_coordinator()
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu.start_battle_button.pressed.emit()
	await frames()
	await capture("01_character_select_36", [menu.character_view.weapon_list.get_child(0).get_node("WeaponIcon")], 36)
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "start production battle")
	await frames(30)
	battle = game.get_node("SceneDirector").battle_root
	var manager := battle.wave_manager
	manager.set_process(false)
	manager.clear_battle_entities()
	battle.player.set_physics_process(false)
	battle.player.set("_invincibility_timer", 1000.0)
	battle.player.modifier_stack.set_base_stat("load_capacity", 1000)
	battle.loadout.set_physics_process(false)
	battle.active_controller.set_process(false)
	battle.active_controller.set_physics_process(false)
	await set_weapons(REVIEW_IDS)
	manager.current_wave_index = 7
	manager.wave_time_left = 43
	manager.current_gold = 1280
	manager.weapon_damage_this_wave = {"weapon_plasma_cannon": 8460, "weapon_camp_dagger": 6720, "weapon_copper_lamp": 3980, "weapon_meteor_flail": 1540}
	battle.hud._weapon_damage_meter.refresh()
	battle.hud._refresh_all()
	await capture("02_battle_72", battle.hud.combat_bar.icons, 72)
	var ids: Array = []
	for record in DataRegistry.get_table("weapons"): ids.append(record.id)
	await set_weapons(ids)
	await capture("03_battle_many_36", battle.hud.combat_bar.icons, 36)
	await set_weapons(REVIEW_IDS)
	for id in ["relic_piggy_bank", "relic_gold_compass", "relic_brass_pocket_watch"]: battle.player.add_relic(id)
	flow.request_esc_overlay()
	await get_tree().create_timer(0.7).timeout
	await capture("04_esc_72", battle.esc_overlay.weapon_strip._weapon_buttons, 72)
	flow.close_esc_overlay()
	flow.request_battle_utility("encyclopedia")
	await frames()
	var encyclopedia := battle.utility_overlay
	encyclopedia._category.select(1)
	encyclopedia._refresh_entries()
	for i in encyclopedia._records.size():
		if encyclopedia._records[i].id == "weapon_plasma_cannon":
			encyclopedia._entries.select(i)
			encyclopedia._show_entry(i)
	await capture("05_encyclopedia_72", [encyclopedia._entry_icon], 72)
	flow.close_battle_utility()
	manager.player.add_relic("relic_finance_manager")
	flow.finish_current_wave()
	await frames(25)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.visible, "production finance screen opens")
	popup.interest_arrival.skip()
	manager.goblin_trades.cancel()
	popup.cancel_trade("weapon_icon_review")
	popup._select_tab("shop")
	var offers: Array = []
	for id in ["weapon_earth_hammer", "weapon_iron_grenade_cannon", "weapon_mutant_tentacle", "weapon_hand_cannon", "weapon_kunyu_ritual_tome", "weapon_rentier_purse"]:
		var record := DataRegistry.get_record("weapons", id).duplicate(true)
		record.merge({"offer_id": "review_" + id, "offer_type": "new_weapon", "target_id": id, "shop_cost": 120, "rarity": "common"}, true)
		offers.append(record)
		flow._active_shop_offers[record.offer_id] = record
	popup.shop_grid.set_offers(offers, true)
	await frames(25)
	var shop_icons: Array = []
	for card in popup.shop_grid._pool:
		if card.visible and popup.shop_grid.get_global_rect().encloses(card._icon.get_global_rect()): shop_icons.append(card._icon)
	check(shop_icons.size() >= 3, "shop displays weapon fixtures in real cards")
	await capture("06_shop_72", shop_icons, 72)
	popup._select_tab("enchant")
	popup.workbench._select_weapon("weapon_plasma_cannon")
	await frames(20)
	var workbench_icons: Array = [popup.workbench._weapon_icon]
	for button in popup.workbench._weapon_row.get_children():
		if popup.workbench._weapon_scroll.get_global_rect().encloses(button.get_global_rect()): workbench_icons.append(button)
	check(workbench_icons.size() >= 2, "workbench displays current and switch weapon icons")
	await capture("07_workbench_36", workbench_icons, 36)
	var manifest_name := "headless-manifest.json" if DisplayServer.get_name() == "headless" else "capture-manifest.json"
	var file := FileAccess.open(output.path_join(manifest_name), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures}, "\t"))
	file.close()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("WEAPON_ICON_UI_REVIEW checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
