extends Node2D
class_name MeteorFlail

signal target_hit(target_id: int, damage: int, child: bool)

const HEAD = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_head.png")
const LINK = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_chain_link.png")
const GRIP = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_grip.png")
const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
const WINDUP := 0.18
const SWEEP := 0.55
const RECOVER := 0.15

var weapon: WeaponInstance
var cancelled := false
var age := 0.0
var heading := Vector2.RIGHT
var swing_sign := 1.0
var time_scale := 1.0
var swings: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var split_profiles: Array[Dictionary] = []
var split_triggered := false
var _shape := CapsuleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	weapon = source
	heading = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	swing_sign = 1.0 if weapon.volley_index % 2 == 0 else -1.0
	time_scale = weapon.get_actual_attack_interval_seconds() / 1.5
	global_position = weapon.owner_player.global_position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 50
	split_profiles = weapon.get_split_profiles()
	var count := maxi(1, int(weapon.get_stat("projectile_count")))
	for index in count:
		var delay := 0.36 * index / maxf(count - 1, 1)
		_add_swing(delay, WINDUP, SWEEP, 1.0, false, index)
	_query.shape = _shape
	_query.collision_mask = 2
	_query.collide_with_areas = false
	add_to_group("meteor_flails")
	add_to_group("weapon_runtime_effects")


func _add_swing(start: float, windup: float, duration: float, multiplier: float, child: bool, index: int) -> void:
	swings.append({"start": start, "windup": windup, "duration": duration,
		"multiplier": multiplier, "child": child, "sign": swing_sign * (1.0 if index % 2 == 0 else -1.0),
		"event": weapon.calculate_damage_events()[0], "hits": {}, "trail": [], "processed_until": start})


func is_swinging() -> bool:
	return not cancelled and swings.any(func(swing): return age < float(swing.start) + float(swing.windup) + float(swing.duration) + RECOVER)


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
	age += delta / time_scale
	global_position = weapon.owner_player.global_position
	# Snapshot the count: contact may append split swings, never recurse this frame.
	for index in swings.size():
		var swing := swings[index]
		var begin := float(swing.start) + float(swing.windup)
		var end := begin + float(swing.duration)
		if age >= begin and float(swing.processed_until) < end:
			# Newly queued follow-throughs catch up even if a long frame crossed their start.
			var first := maxf(float(swing.processed_until), begin)
			var last := minf(age, end)
			# Subdivide the curved trajectory, then query the actual enemy colliders.
			# The same head_position owns rendering and collision; no sector damage.
			var steps := maxi(1, ceili((last - first) / (float(swing.duration) / 64.0)))
			for step in steps:
				var t0 := lerpf(first, last, float(step) / steps)
				var t1 := lerpf(first, last, float(step + 1) / steps)
				var origin0 := old_origin.lerp(global_position, clampf((t0 - previous) / maxf(age - previous, 0.0001), 0, 1))
				var origin1 := old_origin.lerp(global_position, clampf((t1 - previous) / maxf(age - previous, 0.0001), 0, 1))
				_sweep_contacts(swing, origin0 + head_position(swing, t0), origin1 + head_position(swing, t1), t1)
			var trail: Array = swing.trail
			trail.append({"point": head_position(swing, last), "time": age})
		while not swing.trail.is_empty() and age - float(swing.trail[0].time) > 0.10:
			swing.trail.pop_front()
		swing.processed_until = age
	for spark in sparks:
		spark.life -= delta
		spark.point += spark.velocity * delta
	sparks = sparks.filter(func(spark): return spark.life > 0)
	if not is_swinging() and sparks.is_empty():
		cancel()
	queue_redraw()


func head_position(swing: Dictionary, at_time: float) -> Vector2:
	var local_time := at_time - float(swing.start)
	var u := clampf((local_time - float(swing.windup)) / float(swing.duration), 0, 1)
	var eased := u * u * (3.0 - 2.0 * u)
	var angle := deg_to_rad(lerpf(-70.0, 70.0, eased)) * float(swing.sign)
	var reach := weapon.get_attack_range() * (0.45 + 0.55 * sin(PI * u))
	if local_time < float(swing.windup):
		reach *= lerpf(0.70, 1.0, maxf(local_time / float(swing.windup), 0))
	elif local_time > float(swing.windup) + float(swing.duration):
		reach *= lerpf(1.0, 0.45, clampf((local_time - float(swing.windup) - float(swing.duration)) / RECOVER, 0, 1))
	return heading.rotated(angle) * reach


func head_radius(swing: Dictionary) -> float:
	return weapon.get_hit_radius() * (0.8 if bool(swing.child) else 1.0)


