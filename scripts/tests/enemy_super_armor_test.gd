extends "res://scripts/tests/pixel_combat_effect_test.gd"


func boss(scene: String, at: Vector2) -> EnemyController:
	var unit := load("res://scenes/enemy/" + scene + ".tscn").instantiate() as EnemyController
	host.add_child(unit)
	unit.position = at
	reset_boss(unit)
	return unit


func reset_boss(unit: EnemyController) -> void:
	unit.initialize(unit.enemy_id, unit.target_player)
	unit.set_physics_process(false)
	unit.sprite.show()
	unit.current_hp = 100000
	if unit is EliteRusher:
		unit.skill_state = "chase"
		unit._cooldown = 1000.0
	if unit is UnderworldWolf:
		unit.state = "chase"
		unit.breath_cooldown = 1000.0
		unit.leap_cooldown = 1000.0


func trigger(unit: EnemyController) -> void:
	unit.apply_freeze(1.0, {}, 0.0)
	unit._tick_super_armor(0.31)
	unit.apply_slow(2.0, 0.5, 0.0)
	unit._tick_super_armor(0.31)
	unit.apply_lightning_stun(1.0, 0.0)


func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2(1000, 0)])
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(10000, 0)
	var knight := boss("elite_rusher", Vector2.ZERO)
	var wolf := boss("underworld_wolf", Vector2(200, 0))
	for unit: EnemyController in [knight, wolf]:
		unit.target_player = player
		var label: String = unit.enemy_id + ": "
		for i in 100:
			unit.take_damage_with_feedback(1, "probe", false, Vector2.RIGHT, &"light")
			unit._physics_process(0.1)
		check(not unit.is_control_immune() and unit._super_armor_visual == null, label + "ten seconds of native hits never trigger armor")
		reset_boss(unit)
		unit.apply_freeze(0, {}, 0)
		unit.apply_slow(0, 0.5, 0)
		unit.apply_slow(1, 1, 0)
		unit.apply_lightning_stun(0, 0)
		unit.apply_blind(0, 0)
		unit.apply_knockback(Vector2.RIGHT, 450, 0, 0)
		check(unit._super_armor_control_times.is_empty(), label + "zero and ineffective controls do not count")
		unit.apply_freeze(1, {}, 100)
		check(not unit.is_control_immune() and is_equal_approx(unit._frozen_remaining, 2 * unit.get_control_multiplier()), label + "first freeze preserves control power and permanent resistance")
		unit.apply_blind(1, 0)
		unit.apply_lightning_stun(1, 0)
		unit.apply_knockback(Vector2.RIGHT, 450, 0.3, 0)
		check(not unit.is_control_immune() and unit._super_armor_control_times.size() == 1, label + "same-hit controls count once")
		unit._tick_super_armor(2.01)
		unit.apply_slow(1, 0.5, 0)
		check(not unit.is_control_immune() and unit._super_armor_control_times.size() == 1, label + "old controls expire outside two-second window")
		reset_boss(unit)
		unit.apply_freeze(3, {"wet_duration": 5}, 0)
		unit._tick_super_armor(0.31)
		unit.apply_slow(2, 0.5, 0)
		unit.apply_wet(5, 0.5, 0)
		unit.apply_blind(2, 0)
		unit.apply_lightning_stun(2, 0)
		unit.apply_knockback(Vector2.RIGHT, 450, 0.3, 0)
		check(not unit.is_control_immune(), label + "two spaced controls still allow crowd control")
		unit._tick_super_armor(0.31)
		unit.apply_freeze(1, {}, 0)
		var visual: Node2D = unit._super_armor_visual
		check(unit.is_control_immune() and visual.visible and is_equal_approx(visual.remaining, 2), label + "third spaced control activates exactly two seconds of armor")
		check(unit._stunned_remaining == 0 and not unit.has_status("frozen") and not unit.has_status("slowed") and not unit.has_status("blinded") and unit._knockback_timer == 0, label + "activation removes every existing hard control and recoil")
		check(unit._wet_slow_multiplier == 1 and unit._thaw_reaction_data.is_empty(), label + "activation removes wet slow and pending thaw control")
		check(not unit._lightning_visual.visible, label + "old stun visual disappears on armor activation")
		var original_material: Material = unit.sprite.material
		unit.sprite.flip_h = true
		unit.sprite.position += Vector2(3, -4)
		visual._sync()
		check(visual.outline.flip_h and visual.outline.transform == unit.sprite.transform and unit.sprite.material == original_material, label + "outline follows sprite without replacing material")
		unit.velocity = Vector2(23, 7)
		unit.apply_freeze(3, {"wet_duration": 5}, 1000)
		unit.apply_lightning_stun(3, 1000)
		unit.apply_blind(3, 1000)
		unit.apply_slow(3, 0.05, 1000)
		unit.apply_wet(5, 0.05, 1000)
		unit.apply_knockback(Vector2.RIGHT, 5000, 3, 1000)
		unit._apply_contact_knockback()
		var old_hp := unit.current_hp
		var pose := unit.sprite.transform
		var tint := unit.sprite.modulate
		unit.take_damage_with_feedback(10, "probe", false, Vector2.RIGHT, &"heavy")
		check(unit._stunned_remaining == 0 and not unit.has_status("frozen") and not unit.has_status("slowed") and not unit.has_status("blinded") and unit._knockback_timer == 0 and unit._wet_slow_multiplier == 1, label + "all controls are blocked even with extreme control power")
		check(unit.velocity == Vector2(23, 7) and unit.current_hp < old_hp, label + "immune boss still takes damage without physical recoil")
		check(unit.sprite.transform == pose and unit.sprite.modulate == tint and unit.sprite.offset.length() > 0 and not unit._hit_visual.flash_white, label + "armored small boss shakes without white or pose changes")
		unit.apply_burning(3, 5, "burn")
		old_hp = unit.current_hp
		unit._process_burning(0.5)
		check(unit.current_hp < old_hp and unit.has_status("burning"), label + "armor does not prevent burn damage")
		var hole := BlackHoleEffect.new()
		host.add_child(hole)
		hole.set_process(false)
		hole.position = unit.position + Vector2(100, 0)
		hole._targets = [unit]
		var old_position := unit.position
		hole._process(0.1)
		check(unit.position == old_position, label + "actual black hole cannot move an armored boss")
		hole.queue_free()
		unit._tick_super_armor(0.5)
		var pulse_count: int = visual.pulses
		for i in 20:
			unit.apply_freeze(1, {}, 0)
			unit.show_control_resistance()
		check(is_equal_approx(visual.remaining, 1.5) and visual.pulses == pulse_count, label + "repeated hits neither extend armor nor restart caption")
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		unit._physics_process(3.0)
		visual._process(3.0)
		check(is_equal_approx(unit._super_armor_remaining, 1.5) and is_equal_approx(visual.remaining, 1.5), label + "pause freezes both state and outline")
		GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		unit._tick_super_armor(0.5)
		check(unit.is_control_immune() and visual.visible and is_equal_approx(visual.remaining, 1), label + "immunity and outline remain after the old one-second deadline")
		unit._tick_super_armor(0.5)
		check(unit.is_control_immune() and visual.visible and is_equal_approx(visual.remaining, 0.5), label + "immunity and outline remain through the second second")
		unit._tick_super_armor(0.5)
		check(not unit.is_control_immune() and not visual.visible, label + "immunity and outline end together at two seconds")
		unit.apply_freeze(1, {}, 0)
		check(is_equal_approx(unit._frozen_remaining, unit.get_control_multiplier()), label + "controls work again immediately after armor")
		for i in 16:
			unit._tick_super_armor(0.3)
			unit.apply_lightning_stun(1, 0)
		check(not unit.is_control_immune() and unit._super_armor_control_times.is_empty(), label + "five-second cooldown does not bank control attempts")
		unit._tick_super_armor(0.21)
		trigger(unit)
		check(unit.is_control_immune() and visual.pulses == pulse_count + 1, label + "three fresh controls can trigger again after cooldown")
		reset_boss(unit)
		check(not unit.is_control_immune() and not visual.visible and unit._super_armor_control_times.is_empty(), label + "reinitialization resets immunity and pressure")
		trigger(unit)
		if unit is EliteRusher:
			unit.skill_state = "windup"
			unit._state_time = 0.2
		else:
			unit.state = "breath_charge"
			unit.state_time = 0.2
		unit.apply_freeze(3, {}, 100)
		unit.apply_lightning_stun(3, 100)
		unit._physics_process(0.1)
		var skill_time: float = unit._state_time if unit is EliteRusher else unit.state_time
		check(is_equal_approx(skill_time, 0.3), label + "real boss skill timer keeps advancing under control attacks")
		reset_boss(unit)
		var pull := BlackHoleEffect.new()
		host.add_child(pull)
		pull.set_process(false)
		pull._duration = 5
		pull.position = unit.position + Vector2(100, 0)
		pull._targets = [unit]
		old_position = unit.position
		for i in 10: pull._process(0.01)
		check(unit.position != old_position and not unit.is_control_immune(), label + "per-frame pull cannot instantly trigger armor")
		unit._tick_super_armor(0.31)
		pull._process(0.01)
		unit._tick_super_armor(0.31)
		old_position = unit.position
		pull._process(0.01)
		check(unit.is_control_immune() and unit.position == old_position, label + "sustained pull eventually triggers armor and stops on triggering frame")
		pull.queue_free()
	reset_boss(knight)
	reset_boss(wolf)
	knight.position = Vector2.ZERO
	wolf.position = Vector2(200, 0)
	var shock := ExplosionEffect.new()
	host.add_child(shock)
	shock._weapon = weapon
	shock._damage_event = event
	shock._shockwave()
	check(not knight.is_control_immune() and not knight._super_armor_visual.visible and knight._knockback_timer == 0, "immune shockwave does not trigger armor or move knight")
	var wolf_hp := wolf.current_hp
	WindBladeEffect.spawn(host, wolf.position, Vector2.RIGHT, 480, 0.46, weapon, event)
	for child in host.get_children():
		if child is WindBladeEffect:
			child.set_process(false)
			child._damage_path_enemies()
	check(not wolf.is_control_immune() and not wolf._super_armor_visual.visible and wolf.current_hp < wolf_hp and wolf._knockback_timer == 0, "wind deals damage without false armor activation")
	trigger(enemies[0])
	check(not enemies[0].is_control_immune() and enemies[0]._super_armor_visual == null and enemies[0]._stunned_remaining == 1, "ordinary enemies retain full control durations and never gain armor")
	trigger(knight)
	knight.take_damage(1000000, "lethal")
	check(not knight.is_control_immune() and not knight._super_armor_visual.visible, "death clears armor immediately")
	trigger(wolf)
	wolf.fade_out_and_free()
	check(not wolf.is_control_immune() and not wolf._super_armor_visual.visible, "wave cleanup clears armor immediately")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.2).timeout
	CampProgression.end_transient_session()
	print("ENEMY_SUPER_ARMOR checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
