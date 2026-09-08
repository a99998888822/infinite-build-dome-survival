extends Node2D

const ORBIT_PARTICLES: int = 8

var _enemy: Node = null
var _remaining: float = 0.65
var _duration: float = 0.65
var _elapsed: float = 0.0


static func attach(parent: Node2D, duration: float, visual_script: Script) -> Node2D:
	if parent == null or visual_script == null:
		return null
	var visual: Node2D = visual_script.new() as Node2D
	parent.add_child(visual)
	visual.set("_duration", maxf(duration, 0.15))
	visual.set("_remaining", maxf(duration, 0.15))
	return visual


func refresh(duration: float = 0.65) -> void:
	_duration = maxf(_duration, duration)
	_remaining = maxf(_remaining, duration)


func _ready() -> void:
	z_index = 100
	_enemy = get_parent()
	position = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(_remaining / maxf(_duration, 0.01), 0.0, 1.0)
	var body_radius := 10.0
	if _enemy != null:
		var collision_shape := _enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape != null and collision_shape.shape is CircleShape2D:
			body_radius = (collision_shape.shape as CircleShape2D).radius
	var center := Vector2(0.0, -body_radius - 10.0)
	var orbit_radius := clampf(body_radius * 0.48, 7.0, 12.0)
	var orbit_x := orbit_radius * 1.35
	var orbit_y := orbit_radius * 0.62
	draw_set_transform(center, 0.0, Vector2(1.35, 0.65))
	draw_circle(Vector2.ZERO, orbit_radius + 4.0, Color(0.15, 0.48, 1.0, 0.12 * fade))
	draw_arc(Vector2.ZERO, orbit_radius, _elapsed * 5.0, _elapsed * 5.0 + TAU, 32, Color(0.25, 0.68, 1.0, 0.9 * fade), 2.2, true)
	draw_arc(Vector2.ZERO, orbit_radius + 2.0, -_elapsed * 3.2, -_elapsed * 3.2 + PI * 0.65, 20, Color(0.80, 0.95, 1.0, 0.9 * fade), 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for index in ORBIT_PARTICLES:
		var angle := _elapsed * 5.0 + float(index) * TAU / float(ORBIT_PARTICLES)
		var point := center + Vector2(cos(angle) * orbit_x, sin(angle) * orbit_y)
		draw_circle(point, 2.0, Color(0.70, 0.92, 1.0, fade))
