extends "res://scripts/tests/active_combat_integration_test.gd"

var target: EnemyController

func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.set_option("wheelchair_mode", false, false)
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	await boot()
	player.set_physics_process(false)
	battle.set_process(false)
	player.collision_layer = 0
	for record in DataRegistry.get_table("weapons"):
		await _automatic_weapon(record.id)
	await _boundaries_and_switching()
	await _lamp_all_modes()
	await _lamp_target_boundaries()
	await _special_shapes()
	CombatSettings.set_option("wheelchair_mode", false, false)
	flow.enter_start_page()
	await frames(8)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("WHEELCHAIR_MODE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func fixture(id: String, position: Vector2 = Vector2(60, 0)) -> WeaponInstance:
	CombatSettings.set_option("wheelchair_mode", false, false)
	for old in loadout.weapon_instances.duplicate():
		loadout.remove_weapon(old.weapon_id)
	manager.clear_battle_entities()
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		enemy.free()
	await frames(2)
	player.global_position = Vector2.ZERO
	player.last_move_direction = Vector2.RIGHT
	check(loadout.equip_weapon(id), "equip " + id)
	target = manager.spawn_enemy("enemy_mutated_grub", position)
	target.set_physics_process(false)
	target.modifier_stack.set_base_stat("max_hp", 100000)
	target.current_hp = 100000
	var weapon := loadout.weapon_instances[0]
	weapon.runtime_stats.projectile_count = 3
	weapon.runtime_stats.crit_chance = 0
	await get_tree().physics_frame
	return weapon

func _automatic_weapon(id: String) -> void:
	var weapon := await fixture(id, Vector2(2000, 0))
	loadout.tick(10)
	check(weapon.volley_index == 0, "manual mode stays idle " + id)
	CombatSettings.set_option("wheelchair_mode", true, false)
	loadout.tick(10)
	check(weapon.volley_index == 0, "out-of-range target does not consume cooldown " + id)
	target.global_position = Vector2(-60, 0)
	await get_tree().physics_frame
	loadout.tick(0)
	var state := loadout.active_casting.state_for(weapon)
	check(weapon.volley_index == 1 and state.executing and state.remaining == 0, "automatic cast uses execution state " + id)
	loadout.tick(0)
	check(weapon.volley_index == 1, "no duplicate cast during animation " + id)
	await get_tree().create_timer(0.85).timeout
	check(target.current_hp < 100000, "real automatic attack damages target " + id)
	var body: Node2D = state.body.get_ref() if state.body is WeakRef else null
	if is_instance_valid(body):
		body.set_physics_process(false)
		for step in 100:
			if body.cancelled:
				break
			body._physics_process(0.1)
	loadout.tick(0.2)
	check(not state.executing and is_equal_approx(state.remaining, weapon.get_active_cooldown_seconds()), "cooldown begins after full attack " + id)
	var cooldown: float = state.remaining
	CombatSettings.set_option("wheelchair_mode", false, false)
	CombatSettings.set_option("wheelchair_mode", true, false)
	check(state.remaining == cooldown, "toggling does not reset cooldown " + id)
	loadout.tick(cooldown * 0.5)
	check(weapon.volley_index == 1, "cooldown prevents early automatic repeat " + id)
	loadout.tick(cooldown * 0.5 + 0.001)
	check(weapon.volley_index == 2 and state.executing, "cooldown completion automatically repeats " + id)

func _boundaries_and_switching() -> void:
	var weapon := await fixture("weapon_void_blade")
	controller.select_slot(0)
	check(controller.selected_weapon == weapon, "manual targeting works before switch")
	CombatSettings.set_option("wheelchair_mode", true, false)
	controller.select_slot(0)
	check(controller.selected_weapon == null and not controller.indicator.visible, "auto mode clears aim and ignores manual selection")
	player.request_move(Vector2(300, 100))
	check(player.has_move_destination, "automatic attacks retain click-to-move")
	controller.stop_movement()
	check(not player.has_move_destination, "stop movement works in automatic mode")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	loadout.tick(10)
	check(weapon.volley_index == 0, "pause blocks automatic casting")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_FINANCE_POPUP)
	loadout.tick(10)
	check(weapon.volley_index == 0, "finance phase blocks automatic casting")
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_WAVE_COMBAT)
	player.alive = false
	loadout.tick(10)
	check(weapon.volley_index == 0, "dead player cannot auto attack")
	player.alive = true
	target.alive = false
	loadout.tick(10)
	check(weapon.volley_index == 0, "dead targets are ignored")
	target.alive = true
	var elite := manager.spawn_enemy("enemy_elite_rusher", Vector2(40, 0)) as EliteRusher
	elite.set_physics_process(false)
	check(loadout.active_casting._auto_target(weapon) == target, "invulnerable spawning boss is skipped")
	elite.free()
	check(loadout.equip_weapon("weapon_nightwatch_spear"), "equip second independent weapon")
	loadout.tick(0)
	check(loadout.weapon_instances.all(func(w): return w.volley_index == 1), "multiple weapons auto cast independently in same tick")
	var state := loadout.active_casting.state_for(weapon)
	CombatSettings.set_option("wheelchair_mode", false, false)
	check(state.executing, "disabling auto does not interrupt an attack already started")
	await get_tree().create_timer(0.3).timeout
	loadout.tick(0.2)
	loadout.tick(10)
	check(weapon.volley_index == 1, "disabled auto mode does not repeat")
	controller.select_slot(0)
	check(controller.selected_weapon == weapon, "manual aiming restored after disabling")
	check(loadout.cast_weapon(weapon, target.global_position), "manual release works after disabling")

