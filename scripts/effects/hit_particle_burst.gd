extends Node2D
class_name HitParticleBurst

const PARTICLE_COUNT := 14
const PARTICLE_COLORS: Array[Color] = [
	Color(0.17, 0.38, 0.27, 1.0),
	Color(0.22, 0.49, 0.32, 1.0),
	Color(0.28, 0.57, 0.37, 1.0),
	Color(0.35, 0.65, 0.42, 1.0),
	Color(0.43, 0.72, 0.48, 1.0),
	Color(0.25, 0.52, 0.46, 1.0),
]

var _particles: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _elapsed := 0.0
var _lifetime := 0.0
var _burst_direction := Vector2.ZERO


static func spawn(parent: Node, hit_position: Vector2, burst_direction: Vector2 = Vector2.ZERO) -> HitParticleBurst:
	if parent == null:
		return null
	var burst := HitParticleBurst.new()
	burst.name = "HitParticleBurst"
	burst.top_level = true
	burst.z_index = 80
	burst._burst_direction = burst_direction.normalized() if not burst_direction.is_zero_approx() else Vector2.ZERO
	parent.add_child(burst)
	burst.global_position = hit_position
	burst._start()
	return burst


func _start() -> void:
	_random.randomize()
	for index in PARTICLE_COUNT:
		var direction := Vector2.from_angle(_random.randf_range(0.0, TAU))
		if not _burst_direction.is_zero_approx():
			direction = _burst_direction.rotated(_random.randf_range(-PI * 0.72, PI * 0.72))
		var particle_lifetime := _random.randf_range(0.34, 0.58)
		var particle_size := Vector2(
			float(_random.randi_range(4, 7)),
			float(_random.randi_range(4, 8))
		)
		_particles.append({
			"position": direction * _random.randf_range(0.0, 3.0),
			"velocity": direction * _random.randf_range(60.0, 170.0),
			"gravity": _random.randf_range(55.0, 120.0),
			"drag": _random.randf_range(35.0, 80.0),
			"rotation": _random.randf_range(-0.35, 0.35),
			"spin": _random.randf_range(-5.0, 5.0),
			"size": particle_size,
			"color": PARTICLE_COLORS[_random.randi_range(0, PARTICLE_COLORS.size() - 1)],
			"lifetime": particle_lifetime,
		})
		_lifetime = maxf(_lifetime, particle_lifetime)
	queue_redraw()


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	for index in _particles.size():
		var particle := _particles[index]
		var velocity: Vector2 = particle["velocity"]
		velocity = velocity.move_toward(Vector2.ZERO, float(particle["drag"]) * delta)
		velocity.y += float(particle["gravity"]) * delta
		particle["velocity"] = velocity
		particle["position"] = particle["position"] + velocity * delta
		particle["rotation"] = float(particle["rotation"]) + float(particle["spin"]) * delta
		_particles[index] = particle
	queue_redraw()
	if _elapsed >= _lifetime:
		queue_free()


func _draw() -> void:
	for particle in _particles:
		var particle_lifetime := maxf(float(particle["lifetime"]), 0.01)
		var fade := clampf(1.0 - _elapsed / particle_lifetime, 0.0, 1.0)
		var color: Color = particle["color"]
		color.a *= fade * fade
		var position: Vector2 = particle["position"]
		var size: Vector2 = particle["size"]
		draw_set_transform(position.round(), float(particle["rotation"]), Vector2.ONE)
		draw_rect(Rect2(-size * 0.5, size), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
