extends Area2D
class_name ProjectileInstance

const DEFAULT_HIT_RADIUS: float = 6.0
const ENEMY_COLLISION_LAYER: int = 2
const TERRAIN_COLLISION_LAYER: int = 4
const TRAIL_INTERVAL_SECONDS: float = 0.035
const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const HIT_PARTICLE_BURST_SCRIPT = preload("res://scripts/effects/hit_particle_burst.gd")
const DESTRUCTIBLE_TEST_AREA_SCRIPT = preload("res://scripts/terrain/destructible_test_area.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const COMBAT_EFFECT_WORLD_SCRIPT = preload("res://scripts/effects/combat_effect_world.gd")

var projectile_id: String = ""
var weapon: WeaponInstance = null
var damage_event: DamageEvent = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var remaining_distance: float = 0.0
var remaining_hits: int = 1
var hit_targets: Dictionary = {}
var active: bool = false
var _trail_emitter: Node2D = null


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
	collision_mask = ENEMY_COLLISION_LAYER | TERRAIN_COLLISION_LAYER
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

	var trail_context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "projectile_trail")
	_trail_emitter = PARTICLE_WORLD_SCRIPT.create_emitter(self, "projectile_trail", trail_context, {
		"motion_type": "attached",
		"particle_rate": 1.0 / TRAIL_INTERVAL_SECONDS,
		"direction": -direction,
	})

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
	if body.get_script() == DESTRUCTIBLE_TEST_AREA_SCRIPT:
		damage_event.hit_position = global_position
		if bool(body.call("destroy_point", global_position)):
			_spawn_terrain_sparks(global_position, direction)
		COMBAT_EFFECT_WORLD_SCRIPT.trigger_weapon_impact(get_parent(), weapon, damage_event, global_position, direction, body)
		_destroy()
		return
	var enemy := body as EnemyController
	if enemy == null or not enemy.is_alive():
		return
	var target_key := enemy.get_instance_id()
	if hit_targets.has(target_key):
		return
	hit_targets[target_key] = true
	var enemy_hit_position := enemy.global_position
	damage_event.hit_position = enemy_hit_position
	enemy.take_damage(damage_event.damage, damage_event.source_weapon_id, damage_event.is_critical, direction)
	COMBAT_EFFECT_WORLD_SCRIPT.trigger_weapon_impact(get_parent(), weapon, damage_event, enemy_hit_position, direction, enemy)
	if weapon != null:
		if weapon.register_hit_feedback_frame(true):
			_spawn_hit_sparks(enemy_hit_position, direction)
		weapon.play_projectile_hit_sfx(projectile_id)
	remaining_hits -= 1
	if remaining_hits <= 0:
		_destroy()


func _spawn_hit_sparks(hit_position: Vector2, burst_direction: Vector2 = Vector2.ZERO) -> void:
	HIT_PARTICLE_BURST_SCRIPT.spawn(get_parent(), hit_position, burst_direction)


func _spawn_terrain_sparks(hit_position: Vector2, burst_direction: Vector2 = Vector2.ZERO) -> void:
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "impact_terrain", hit_position, burst_direction)


func _destroy() -> void:
	if not active:
		return
	active = false
	queue_free()