func _lamp_all_modes() -> void:
	for wheelchair in [false, true]:
		for keyboard in [false, true]:
			var weapon := await fixture("weapon_copper_lamp", Vector2(-60, 0))
			CombatSettings.set_option("wheelchair_mode", wheelchair, false)
			CombatSettings.set_option("keyboard_movement", keyboard, false)
			var label := " wheelchair=%s keyboard=%s" % [wheelchair, keyboard]
			var farther := manager.spawn_enemy("enemy_mutated_grub", Vector2(90, 0))
			farther.set_physics_process(false)
			farther.modifier_stack.set_base_stat("max_hp", 100000)
			farther.current_hp = 100000
			check(loadout.equip_weapon("weapon_void_blade"), "equip manual companion" + label)
			controller.current_weapon = loadout.weapon_instances[1]
			loadout.tick(0)
			var state := loadout.active_casting.state_for(weapon)
			check(weapon.volley_index == 1 and state.executing, "unselected lamp starts without input" + label)
			check(loadout.weapon_instances[1].volley_index == (1 if wheelchair else 0), "other weapons retain their mode rules" + label)
			var body: CopperLamp = state.body.get_ref()
			body.set_physics_process(false)
			body._physics_process(0.01)
			check(not body.manual_control and body.target == target and body.heading.is_equal_approx(Vector2.LEFT), "nearest rear target wins over facing target" + label)
			check(target.current_hp < 100000 and farther.current_hp == 100000, "flame damages the selected rear cone" + label)
			player.last_move_direction = Vector2.UP
			controller._pointer_position = Vector2(1200, 0)
			controller._has_pointer_position = true
			loadout.tick(0)
			body._physics_process(0.01)
			check(body.heading.is_equal_approx(Vector2.LEFT), "movement and pointer cannot redirect spray" + label)
			check(not loadout.cast_weapon(weapon, Vector2.UP * 100) and weapon.volley_index == 1, "manual input cannot duplicate automatic burst" + label)
			target.alive = false
			var previous := body.heading
			body._physics_process(0.1)
			check(body.target == farther and is_equal_approx(absf(previous.angle_to(body.heading)), deg_to_rad(18)), "dead target switches with existing turn speed" + label)
			target.alive = true
			target.global_position = Vector2(0, -40)
			player.global_position = Vector2(0, 10)
			body._physics_process(0.1)
			check(body.target == target and body.global_position == player.global_position, "nearest target is reevaluated as player and enemies move" + label)
			var heat := body.heat
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			body._physics_process(10)
			loadout.tick(10)
			check(body.heat == heat and state.executing and weapon.volley_index == 1, "pause freezes automatic burst" + label)
			GameGlobal.set_runtime_flag("battle_runtime_paused", false)
			body._physics_process(weapon.get_lamp_spray_seconds())
			loadout.tick(0)
			var cooldown := weapon.get_active_cooldown_seconds()
			check(not state.executing and is_equal_approx(state.remaining, cooldown), "full spray ends before cooldown" + label)
			loadout.tick(cooldown * 0.5)
			check(weapon.volley_index == 1, "cooldown blocks repeat" + label)
			loadout.tick(cooldown * 0.5 + 0.001)
			check(weapon.volley_index == 2 and state.executing, "lamp automatically repeats after cooldown" + label)
	CombatSettings.set_option("keyboard_movement", false, false)

