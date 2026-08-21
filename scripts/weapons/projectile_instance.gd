extends Area2D
class_name ProjectileInstance

const DEFAULT_HIT_RADIUS: float = 6.0

var projectile_id: String = ""
var weapon: WeaponInstance = null
var damage_event: DamageEvent = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var remaining_distance: float = 0.0
var remaining_hits: int = 1
var hit_targets: Dictionary = {}
var active: bool = false


func initialize(
	source_weapon: WeaponInstance,
	source_damage_event: DamageEvent,
	source_projectile_id: String,
	start_position: Vector2,
	flight_direction: Vector2,
	max_distance: float,
	texture: Texture2D,
	visual_scale: float
) -> bool:
	if source_weapon == null or source_damage_event == null:
		return false
	weapon = source_weapon
	damage_event = source_damage_event
	projectile_id = source_projectile_id.strip_edges()
	global_position = start_position
	direction = flight_direction.normalized() if not flight_direction.is_zero_approx() else Vector2.RIGHT
	speed = maxf(weapon.get_projectile_speed(), 1.0)
	remaining_distance = maxf(max_distance, 1.0)
	remaining_hits = maxi(weapon.get_total_pierce_hits(), 1)
	active = true

	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	var shape := CircleShape2D.new()
	shape.radius = maxf(weapon.get_hit_radius(), DEFAULT_HIT_RADIUS)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.scale = Vector2.ONE * visual_scale
		sprite.rotation = direction.angle()
		add_child(sprite)

	body_entered.connect(_on_body_entered)
	return true


func _physics_process(delta: float) -> void:
	if not active:
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	var step := speed * delta
	global_position += direction * step
	remaining_distance -= step
	if remaining_distance <= 0.0:
		_destroy()


func _on_body_entered(body: Node) -> void:
	if not active:
		return
	var enemy := body as EnemyController
	if enemy == null or not enemy.is_alive():
		return
	var target_key := enemy.get_instance_id()
	if hit_targets.has(target_key):
		return
	hit_targets[target_key] = true
	damage_event.hit_position = enemy.global_position
	enemy.take_damage(damage_event.damage, damage_event.source_weapon_id, damage_event.is_critical, direction)
	if weapon != null:
		if weapon.register_hit_feedback_frame(true):
			_spawn_hit_sparks(enemy.global_position)
		weapon.play_projectile_hit_sfx(projectile_id)
	remaining_hits -= 1
	if remaining_hits <= 0:
		_destroy()


func _spawn_hit_sparks(hit_position: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "HitSparks"
	particles.top_level = true
	particles.global_position = hit_position
	particles.z_index = 80
	particles.amount = 10
	particles.lifetime = 0.22
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(1.0, 0.68, 0.16, 1.0)
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.restart()


func _destroy() -> void:
	if not active:
		return
	active = false
	queue_free()
