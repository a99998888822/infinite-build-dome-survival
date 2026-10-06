extends "res://scripts/tests/active_combat_integration_test.gd"
## Capture the installed scene with fixed cooldown display samples.

func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.set_option("wheelchair_mode", false, false)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(12)
	await boot()
	player.set_physics_process(false)
	battle.set_process(false)
	controller.enabled = false
	for id in ["weapon_plasma_cannon", "weapon_copper_lamp", "weapon_camp_dagger", "weapon_nightwatch_spear"]:
		loadout.equip_weapon(id)
	await frames(6)
	var hud := battle.hud as BattleHud
	hud.set_process(false)
	var fractions := [1.0, 0.75, 0.5, 0.25, 0.0]
	for index in loadout.weapon_instances.size():
		var state := loadout.active_casting.state_for(loadout.weapon_instances[index])
		state.executing = false
		state.total = 4.0
		state.remaining = fractions[index] * 4.0
	hud._refresh_active_combat()
	await frames(4)
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = dimensions
		await frames(8)
		hud._apply_combat_layout()
		hud._refresh_active_combat()
		await capture("horizon_cooldown_%d" % dimensions.x)
		var ground := get_tree().get_first_node_in_group("battle_meadow") as MeadowBattleBackdrop
		var sky := battle.get_node("BattleSky/Sky") as TextureRect
		print("HORIZON size=", dimensions, " sky_bottom=", sky.offset_bottom, " ground_horizon=", ground._horizon.horizon_y)
	flow.enter_start_page()
	await frames(6)
	game.queue_free()
	await frames(4)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer: child.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("HORIZON_COOLDOWN_REVIEW failures=", failures)
	get_tree().quit(failures)
