extends "res://scripts/tests/pixel_combat_effect_test.gd"
const RESPONSE = preload("res://scripts/effects/combat_feedback_r02.gd")
const PULSE = preload("res://scripts/ui/weapon_pulse_r02.gd")

class MitigatedEnemy extends EnemyController:
	func take_damage(raw: int, source: String = "", critical: bool = false, direction: Vector2 = Vector2.ZERO, components: Array[int] = [], light_bonus: bool = true) -> int:
		return super.take_damage(raw / 2, source, critical, direction, components, light_bonus)


func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
	check(RESPONSE.enabled(), "approved feedback is enabled without a review override")
	await setup([Vector2.ZERO, Vector2(100, 0)])
	Engine.time_scale = 0
	var baseline := enemies[0]
	var candidate := enemies[1]
	var baseline_origin := baseline.sprite.position
	var candidate_origin := candidate.sprite.position
	var receipts: Array = []
	candidate.damage_received.connect(func(id: String, amount: int): receipts.append([id, amount]))
	GameGlobal.set_runtime_flag(RESPONSE.SETTINGS.FLAG, false)
	seed(1204)
	for i in 10: baseline.take_damage_with_feedback(5, "lamp", false, Vector2.RIGHT, &"sustain")
	var next_random := randf()
	check(not baseline.has_meta(RESPONSE.META), "review disabled leaves normal feedback in place")
	GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
	check(RESPONSE.enabled(), "clearing a comparison override restores production feedback")
	seed(1204)
	for i in 10:
		candidate.take_damage_with_feedback(5, "lamp", false, Vector2.RIGHT, &"sustain")
		candidate.get_meta(RESPONSE.META)._physics_process(0.06)
	var response = candidate.get_meta(RESPONSE.META)
	response.set_physics_process(false)
	check(is_equal_approx(next_random, randf()), "feedback does not alter the global combat RNG stream")
	check(candidate.current_hp == baseline.current_hp and receipts.size() == 10, "all ten sustained ticks still deal and report damage")
	check(candidate._knockback_velocity == baseline._knockback_velocity and candidate._knockback_timer == baseline._knockback_timer, "sustained feedback throttle preserves physical knockback")
	check(response.response_count == 2 and response.suppressed_count == 8, "continuous contact accents at 280 ms intervals")
	check(candidate.position == Vector2(100, 0) and baseline.sprite.position == baseline_origin, "response never translates the collision body")
	response._physics_process(0.5)
	candidate.take_damage_with_feedback(5, "lamp", false, Vector2.RIGHT, &"sustain")
	check(response.response_count == 3, "contact after a gap immediately restores the first-hit accent")
	response._physics_process(0.1)
	candidate.take_damage_with_feedback(9, "hammer", false, Vector2.RIGHT, &"heavy")
	check(response.active_kind == &"heavy" and response.duration > 0.2, "heavy hit has a longer response")
	var count: int = response.response_count
	candidate.take_damage_with_feedback(5, "lamp", false, Vector2.RIGHT, &"sustain")
	candidate.take_damage_with_feedback(7, "knife", false, Vector2.RIGHT, &"light")
	check(response.response_count == count and response.active_kind == &"heavy", "smaller overlapping hits preserve the heavy visual accent")
	var at: float = response.age
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	response._physics_process(0.4)
	check(response.age == at, "battle pause freezes the response")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	response._physics_process(0.5)
	check(candidate.sprite.position == candidate_origin and candidate.sprite.rotation == 0 and candidate.sprite.modulate == candidate._base_sprite_modulate, "response restores the exact sprite pose and color")
	candidate.take_damage_with_feedback(7, "knife", false, Vector2.RIGHT, &"light")
	check(response.duration == 0.12, "light hit returns promptly")
	candidate.take_damage(3, "reaction")
	check(response.age >= response.duration and candidate.sprite.position == candidate_origin, "independent reaction damage retains its original feedback")
	var nested := [false]
	candidate.damage_received.connect(func(id: String, _amount: int):
		if id == "outer":
			candidate.take_damage(2, "nested")
			nested[0] = candidate._next_feedback_kind == &"")
	candidate.take_damage_with_feedback(4, "outer", false, Vector2.RIGHT, &"light")
	check(nested[0], "reentrant reaction does not inherit the native feedback category")
	var special := MitigatedEnemy.new()
	special.auto_initialize_on_ready = false
	host.add_child(special)
	special.current_hp = 100
	check(special.take_damage_with_feedback(20, "probe", false, Vector2.ZERO, &"heavy") == 10, "wrapper respects enemy subclass damage overrides")
	var card := Panel.new()
	host.add_child(card)
	card.size = Vector2(64, 64)
	var icon := TextureRect.new()
	card.add_child(icon)
	icon.size = Vector2(48, 48)
	var pulse := PULSE.new()
	card.add_child(pulse)
	pulse.configure(icon, weapon)
	weapon.feedback_mark.emit(0)
	check(icon.scale.x < 1 and pulse.pulses == 1, "real source signal compresses the weapon icon")
	pulse._physics_process(0.06)
	check(icon.scale.x > 1, "weapon icon rebounds after the mark")
	pulse._physics_process(0.20)
	check(icon.scale == Vector2.ONE and icon.modulate == Color.WHITE, "weapon icon restores cleanly")
	GameGlobal.set_runtime_flag(RESPONSE.SETTINGS.FLAG, false)
	weapon.feedback_mark.emit(1)
	check(pulse.pulses == 1, "disabled review produces no icon pulse")
	GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
	candidate.current_hp = 1
	candidate.take_damage_with_feedback(10, "lethal", false, Vector2.RIGHT, &"heavy")
	check(not candidate.alive and response.age >= response.duration, "lethal damage hands the sprite over to the death fade")
	var decorations := get_tree().get_nodes_in_group("combat_impacts_r02")
	var loadout := WeaponLoadout.new()
	host.add_child(loadout)
	loadout._clear_weapon_runtime(weapon)
	check(not decorations.is_empty() and decorations.all(func(node: Node): return not node.is_in_group("weapon_runtime_effects")), "contact decoration does not enter weapon ownership cleanup")
	var manager := WaveManager.new()
	host.add_child(manager)
	manager.clear_battle_entities()
	check(decorations.all(func(node: Node2D): return node.is_queued_for_deletion() and not node.visible), "wave transition clears all contact decoration immediately")
	GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
	Engine.time_scale = 1
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("COMBAT_FEEDBACK_R02 checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
