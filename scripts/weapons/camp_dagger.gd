extends Node2D
class_name CampDagger

signal target_hit(target_id: int, damage: int, child: bool)

const BLADE := preload("res://assets/sprites/weapons/camp_dagger.png")
const SLASH := preload("res://assets/sprites/weapons/effects/camp_dagger_slash.png")
const EFFECTS := preload("res://scripts/effects/combat_effect_world.gd")
const GRIP := Vector2(7, 15)
const BASE_REACH := 40.0

var weapon: WeaponInstance
var cancelled := false
var age := 0.0
var heading := Vector2.RIGHT
var time_scale := 1.0
var main_duration := 0.24
var continuous_combo := false
var split_triggered := false
var cuts: Array[Dictionary] = []
var split_profiles: Array[Dictionary] = []
var _shape := CapsuleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


static func find_target(source: WeaponInstance) -> EnemyController:
	# Acquire by collider edge, using the same outer reach as the rendered blade.
	# A center-only radius cannot engage enemies that retreat after contact damage.
	var origin := source.get_attack_origin()
	var shape := CircleShape2D.new()
	shape.radius = source.get_dagger_outer_radius()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, origin)
	query.collision_mask = 2
	query.collide_with_areas = false
	var space := source.owner_player.get_world_2d().direct_space_state
	var nearest: EnemyController
	var distance := INF
	for result in space.intersect_shape(query, maxi(32, EnemyRegistry.get_registered_enemies().size())):
		var enemy := result.collider as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var next_distance := origin.distance_squared_to(enemy.global_position)
		if next_distance >= distance:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters2D.create(origin, enemy.global_position, 4)).is_empty():
			continue
		nearest = enemy
		distance = next_distance
	return nearest


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	weapon = source
	heading = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	global_position = weapon.get_attack_origin()
	time_scale = 1.0 if weapon.use_active_range_rules else weapon.get_actual_attack_interval_seconds() / (float(weapon.attack_interval_ms) / 1000.0)
	var windup := float(weapon.weapon_data.get("dagger_windup_ms", 60)) / 1000.0
	var sweep := float(weapon.weapon_data.get("dagger_sweep_ms", 100)) / 1000.0
	var recover := float(weapon.weapon_data.get("dagger_recover_ms", 80)) / 1000.0
	main_duration = windup + sweep + recover
	var count := maxi(1, int(weapon.get_stat("projectile_count")))
	# Extra attacks share the main combo window: one visible blade, sequential cuts.
	for index in count:
		_add_cut(main_duration * index / count, windup / count, sweep / count, recover / count,
			weapon.calculate_damage_events()[0], false, index)
	split_profiles = weapon.get_split_profiles()
	_query.shape = _shape
	_query.collision_mask = 2
	_query.collide_with_areas = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 50
	add_to_group("camp_daggers")
	add_to_group("weapon_runtime_effects")
	queue_redraw()


## Enable before the first tick for active casts and their native replays.
func configure_continuous_combo() -> void:
	if continuous_combo:
		return
	continuous_combo = true
	time_scale *= 1.25
	var windup := float(weapon.weapon_data.get("dagger_windup_ms", 60)) / 1000.0
	var sweep := float(weapon.weapon_data.get("dagger_sweep_ms", 100)) / 1000.0
	var recover := float(weapon.weapon_data.get("dagger_recover_ms", 80)) / 1000.0
	var next := 0.0
	for index in cuts.size():
		var cut := cuts[index]
		cut.start = next
		cut.windup = windup if index == 0 else 0.0
		cut.sweep = sweep
		cut.recover = recover if index == cuts.size() - 1 else 0.0
		next = cut_end(cut)


func _add_cut(start: float, windup: float, sweep: float, recover: float, event: DamageEvent, child: bool, index: int) -> void:
	cuts.append({"start": start, "windup": windup, "sweep": sweep, "recover": recover,
		"sign": 1.0 if (weapon.volley_index + index) % 2 == 0 else -1.0,
		"event": event, "child": child, "hits": {}})


func is_attacking() -> bool:
	return not cancelled and not cuts.is_empty() and age < cut_end(cuts[-1])


func cut_end(cut: Dictionary) -> float:
	return float(cut.start) + float(cut.windup) + float(cut.sweep) + float(cut.recover)


func cut_opacity(cut: Dictionary, at: float) -> float:
	if float(cut.recover) <= 0.0:
		return 1.0
	var end := float(cut.start) + float(cut.windup) + float(cut.sweep)
	return 1.0 - clampf((at - end) / float(cut.recover), 0, 1)


func blade_direction(cut: Dictionary, at: float) -> Vector2:
	var t := clampf((at - float(cut.start) - float(cut.windup)) / float(cut.sweep), 0, 1)
	var half_angle := deg_to_rad(float(weapon.weapon_data.get("dagger_arc_degrees", 130))) * 0.5
	return heading.rotated(lerpf(-half_angle, half_angle, smoothstep(0, 1, t)) * float(cut.sign))


func blade_segment(cut: Dictionary, at: float) -> PackedVector2Array:
	var radial := blade_direction(cut, at)
	var scale_factor := weapon.get_attack_range() / BASE_REACH
	# Keep the inner slash reachable when extending the outer arc: increased
	# range must not create a blind ring where touching enemies cannot be hit.
	return PackedVector2Array([radial * 21.0 * minf(scale_factor, 1.0), radial * (weapon.get_dagger_outer_radius() - weapon.get_hit_radius())])