func _lamp_target_boundaries() -> void:
	var weapon := await fixture("weapon_copper_lamp", Vector2(-2000, 0))
	loadout.tick(10)
	check(weapon.volley_index == 0 and not loadout.cast_weapon(weapon, Vector2.LEFT), "automatic and manual lamp ignore out-of-range targets")
	target.global_position = Vector2(-60, 0)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	loadout.tick(10)
	check(weapon.volley_index == 0, "manual-mode lamp cannot start while paused")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_FINANCE_POPUP)
	loadout.tick(10)
	check(weapon.volley_index == 0, "manual-mode lamp cannot start outside combat")
	GameGlobal.set_runtime_flag("main_flow_state", MainFlowCoordinator.STATE_WAVE_COMBAT)
	player.alive = false
	loadout.tick(10)
	check(weapon.volley_index == 0, "dead player cannot start automatic lamp")
	player.alive = true
	target.alive = false
	loadout.tick(10)
	check(weapon.volley_index == 0, "dead target cannot start automatic lamp")
	target.alive = true
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 120)
	collider.shape = shape
	wall.add_child(collider)
	player.get_parent().add_child(wall)
	wall.global_position = Vector2(-30, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	loadout.tick(10)
	check(weapon.volley_index == 0 and not loadout.cast_weapon(weapon, target.global_position), "blocked target cannot consume lamp cooldown")
	var elite := manager.spawn_enemy("enemy_elite_rusher", Vector2(20, 0)) as EliteRusher
	elite.set_physics_process(false)
	loadout.tick(0)
	check(weapon.volley_index == 0, "spawning boss cannot start lamp while other targets are blocked")
	wall.free()
	await get_tree().physics_frame
	loadout.tick(0)
	check(weapon.volley_index == 1, "clearing obstruction starts lamp automatically")
	var body: CopperLamp = loadout.active_casting.state_for(weapon).body.get_ref()
	body.set_physics_process(false)
	body._physics_process(0.01)
	check(body.target == target, "continuous tracking also skips spawning boss")

func _special_shapes() -> void:
	for id in ["weapon_kunyu_ritual_tome", "weapon_iron_grenade_cannon"]:
		var weapon := await fixture(id)
		var axes := weapon.get_domain_axes() if weapon.is_ritual_tome() else AttackFootprint.grenade_range_axes(weapon)
		target.global_position = Vector2(0, axes.y + 10)
		CombatSettings.set_option("wheelchair_mode", true, false)
		loadout.tick(0)
		check(weapon.volley_index == 0, "ellipse excludes targets beyond minor axis " + id)
		weapon.runtime_stats.area_size = 100
		loadout.tick(0)
		check(weapon.volley_index == 1, "auto targeting follows increased range " + id)
	var tome := await fixture("weapon_kunyu_ritual_tome")
	CombatSettings.set_option("wheelchair_mode", true, false)
	loadout.tick(0)
	var state := loadout.active_casting.state_for(tome)
	var domain: RitualDomain = state.body.get_ref()
	target.global_position = Vector2(1000, 0)
	player.global_position = Vector2(300, 0)
	domain.set_physics_process(false)
	domain._physics_process(2)
	loadout.tick(2)
	check(domain.marks_remaining == 5 and domain.global_position == Vector2.ZERO and state.executing, "empty automatic tome keeps its marks at fixed cast position")
	target.global_position = Vector2(60, 0)
	for step in 6:
		domain._physics_process(0.36)
	loadout.tick(0)
	check(domain.marks_completed == 5 and not state.executing and state.remaining > 0, "returning target completes all tome marks before cooldown")
