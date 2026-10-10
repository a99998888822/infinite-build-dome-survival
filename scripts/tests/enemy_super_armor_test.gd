extends "res://scripts/tests/pixel_combat_effect_test.gd"


func boss(scene: String, at: Vector2) -> EnemyController:
	var unit := load("res://scenes/enemy/" + scene + ".tscn").instantiate() as EnemyController
	host.add_child(unit)
	unit.position = at
	unit.set_physics_process(false)
	unit.sprite.show()
	if unit is EliteRusher: unit.skill_state = "chase"
	if unit is UnderworldWolf: unit.state = "chase"
	return unit


func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2(1000, 0)])
	var knight := boss("elite_rusher", Vector2.ZERO)
	var wolf := boss("underworld_wolf", Vector2(200, 0))
	enemies[0].apply_freeze(1.0, {}, 0.0)
	check(enemies[0]._super_armor_visual == null, "ordinary enemies never show super armor")
	knight.apply_slow(0.0, 0.5, 0.0)
	check(knight._super_armor_visual == null, "zero duration does not trigger feedback")
	for unit in [knight, wolf]:
		var resistance: float = unit.get_control_multiplier()
		var original_material: Material = unit.sprite.material
		unit.apply_freeze(1.0, {}, 100.0)
		var visual = unit._super_armor_visual
		visual.set_process(false)
		check(visual.visible and visual.pulses == 1, "real freeze triggers resistance caption")
		check(is_equal_approx(unit._frozen_remaining, 2 * resistance), "freeze preserves control power and boss resistance")
		visual._process(0.4)
		unit.apply_slow(2.0, 0.5, 0.0)
		check(visual.pulses == 1 and visual.remaining == 2.0 and is_equal_approx(visual.elapsed, 0.4), "repeated control extends outline without caption spam")
		check(is_equal_approx(unit._slowed_remaining, 2 * resistance), "slow keeps existing duration")
		unit.sprite.flip_h = true
		unit.sprite.rotation = 0.04
		unit.sprite.position += Vector2(3, -4)
		visual._sync()
		check(visual.outline.flip_h and visual.outline.transform == unit.sprite.transform, "outline tracks live mirrored and shaken sprite")
		check(unit.sprite.material == original_material, "overlay leaves the body material untouched")
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		visual._process(1.0)
		check(visual.remaining == 2.0, "battle pause freezes the overlay")
		GameGlobal.set_runtime_flag("battle_runtime_paused", false)
		visual._process(2.1)
		check(not visual.visible, "overlay disappears two seconds after last resistance")
		unit.apply_knockback(Vector2.RIGHT, 450, 0.3, 100.0)
		check(visual.visible and visual.pulses == 2, "new control burst restores caption")
		check(is_equal_approx(unit._knockback_timer, 0.6 * resistance), "knockback keeps existing duration")
		visual.clear()
		unit._knockback_timer = 0.0
		unit.take_damage_with_feedback(1, "probe", false, Vector2.RIGHT, &"light")
		check(visual.visible and unit.has_meta(unit.FEEDBACK_R02.META), "native hit resistance coexists with R02 hit feedback")
		unit.FEEDBACK_R02.interrupt(unit)
		unit._knockback_timer = 0.0
		visual.clear()
	# Test the actual pure-displacement enchantment, including range exclusion.
	var shock := ExplosionEffect.new()
	host.add_child(shock)
	shock._weapon = weapon
	shock._damage_event = event
	shock._shockwave()
	check(knight._super_armor_visual.visible and not wolf._super_armor_visual.visible, "immune shockwave target shows feedback only inside radius")
	check(knight._knockback_timer == 0 and wolf._knockback_timer == 0, "shockwave does not move immune bosses")
	var old_hp := wolf.current_hp
	WindBladeEffect.spawn(host, wolf.position, Vector2.RIGHT, 480, 0.46, weapon, event)
	for child in host.get_children():
		if child is WindBladeEffect:
			child.set_process(false)
			child._damage_path_enemies()
	check(wolf._super_armor_visual.visible and wolf.current_hp < old_hp and wolf._knockback_timer == 0, "wind deals damage, shows resistance, and preserves displacement immunity")
	wolf._super_armor_visual.clear()
	var hole := BlackHoleEffect.new()
	host.add_child(hole)
	hole.set_process(false)
	hole._targets = [wolf]
	hole._pull_speed = 100
	var old_position := wolf.position
	hole._process(0.1)
	check(wolf._super_armor_visual.visible and is_equal_approx(old_position.distance_to(wolf.position), 2.5), "black hole shows resistance and preserves reduced pull distance")
	knight.initialize("enemy_elite_rusher")
	check(not knight._super_armor_visual.visible, "reinitialization clears old feedback")
	knight.sprite.show()
	knight.skill_state = "chase"
	knight.apply_slow(1, 0.5, 0)
	knight.take_damage(100000, "lethal")
	check(not knight._super_armor_visual.visible, "knight death clears overlay immediately")
	wolf.fade_out_and_free()
	check(not wolf._super_armor_visual.visible, "wave cleanup clears overlay immediately")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.2).timeout
	CampProgression.end_transient_session()
	print("ENEMY_SUPER_ARMOR checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
