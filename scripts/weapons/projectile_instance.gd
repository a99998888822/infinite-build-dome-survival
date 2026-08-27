extends Area2D
class_name ProjectileInstance

const DEFAULT_HIT_RADIUS: float = 6.0
const ENEMY_COLLISION_LAYER: int = 2
const TERRAIN_COLLISION_LAYER: int = 4
const TRAIL_INTERVAL_SECONDS: float = 0.035
const ENABLE_ENEMY_HIT_GREEN_PARTICLES: bool = false
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
var remaining_target_hits: int = 1
var _spawn_projectile_callback: Callable = Callable()
var _split_depth: int = 0
var _has_split: bool = false
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
	visual_scale: float,
	spawn_projectile_callback: Callable = Callable(),
	ignored_target_ids: Dictionary = {},
	split_depth: int = 0
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
	remaining_target_hits = _get_target_hit_limit()
	hit_targets = ignored_target_ids.duplicate()
	_spawn_projectile_callback = spawn_projectile_callback
	_split_depth = maxi(split_depth, 0)
	_has_split = false
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
	if weapon != null and weapon.has_effect("split") and _split_depth == 0 and not _has_split:
		_has_split = true
		_spawn_split_projectiles(enemy_hit_position)
	if weapon != null:
		if ENABLE_ENEMY_HIT_GREEN_PARTICLES and weapon.register_hit_feedback_frame(true):
			_spawn_hit_sparks(enemy_hit_position, direction)
		weapon.play_projectile_hit_sfx(projectile_id)
	remaining_target_hits -= 1
	if remaining_target_hits <= 0:
		_destroy()


func _get_target_hit_limit() -> int:
	if weapon == null or not weapon.has_effect("pierce"):
		return 1
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "pierce", {
		"extra_target_hits": 0.0,
	})
	var extra_hits := clampi(int(roundi(context.get_resolved_parameter("extra_target_hits", 0.0))), 0, 32)
	return maxi(1, 1 + extra_hits)


func _spawn_split_projectiles(hit_position: Vector2) -> void:
	if not _spawn_projectile_callback.is_valid() or weapon == null:
		return
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "split", {
		"child_count": 3.0,
		"spread_angle": 36.0,
	})
	var child_count := clampi(int(roundi(context.get_resolved_parameter("child_count", 3.0))), 1, 8)
	var spread_angle := maxf(context.get_resolved_parameter("spread_angle", 36.0), 0.0)
	var inherited_targets := hit_targets.duplicate()
	var reserved_targets := inherited_targets.duplicate()
	var split_color := context.get_tinted_color(Color(1.0, 0.62, 0.9, 1.0))
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "projectile_split", hit_position, direction, 1.0, split_color, {
		"count_multiplier": context.get_resolved_parameter("count_multiplier", 1.0),
		"glow_multiplier": context.get_resolved_parameter("glow_multiplier", 1.0),
	})

	var child_directions: Array[Vector2] = []
	var child_targets: Array[EnemyController] = []
	for child_index in range(child_count):
		var target := _find_split_target(hit_position, reserved_targets)
		var child_direction := direction
		if target != null:
			child_direction = hit_position.direction_to(target.global_position)
			reserved_targets[target.get_instance_id()] = true
		elif child_count > 1:
			var normalized_index := float(child_index) / float(child_count - 1)
			child_direction = direction.rotated(deg_to_rad(lerpf(-spread_angle * 0.5, spread_angle * 0.5, normalized_index)))
		child_directions.append(child_direction)
		child_targets.append(target)

	for child_index in range(child_count):
		var child_ignored_targets := inherited_targets.duplicate()
		var assigned_target: EnemyController = child_targets[child_index]
		for reserved_target_id in reserved_targets.keys():
			if assigned_target == null or int(reserved_target_id) != assigned_target.get_instance_id():
				child_ignored_targets[reserved_target_id] = true
		var launch_position := hit_position + child_directions[child_index] * maxf(weapon.get_hit_radius(), DEFAULT_HIT_RADIUS)
		_spawn_projectile_callback.call(
			weapon,
			damage_event.duplicate_event(),
			child_directions[child_index],
			maxf(weapon.get_attack_range(), remaining_distance),
			launch_position,
			child_ignored_targets,
			_split_depth + 1
		)


func _find_split_target(origin: Vector2, excluded_targets: Dictionary) -> EnemyController:
	var nearest: EnemyController = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or excluded_targets.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _spawn_hit_sparks(hit_position: Vector2, burst_direction: Vector2 = Vector2.ZERO) -> void:
	HIT_PARTICLE_BURST_SCRIPT.spawn(get_parent(), hit_position, burst_direction)


func _spawn_terrain_sparks(hit_position: Vector2, burst_direction: Vector2 = Vector2.ZERO) -> void:
	PARTICLE_WORLD_SCRIPT.emit_profile(get_parent(), "impact_terrain", hit_position, burst_direction)


func _destroy() -> void:
	if not active:
		return
	active = false
	queue_free()
