extends Node
## Real GameRoot integration; synthetic input goes through the viewport and GUI.
var checks := 0
var failures := 0
var game: GameRoot
var flow: MainFlowCoordinator
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var manager: WaveManager
var controller: ActiveCombatController
var capture_dir := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(120).timeout
	push_error("ACTIVE_COMBAT_TIMEOUT")
	get_tree().quit(99)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame
	# Headless can run idle frames before deferred Container layout has settled.
	await get_tree().create_timer(0.025).timeout

func key(code: int, down: bool = true, repeat: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = repeat
	Input.parse_input_event(event)
	await frames(2)

func mouse(at: Vector2, button: int = 0, down: bool = true) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	if button:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
	await frames(2)

func click(control: Control) -> void:
	var at := control.get_global_transform_with_canvas() * (control.size * 0.5)
	await mouse(at, MOUSE_BUTTON_LEFT)
	await mouse(at, MOUSE_BUTTON_LEFT, false)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await frames(4)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "GPU " + name)

func boot() -> void:
	if flow != null:
		flow.enter_start_page()
		await frames(6)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames()
	check(flow.confirm_character_selection(), "real battle starts")
	await frames(8)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	player = battle.player
	loadout = battle.loadout
	manager = battle.wave_manager
	controller = battle.active_controller
	manager.set_process(false)
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		enemy.free()
	player.modifier_stack.set_base_stat("load_capacity", 1000)

