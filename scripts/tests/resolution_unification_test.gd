extends Node
## Production flow, viewport mapping and 1080p spatial regression coverage.

var failures: Array[String] = []
var checks := 0
var output := ""
var game: GameRoot
var battle: BattleRoot

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	run.call_deferred()

func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await frames()
	await RenderingServer.frame_post_draw
	var picture := get_tree().root.get_texture().get_image()
	check(picture.save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func run() -> void:
	check(DataRegistry.load_errors.is_empty(), "data configuration validates")
	CampProgression.begin_transient_session()
	get_tree().root.size = Vector2i(1920, 1080)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	check(get_tree().root.content_scale_size == Vector2i(1920, 1080), "native UI canvas")
	check(game._world_viewport.size == get_tree().root.content_scale_size, "world and UI use the same canvas")
	await capture("01_menu")
	await click(menu.settings_button)
	await get_tree().create_timer(0.3).timeout
	check(menu._settings_overlay.visible, "native menu button opens settings via pointer")
	check(get_viewport().get_visible_rect().encloses(menu._settings_panel.get_global_rect()), "settings fit native canvas")
	await capture("02_settings")
	await click(menu._settings_panel.return_button)
	await get_tree().create_timer(0.2).timeout
	check(not menu._settings_overlay.visible, "scaled settings return button accepts pointer input")
	menu._on_talents_pressed()
	await frames(12)
	await capture("03_talents")
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade", "weapon_camp_dagger"])
	await frames(12)
	await capture("04_characters")
	check(flow.confirm_character_selection(), "character selection enters battle")
	await frames(16)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	check(not game.get_node("UiRoot/CampBlueprintUIController").visible, "talent UI leaves no overlay after entering battle")
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		await frames()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	battle.player.set_physics_process(false)
	battle.set_process(false)
	await frames()
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(2560,1440)]:
		get_tree().root.size = dimensions
		await frames()
		check(get_viewport().get_visible_rect().size == Vector2(1920,1080), "UI canvas stable at " + str(dimensions))
		check(game._world_viewport_container.scale.is_equal_approx(Vector2.ONE), "world has no extra downscale at " + str(dimensions))
		check(get_viewport().get_visible_rect().encloses((battle.hud as BattleHud).combat_bar.get_global_rect()), "weapon bar fits at " + str(dimensions))
		var aim := battle.active_controller
		aim._has_pointer_position = true
		aim._pointer_position = battle.player.get_global_transform_with_canvas().origin + Vector2(300, -80)
		check(aim.pointer_world().distance_to(battle.player.global_position + Vector2(300, -80)) < 0.1, "pointer aligns with world at " + str(dimensions))
		aim._has_pointer_position = false
	get_tree().root.size = Vector2i(1920,1080)
	var ids := ["enemy_mutated_grub", "enemy_echo_bat", "enemy_elite_rusher", "enemy_underworld_wolf"]
	var expected_scales := [0.6, 0.6, 0.75]
	for i in ids.size():
		var enemy := battle.wave_manager.spawn_enemy(ids[i], battle.player.global_position + Vector2(-420 + i * 280, 10)) as EnemyController
		if enemy is EliteRusher or enemy is UnderworldWolf: enemy._physics_process(0.8)
		enemy.set_physics_process(false)
		if i < 3: check(enemy.sprite.scale.is_equal_approx(Vector2.ONE * expected_scales[i]), "body scale " + ids[i])
		var collider := enemy.get_node("CollisionShape2D") as CollisionShape2D
		var before := collider.scale
		enemy.apply_body_scale(1.5)
		enemy.apply_body_scale(1.5)
		check(collider.scale.is_equal_approx(before * 1.5), "challenge body scaling does not compound " + ids[i])
		enemy.apply_body_scale(1.0)
	var arrow := battle.loadout.get_weapon_instance("weapon_void_blade")
	var dagger := battle.loadout.get_weapon_instance("weapon_camp_dagger")
	check(is_equal_approx(arrow.get_attack_range(), 467.0), "arrow range migrates to 1080p")
	check(is_equal_approx(dagger.get_attack_range(), 167.0), "melee range migrates to 1080p")
	check(absf(arrow.get_attack_range() / arrow.get_projectile_speed() - 280.0 / 500.0) < 0.002, "projectile travel time preserved within pixel rounding")
	var reaches := {"weapon_void_blade":467, "weapon_plasma_cannon":400, "weapon_iron_grenade_cannon":333,
		"weapon_kunyu_ritual_tome":367, "weapon_rentier_purse":467, "weapon_copper_lamp":200,
		"weapon_mutant_tentacle":233, "weapon_earth_hammer":495, "weapon_camp_dagger":167,
		"weapon_nightwatch_spear":367, "weapon_meteor_flail":240, "weapon_dash_blade":233,
		"weapon_hand_cannon":250, "weapon_star_tome":350}
	for id in reaches:
		var source := WeaponInstance.new()
		source.initialize(id, battle.player)
		source.use_active_range_rules = true
		check(is_equal_approx(source.get_attack_range(), float(reaches[id])), "native range " + id)
		if source.is_ritual_tome():
			check(source.get_domain_axes().is_equal_approx(Vector2(367,242)), "ritual minor axis migrates with its range")
		if source.is_grenade():
			check(is_equal_approx(source.get_grenade_blast_radius(), 107.0), "grenade blast migrates with its range")
	await capture("05_battle")
	await verify_spear_contacts()
	flow.request_esc_overlay()
	await frames(12)
	await capture("06_inventory")
	flow.close_esc_overlay()
	flow.finish_current_wave()
	await frames(30)
	var popup := game.find_child("FinancePopup", true, false) as FinancePopup
	if popup.visible:
		popup.interest_arrival.skip()
		await frames(12)
		check(Rect2(Vector2.ZERO, Vector2(1920,1080)).encloses(popup.start_button.get_global_rect()), "finance next-wave button in bounds")
		check(popup._shop.get_global_rect().end.x < (battle.hud as BattleHud).stats_drawer.get_global_rect().position.x, "finance workspace stays clear of the drawer")
		await capture("07_finance")
		popup._select_tab("enchant")
		await frames(12)
		await capture("08_enchant")
	else:
		check(false, "production flow opens finance")
	game.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	print("RESOLUTION_UNIFICATION_COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_spear_contacts() -> void:
	battle.wave_manager.clear_enemies()
	await frames()
	var source := WeaponInstance.new()
	source.initialize("weapon_nightwatch_spear", battle.player)
	source.use_active_range_rules = true
	var targets: Array[EnemyController] = []
	for distance in [330.0, 450.0]:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", source.get_attack_origin() + Vector2(distance, 0)) as EnemyController
		enemy.set_physics_process(false)
		enemy.current_hp = 10000
		targets.append(enemy)
	await frames()
	await get_tree().physics_frame
	var spear := NightwatchSpear.new()
	battle.player.get_parent().add_child(spear)
	spear.initialize(source, Vector2.RIGHT)
	spear.set_physics_process(false)
	spear._physics_process(0.22)
	check(targets[0].current_hp < 10000, "real spear hits at 330 pixels, beyond the old 220 range")
	check(targets[1].current_hp == 10000, "real spear rejects a target outside the new range")
	spear.queue_free()