func _physics_process(delta: float) -> void:
	if cancelled:
		return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	var previous := age
	var old_origin := global_position
	age += delta / maxf(time_scale, 0.001)
	global_position = weapon.get_attack_origin()
	var index := 0
	# Process newly appended split cuts too if a long frame already crossed them.
	while index < cuts.size():
		var cut := cuts[index]
		var begin := float(cut.start) + float(cut.windup)
		var end := begin + float(cut.sweep)
		if age >= begin and previous < end:
			var first := maxf(previous, begin)
			var last := minf(age, end)
			var angular_steps := ceili((last - first) / float(cut.sweep) * 32.0)
			var motion_steps := ceili(old_origin.distance_to(global_position) / maxf(weapon.get_hit_radius(), 1.0))
			var steps := maxi(1, maxi(angular_steps, motion_steps))
			for step in range(steps + 1):
				var at := lerpf(first, last, float(step) / steps)
				var origin := old_origin.lerp(global_position, clampf((at - previous) / maxf(age - previous, 0.0001), 0, 1))
				_contact(cut, origin, at)
		index += 1
	if not is_attacking():
		cancel()
	queue_redraw()


func _contact(cut: Dictionary, origin: Vector2, at: float) -> void:
	var segment := blade_segment(cut, at)
	_shape.radius = maxf(weapon.get_hit_radius(), 1.0)
	_shape.height = segment[0].distance_to(segment[1]) + 2 * _shape.radius
	_query.transform = Transform2D((segment[1] - segment[0]).angle() - PI / 2, origin + (segment[0] + segment[1]) * 0.5)
	var contacts := get_world_2d().direct_space_state.intersect_shape(_query, maxi(32, EnemyRegistry.get_registered_enemies().size()))
	AudioManager.begin_combat_audio()
	for result in contacts:
		var enemy := result.collider as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive() or cut.hits.has(enemy.get_instance_id()):
			continue
		if (weapon.get_auto_target_position(enemy) - origin).dot(heading) < 0:
			continue
		var ray := PhysicsRayQueryParameters2D.create(origin, enemy.global_position, 4)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		cut.hits[enemy.get_instance_id()] = true
		var event: DamageEvent = cut.event.duplicate_event()
		event.hit_position = enemy.global_position
		if not bool(cut.child) and not split_triggered:
			split_triggered = true
			_append_split_cuts(event)
		EFFECTS.trigger_weapon_impact(get_parent(), weapon, event, event.hit_position, heading, enemy)
		enemy.take_damage(event.damage, event.source_weapon_id, event.is_critical, heading)
		weapon.play_attack_hit_sfx()
		target_hit.emit(enemy.get_instance_id(), event.damage, bool(cut.child))
	AudioManager.end_combat_audio()


func _append_split_cuts(source: DamageEvent) -> void:
	var events: Array[DamageEvent] = []
	for profile in split_profiles:
		for _index in int(profile.child_count):
			var event := source.continue_after_split(profile)
			event.damage = maxi(1, roundi(event.damage * float(profile.damage_multiplier)))
			event.elemental_damage_scale *= float(profile.damage_multiplier)
			events.append(event)
	var count := events.size()
	if count == 0:
		return
	if continuous_combo:
		# Continue from the final main blade position; only the final child recovers.
		var recover := float(cuts[-1].recover)
		cuts[-1].recover = 0.0
		var next := cut_end(cuts[-1])
		var sweep := float(weapon.weapon_data.get("dagger_sweep_ms", 100)) / 1000.0
		for index in count:
			_add_cut(next, 0.0, sweep, recover if index == count - 1 else 0.0, events[index], true, cuts.size())
			next += sweep
		return
	var duration := float(weapon.weapon_data.get("dagger_split_window_ms", 140)) / 1000.0 / count
	var first_index := cuts.size()
	for index in count:
		_add_cut(main_duration + duration * index, duration / 7.0, duration * 4.0 / 7.0,
			duration * 2.0 / 7.0, events[index], true, first_index + index)


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	if cancelled or weapon == null:
		return
	var scale_factor := weapon.get_attack_range() / BASE_REACH
	var tint := Color.WHITE
	if weapon.has_effect("fire"): tint = Color("ffc38a")
	elif weapon.has_effect("ice"): tint = Color("b4efff")
	elif weapon.has_effect("lightning"): tint = Color("dbccff")
	for cut in cuts:
		if age < float(cut.start) or age >= cut_end(cut):
			continue
		var begin := float(cut.start) + float(cut.windup)
		var end := begin + float(cut.sweep)
		var radial := blade_direction(cut, age)
		var fade := cut_opacity(cut, age)
		if age >= begin:
			# Reveal the approved crescent only behind the moving edge, then fade it.
			var angle := heading.angle_to(radial)
			var edge_y := clampi(roundi(32 + 29 * sin(angle)), 0, 64)
			var y0 := 0 if float(cut.sign) > 0 else edge_y
			var height := edge_y if float(cut.sign) > 0 else 64 - edge_y
			var slash_scale := weapon.get_attack_range() / 29.0
			draw_set_transform(Vector2.ZERO, heading.angle())
			draw_texture_rect_region(SLASH, Rect2(Vector2(-22, y0 - 32) * slash_scale, Vector2(64, height) * slash_scale),
				Rect2(0, y0, 64, height), Color(tint, 0.58 * fade))
		var grip := radial * 14.0 * scale_factor
		var body_scale := weapon.get_dagger_body_scale()
		if weapon.use_active_range_rules:
			# Move the fixed-size blade out to the new arc; only the slash trail grows.
			grip = radial * (weapon.get_dagger_outer_radius() - weapon.get_hit_radius() - 22.0 * body_scale.x)
		draw_set_transform(grip.round(), radial.angle(), body_scale)
		draw_texture(BLADE, -GRIP, Color(tint if bool(cut.child) else Color.WHITE, fade))
		draw_set_transform(Vector2.ZERO)
