extends Node

class CustomEvent extends DamageEvent:
	func to_dictionary() -> Dictionary:
		var data := super.to_dictionary()
		data.damage = 123
		data.tags.append("custom")
		return data

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var player := PlayerController.new()
	var source := DamageEvent.create({
		"source_player": player, "source_weapon_id": "copy_test", "damage": 57,
		"original_damage": 31, "element_damage_bonus": 8, "elemental_damage_scale": 1.7,
		"damage_area_scale": 2.2, "control_power": 19.0, "damage_kind": "electric",
		"is_critical": true, "tags": ["fire", "ranged"], "hit_position": Vector2(11, -33),
		"attack_context": {"hit_feedback_id": 37, "nested": {"count": 1}},
		"enchantment_start": 3, "split_child": true,
	})
	for scenario in 4:
		if scenario == 1:
			source.element_damage_bonus = -8
			source.elemental_damage_scale = -1.5
			source.damage_area_scale = -3.0
		elif scenario == 2:
			source.damage = -2
			source.original_damage = 0
			source.elemental_damage_scale = 0.0
			source.damage_area_scale = 0.0
			source.control_power = -1.0
		elif scenario == 3:
			source.tags.clear()
			source.source_player = null
		var expected := DamageEvent.create(source.to_dictionary())
		var actual := source.duplicate_event()
		check(actual != source and actual.get_script() == DamageEvent, "independent base event %d" % scenario)
		for key in expected.to_dictionary():
			check(actual.to_dictionary()[key] == expected.to_dictionary()[key], "same field %s scenario %d" % [key, scenario])
		check(not is_same(actual.tags, source.tags), "independent typed tags %d" % scenario)
		check(is_same(actual.attack_context, source.attack_context), "shared attack context %d" % scenario)
		actual.tags.append("copy_only")
		check(not source.tags.has("copy_only"), "copy tags cannot modify original %d" % scenario)
		actual.attack_context.nested.count += 1
		check(source.attack_context.nested.count == scenario + 2, "nested attack context still shared %d" % scenario)
	var custom := CustomEvent.new()
	var custom_copy := custom.duplicate_event()
	check(custom_copy.damage == 123 and custom_copy.tags == ["custom"], "custom serializer is respected")
	var child := source.continue_after_split({"enchantment_start": 7})
	check(child.split_child and child.enchantment_start == 7 and source.enchantment_start == 3, "split child fields are independent")
	check(is_same(child.attack_context, source.attack_context), "split child shares attack context")
	source.tags.assign(["fire", "electric", "ranged"])
	source.damage = 57
	for i in 1024:
		source.duplicate_event()
		DamageEvent.create(source.to_dictionary())
	var rows: Array = []
	for baseline in [true, false, false, true, false, true, true, false]:
		await get_tree().process_frame
		var total := 0
		var at := Time.get_ticks_usec()
		for i in 32768:
			var copy := DamageEvent.create(source.to_dictionary()) if baseline else source.duplicate_event()
			total += copy.damage + copy.enchantment_start + copy.tags.size()
		rows.append({"baseline": baseline, "ms": (Time.get_ticks_usec() - at) / 1000.0, "checksum": total})
		check(total == rows[0].checksum, "benchmark checksum")
	FileAccess.open("artifacts/reports/damage_event_copy_metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"rows": rows, "calls_each": 32768, "checks": checks, "failures": failures}, "\t"))
	player.free()
	print("DAMAGE_EVENT_COPY checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