func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	await frames(12)
	await boot()
	if DisplayServer.get_name() == "headless":
		print("GUI input/layout assertions run in the private-desktop GPU pass.")
		player.set_physics_process(false)
		battle.set_process(false)
	else:
		await _input_and_settings()
	await _weapon_execution()
	await _inventory_tooltips()
	await _cleanup()
	flow.enter_start_page()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	print("ACTIVE_COMBAT_INTEGRATION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _input_and_settings() -> void:
	var bow := loadout.weapon_instances[0]
	check(loadout.active_combat_enabled and bow.use_active_range_rules and player.active_controls, "production uses active input and stat rules")
	loadout.tick(10)
	check(bow.volley_index == 0, "idle does not auto attack")
	await mouse(Vector2(830, 350), MOUSE_BUTTON_LEFT)
	await mouse(Vector2(830, 350), MOUSE_BUTTON_LEFT, false)
	check(bow.volley_index == 0, "left click without aim cannot attack")
	await mouse(Vector2(830, 350), MOUSE_BUTTON_RIGHT)
	await mouse(Vector2(830, 350), MOUSE_BUTTON_RIGHT, false)
	var before := player.global_position
	await get_tree().create_timer(0.15).timeout
	check(player.global_position.distance_to(before) > 5 and controller.marker.active, "right click moves with destination marker")
	await key(KEY_1)
	check(controller.selected_weapon == bow and controller.indicator.visible, "number selects aim while moving")
	check(player.has_move_destination, "aim preserves movement")
	var facing := player.last_move_direction
	await key(KEY_S)
	check(not player.has_move_destination and player.velocity.is_zero_approx() and not controller.marker.active, "S stops click-to-move immediately and removes its marker")
	check(controller.selected_weapon == bow and controller.indicator.visible and player.last_move_direction == facing, "stop preserves aim and the last movement facing")
	before = player.global_position
	await get_tree().create_timer(0.12).timeout
	check(player.global_position.is_equal_approx(before), "player stays stopped after S")
	await key(KEY_S, false)
	await mouse(Vector2(830, 350), MOUSE_BUTTON_RIGHT)
	await key(KEY_1)
	await key(KEY_S)
	check(not controller.right_held and not player.has_move_destination and controller.selected_weapon == bow, "S overrides held right-click without cancelling aim")
	await get_tree().create_timer(0.12).timeout
	check(not player.has_move_destination, "held mouse does not reissue movement after stop")
	await mouse(Vector2(830, 350), MOUSE_BUTTON_RIGHT, false)
	await key(KEY_S, false)
	await mouse(Vector2(830, 350), MOUSE_BUTTON_RIGHT)
	await mouse(Vector2(830, 350), MOUSE_BUTTON_RIGHT, false)
	check(player.has_move_destination, "a fresh right click resumes movement")
	await key(KEY_1)
	await key(KEY_1, true, true)
	check(bow.volley_index == 0, "keyboard repeat does not cast")
	loadout.equip_weapon("weapon_camp_dagger")
	await key(KEY_1)
	await key(KEY_2)
	check(controller.selected_weapon == loadout.weapon_instances[1], "latest number replaces aim")
	await key(KEY_ESCAPE)
	check(controller.selected_weapon == null and flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "Escape cancels aim before pause")
	await key(KEY_ESCAPE)
	check(flow.current_state == MainFlowCoordinator.STATE_ESC_OVERLAY and not player.has_move_destination, "second Escape pauses and clears movement")
	check(not (battle.hud as BattleHud).combat_bar.is_visible_in_tree(), "battle bar hidden in Escape inventory")
	await key(KEY_ESCAPE)
	await get_tree().create_timer(0.4).timeout
	await key(KEY_1)
	await click((battle.hud as BattleHud).combat_bar.cards[0])
	check(bow.volley_index == 0 and controller.selected_weapon == bow, "HUD blocks attack click")
	await mouse(Vector2(830, 350), MOUSE_BUTTON_LEFT)
	await mouse(Vector2(830, 350), MOUSE_BUTTON_LEFT, false)
	check(bow.volley_index == 1 and controller.selected_weapon == null, "successful left click casts once and exits aim")
	await key(KEY_1)
	check(not controller.indicator.available, "cooling weapon previews unavailable range")
	await mouse(Vector2(830, 350), MOUSE_BUTTON_LEFT)
	check(bow.volley_index == 1, "cooldown rejects cast without queue")
	await mouse(Vector2(900, 400), MOUSE_BUTTON_RIGHT)
	await mouse(Vector2(900, 400), MOUSE_BUTTON_RIGHT, false)
	check(controller.selected_weapon == null and player.has_move_destination, "right click cancels aim and moves")
	await click((battle.hud as BattleHud).settings_button)
	var settings := battle.utility_overlay
	check(settings._basic_settings.visible and not settings._combat_settings.visible, "wrench opens basic settings by default")
	await capture("02_settings_basic")
	await click(settings._settings_tabs[1])
	check(settings._combat_settings.visible, "combat tab opens real operation settings")
	await click(settings._quick_cast)
	check(CombatSettings.quick_cast, "quick cast checkbox updates setting")
	await capture("03_settings_combat")
	await key(KEY_ESCAPE)
	loadout.active_casting.state_for(bow).remaining = 0
	await mouse(Vector2(820, 360))
	await key(KEY_1)
	check(bow.volley_index == 2 and controller.selected_weapon == null, "quick cast fires directly on number")
	CombatSettings.set_option("keyboard_movement", true, false)
	await mouse(Vector2(900, 400), MOUSE_BUTTON_RIGHT)
	await mouse(Vector2(900, 400), MOUSE_BUTTON_RIGHT, false)
	check(not player.has_move_destination, "keyboard mode right click does not move")
	before = player.global_position
	await key(KEY_D)
	await get_tree().create_timer(0.12).timeout
	await key(KEY_D, false)
	check(player.global_position.x > before.x + 5, "WASD movement works in keyboard mode")
	before = player.global_position
	await key(KEY_S)
	await get_tree().create_timer(0.12).timeout
	await key(KEY_S, false)
	check(player.global_position.y > before.y + 5, "S still moves down in keyboard movement mode")
	controller._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(player._held_move_keys.is_empty() and not controller.right_held and controller.selected_weapon == null, "focus loss clears held input")
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	await click((battle.hud as BattleHud).settings_button)
	check(settings._basic_settings.visible, "settings resets to basic tab on next open")
	await key(KEY_ESCAPE)
	player.set_physics_process(false)
	battle.set_process(false)
	controller.clear_input()
	var hud := battle.hud as BattleHud
	check(hud.exp_bar.custom_minimum_size.y == 4 and not hud.exp_label.visible and not hud._experience_frame.visible, "thin frameless XP without digits")

func _weapon_execution() -> void:
	for record in DataRegistry.get_table("weapons"):
		for old in loadout.weapon_instances.duplicate():
			loadout.remove_weapon(old.weapon_id)
		loadout.equip_weapon(record.id)
		var source := loadout.weapon_instances[0]
		source.runtime_stats.projectile_count = 3
		source.runtime_stats.attack_speed = 100
		source.runtime_stats.crit_chance = 0
		var lamp_target: EnemyController
		if source.is_copper_lamp():
			lamp_target = manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(-60, 0))
			lamp_target.set_physics_process(false)
			lamp_target.modifier_stack.set_base_stat("max_hp", 100000)
			lamp_target.current_hp = 100000
		check(loadout.cast_weapon(source, player.global_position + Vector2(240, 0)), "cast " + source.weapon_id)
		var state := loadout.active_casting.state_for(source)
		if source.is_star_tome():
			check(state.executing and is_equal_approx(state.remaining, source.get_active_cooldown_seconds()) and source.is_return_ready(), "tome starts cooldown on blink with immediate return availability")
		else:
			check(state.executing and state.remaining == 0 and not loadout.cast_weapon(source, Vector2.ZERO), "execution rejects recast; cooldown has not started")
		var body: Node2D = state.body.get_ref() if state.body is WeakRef else null
		for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"):
			effect.set_physics_process(false)
		if body != null:
			check(body.weapon != source and body.weapon.source_instance_id == source.instance_id, "cast owns immutable snapshot")
			var reach: float = body.weapon.get_attack_range()
			source.runtime_stats.area_size = 100
			check(body.weapon.get_attack_range() == reach and source.get_attack_range() > reach, "live stat changes apply only to next cast")
			if body is CampDagger:
				check(is_equal_approx(body.cut_end(body.cuts[-1]) * body.time_scale, 0.55) and body.cuts[1].windup == 0 and body.cuts[0].recover == 0, "three dagger cuts have no gaps and take 0.55s despite attack speed")
			if body is MeteorFlail:
				check(is_equal_approx(body.sequence_duration() * body.time_scale, 1.8), "three full flail swings take 1.8s")
			if body is MutantTentacle:
				check(is_equal_approx(body.motion_duration, 0.33), "tentacle preserves 1.5x animation duration")
			if body is RitualDomain:
				body._physics_process(5)
				loadout.tick(5)
				check(state.executing and state.remaining == 0 and body.marks_remaining == 5, "empty ritual waits indefinitely without cooling")
				var cast_origin := body.global_position
				var old_target := manager.spawn_enemy("enemy_mutated_grub", cast_origin + Vector2(100, 0))
				old_target.current_hp = 10000
				old_target.set_physics_process(false)
				player.global_position += Vector2(400, 0)
				body._physics_process(0.11)
				check(body.global_position == player.global_position and not body.contains_enemy(old_target) and old_target.current_hp == 10000 and body.marks_remaining == 5, "ritual follows movement and leaves old targets outside without spending marks")
				var target := manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(100, 0))
				target.modifier_stack.set_base_stat("max_hp", 10000)
				target.current_hp = 10000
				target.set_physics_process(false)
				body._physics_process(0.11)
				body._physics_process(0.34)
				check(body.marks_completed == 1 and target.current_hp < 10000 and body.global_position == player.global_position, "moving ritual hits new in-range target; no second mark before 0.35s")
				body._physics_process(0.02)
				check(body.marks_completed == 2, "ritual repeats living target at 0.35s")
				player.global_position += Vector2(400, 150)
				var target_hp := target.current_hp
				body._physics_process(0.36)
				loadout.tick(0.36)
				check(body.global_position == player.global_position and body.marks_remaining == 3 and target.current_hp == target_hp and state.executing and state.remaining == 0, "moving away mid-cast retains remaining marks without damage or cooldown")
				target.global_position = player.global_position + Vector2(100, 0)
			if body is CopperLamp:
				player.last_move_direction = Vector2.UP
				loadout.tick(0)
				body._physics_process(0.01)
				check(body.target == lamp_target and body.heading.is_equal_approx(Vector2.LEFT) and is_equal_approx(body.burst_duration, 5.4), "lamp follows nearest enemy and three projectiles spray for 5.4s")
			var before_age: float = body.elapsed if body is RitualDomain else body.age
			GameGlobal.set_runtime_flag("battle_runtime_paused", true)
			body._physics_process(2)
			loadout.tick(2)
			check((body.elapsed if body is RitualDomain else body.age) == before_age and state.executing, "pause freezes execution")
			GameGlobal.set_runtime_flag("battle_runtime_paused", false)
			for i in 800:
				if not is_instance_valid(body) or body.cancelled:
					break
				if body is MobilityWeaponRuntime:
					player._physics_process(0.01)
					for effect in body.get_children():
						if effect.has_method("_physics_process") and not effect.is_queued_for_deletion(): effect._physics_process(0.01)
					if body.return_ready: body.request_return()
				body._physics_process(0.01)
				if source.is_star_tome():
					loadout.tick(0.01)
					if not body.is_attacking(): break
		loadout.tick(0.2)
		if source.is_star_tome():
			check(not state.executing and state.remaining > 0 and state.remaining < state.total, "tome return keeps the first-blink cooldown running")
		else:
			check(not state.executing and is_equal_approx(state.remaining, source.get_active_cooldown_seconds()), "cooldown starts exactly once after authored action")
		var remaining: float = state.remaining
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		loadout.tick(1)
		check(state.remaining == remaining, "pause freezes cooldown")
		GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		if is_instance_valid(lamp_target):
			lamp_target.free()
		loadout.tick(remaining + 1)
		check(loadout.active_casting.can_cast(source) and source.volley_index == 1, "cooldown completes without repeat when no automatic target remains")
		manager.clear_battle_entities()
		for enemy in EnemyRegistry.get_registered_enemies().duplicate():
			enemy.free()
		await frames(2)
	# Two simultaneous independent casts, plus all ten supported HUD slots.
	for record in DataRegistry.get_table("weapons"):
		if loadout.weapon_instances.size() < 10 and not loadout.has_weapon(record.id):
			loadout.equip_weapon(record.id)
	check(loadout.cast_weapon(loadout.weapon_instances[0], player.global_position + Vector2(240, 0)) and loadout.cast_weapon(loadout.weapon_instances[1], player.global_position + Vector2(240, 0)), "different weapons can execute together")
	await frames()
	controller.select_slot(9)
	check((battle.hud as BattleHud).combat_bar.numbers[9].text == "0", "tenth battle slot maps to zero")
	await capture("01_combat_bar")
	get_tree().root.size = Vector2i(960, 540)
	get_tree().root.content_scale_size = Vector2i(960, 540)
	await frames(6)
	await capture("04_combat_960")
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	# Let embedded popup geometry settle before the next fixture frees the scene.
	await frames(4)

