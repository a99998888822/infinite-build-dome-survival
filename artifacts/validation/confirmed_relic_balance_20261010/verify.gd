extends Node

const ROOT := "res://artifacts/validation/confirmed_relic_balance_20261010/"
var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)
		push_error(note)

func _run() -> void:
	CampProgression.begin_transient_session()
	var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "confirmed_values.json"))
	var previous: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "before_relics.json"))
	var old := {}
	for row: Dictionary in previous: old[row.id] = row
	for id: String in specs:
		var spec: Dictionary = specs[id]
		var player := PlayerController.new()
		player.auto_initialize_on_ready = false
		add_child(player)
		player.initialize_from_character("character_void_hunter")
		player.set_physics_process(false)
		var affected: Dictionary = spec.stats.duplicate()
		for effect: Dictionary in old[id].effects:
			if not affected.has(effect.stat): affected[effect.stat] = 0.0
		var baseline := {}
		for stat: String in affected: baseline[stat] = player.get_stat(stat)
		var record := DataRegistry.get_record("relics", id)
		check(record.rarity == old[id].rarity and record.max_stack == old[id].max_stack, id + " preserves rarity and stack limit")
		for amount in [1, 2]:
			if int(spec.max_stack) == 1 and amount == 2:
				check(not player.add_relic(id), id + " rejects excess copy")
				continue
			var preview := player.create_stat_preview_copy()
			check(preview.add_relic(id) and player.add_relic(id), id + " can be acquired")
			player.relic_system.refresh_effects()
			for stat: String in affected:
				var expected := StatDefinitions.clamp_stat_value(stat, float(baseline[stat]) + float(affected[stat]) * amount)
				check(is_equal_approx(player.get_stat(stat), expected), "%s copy %d applies %s and removes retired effects" % [id, amount, stat])
				check(is_equal_approx(preview.get_stat(stat), player.get_stat(stat)), id + " preview agrees for " + stat)
			preview.free()
		player.free()
	var out := FileAccess.open(ROOT + "runtime_result.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"relics": specs.size(), "checks": checks, "failures": failures}, "\t"))
	out.close()
	print("CONFIRMED_RELIC_BALANCE_COMPLETE relics=%d checks=%d failures=%d" % [specs.size(), checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
