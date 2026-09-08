extends Node2D
class_name LightReflectionEffect

const DEFAULT_RADIUS: float = 220.0
const DEFAULT_DURATION: float = 0.58
const DEFAULT_DAMAGE_MULTIPLIER: float = 3.5

var _damage_event: DamageEvent = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER
var _elapsed: float = 0.0
var _hit_targets: Dictionary = {}
var _sweep_start: float = -PI * 0.5
var _sweep_end: float = PI * 0.5


static func spawn(parent: Node, origin: Vector2, direction: Vector2, damage_event: DamageEvent, radius: float = DEFAULT_RADIUS, damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER) -> void:
	if parent == null or damage_event == null:
		return
	var effect := LightReflectionEffect.new()
	parent.add_child(effect)
	effect.global_position = origin
	effect.rotation = direction.angle() if not direction.is_zero_approx() else 0.0
	effect._damage_event = damage_event
	effect._radius = maxf(radius, 48.0)
	effect._damage_multiplier = maxf(damage_multiplier, 1.0)
	effect.queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	_damage_sweep()
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func _damage_sweep() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var sweep_angle := lerpf(_sweep_start, _sweep_end, progress)
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or _hit_targets.has(enemy.get_instance_id()):
			continue
		var offset := global_position.direction_to(enemy.global_position)
		var distance := global_position.distance_to(enemy.global_position)
		if distance > _radius:
			continue
		var angle := atan2(offset.y, offset.x) - rotation
		while angle > PI:
			angle -= TAU
		while angle < -PI:
			angle += TAU
		if angle < _sweep_start or angle > sweep_angle:
			continue
		_hit_targets[enemy.get_instance_id()] = true
		var damage := maxi(1, int(roundi(float(_damage_event.original_damage) * _damage_multiplier)))
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, offset)


func _draw() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := 1.0 - progress * 0.72
	var sweep_angle := lerpf(_sweep_start, _sweep_end, progress)
	var beam_end := Vector2.from_angle(sweep_angle) * _radius
	var beam_direction := beam_end.normalized()
	var perpendicular := beam_direction.orthogonal()
	draw_line(Vector2.ZERO, beam_end, Color(1.0, 1.0, 1.0, 0.12 * fade), 18.0, true)
	draw_line(Vector2.ZERO, beam_end, Color(1.0, 1.0, 1.0, 0.92 * fade), 7.0, true)
	draw_line(perpendicular * 3.0, beam_end + perpendicular * 3.0, Color(0.88, 0.98, 1.0, 0.9 * fade), 2.0, true)
	for index in range(18):
		var ratio := float(index) / 17.0
		var angle := lerpf(_sweep_start, sweep_angle, ratio)
		var distance := _radius * (0.26 + fmod(float(index) * 0.137, 0.66))
		var point := Vector2.from_angle(angle) * distance
		var color := Color.from_hsv(fmod(float(index) * 0.17 + 0.56, 1.0), 0.72, 1.0, 0.9 * fade)
		draw_circle(point, 2.0 + float(index % 2), color)
