extends "res://scripts/tests/pixel_combat_effect_test.gd"

const LEGACY = preload("res://scripts/tests/fixtures/legacy_light_reflection_effect.gd")
const CURRENT = preload("res://scripts/effects/light_reflection_effect.gd")
const SHARED_BASELINE = preload("res://scripts/tests/fixtures/shared_baseline_reflection.gd")
const OLD_PIXEL = preload("res://scripts/tests/fixtures/legacy_reflection_pixel_effect_draw.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
var trace: Array = []
var beams: Array[Node2D] = []
var step_id := 0
var beam_id := 0
var mutation := ""
var mutated := false
var target_parent: Node2D

func receive(source: String, damage: int, target: int) -> void:
	trace.append([step_id, beam_id, target, damage, source])
	if mutated or mutation.is_empty(): return
	mutated = true
	match mutation:
		"move_target": enemies[1].global_position = Vector2(20, -5)
		"move_parent": target_parent.position += Vector2(-140, 0)
		"move_beam": beams[beam_id].position += Vector2(140, 0)
		"change_start": beams[beam_id].set("_sweep_start", 0.0)
		"spawn":
			var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
			target_parent.add_child(enemy)
			enemy.global_position = Vector2(20, -5)
			enemy.current_hp = 10000
			enemy.set_physics_process(false)
			enemy.damage_received.connect(receive.bind(enemies.size()))
			enemies.append(enemy)
		"remove_next": EnemyRegistry.unregister_enemy(enemies[1])
		"remove_current": EnemyRegistry.unregister_enemy(enemies[target])
		"kill_next": enemies[1].alive = false
		"revive_next": enemies[1].alive = true
		"event":
			event.original_damage += 7
			enemies[1].apply_light()

func spawn_beam(factory: Script, origin: Vector2, direction: Vector2, radius: float) -> Node2D:
	factory.spawn(host, origin, direction, event, radius)
	var result: Node2D
	for child in host.get_children():
		if child.get_script() == factory: result = child
	# Keep beams outside the target ancestor so moving it changes their contacts.
	result.reparent(self)
	result.set_process(false)
	beams.append(result)
	return result

func exercise(factory: Script, mode: String, sparse: bool) -> Dictionary:
	var positions: Array = [Vector2(10, -10), Vector2(160, -8), Vector2(40, 0), Vector2(70, 30), Vector2(0, -220), Vector2(220, 0), Vector2(220.00002, 0)]
	for i in (153 if mode == "mask_boundaries" else 41):
		if mode == "mask_boundaries": positions.append(Vector2(30 + (i % 12) * 10, -60 + ((i / 12) % 12) * 10))
		else: positions.append(Vector2(1500 + i * 8, 0) if sparse else Vector2.from_angle(float(i) * 0.17) * (60.0 + i * 3.0))
	await setup(positions)
	CombatHitFeedback.active = false
	target_parent = host
	for i in enemies.size():
		enemies[i].damage_received.connect(receive.bind(i))
		if i % 3 == 0: enemies[i].apply_light()
	if mode in ["revive_next", "revive_late"]: enemies[1].alive = false
	trace.clear()
	beams.clear()
	mutation = "" if mode in ["moving", "boundaries", "mask_boundaries", "ledger_reset", "revive_late"] else mode
	mutated = false
	for i in 24:
		var radius := 220.0 if i % 3 != 0 else 110.0
		var beam := spawn_beam(factory, Vector2.ZERO, Vector2.RIGHT if i % 4 != 3 else Vector2.LEFT, radius)
		beam.set("_damage_multiplier", 3.5 + (i % 3) * 0.25)
		if i % 4 != 0:
			var independent := event.duplicate_event()
			independent.original_damage += i
			independent.source_weapon_id = "source_%d" % i
			beam.set("_damage_event", independent)
		if mode == "boundaries":
			# Values collapse if a cache key or stored angle is rounded to float32.
			beam.set("_orientation", 0.25 + (1e-10 if i % 2 == 0 else -1e-10))
			beam.set("_sweep_end", -0.25 + (1e-10 if i % 4 < 2 else -1e-10))
			beam.set("_radius", 220.0 + (1e-7 if i % 3 == 0 else -1e-7))
	for step in 42:
		step_id = step
		if mode == "ledger_reset" and step == 20:
			for beam in beams: beam.get("_hit_targets").clear()
		if mode == "revive_late" and step == 25: enemies[1].alive = true
		if mode == "moving":
			enemies[1].position = Vector2(90 + step * 2, 20 - step)
			target_parent.position = Vector2(step % 5, step % 3)
		for i in beams.size():
			beam_id = i
			var beam := beams[i]
			if beam.is_queued_for_deletion(): continue
			if mode == "filter_budget": CURRENT.QUERY_CACHE._filter_count = CURRENT.QUERY_CACHE.MAX_FILTERS
			if mode == "moving" and i % 3 == 0: beam.position = Vector2(step % 7, 0)
			beam.call("_process", 1.0 / 60.0)
	var hp: Array = []
	var lights: Array = []
	var ledgers: Array = []
	var visual: Array = []
	for enemy in enemies:
		hp.append(enemy.current_hp)
		lights.append(enemy.has_status("light"))
	for beam in beams:
		ledgers.append([beam.get("_hit_targets").size(), beam.is_queued_for_deletion()])
		var tier: int = beam.get("_visual_tier")
		visual.append([tier, beam.get("_visual_detail") if tier != 3 else -1, beam.is_in_group(PIXEL.DETAIL_GROUP)])
	return {"trace": trace.duplicate(true), "hp": hp, "lights": lights, "ledgers": ledgers, "visual": visual}

func check_pixel_registration() -> void:
	await setup([])
	# Include both distance boundaries, mixed kinds and queued peers.
	for i in 120:
		var probe := Node2D.new()
		host.add_child(probe)
		probe.position = Vector2(160 if i % 2 == 0 else 159.99, i % 4)
		var kind := "reflection" if i % 3 == 0 else "other"
		var expected := OLD_PIXEL.register(probe, kind)
		probe.remove_from_group(PIXEL.DETAIL_GROUP)
		var actual := PIXEL.register(probe, kind)
		check(actual == expected, "pixel tier %d" % i)
		if i % 7 == 0: probe.queue_free()

func _run() -> void:
	CampProgression.begin_transient_session()
	for sparse in [false, true]:
		for mode in ["", "moving", "boundaries", "move_target", "move_parent", "move_beam", "change_start", "spawn", "remove_next", "remove_current", "kill_next", "revive_next", "event"]:
			var old := await exercise(LEGACY, mode, sparse)
			var updated := await exercise(CURRENT, mode, sparse)
			for key in old:
				check(old[key] == updated[key], "%s sparse=%s %s" % [mode, sparse, key])
			check(not updated.trace.is_empty(), "nonempty contact trace " + mode)
	# Cover signed bit 63, multiple 64-bit words, independent cohort ledgers,
	# late revival without a spatial change, and explicit ledger reset.
	for mode in ["mask_boundaries", "ledger_reset", "revive_late", "filter_budget"]:
		var old := await exercise(SHARED_BASELINE, mode, false)
		var updated := await exercise(CURRENT, mode, false)
		for key in old:
			check(old[key] == updated[key], "mask cache %s %s" % [mode, key])
		check(not updated.trace.is_empty(), "nonempty mask trace " + mode)
		if mode == "mask_boundaries":
			for index in [63, 64, 127, 128, 159]:
				check(updated.trace.any(func(hit): return hit[2] == index), "contact across mask word boundary %d" % index)
	await check_pixel_registration()
	await setup([Vector2(50, 0)])
	beams.clear()
	var beam := spawn_beam(CURRENT, Vector2.ZERO, Vector2.RIGHT, 220)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	beam.call("_process", 1.0)
	check(beam.get("_elapsed") == 0.0 and enemies[0].current_hp == 10000, "pause keeps clock and HP")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	beam.call("_process", 0.58)
	check(beam.is_queued_for_deletion() and enemies[0].current_hp == 9650, "full lifetime applies damage and expires")
	host.queue_free()
	await frames()
	CombatHitFeedback.clear()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("REFLECTION_OPTIMIZATION_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