func _inventory_tooltips() -> void:
	player.add_relic("relic_worn_hemostatic_cloth")
	player.item_inventory.add_item_from_base("scroll_lightning", "tooltip_test")
	flow.request_esc_overlay()
	await get_tree().create_timer(0.4).timeout
	var esc := battle.esc_overlay
	var hud := battle.hud as BattleHud
	hud._set_drawer_open(true, false)
	var strip := esc.weapon_strip
	strip.set_process(false)
	strip._show_weapon_tooltip(loadout.weapon_instances[0], strip._weapon_buttons[0])
	await frames()
	check(strip.weapon_tooltip.is_visible_in_tree() and strip.weapon_tooltip.get_parent() is GameTooltipLayer and (strip.weapon_tooltip.get_parent() as CanvasLayer).layer > hud.layer, "Escape weapon tooltip renders above the attribute drawer")
	check(get_viewport().get_visible_rect().encloses(strip.weapon_tooltip.get_global_rect()), "weapon tooltip retains viewport placement after reparenting")
	await capture("06_weapon_tooltip")
	strip._hide_weapon_tooltip()
	esc._show_relic_tooltip(DataRegistry.get_record("relics", "relic_worn_hemostatic_cloth"), esc._relic_cells[0])
	await frames()
	check(esc.relic_tooltip.is_visible_in_tree() and esc.relic_tooltip.get_parent() is GameTooltipLayer, "Escape relic tooltip renders in shared foreground layer")
	await capture("07_relic_tooltip")
	esc._hide_relic_tooltip()
	var card := esc._item_cards[0] as ItemInventoryCard
	esc._show_item_tooltip(card, card._build_tooltip())
	await frames()
	check(esc._item_tooltip_panel.is_visible_in_tree() and esc._item_tooltip_panel.get_parent() is GameTooltipLayer, "Escape enchantment tooltip renders in shared foreground layer")
	await capture("08_inventory_tooltip")
	strip._show_weapon_tooltip(loadout.weapon_instances[0], strip._weapon_buttons[0])
	esc._show_relic_tooltip(DataRegistry.get_record("relics", "relic_worn_hemostatic_cloth"), esc._relic_cells[0])
	flow.close_esc_overlay()
	await get_tree().create_timer(0.4).timeout
	check(not strip.weapon_tooltip.visible and not esc.relic_tooltip.visible and esc._item_tooltip_panel == null, "closing Escape clears weapon relic and item tooltips")
	strip.set_process(true)


