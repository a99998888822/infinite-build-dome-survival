extends Node2D
var checks := 0
var failures := 0
var lamp: CopperLamp
var actors: Array[Node2D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func original_order() -> Array[Node]:
	var nodes := EnemyRegistry.get_registered_enemies().duplicate()
	nodes.sort_custom(func(a: Node, b: Node): return lamp.global_position.distance_squared_to((a as Node2D).global_position) < lamp.global_position.distance_squared_to((b as Node2D).global_position))
	return nodes

func clear_actors() -> void:
	for actor in actors:
		EnemyRegistry.unregister_enemy(actor)
		actor.free()
	actors.clear()

func layout(count: int, kind: String) -> void:
	clear_actors()
	for i in count:
		var actor := Node2D.new()
		add_child(actor)
		match kind:
			"random": actor.position = Vector2(rng.randi_range(-500, 500), rng.randi_range(-500, 500))
			"ties": actor.position = [Vector2(90, 0), Vector2(0, 90), Vector2(-90, 0), Vector2(0, -90)][i % 4]
			"same": actor.position = Vector2(100, 50)
			"ascending": actor.position = Vector2(i / 4, 0)
			"descending": actor.position = Vector2((count - i) / 4, 0)
		actors.append(actor)
		EnemyRegistry.register_enemy(actor)

func run() -> void:
	CampProgression.begin_transient_session()
	rng.seed = 20261020
	lamp = CopperLamp.new()
	add_child(lamp)
	lamp.set_physics_process(false)
	var rows: Array = []
	for count in [0, 1, 2, 7, 15, 16, 17, 31, 32, 64, 96, 192, 384, 1024]:
		for kind in ["random", "ties", "same", "ascending", "descending"]:
			layout(count, kind)
			for pose in [Transform2D.IDENTITY, Transform2D(0.35, Vector2(1.2, 0.8), 0.1, Vector2(43, -27))]:
				transform = pose
				lamp.position = Vector2.ZERO
				var registry := EnemyRegistry.get_registered_enemies().duplicate()
				check(lamp._ordered_damage_targets() == original_order(), "sort order mismatch %s %d" % [kind, count])
				check(EnemyRegistry.get_registered_enemies() == registry, "registry order changed")
				lamp.position = Vector2(76, -80)
				if not actors.is_empty(): actors[0].position += Vector2(120, -50)
				check(lamp._ordered_damage_targets() == original_order(), "movement must be read on next sort")
			transform = Transform2D.IDENTITY
			if count not in [96, 384, 1024] or kind not in ["random", "ties"]: continue
			var timings: Array = []
			for round_id in 4:
				for before in ([true, false] if round_id % 2 == 0 else [false, true]):
					var at := Time.get_ticks_usec()
					var ordered: Array[Node]
					for repeat in 40:
						ordered = original_order() if before else lamp._ordered_damage_targets()
					timings.append({"before":before,"ms":(Time.get_ticks_usec()-at)/1000.0,"sorts":40})
					check(ordered == original_order(), "timed order differs")
			rows.append({"count":count,"layout":kind,"timings":timings})
	clear_actors()
	lamp.free()
	FileAccess.open("res://artifacts/reports/lamp_order_cpu.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	CampProgression.end_transient_session()
	print("LAMP_ORDER checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
