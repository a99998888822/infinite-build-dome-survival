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
var _plasma_tick_timer: float = 0.0
var _plasma_tick_count: int = 0
var _plasma_rotation: float = 0.0


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
	_plasma_tick_timer = 0.0
	_plasma_tick_count = 0
	_plasma_rotation = direction.angle()

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

	if _split_depth == 0 and not _is_plasma_projectile():
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
	if _is_plasma_projectile():
		_plasma_rotation += float(weapon.weapon_data.get("plasma_rotation_speed", 4.0)) * delta
		_process_plasma_contact(delta)
		queue_redraw()
	var step := speed * delta
	global_position += direction * step
	remaining_distance -= step
	if remaining_distance <= 0.0:
		_destroy()

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if _is_plasma_projectile() and body is EnemyController:
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


func _is_plasma_projectile() -> bool:
	return weapon != null and str(weapon.weapon_data.get("projectile_behavior", "")) == "plasma"


func _process_plasma_contact(delta: float) -> void:
	var enemies := _query_plasma_enemies()
	if enemies.is_empty():
		speed = maxf(weapon.get_projectile_speed(), 1.0)
		_plasma_tick_timer = 0.0
		return
	speed = maxf(float(weapon.weapon_data.get("plasma_contact_speed", 80.0)), 1.0)
	_plasma_tick_timer -= delta
	if _plasma_tick_timer <= 0.0:
		_process_plasma_tick(enemies)


func _query_plasma_enemies() -> Array[EnemyController]:
	var enemies: Array[EnemyController] = []
	var radius := maxf(float(weapon.weapon_data.get("plasma_damage_radius", 48.0)), 8.0)
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_COLLISION_LAYER
	query.collide_with_bodies = true
	var results := get_world_2d().direct_space_state.intersect_shape(query, 64)
	var found_ids: Dictionary = {}
	for result in results:
		var enemy := result.get("collider") as EnemyController
		if enemy == null or not enemy.is_alive() or found_ids.has(enemy.get_instance_id()):
			continue
		found_ids[enemy.get_instance_id()] = true
		enemies.append(enemy)
	return enemies


func _process_plasma_tick(enemies: Array[EnemyController]) -> void:
	if _plasma_tick_count >= 5:
		_destroy()
		return
	for enemy in enemies:
		if enemy == null or not enemy.is_alive():
			continue
		var tick_event := damage_event.duplicate_event()
		tick_event.hit_position = enemy.global_position
		enemy.take_damage(tick_event.damage, tick_event.source_weapon_id, tick_event.is_critical, direction)
		var effect_event := tick_event.duplicate_event()
		effect_event.damage = maxi(1, int(roundi(float(effect_event.damage) * 0.2)))
		COMBAT_EFFECT_WORLD_SCRIPT.trigger_weapon_impact(get_parent(), weapon, effect_event, enemy.global_position, direction, enemy)
	_plasma_tick_count += 1
	_plasma_tick_timer = maxf(float(weapon.weapon_data.get("plasma_tick_interval", 0.1)), 0.01)
	if _plasma_tick_count >= 5:
		_destroy()


func _draw() -> void:
	if not _is_plasma_projectile():
		return
	var time := Time.get_ticks_msec() * 0.001
	var base_radius := maxf(float(weapon.weapon_data.get("plasma_visual_radius", 11.0)), 8.0)
	var pulse := 1.0 + sin(time * 11.0) * 0.09
	var jitter := Vector2(sin(time * 31.0), cos(time * 37.0)) * base_radius * 0.12
	draw_circle(jitter, base_radius * 1.42 * pulse, Color(0.36, 0.78, 1.0, 0.10))
	draw_circle(jitter, base_radius * pulse, Color(0.55, 0.86, 1.0, 0.24))
	draw_circle(jitter, base_radius * 0.62 * pulse, Color(0.88, 0.97, 1.0, 0.96))
	var arc_count := clampi(int(weapon.weapon_data.get("plasma_arc_count", 4)), 2, 8)
	var arc_segments := clampi(int(weapon.weapon_data.get("plasma_arc_segments", 12)), 8, 24)
	var arc_jitter := maxf(float(weapon.weapon_data.get("plasma_arc_jitter", 3.0)), 0.0)
	for arc_index in range(arc_count):
		var arc_phase := float(arc_index) * TAU / float(arc_count)
		var ring_rotation := _plasma_rotation * (1.0 + float(arc_index) * 0.08) + arc_phase
		var major_radius := base_radius * (1.02 + sin(time * 4.0 + arc_phase) * 0.10)
		var minor_radius := major_radius * (0.38 + 0.10 * sin(time * 3.0 + arc_phase * 1.7))
		var points := PackedVector2Array()
		for point_index in range(arc_segments + 1):
			var ratio := float(point_index) / float(arc_segments)
			var angle := ratio * TAU
			var radial_noise := sin(time * 29.0 + arc_phase * 5.0 + float(point_index) * 4.7) * arc_jitter
			var tangent_noise := sin(time * 37.0 + arc_phase * 3.0 + float(point_index) * 8.3) * arc_jitter * 0.34
			var point := Vector2(cos(angle) * (major_radius + radial_noise), sin(angle) * (minor_radius + radial_noise * 0.45))
			point += Vector2(-sin(angle), cos(angle)) * tangent_noise
			points.append(jitter + point.rotated(ring_rotation))
		draw_polyline(points, Color(0.28, 0.72, 1.0, 0.24), 4.0, true)
		draw_polyline(points, Color(0.82, 0.96, 1.0, 0.96), 1.5, true)


func _get_target_hit_limit() -> int:
	if weapon == null or not weapon.has_effect("pierce"):
		return 1
	var extra_hits := 0
	for pierce_instance in weapon.get_effect_instances("pierce"):
		var item_instance_id := str(pierce_instance.get("item_instance_id", ""))
		var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "pierce", {
			"extra_target_hits": 0.0,
		}, item_instance_id)
		extra_hits += clampi(int(roundi(context.get_resolved_parameter("extra_target_hits", 0.0))), 0, 32)
	return maxi(1, 1 + mini(extra_hits, 32))


func _spawn_split_projectiles(hit_position: Vector2) -> void:
	if not _spawn_projectile_callback.is_valid() or weapon == null:
		return
	for split_instance in weapon.get_effect_instances("split"):
		_spawn_split_projectiles_for_item(hit_position, str(split_instance.get("item_instance_id", "")))


func _spawn_split_projectiles_for_item(hit_position: Vector2, attachment_item_id: String) -> void:
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "split", {
		"child_count": 3.0,
		"spread_angle": 36.0,
	}, attachment_item_id)
	var child_count := clampi(int(roundi(context.get_resolved_parameter("child_count", 3.0))), 1, 8)
	var spread_angle := maxf(context.get_resolved_parameter("spread_angle", 36.0), 0.0)
	var inherited_targets := hit_targets.duplicate()
	var reserved_targets := inherited_targets.duplicate()
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