func _sweep_contacts(swing: Dictionary, from: Vector2, to: Vector2, at_time: float) -> void:
	_shape.radius = maxf(head_radius(swing), 1.0)
	_shape.height = from.distance_to(to) + 2.0 * _shape.radius
	_query.transform = Transform2D((to - from).angle() - PI / 2, (from + to) * 0.5)
	var contacts := get_world_2d().direct_space_state.intersect_shape(_query, maxi(32, EnemyRegistry.get_registered_enemies().size()))
	for contact in contacts:
		var enemy := contact.collider as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive() or swing.hits.has(enemy.get_instance_id()):
			continue
		# A chain cannot reach through blocking terrain.
		var ray := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, 4)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_apply_hit(swing, enemy, at_time)


func damage_for_contact(swing: Dictionary, at_time: float) -> DamageEvent:
	var event: DamageEvent = swing.event.duplicate_event()
	var multiplier := float(swing.multiplier)
	var extension := head_position(swing, at_time).length() / maxf(weapon.get_attack_range(), 1)
	if extension >= float(weapon.weapon_data.get("flail_outer_threshold", 0.8)):
		multiplier *= float(weapon.weapon_data.get("flail_outer_multiplier", 1.5))
	event.damage = maxi(1, roundi(event.damage * multiplier))
	# Keep the unscaled elemental base; multiply the complete base exactly once.
	event.elemental_damage_scale *= multiplier
	return event


func _apply_hit(swing: Dictionary, enemy: EnemyController, at_time: float) -> void:
	var id := enemy.get_instance_id()
	swing.hits[id] = true
	var where := enemy.global_position
	var event := damage_for_contact(swing, at_time)
	event.hit_position = where
	if not bool(swing.child) and not split_triggered:
		split_triggered = true
		var children: Array[float] = []
		for profile in split_profiles:
			for _index in int(profile.child_count): children.append(float(profile.damage_multiplier))
		for index in children.size():
			_add_swing(maxf(0.70, at_time) + 0.36 * index / maxf(children.size() - 1, 1), 0.03, 0.32, children[index], true, index + 1)
	# Every contacted victim gets attachments, including a lethal native hit.
	EFFECTS.trigger_weapon_impact(get_parent(), weapon, event, where, heading, enemy)
	enemy.take_damage(event.damage, event.source_weapon_id, event.is_critical, heading)
	weapon.play_attack_hit_sfx()
	for index in 7:
		var direction := heading.rotated(index * TAU / 7.0)
		sparks.append({"point": where, "velocity": direction * (38.0 + index * 7), "life": 0.20})
	target_hit.emit(id, event.damage, bool(swing.child))


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	if cancelled:
		return
	var tint := Color(0.68, 0.88, 1.0)
	if weapon.has_effect("fire"): tint = Color(1.0, 0.59, 0.25)
	elif weapon.has_effect("lightning"): tint = Color(0.57, 0.79, 1.0)
	elif weapon.has_effect("ice"): tint = Color(0.54, 0.97, 1.0)
	for swing in swings:
		var local_time := age - float(swing.start)
		var end := float(swing.windup) + float(swing.duration)
		if local_time < 0 or local_time > end + RECOVER:
			continue
		var fade := minf(1.0, local_time / 0.045) * (1.0 - clampf((local_time - end) / RECOVER, 0, 1))
		var head := head_position(swing, age)
		var radial := head.normalized()
		var grip := heading * 14.0
		var length := grip.distance_to(head)
		var chain_angle := (head - grip).angle()
		for index in maxi(1, int(length / 7)):
			var point := grip.lerp(head, float(index) / maxf(int(length / 7), 1))
			draw_set_transform(point.round(), chain_angle)
			draw_texture(LINK, -LINK.get_size() * 0.5, Color(1, 1, 1, fade * (0.65 if bool(swing.child) else 1)))
		draw_set_transform(grip.round(), heading.angle() + PI / 2)
		draw_texture_rect(GRIP, Rect2(-3, -8, 6, 16), false, Color(1, 1, 1, fade))
		draw_set_transform(Vector2.ZERO)
		for entry in swing.trail:
			var opacity := (1.0 - (age - float(entry.time)) / 0.10) * 0.50 * fade
			draw_rect(Rect2((Vector2(entry.point) - radial * 9).round(), Vector2(3, 3)), Color(tint, opacity))
		var radius := head_radius(swing)
		draw_set_transform(head.round(), chain_angle + age * float(swing.sign) * 5.0)
		draw_texture_rect(HEAD, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), false, Color(1, 1, 1, fade))
		# A few attached square sparks identify enchantments without obscuring the iron head.
		if weapon.has_effect("fire") or weapon.has_effect("lightning") or weapon.has_effect("ice"):
			for index in 3:
				var point := Vector2.RIGHT.rotated(age * 6 + TAU * index / 3) * (radius + 3)
				draw_rect(Rect2(point.round(), Vector2(2, 2)), Color(tint, fade * 0.85))
		draw_set_transform(Vector2.ZERO)
	for spark in sparks:
		draw_rect(Rect2((Vector2(spark.point) - global_position).round(), Vector2(2, 2)), Color(tint, float(spark.life) / 0.20))
