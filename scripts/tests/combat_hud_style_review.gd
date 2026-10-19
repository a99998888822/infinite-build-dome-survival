extends Node
## Review fixtures feed real production HUD widgets; capture on the native canvas.

var output := "res://artifacts/reviews/combat_hud_20261019/preview"
var game: GameRoot
var battle: BattleRoot
var hud: BattleHud
var failures := 0
var checks := 0


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 12) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func capture(name: String) -> void:
	await frames()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.set_option("show_hints", false, false)
	get_tree().root.size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames()
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "real battle starts")
	await frames(30)
	battle = game.get_node("SceneDirector").battle_root
	hud = battle.hud
	var manager := battle.wave_manager
	manager.set_process(false)
	manager.clear_battle_entities()
	battle.player.set_physics_process(false)
	battle.player.set("_invincibility_timer", 1000.0)
	for id in ["weapon_plasma_cannon", "weapon_rentier_purse", "weapon_kunyu_ritual_tome"]:
		check(battle.loadout.equip_weapon(id), "equip review weapon " + id)
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", false, false)
	CombatSettings.set_weapon_auto_cast("weapon_plasma_cannon", false, false)
	CombatSettings.set_weapon_auto_cast("weapon_rentier_purse", true, false)
	CombatSettings.set_weapon_auto_cast("weapon_kunyu_ritual_tome", true, false)
	battle.loadout.set_physics_process(false)
	battle.active_controller.set_process(false)
	battle.active_controller.set_physics_process(false)
	manager.current_wave_index = 7
	manager.wave_time_left = 43
	manager.current_gold = 1280
	battle.player.grant_shield(20)
	battle.player.current_hp = 24
	hud._sync_vitals(false)
	manager.weapon_damage_this_wave = {"weapon_void_blade": 8460, "weapon_plasma_cannon": 6720, "weapon_rentier_purse": 3980, "weapon_kunyu_ritual_tome": 1540}
	hud._weapon_damage_meter.refresh()
	hud._refresh_all()
	await frames()
	hud.set_process(false)
	check(hud._vitals_frame.get_theme_stylebox("panel").detail == 3 and hud.wave_panel.get_theme_stylebox("panel").detail == 2, "vitals and wave use the requested ornament hierarchy")
	check(hud.combat_bar.cards[0].get_theme_stylebox("panel").detail == 1 and hud._weapon_damage_meter._frame is PixelTooltipStyle, "weapon slots keep compact ornaments and damage uses minimal single outline")
	check(hud._vitals_frame.get_global_rect().encloses(hud.shield_bar.get_global_rect()), "vitals frame encloses the shield row")
	await capture("01_battle")
	hud.combat_bar.update_slot(0, 0, 1, false, true)
	hud.combat_bar.update_slot(1, 3, 5, false, false)
	await capture("02_selected_weapon")
	# Exercise an actual custom stat tooltip, including its preexisting margins.
	hud._set_drawer_open(true, false)
	await frames()
	hud._show_stat_tooltip(hud.stats_scroll, "armor")
	await frames()
	check(hud._stat_tooltip_panel.get_theme_stylebox("panel") is PixelTooltipStyle, "custom stat tooltip uses single pixel iron skin")
	await capture("03_stat_tooltip")
	hud._hide_stat_tooltip()
	hud._set_drawer_open(false, false)
	# Native engine hover popup also picks up the shared minimal theme.
	var motion := InputEventMouseMotion.new()
	motion.position = hud.settings_button.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.8).timeout
	await capture("04_native_tooltip")
	flow.request_esc_overlay()
	await frames()
	var strip := battle.esc_overlay.weapon_strip
	motion = InputEventMouseMotion.new()
	motion.position = strip._weapon_buttons[0].get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	await frames()
	strip._show_weapon_tooltip(battle.loadout.weapon_instances[0], strip._weapon_buttons[0])
	await frames()
	check(strip.weapon_tooltip.get_theme_stylebox("panel") is PixelTooltipStyle, "reused ESC weapon tooltip has the same simple skin")
	check(strip.weapon_tooltip.is_visible_in_tree(), "weapon tooltip remains visible under actual pointer")
	await capture("05_weapon_tooltip")
	flow.close_esc_overlay()
	for extent in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(2560, 1440)]:
		get_tree().root.size = extent
		await frames()
		var bounds := get_viewport().get_visible_rect()
		check(bounds.encloses(hud._vitals_frame.get_global_rect()) and bounds.encloses(hud.combat_bar.get_global_rect()), "frame bounds at " + str(extent))
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("COMBAT_HUD_STYLE_REVIEW_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
