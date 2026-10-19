extends "res://scripts/tests/pixel_combat_effect_test.gd"
## Deliberately coincident frozen targets expose the reaction's multiplicative
## fanout. This is a count audit, not a reproduction of an old wall-clock frame.
const OLD_EVENT = preload("res://scripts/tests/fixtures/uncached_damage_event.gd")
var output := "artifacts/reports/damage_fanout_audit.json"
var phase := ""
var counts := {}
var damage_sum := 0
var beam_list: Array[LightReflectionEffect] = []

func received(_source: String, amount: int) -> void:
	counts[phase] = int(counts.get(phase, 0)) + 1
	damage_sum += amount

func track_child(node: Node) -> void:
	if node is LightReflectionEffect:
		node.set_process(false)
		beam_list.append(node)

func exercise_count(count: int, swords: int) -> Dictionary:
	var positions: Array = []
	positions.resize(count)
	positions.fill(Vector2.ZERO)
	await setup(positions)
	CombatHitFeedback.active = false
	counts.clear()
	damage_sum = 0
	beam_list.clear()
	host.child_entered_tree.connect(track_child)
	for enemy in enemies:
		enemy.current_hp = 1000000
		enemy.apply_freeze(3.0)
		enemy.damage_received.connect(received)
	phase = "sword"
	for i in swords:
		var sword := spawn_effect("light_sword") as LightSwordEffect
		sword._land()
	check(beam_list.size() == count * swords, "each sword emits one reflection per frozen target")
	phase = "reflection"
	for beam in beam_list: beam._process(0.3)
	check(int(counts.get("sword", 0)) == swords * count, "direct sword hit count")
	check(int(counts.get("reflection", 0)) == swords * count * count, "reflection fanout is swords times targets squared")
	var before := damage_sum
	for beam in beam_list: beam._process(0.01)
	check(damage_sum == before, "one beam never damages the same target twice")
	check(beam_list.size() == swords * count, "reflection damage does not recursively spawn reflections")
	return {"targets": count, "swords": swords, "reflections": beam_list.size(),
		"damage_calls": counts.duplicate(), "total_damage": damage_sum,
		"method": "coincident frozen targets; actual light sword land and reflection sweeps; one script frame; independent per-beam ledgers"}

func check_source_arithmetic() -> void:
	var current := DamageEvent.new()
	var old := OLD_EVENT.new()
	for raw in [0, 1, 10, 999, 1000001]:
		for bonus in [0, 13]:
			for scale in [0.0, 0.5, 1.0, 1.37]:
				for value in [old, current]:
					value.original_damage = raw
					value.element_damage_bonus = bonus
					value.elemental_damage_scale = scale
				for multiplier in [3.5, 3.5, 0.65, -1.0, 0.0, 3.5]:
					check(current.get_elemental_damage(multiplier) == old.get_elemental_damage(multiplier), "source arithmetic matches reference")
	for field in ["original_damage", "element_damage_bonus", "elemental_damage_scale"]:
		current.get_elemental_damage(3.5)
		old.set(field, old.get(field) + 1)
		current.set(field, current.get(field) + 1)
		check(current.get_elemental_damage(3.5) == old.get_elemental_damage(3.5), "public mutation updates " + field)
	var copy := current.duplicate_event()
	check(copy.get_elemental_damage(3.5) == current.get_elemental_damage(3.5), "duplicate computes matching source damage")
	var prior := current.get_elemental_damage(3.5)
	copy.original_damage += 100
	check(copy.get_elemental_damage(3.5) != prior and current.get_elemental_damage(3.5) == prior, "duplicate source inputs are independent")
	current.original_damage = -10
	old.original_damage = -10
	current.element_damage_bonus = 0
	old.element_damage_bonus = 0
	check(current.get_elemental_damage(3.5) == old.get_elemental_damage(3.5), "negative public input preserves clamp")

func _run() -> void:
	CampProgression.begin_transient_session()
	check_source_arithmetic()
	var rows: Array = []
	for config in [[16, 1], [32, 1], [96, 1], [96, 3]]:
		rows.append(await exercise_count(config[0], config[1]))
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"rows": rows, "checks": checks, "failures": failures}, "\t"))
	host.queue_free()
	await frames()
	beam_list.clear()
	enemies.clear()
	weapon = null
	event = null
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("DAMAGE_FANOUT_AUDIT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