func _cleanup() -> void:
	await boot()
	player.set_physics_process(false)
	var elite := manager.spawn_enemy("enemy_elite_rusher", player.global_position + Vector2(220, 30))
	elite.set_physics_process(false)
	var ordinary := manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(-180, 0))
	ordinary.set_physics_process(false)
	manager.wave_time_left = 0.01
	manager._process(0.02)
	check(manager.cleanup_active and manager.cleanup_time_left == 10 and flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "living miniboss enters ten-second combat cleanup")
	check(manager.get_living_enemy_count() == 2, "cleanup counts both ordinary enemies and minibosses")
	(battle.hud as BattleHud)._process(0)
	check((battle.hud as BattleHud).cleanup_label.text == "剩余敌人：2", "cleanup HUD shows the count without reinforcement text")
	check(manager.spawn_enemy("enemy_mutated_grub") == null and manager.spawn_enemy("enemy_elite_rusher") == null, "cleanup blocks all reinforcements")
	var population := EnemyRegistry.get_registered_enemies().size()
	manager._process_spawn_timers(10)
	check(EnemyRegistry.get_registered_enemies().size() == population, "direct scheduler call cannot spawn in cleanup")
	await capture("05_cleanup")
	var lifetime_before_pause := manager.wave_challenges._enemy_clock
	flow.request_esc_overlay()
	manager._process(8)
	check(manager.cleanup_time_left == 10, "Escape freezes cleanup")
	check(manager.wave_challenges._enemy_clock == lifetime_before_pause, "Escape also freezes enemy lifespan accounting")
	flow.close_esc_overlay()
	flow.request_shared_reward_shop_popup(2)
	manager._process(8)
	check(manager.cleanup_time_left == 10, "reward popup freezes cleanup")
	check(manager.wave_challenges._enemy_clock == lifetime_before_pause, "reward popup does not inflate average enemy lifespan")
	flow.close_shared_reward_shop_popup()
	manager._process(9.9)
	check(manager.running and manager.cleanup_time_left > 0, "cleanup remains in combat until deadline")
	var gold := manager.current_gold
	var finishes := [0]
	manager.wave_end_absorb_started.connect(func(_id): finishes[0] += 1)
	manager._process(0.2)
	await frames(8)
	check(not manager.running and not manager.cleanup_active and manager.current_gold == gold, "timeout ends without rewarding un-killed enemies")
	var population_pressure := manager.wave_challenges.pressure
	check(population_pressure.cleanup_timed_out and population_pressure.cleanup_remaining_enemies == 2 and population_pressure.enemy_spawned_count >= 2, "real cleanup timeout snapshots remaining ordinary and elite enemies before deletion")
	check(is_equal_approx(manager.wave_challenges._enemy_clock - lifetime_before_pause, 10.0) and population_pressure.average_enemy_lifetime >= 10.0, "lifespan includes ten active cleanup seconds and clamps frame overshoot")
	check(flow.current_state != MainFlowCoordinator.STATE_WAVE_COMBAT, "timeout advances normal finance flow")
	manager._process(20)
	manager.finish_current_wave()
	check(finishes[0] == 1, "repeated timeout cannot settle twice")
	await boot()
	player.set_physics_process(false)
	elite = manager.spawn_enemy("enemy_elite_rusher", player.global_position + Vector2(300, 0))
	elite._physics_process(0.8) # Leave the existing spawn invulnerability first.
	elite.set_physics_process(false)
	ordinary = manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(-300, 0))
	ordinary.set_physics_process(false)
	manager.wave_time_left = 0
	check(manager.spawn_enemy("enemy_mutated_grub") == null and manager.spawn_enemy("enemy_elite_rusher") == null, "countdown boundary blocks spawns before cleanup transition")
	population = manager.get_living_enemy_count()
	manager._process_spawn_timers(10)
	check(manager.get_living_enemy_count() == population, "expired wave blocks direct scheduler before cleanup transition")
	manager._process(0.01)
	elite.take_damage(99999, "weapon_void_blade")
	manager._process(0.01)
	await frames(6)
	check(manager.running and manager.cleanup_active and manager.get_living_enemy_count() == 1, "last miniboss death does not skip remaining ordinary enemies")
	ordinary.take_damage(99999, "weapon_void_blade")
	manager._process(0.01)
	await frames(6)
	check(not manager.running, "last ordinary enemy death finishes cleanup early")
	check(not manager.wave_challenges.pressure.cleanup_timed_out and manager.wave_challenges.pressure.cleanup_remaining_enemies == 0, "early clear snapshot never qualifies as timeout with survivors")
	await boot()
	player.set_physics_process(false)
	ordinary = manager.spawn_enemy("enemy_mutated_grub", player.global_position + Vector2(300, 0))
	ordinary.set_physics_process(false)
	manager.wave_time_left = 0
	manager._process(0.01)
	check(manager.running and manager.cleanup_active and manager.cleanup_time_left == 10, "ordinary-only wave enters full ten-second cleanup")
	manager._process(10)
	await frames(8)
	check(not manager.running and flow.current_state != MainFlowCoordinator.STATE_WAVE_COMBAT, "ordinary-only cleanup forces finance at ten seconds")
	await boot()
	player.set_physics_process(false)
	manager.wave_time_left = 0
	manager._process(0.01)
	await frames(6)
	check(not manager.cleanup_active and not manager.running, "no living enemies finishes directly without cleanup")
	await boot()
	player.set_physics_process(false)
	finishes = [0]
	manager.wave_end_absorb_started.connect(func(_id): finishes[0] += 1)
	manager.wave_time_left = 0
	manager._process(0.01)
	player.take_damage(99999, "test_death_at_timeout")
	await frames(8)
	check(finishes[0] == 0 and flow.current_state == MainFlowCoordinator.STATE_BATTLE_RESULT, "death on timeout frame wins without wave rewards")
