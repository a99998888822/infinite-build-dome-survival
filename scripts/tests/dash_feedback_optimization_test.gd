extends Node
const BEFORE = preload("res://scripts/tests/fixtures/dash_baseline_hit_feedback.gd")
const AFTER = preload("res://scripts/effects/combat_hit_feedback.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var old := BEFORE.new()
	var updated := AFTER.new()
	seed(10192026)
	for scenario in 32:
		old._chains.clear()
		updated._chains.clear()
		for batch in 4:
			var hits: Dictionary = {}
			for id in range(batch * 6, 96 + batch * 6):
				var position := Vector2((id % 12) * 6, (id / 12) * 6)
				match scenario % 4:
					1: position.x += (id % 3) * 900
					2: position = Vector2(id * 40, 0)
					3: position = Vector2(randf_range(-500, 500), randf_range(-500, 500))
				hits[id] = position
			var attack := 7 if batch < 3 else 8
			var at := batch * 0.1
			check(old._accumulate(attack, hits, at) == updated._accumulate(attack, hits, at), "same milestones %d/%d" % [scenario, batch])
			check(old._chains == updated._chains and old.last_local_count == updated.last_local_count, "same centers/order/members %d/%d" % [scenario, batch])
			check(BEFORE.local_hit_count(hits.values()) == AFTER.local_hit_count(hits.values()), "same local density %d/%d" % [scenario, batch])
	var edge := {1: Vector2.ZERO, 2: Vector2(240, 0), 3: Vector2(240.001, 0), 4: Vector2(-240, 0)}
	old._chains.clear()
	updated._chains.clear()
	check(old._accumulate(1, edge, 0.0) == updated._accumulate(1, edge, 0.0) and old._chains == updated._chains, "inclusive radius and first-center tie")
	var rows: Array = []
	for count in [96, 192]:
		var hits: Dictionary = {}
		for i in count: hits[i] = Vector2((i % 16) * 6, (i / 16) * 6)
		for baseline in [true, false, false, true, false, true, true, false]:
			var instance: Node = old if baseline else updated
			var total := 0
			var at := Time.get_ticks_usec()
			for i in 64:
				instance._chains.clear()
				total += instance._accumulate(i + 1, hits, 0.0)
			rows.append({"count": count, "baseline": baseline, "calls": 64, "ms": (Time.get_ticks_usec() - at) / 1000.0, "checksum": total})
			check(total == 64 * count, "all unique victims retained")
	old.free()
	updated.free()
	FileAccess.open("artifacts/reports/dash_feedback_cpu_metrics.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "rows": rows}, "\t"))
	print("DASH_FEEDBACK_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
