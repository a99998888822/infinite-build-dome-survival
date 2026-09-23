extends Node2D
class_name LightReflectionEffect

const DEFAULT_RADIUS: float = 220.0
const DEFAULT_DURATION: float = 0.58
const DEFAULT_DAMAGE_MULTIPLIER: float = 3.5
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")

var _damage_event: DamageEvent = null
var _radius: float = DEFAULT_RADIUS
var _duration: float = DEFAULT_DURATION
var _damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER
var _elapsed: float = 0.0
var _hit_targets: Dictionary = {}
var _sweep_start: float = -PI * 0.5
var _sweep_end: float = PI * 0.5
var _orientation: float = 0.0
var _visual_detail: int = 2


static func spawn(parent: Node, origin: Vector2, direction: Vector2, damage_event: DamageEvent, radius: float = DEFAULT_RADIUS, damage_multiplier: float = DEFAULT_DAMAGE_MULTIPLIER) -> void:
	if parent == null or damage_event == null:
		return
	var effect := LightReflectionEffect.new()
	parent.add_child(effect)
	effect.global_position = origin
	effect._orientation = direction.angle() if not direction.is_zero_approx() else 0.0
	effect._visual_detail = PIXEL.register(effect, "reflection")
	effect.z_index = 81
	effect._damage_event = damage_event
	effect._radius = maxf(radius, 48.0)
	effect._damage_multiplier = maxf(damage_multiplier, 1.0)
	AudioManager.play_reaction_sfx("reflection")
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
		var angle := atan2(offset.y, offset.x) - _orientation
		while angle > PI:
			angle -= TAU
		while angle < -PI:
			angle += TAU
		if angle < _sweep_start or angle > sweep_angle:
			continue
		_hit_targets[enemy.get_instance_id()] = true
		var damage := _damage_event.get_elemental_damage(_damage_multiplier)
		enemy.take_damage(damage, _damage_event.source_weapon_id, false, offset)


func _draw() -> void:
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := 1.0 - progress * 0.72
	var sweep_angle := lerpf(_sweep_start, _sweep_end, progress)
	var beam_end := Vector2.from_angle(sweep_angle + _orientation) * _radius
	var beam_direction := beam_end.normalized()
	var perpendicular := beam_direction.orthogonal()
	PIXEL.line(self, Vector2.ZERO, beam_end, Color(0.19, 0.43, 0.65, 0.65 * fade), 10)
	PIXEL.line(self, Vector2.ZERO, beam_end, Color(0.65, 0.95, 1.0, 0.98 * fade), 6)
	PIXEL.line(self, Vector2.ZERO, beam_end, Color(1.0, 1.0, 0.89, fade), 2)
	if _visual_detail > 0:
		PIXEL.line(self, beam_direction * 22 + perpendicular * 5, beam_end + perpendicular * 5, Color(0.67, 0.43, 0.91, 0.7 * fade), 2)
		PIXEL.line(self, beam_direction * 22 - perpendicular * 5, beam_end - perpendicular * 5, Color(1.0, 0.79, 0.32, 0.75 * fade), 2)
	SHAPES.shard(self, Vector2(0, -8), Vector2.UP, 38, 11, fade)
	SHAPES.star(self, beam_direction * 16, 11, Color(0.93, 1.0, 0.92, fade))
	for index in range(7 if _visual_detail > 0 else 3):
		var ratio := float(index) / 7.0
		var angle := lerpf(_sweep_start, sweep_angle, ratio) + _orientation
		var distance := _radius * (0.24 + fmod(float(index) * 0.137, 0.6))
		var point := Vector2.from_angle(angle) * distance
		var color := Color(0.60, 0.82, 0.85, 0.7 * fade) if index % 2 == 0 else Color(0.76, 0.70, 0.82, 0.6 * fade)
		SHAPES.shard(self, point, Vector2.from_angle(angle), 9, 3, color.a)
