extends Node2D
class_name WindBladeEffect

const DEFAULT_SPEED: float = 480.0
const DEFAULT_LIFETIME: float = 0.46
const DEFAULT_RADIUS: float = 28.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = DEFAULT_SPEED
var _lifetime: float = DEFAULT_LIFETIME
var _elapsed: float = 0.0


static func spawn(parent: Node, hit_position: Vector2, direction: Vector2, speed: float = DEFAULT_SPEED, lifetime: float = DEFAULT_LIFETIME) -> void:
	if parent == null:
		return
	var effect := WindBladeEffect.new()
	parent.add_child(effect)
	effect.global_position = hit_position
	effect._direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	effect._speed = maxf(speed, 1.0)
	effect._lifetime = maxf(lifetime, 0.1)
	effect.rotation = effect._direction.angle()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	global_position += _direction * _speed * delta
	queue_redraw()
	if _elapsed >= _lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_elapsed / _lifetime, 0.0, 1.0)
	var fade := 1.0 - progress
	var radius := DEFAULT_RADIUS * (1.0 + progress * 0.32)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for index in range(19):
		var ratio := float(index) / 18.0
		var angle := lerpf(-PI * 0.72, PI * 0.72, ratio)
		outer.append(Vector2.from_angle(angle) * radius)
		inner.append(Vector2.from_angle(angle) * radius * 0.56)
	var shape := outer.duplicate()
	for index in range(inner.size() - 1, -1, -1):
		shape.append(inner[index])
	draw_colored_polygon(shape, Color(0.72, 0.98, 1.0, 0.18 * fade))
	draw_polyline(outer, Color(0.82, 1.0, 1.0, 0.96 * fade), 4.0, true)
	draw_polyline(inner, Color(0.24, 0.78, 0.88, 0.64 * fade), 2.0, true)
	draw_line(Vector2(-radius * 0.12, 0.0), Vector2(radius * 0.92, 0.0), Color(0.96, 1.0, 1.0, 0.72 * fade), 1.0, true)
