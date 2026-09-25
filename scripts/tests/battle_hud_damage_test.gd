extends Node

const BLADE := "weapon_void_blade"
const PURSE := "weapon_rentier_purse"
const TOME := "weapon_kunyu_ritual_tome"
var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var battle: BattleRoot
var hud: BattleHud
var manager: WaveManager
var flow: MainFlowCoordinator
var player: PlayerController


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()


func _watchdog() -> void:
	await get_tree().create_timer(180).timeout
	push_error("BATTLE_HUD_DAMAGE_TIMEOUT")
	get_tree().quit(99)


func frames(count: int = 4) -> void:
	for index in count:
		await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	seed(250925)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1152, 648)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [BLADE])
	await frames()
	check(flow.confirm_character_selection(), "start real battle")
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	hud = battle.hud as BattleHud
	manager = battle.wave_manager
	player = battle.player
	battle.set_process(false)
	manager.set_process(false)
	manager.clear_battle_entities()
	player.set_physics_process(false)
	check(battle.loadout.equip_weapon(PURSE) and battle.loadout.equip_weapon(TOME), "equip three distinct weapons")
	var enemy := manager.spawn_enemy("enemy_mutated_grub", Vector2(150, 0))
	enemy.set_physics_process(false)
	enemy.current_hp = 10000
	manager.weapon_damage_this_wave.clear()
	var expected := enemy.take_damage(30, BLADE)
	check(manager.weapon_damage_this_wave.get(BLADE, 0) == expected, "direct final damage recorded once")
	enemy.apply_burning(3, 4, BLADE)
	enemy._process_burning(0.5)
	expected += 4
	check(manager.weapon_damage_this_wave[BLADE] == expected, "burn tick attributed to original weapon")
	enemy.clear_burning()
	enemy.apply_light(5)
	expected += enemy.take_damage(10, BLADE)
	check(manager.weapon_damage_this_wave[BLADE] == expected, "light bonus recorded at final damage value")
	enemy.apply_burning(3, 4, BLADE)
	var reaction := ElementReactionResolver.apply_element(enemy, "water", {"source_id": PURSE, "damage": 20, "original_damage": 20})
	check(manager.weapon_damage_this_wave.get(PURSE, 0) == reaction.steam_damage, "reaction attributed to triggering weapon")
	var before := manager.weapon_damage_this_wave.duplicate()
	enemy.take_damage(0, BLADE)
	enemy.take_damage(12, "environment")
	check(manager.weapon_damage_this_wave == before, "zero and nonweapon damage excluded")
	manager.running = false
	enemy.take_damage(12, BLADE)
	check(manager.weapon_damage_this_wave == before, "between-wave damage excluded")
	manager.running = true
	enemy.take_damage(200, PURSE)
	hud._weapon_damage_meter.refresh()
	var entries: Array = hud._weapon_damage_meter._entries
	check(entries.size() == 3 and entries[0].weapon_id == PURSE and entries[2].weapon_id == TOME, "descending damage order with zero-damage equipped weapons")
	hud.bind_context(flow, player, manager)
	check(manager.weapon_damage_this_wave[BLADE] == expected, "HUD rebind preserves accumulated damage")
	enemy.current_hp = 1
	var lethal := enemy.take_damage(80, BLADE)
	var after_lethal: int = manager.weapon_damage_this_wave[BLADE]
	enemy.take_damage(80, BLADE)
	check(after_lethal == expected + lethal and manager.weapon_damage_this_wave[BLADE] == after_lethal, "lethal hit agrees with combat number and dead target cannot double count")
	check(manager.start_next_wave(), "next wave starts")
	hud._weapon_damage_meter.refresh()
	check(manager.weapon_damage_this_wave.is_empty() and hud._weapon_damage_meter._entries.all(func(entry): return entry.damage == 0), "next wave resets all bars")
	manager.initialize(player)
	check(manager.weapon_damage_this_wave.is_empty(), "new run resets totals")
	manager.start_next_wave()
	hud._set_drawer_open(true, false)
	await frames(12)
	check(hud.stats_scroll.get_parent().get_node_or_null("TitleLabel") == null, "old drawer title removed")
	check(hud.stats_list.has_node("MainStats") and hud.stats_list.has_node("SpecialStats"), "two named attribute sections")
	check(hud._stat_value_labels.size() == StatDefinitions.get_all_stat_ids().size() - 3, "all displayed attributes retained")
	var scroll_rect := hud.stats_scroll.get_global_rect()
	var visible_values := 0
	for label: Label in hud._stat_value_labels.values():
		if scroll_rect.encloses(label.get_global_rect()):
			visible_values += 1
	check(visible_values >= 22 and is_equal_approx(hud.stats_drawer.size.x, 320), "compact single-column drawer retains original width and shows more attributes")
	check(hud._weapon_damage_meter.position.y >= hud._vitals_frame.get_rect().end.y, "damage meter is below vitals")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await _capture_live_combat()
	print("BATTLE_HUD_DAMAGE_TEST checks=", checks, " failures=", failures)
	manager.clear_battle_entities()
	game.queue_free()
	await frames(8)
	get_tree().quit(0 if failures == 0 else 1)


func _capture_live_combat() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	# Exercise the shipped weapons and enchantment in a real rendered battle.
	player._invincibility_timer = 100.0
	var purse := battle.loadout.get_weapon_instance(PURSE)
	check(purse.attach_item_instance({"item_instance_id": "capture_fire", "base_item_id": "scroll_fire",
		"category": "enchantment_scroll", "effect_ids": ["fire"]}), "attach fire enchantment for live capture")
	for index in 14:
		var angle := TAU * index / 14.0
		manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2.from_angle(angle) * 220)
	battle.set_process(true)
	manager.set_process(true)
	hud._set_drawer_open(false, false)
	await get_tree().create_timer(7).timeout
	for index in 20:
		if flow.current_state != MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP:
			break
		flow.close_shared_reward_shop_popup()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	hud._set_drawer_open(false, false)
	await frames(8)
	hud._weapon_damage_meter.refresh()
	check(manager.weapon_damage_this_wave.size() >= 2, "live attacks produce independent weapon totals")
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and hud.status_panel.is_visible_in_tree(), "capture shows combat HUD without modal")
	await capture("01_battle_damage")
	hud._set_drawer_open(true, false)
	await frames(10)
	await capture("02_attribute_sections")
	hud.stats_scroll.scroll_vertical = int(hud.stats_scroll.get_v_scroll_bar().max_value)
	await frames(8)
	await capture("03_attribute_scroll")
	var report := {"checks": checks, "failures": failures, "wave_damage": manager.weapon_damage_this_wave}
	var file := FileAccess.open(capture_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))


func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(filename + ".png")) == OK, "capture " + filename)
