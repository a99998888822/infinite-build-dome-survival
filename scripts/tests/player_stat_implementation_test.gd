extends "res://scripts/tests/pixel_combat_effect_test.gd"

const REACTIONS = preload("res://scripts/effects/element_reaction_resolver.gd")

class ResistantEnemy extends EnemyController:
	func get_control_multiplier() -> float: return 0.25


func make_player() -> PlayerController:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	return player


func _run() -> void:
	CampProgression.begin_transient_session()
	_test_direct_controls()
	_test_shield_and_finance()
	await _test_control_sources()
	if is_instance_valid(host): host.queue_free()
	await frames()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.15).timeout
	CampProgression.end_transient_session()
	print("PLAYER_STAT_IMPLEMENTATION_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_direct_controls() -> void:
	var player := make_player()
	for resistant in [false, true]:
		for power in [0, 25, 100]:
			var enemy: EnemyController = ResistantEnemy.new() if resistant else EnemyController.new()
			enemy.auto_initialize_on_ready = false
			add_child(enemy)
			enemy.set_physics_process(false)
			enemy.target_player = player
			player.modifier_stack.set_base_stat("control_power", power)
			var factor: float = (1 + power / 100.0) * (0.25 if resistant else 1.0)
			enemy.apply_slow(3.0, 0.6)
			check(is_equal_approx(enemy._slowed_remaining, 3 * factor), "slow duration scales before resistance")
			check(is_equal_approx(enemy._slow_multiplier, 0.9 if resistant else 0.6), "control power does not increase slow potency")
			enemy.apply_wet(5.0, 0.8)
			check(is_equal_approx(enemy._wet_remaining, 5 * factor), "wet slow duration scales")
			enemy.apply_freeze(3.0)
			check(is_equal_approx(enemy._frozen_remaining, 3 * factor), "freeze duration bonus survives the base duration cap")
			enemy.apply_blind(5.0)
			check(is_equal_approx(enemy._blinded_remaining, 5 * factor), "blind duration bonus survives the base duration cap")
			enemy.apply_light(5.0)
			check(is_equal_approx(enemy._light_remaining, 5.0), "non-control light marking duration does not scale")
			enemy.apply_lightning_stun(3.0)
			check(is_equal_approx(enemy._stunned_remaining, 3 * factor), "stun duration bonus survives the base duration cap")
			enemy.apply_knockback(Vector2.RIGHT, 450, 0.3)
			check(is_equal_approx(enemy._knockback_timer, 0.3 * factor), "explicit pushback duration scales")
			check(is_equal_approx(enemy._knockback_velocity.x, 112.5 if resistant else 450.0), "pushback initial speed stays unchanged")
			enemy._knockback_timer = 0
			enemy._apply_weapon_knockback(Vector2.RIGHT)
			check(is_equal_approx(enemy._knockback_timer, EnemyController.HIT_KNOCKBACK_SECONDS * factor), "native hit pushback also scales")
			enemy._apply_contact_knockback()
			check(is_equal_approx(enemy._knockback_timer, enemy.knockback_seconds * factor), "contact repulsion duration scales")
			enemy._slowed_remaining = 0
			enemy.apply_slow(3.0, 0.6, 0.0)
			check(is_equal_approx(enemy._slowed_remaining, 0.75 if resistant else 3.0), "explicit zero-power source overrides the live player")
			enemy.free()
	player.free()


func _test_shield_and_finance() -> void:
	var player := make_player()
	player.modifier_stack.set_base_stat("shield", 7)
	player.modifier_stack.set_base_stat("finance", 80)
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	check(manager.finance_system.principal == 80, "finance initializes starting principal")
	player.add_relic("relic_dead_shield_badge")
	player.add_relic("relic_dead_shield_badge")
	player.add_relic("relic_void_tentacle")
	check(player.current_shield == 0, "acquiring shield stats waits for the next wave")
	manager.start_next_wave()
	check(player.current_shield == 39 and player.current_shield_capacity == 39, "wave start sums base and stacked relic shields exactly once")
	player.grant_shield(100)
	player.add_runtime_modifier({"id": "shield_runtime_test", "source_type": "test", "source_id": "test", "target_scope": "player", "stat": "shield", "operation": "add_flat", "value": 3, "duration": -1, "stack_rule": "stack_add"})
	check(player.current_shield == 139, "mid-wave stat change does not refill or overwrite current shield")
	player._shield_regen_remainder = 0.5
	manager.start_next_wave()
	check(player.current_shield == 42 and player.current_shield_capacity == 42 and player._shield_regen_remainder == 0, "next wave reads dynamic shields and discards prior excess and remainder")
	player.modifier_stack.set_base_stat("shield", 2)
	manager.start_next_wave()
	check(player.current_shield == 37, "decreasing the shield stat affects the following wave")
	var principal := manager.finance_system.principal
	player.modifier_stack.set_base_stat("finance", 999)
	check(manager.finance_system.principal == principal, "changing finance mid-run does not alter the live balance")
	player.modifier_stack.set_base_stat("currency_gain_percent", 50)
	var gold := manager.current_gold
	manager.add_exp_and_gold(0, 10)
	check(manager.current_gold == gold + 15, "pickup gold keeps its existing percentage bonus")
	manager.apply_gold_delta(10, "fixed_reward_test")
	check(manager.current_gold == gold + 25, "fixed rewards do not inherit the pickup bonus")
	manager.free()
	player.free()


func _test_control_sources() -> void:
	var player := make_player()
	player.modifier_stack.set_base_stat("control_power", 100)
	var source := WeaponInstance.new()
	source.initialize("weapon_void_blade", player)
	var cast := source.make_cast_copy()
	var captured := cast.calculate_damage_events()[0]
	player.modifier_stack.set_base_stat("control_power", 0)
	check(captured.control_power == 100 and captured.duplicate_event().control_power == 100, "damage event and its children preserve cast control power")
	await setup([Vector2.ZERO])
	var enemy := enemies[0]
	enemy.target_player = player
	REACTIONS.apply_element(enemy, "ice", {"damage_event": captured})
	check(is_equal_approx(enemy._slowed_remaining, 6.0), "ice applies the source snapshot instead of the current player stat")
	REACTIONS.apply_element(enemy, "water", {"damage_event": captured})
	check(is_equal_approx(enemy._frozen_remaining, 2.0), "water plus ice freeze scales once")
	enemy._process_freeze(2.0)
	check(is_equal_approx(enemy._wet_remaining, 10.0), "thaw keeps source control power without double-scaling")
	for kind in ["water_wave", "ice_field", "black_hole", "wind_blade"]:
		await setup([Vector2.ZERO])
		weapon.runtime_stats["control_power"] = 100
		event.control_power = 100
		var effect := spawn_effect(kind)
		if kind == "water_wave":
			check(is_equal_approx(enemies[0]._wet_remaining, 10), "water effect forwards control power")
		elif kind == "ice_field":
			check(is_equal_approx(enemies[0]._slowed_remaining, 6), "ice field forwards control power")
		elif kind == "black_hole":
			await frames()
			check(is_equal_approx(effect._duration, 1.7) and is_equal_approx(enemies[0]._blinded_remaining, 4), "black hole doubles pull lifetime and blindness separately")
		elif kind == "wind_blade":
			effect._hit_targets.clear()
			effect._damage_path_enemies()
			check(is_equal_approx(enemies[0]._knockback_timer, 0.6), "wind blade pushback gets the source bonus")
	await setup([Vector2.ZERO])
	weapon.runtime_stats["control_power"] = 100
	event.control_power = 100
	CombatEffectWorld._apply_wind(host, enemies[0], weapon, event, Vector2.ZERO, Vector2.RIGHT, "", false)
	check(is_equal_approx(enemies[0]._knockback_timer, 0.6), "direct wind contact gets the source bonus")
	ExplosionEffect.spawn(host, Vector2.ZERO, weapon, event)
	await frames()
	check(is_equal_approx(enemies[0]._knockback_timer, 0.6), "shockwave pushback gets the source bonus")
	LightningParticleEffect.spawn(host, Vector2.ZERO, enemies[0], weapon, event, Vector2.RIGHT)
	await frames()
	check(is_equal_approx(enemies[0]._stunned_remaining, 1.0), "lightning chain scales actual stun duration")
	player.free()
