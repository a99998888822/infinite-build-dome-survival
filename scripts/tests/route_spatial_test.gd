extends Node2D

const OLD = preload("res://scripts/tests/fixtures/route_spatial_original_obstacle.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + message)

func rock(parent: Node, at: Vector2, size: Vector2) -> BattleTerrainObstacle:
	var obstacle := BattleTerrainObstacle.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	obstacle.add_child(shape)
	obstacle.position = at
	parent.add_child(obstacle)
	return obstacle

func equivalent(current: BattleTerrainObstacle.Route, original: RefCounted, body: CharacterBody2D,
		target: Vector2, label: String) -> void:
	check(current.direction(body, target) == original.direction(body, target), label + " direction")
	check(current.obstacle == original.obstacle and current.bounds == original.bounds
		and current.target == original.target and current.points == original.points, label + " route state")

func run() -> void:
	seed(20261021)
	var host := Node2D.new()
	add_child(host)
	var foreign := SubViewport.new()
	add_child(foreign)
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	host.add_child(body)
	var current := BattleTerrainObstacle.Route.new()
	var original := OLD.Route.new()
	equivalent(current, original, body, Vector2.ZERO, "empty registry")
	var obstacles: Array[BattleTerrainObstacle] = []
	for i in 30:
		obstacles.append(rock(host if i % 6 else foreign,
			Vector2((i % 6) * 160 - 400, (i / 6) * 180 - 350), Vector2(45 + i, 20 + i)))
	# Coincident obstacles exercise the first-in-registry distance tie rule.
	obstacles.append(rock(host, Vector2.ZERO, Vector2(80, 40)))
	obstacles.append(rock(host, Vector2.ZERO, Vector2(80, 40)))
	for step in 1200:
		if step % 100 == 0:
			match (step / 100) % 4:
				0: shape.shape = CircleShape2D.new()
				1: shape.shape = RectangleShape2D.new()
				2: shape.shape = CapsuleShape2D.new()
				3: shape.shape = null
		shape.position = Vector2(step % 7 - 3, -5)
		shape.rotation = step * 0.023
		shape.scale = Vector2(.5 + (step % 5) * .4, 1.3)
		body.rotation = step * .015
		body.scale = Vector2(-1.2, .7) if step % 3 == 0 else Vector2.ONE
		body.position = Vector2(randf_range(-800, 800), randf_range(-800, 800))
		var target := Vector2(randf_range(-800, 800), randf_range(-800, 800))
		if step % 5 == 0: target.x = body.position.x
		if step % 7 == 0: target.y = body.position.y
		if step % 11 == 0: target = body.position
		# Mutations must take effect immediately, without an intervening frame.
		var moved := obstacles[step % obstacles.size()]
		moved.position += Vector2(3, -2)
		moved.rotation += .04
		moved.scale = Vector2(-.8, 1.2) if step % 2 == 0 else Vector2.ONE
		host.position = Vector2(step % 4, step % 3)
		host.rotation = step * .0003
		if step % 13 == 0:
			moved.footprint = Rect2(-20, -10, .01 if step % 26 == 0 else 45, 30)
		equivalent(current, original, body, target, "mutable " + str(step))
	# Exact padded edges, shallow intersections, tiny and inverted rectangles.
	body.transform = Transform2D.IDENTITY
	host.transform = Transform2D.IDENTITY
	shape.transform = Transform2D.IDENTITY
	shape.shape = null
	for size in [Vector2(80, 40), Vector2(.01, .01), Vector2(-50, -80)]:
		obstacles.back().footprint = Rect2(Vector2.ZERO, size)
		var bounds: Rect2 = obstacles.back().routing_bounds(body)
		for delta in [-.501, -.5, -.499, 0.0, .499, .5, .501]:
			for vertical in [false, true]:
				body.position = bounds.position + (Vector2(delta, -200) if vertical else Vector2(-200, delta))
				var target := body.position + (Vector2(0, 500) if vertical else Vector2(500, 0))
				equivalent(current, original, body, target, "boundary")
	# Streaming retires colliders from the registry before deferred deletion.
	var retired: BattleTerrainObstacle = obstacles.pop_back()
	BattleTerrainObstacle.active.erase(retired)
	equivalent(current, original, body, Vector2.ZERO, "retired collider")
	retired.queue_free()
	for obstacle in obstacles: obstacle.free()
	equivalent(current, original, body, Vector2.ZERO, "unloaded terrain")
	host.free()
	foreign.free()
	await get_tree().process_frame
	check(BattleTerrainObstacle.active.is_empty(), "registry cleanup")
	if "--benchmark" in OS.get_cmdline_user_args(): benchmark()
	print("ROUTE_SPATIAL checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

# Paired CPU throughput only, not a simulated long frame. Each repetition
# exercises 48/72/96 separate routes against three streamed-style rectangles.
func benchmark() -> void:
	var host := Node2D.new()
	add_child(host)
	for at in [Vector2(-350, -100), Vector2(60, 0), Vector2(280, 160)]:
		rock(host, at, Vector2(65, 28))
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CapsuleShape2D.new()
	body.add_child(shape)
	host.add_child(body)
	var positions: Array[Vector2] = []
	for i in 96: positions.append(Vector2.from_angle(i * 2.399963) * (180 + (i % 16) * 28))
	var rows: Array = []
	for count in [48, 72, 96]:
		var originals: Array = []
		var currents: Array = []
		for i in count:
			originals.append(OLD.Route.new())
			currents.append(BattleTerrainObstacle.Route.new())
		for warmup in [originals, currents]:
			for i in count:
				body.position = positions[i]
				warmup[i].direction(body, Vector2.ZERO)
		for old in [true, false, false, true, false, true, true, false]:
			var routes: Array = originals if old else currents
			var begin := Time.get_ticks_usec()
			for step in 180:
				var destination := Vector2.from_angle((step / 60) * PI * .5) * 180
				for i in count:
					body.position = positions[(i + step) % count]
					routes[i].direction(body, destination)
			rows.append({"count": count, "before": old, "queries": count * 180,
				"usec": Time.get_ticks_usec() - begin})
		for i in count:
			check(originals[i].obstacle == currents[i].obstacle and originals[i].points == currents[i].points,
				"paired CPU route state")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	host.free()
