extends "res://scripts/tests/pixel_combat_effect_test.gd"
## General feedback replaces legacy categories; retain damage/control invariants.
const SETTINGS = preload("res://scripts/effects/combat_feedback_settings.gd")
const IMPACT = preload("res://scripts/effects/combat_impact_r02.gd")
const PULSE = preload("res://scripts/ui/weapon_pulse_r02.gd")

class MitigatedEnemy extends EnemyController:
	func take_damage(raw: int, source: String = "", critical: bool = false, direction: Vector2 = Vector2.ZERO, components: Array[int] = [], light_bonus: bool = true) -> int:
		return super.take_damage(raw / 2, source, critical, direction, components, light_bonus)


func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2.ZERO])
	Engine.time_scale = 0
	var candidate := enemies[0]
	var pose := candidate.sprite.transform
	var tint := candidate.sprite.modulate
	var at := candidate.global_position
	var receipts: Array = []
	candidate.damage_received.connect(func(id: String, amount: int): receipts.append([id, amount]))
	for enabled in [false, true]:
		GameGlobal.set_runtime_flag(SETTINGS.FLAG, enabled)
		for kind: StringName in [&"", &"light", &"heavy", &"ritual", &"sustain"]:
			var hp := candidate.current_hp
			var count := receipts.size()
			for i in 10:
				if kind == &"": candidate.take_damage(5, "native", i == 0, Vector2.RIGHT)
				else: candidate.take_damage_with_feedback(5, "native", i == 0, Vector2.RIGHT, kind)
			check(candidate.current_hp == hp - 50 and receipts.size() == count + 10, "%s: all damage and receipts survive flag=%s" % [kind, enabled])
			check(candidate.sprite.transform == pose and candidate.sprite.modulate == tint and candidate.sprite.offset.length() > 0 and candidate.sprite.material == candidate._hit_visual.white_material, "%s: general white/shake preserves animation pose and tint" % kind)
			check(candidate.global_position == at and candidate.velocity == Vector2.ZERO and candidate._knockback_timer == 0, "%s: no automatic damage knockback" % kind)
			check(not candidate.has_meta(&"combat_feedback_r02") and get_tree().get_nodes_in_group("combat_impacts_r02").is_empty(), "%s: no response node or contact decoration" % kind)
	check(EnemyController.active_damage_numbers > 0, "normal and critical damage numbers remain")
	candidate._hit_visual._process(1.0)
	check(candidate._hit_visual.elapsed == 0, "a long pre-contact frame cannot consume the first white pose")
	Engine.time_scale = 1
	await get_tree().create_timer(1.1).timeout
	check(candidate.sprite.transform == pose and candidate.sprite.modulate == tint and candidate.sprite.offset == Vector2.ZERO and candidate.sprite.material == null, "general response restores offset and material")
	Engine.time_scale = 0
	seed(1204)
	randf_range(-14.0, 14.0)
	randf_range(-4.0, 4.0)
	randf_range(-0.08, 0.08)
	var expected_random := randf()
	seed(1204)
	candidate.take_damage(3, "rng")
	check(is_equal_approx(randf(), expected_random), "removal preserves later damage and drop random rolls")
	var nested := [false]
	candidate.damage_received.connect(func(id: String, _amount: int):
		if id == "outer":
			candidate.take_damage(2, "nested")
			nested[0] = true)
	var hp := candidate.current_hp
	candidate.take_damage_with_feedback(4, "outer", false, Vector2.RIGHT, &"heavy")
	check(nested[0] and candidate.current_hp == hp - 6 and candidate.sprite.transform == pose, "reentrant damage retains accounting and the current pose")
	candidate.apply_burning(3, 5, "burn")
	hp = candidate.current_hp
	candidate._process_burning(0.5)
	check(candidate.current_hp < hp and candidate.sprite.transform == pose and candidate.sprite.modulate == tint and candidate._hit_visual.elapsed == 0, "burn damage uses the same general response")
	candidate.clear_burning()
	candidate.apply_knockback(Vector2.LEFT, 450, 0.3, 0)
	var control_velocity := candidate.velocity
	var control_timer := candidate._knockback_timer
	candidate.take_damage_with_feedback(5, "native", false, Vector2.RIGHT, &"heavy")
	check(control_velocity.x < 0 and control_timer > 0 and candidate.velocity == control_velocity and candidate._knockback_timer == control_timer, "explicit skill knockback survives an overlapping native hit")
	var special := MitigatedEnemy.new()
	special.auto_initialize_on_ready = false
	host.add_child(special)
	special.current_hp = 100
	check(special.take_damage_with_feedback(20, "probe", false, Vector2.ZERO, &"heavy") == 10, "compatibility wrapper retains subclass mitigation")
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
	check(icon.scale.x < 1 and pulse.pulses == 1, "independent ritual source icon still compresses")
	pulse._physics_process(0.06)
	check(icon.scale.x > 1, "ritual source icon still rebounds")
	pulse._physics_process(0.20)
	check(icon.scale == Vector2.ONE and icon.modulate == Color.WHITE, "ritual source icon restores cleanly")
	candidate.current_hp = 1
	candidate.take_damage_with_feedback(10, "lethal", false, Vector2.RIGHT, &"heavy")
	check(not candidate.alive and candidate.sprite.transform == pose and candidate.sprite.modulate == tint and candidate._hit_visual.elapsed == 0, "lethal hit retains feedback and the normal death fade")
	IMPACT.spawn(host, Vector2.ZERO, &"ground", Vector2.RIGHT)
	var decorations := get_tree().get_nodes_in_group("combat_impacts_r02")
	check(decorations.size() == 1, "independent hammer ground debris remains")
	var manager := WaveManager.new()
	host.add_child(manager)
	manager.clear_battle_entities()
	check(decorations.all(func(node: Node2D): return node.is_queued_for_deletion() and not node.visible), "wave cleanup still removes ground debris")
	GameGlobal.clear_runtime_flag(SETTINGS.FLAG)
	Engine.time_scale = 1
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("COMBAT_GENERAL_FEEDBACK_COMPATIBILITY checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
