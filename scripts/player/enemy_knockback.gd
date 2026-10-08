extends Node
class_name PlayerEnemyKnockback
## Latest successful enemy hit supplies a decelerating impulse after player input.
var player: PlayerController
var speed := Vector2.ZERO
var deceleration := 0.0
var remaining := 0.0
var exceptions: Array[WeakRef] = []
var active_source: WeakRef
var total_distance := 0.0
var impulse_count := 0


func _ready() -> void:
	process_physics_priority = 50


func impulse(source: PhysicsBody2D, direction: Vector2, strength: float, duration: float) -> void:
	if not is_instance_valid(player) or not player.alive: return
	cancel()
	if is_instance_valid(source):
		player.add_collision_exception_with(source)
		exceptions.append(weakref(source))
		active_source = weakref(source)
	speed = direction.normalized() * strength
	remaining = duration
	deceleration = strength / maxf(duration, 0.001)
	impulse_count += 1
	player.reset_stationary_relic_state()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)): return
	if not is_instance_valid(player) or not player.alive:
		cancel()
		return
	if remaining <= 0: return
	if active_source != null and not is_instance_valid(active_source.get_ref()):
		cancel()
		return
	var dt := minf(delta, remaining)
	var after := speed.move_toward(Vector2.ZERO,deceleration*dt)
	var before := player.global_position
	# Integrate the decelerating impulse and respect physical obstacles.
	player.move_and_collide((speed+after)*0.5*dt)
	total_distance += before.distance_to(player.global_position)
	speed = after
	remaining = maxf(0,remaining-dt)
	if remaining <= 0: cancel()


func cancel() -> void:
	speed = Vector2.ZERO
	remaining = 0
	if is_instance_valid(player):
		for reference in exceptions:
			var body := reference.get_ref() as PhysicsBody2D
			if is_instance_valid(body): player.remove_collision_exception_with(body)
	exceptions.clear()
	active_source = null


func cancel_source(source: PhysicsBody2D) -> void:
	if active_source != null and active_source.get_ref() == source: cancel()


func _exit_tree() -> void:
	cancel()
