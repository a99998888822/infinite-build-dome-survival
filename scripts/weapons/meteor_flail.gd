extends Node2D
class_name MeteorFlail

signal target_hit(target_id: int, damage: int, child: bool)

const HEAD = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_head.png")
const LINK = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_chain_link.png")
const GRIP = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_grip.png")
const TRAIL = preload("res://assets/sprites/weapons/meteor_flail/meteor_flail_trail.png")
const TRAIL_FRAME_SIZE := Vector2(320, 320)
const TRAIL_FPS := 30.0
const TRAIL_AUTHORED_REACH := 144.0
const BASE_TINT := Color(0.68, 0.88, 1.0)
const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
const WINDUP := 0.13
const SWEEP := 0.37
const RECOVER := 0.10

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


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	weapon = source
	heading = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	swing_sign = 1.0 if weapon.volley_index % 2 == 0 else -1.0
	time_scale = 1.0 if weapon.use_active_range_rules else weapon.get_actual_attack_interval_seconds() / 1.5
	global_position = weapon.get_attack_origin()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 50
	split_profiles = weapon.get_split_profiles()
	var count := maxi(1, int(weapon.get_stat("projectile_count")))
	for index in count:
		var delay := (WINDUP + SWEEP + RECOVER) * index
		_add_swing(delay, WINDUP, SWEEP, 1.0, false, index)
	add_to_group("meteor_flails")
	add_to_group("weapon_runtime_effects")


func _add_swing(start: float, windup: float, duration: float, multiplier: float, child: bool, index: int, continuation: int = 0) -> void:
	var event := weapon.calculate_damage_events()[0]
	event.split_child = child
	event.enchantment_start = continuation
	swings.append({"start": start, "windup": windup, "duration": duration,
		"multiplier": multiplier, "child": child, "sign": swing_sign * (1.0 if index % 2 == 0 else -1.0),
		"event": event, "hits": {}, "trail": [], "processed_until": start})


func sequence_duration() -> float:
	var end := 0.0
	for swing in swings:
		end = maxf(end, float(swing.start) + float(swing.windup) + float(swing.duration) + RECOVER)
	return end


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
	global_position = weapon.get_attack_origin()
	# Snapshot the count: contact may append split swings, never recurse this frame.
	for index in swings.size():
		var swing := swings[index]
		var begin := float(swing.start) + float(swing.windup)
		var end := begin + float(swing.duration)
		if age >= begin and float(swing.processed_until) < end:
			# Newly queued follow-throughs catch up even if a long frame crossed their start.
			var first := maxf(float(swing.processed_until), begin)
			var last := minf(age, end)
			# The chain sweeps the entire fan, including enemies near the grip.
			var steps := maxi(1, ceili((last - first) / (float(swing.duration) / 64.0)))
			for step in steps:
				var t0 := lerpf(first, last, float(step) / steps)
				var t1 := lerpf(first, last, float(step + 1) / steps)
				var origin0 := old_origin.lerp(global_position, clampf((t0 - previous) / maxf(age - previous, 0.0001), 0, 1))
				var origin1 := old_origin.lerp(global_position, clampf((t1 - previous) / maxf(age - previous, 0.0001), 0, 1))
				_sweep_contacts(swing, origin0 + head_position(swing, t0), origin1 + head_position(swing, t1), t1, origin0, origin1)
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
	var half := AttackFootprint.FLAIL_ARC * 0.5
	var angle := deg_to_rad(lerpf(-half, half, eased)) * float(swing.sign)
	var reach := weapon.get_attack_range()
	if local_time < float(swing.windup):
		reach *= lerpf(0.70, 1.0, maxf(local_time / float(swing.windup), 0))
	elif local_time > float(swing.windup) + float(swing.duration):
		reach *= lerpf(1.0, 0.45, clampf((local_time - float(swing.windup) - float(swing.duration)) / RECOVER, 0, 1))
	return heading.rotated(angle) * reach


func head_radius(swing: Dictionary) -> float:
	return weapon.get_hit_radius() * (0.8 if bool(swing.child) else 1.0)


func _sweep_contacts(swing: Dictionary, from: Vector2, to: Vector2, at_time: float, from_origin: Vector2 = Vector2.INF, to_origin: Vector2 = Vector2.INF) -> void:
	var first_angle := heading.angle_to(from - (global_position if from_origin == Vector2.INF else from_origin))
	var last_angle := heading.angle_to(to - (global_position if to_origin == Vector2.INF else to_origin))
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive() or swing.hits.has(enemy.get_instance_id()):
			continue
		var offset := enemy.global_position - global_position
		if not AttackFootprint.in_flail_fan(offset, heading, weapon.get_attack_range()):
			continue
		var angle := heading.angle_to(offset)
		if angle < minf(first_angle, last_angle) - 0.001 or angle > maxf(first_angle, last_angle) + 0.001:
			continue
		# A chain cannot reach through blocking terrain.
		var ray := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, 4)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_apply_hit(swing, enemy, at_time)


func damage_for_contact(swing: Dictionary, at_time: float, contact_distance: float = -1.0) -> DamageEvent:
	var event: DamageEvent = swing.event.duplicate_event()
	var multiplier := float(swing.multiplier)
	var extension := (head_position(swing, at_time).length() if contact_distance < 0 else contact_distance) / maxf(weapon.get_attack_range(), 1)
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
	var event := damage_for_contact(swing, at_time, global_position.distance_to(where))
	event.hit_position = where
	if not bool(swing.child) and not split_triggered:
		split_triggered = true
		var children: Array[Dictionary] = []
		for profile in split_profiles:
			for _index in int(profile.child_count): children.append(profile)
		# Finish every queued swing before starting the next follow-through.
		for index in children.size():
			_add_swing(maxf(sequence_duration(), at_time), 0.03, 0.32, float(children[index].damage_multiplier), true, swings.size(), int(children[index].enchantment_start))
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


func trail_frame_for_swing(swing: Dictionary, at_time: float) -> int:
	var elapsed := at_time - float(swing.start) - float(swing.windup)
	var duration := float(swing.duration)
	if elapsed < -0.000001 or elapsed > duration + 0.000001:
		return -1
	# Split/continuation swings use their own clock, mapped onto the approved clip.
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	return clampi(int((WINDUP + progress * SWEEP) * TRAIL_FPS), 4, 14)


func trail_transform_for_swing(swing: Dictionary, at_time: float, frame: int) -> Transform2D:
	var sample_progress := clampf(((frame + 0.5) / TRAIL_FPS - WINDUP) / SWEEP, 0.0, 1.0)
	var eased := sample_progress * sample_progress * (3.0 - 2.0 * sample_progress)
	var half_arc := AttackFootprint.FLAIL_ARC * 0.5
	var sample_angle := deg_to_rad(lerpf(-half_arc, half_arc, eased))
	var head := head_position(swing, at_time)
	var factor := head.length() / TRAIL_AUTHORED_REACH
	# Mirror reverse swings, then align the sampled leading edge to the live head.
	var angle := head.angle() - sample_angle * float(swing.sign)
	return Transform2D(angle, Vector2.ZERO).scaled_local(Vector2(factor, factor * float(swing.sign)))


func _draw() -> void:
	if cancelled:
		return
	var tint := BASE_TINT
	if weapon.has_effect("fire"): tint = Color(1.0, 0.59, 0.25)
	elif weapon.has_effect("lightning"): tint = Color(0.57, 0.79, 1.0)
	elif weapon.has_effect("ice"): tint = Color(0.54, 0.97, 1.0)
	for swing in swings:
		var local_time := age - float(swing.start)
		var end := float(swing.windup) + float(swing.duration)
		if local_time < 0 or local_time >= end + RECOVER:
			continue
		var fade := minf(1.0, local_time / 0.045) * (1.0 - clampf((local_time - end) / RECOVER, 0, 1))
		var head := head_position(swing, age)
		var trail_frame := trail_frame_for_swing(swing, age)
		if trail_frame >= 0:
			var trail_tint := Color(tint.r / BASE_TINT.r, tint.g / BASE_TINT.g, tint.b / BASE_TINT.b, fade)
			draw_set_transform_matrix(trail_transform_for_swing(swing, age, trail_frame))
			draw_texture_rect_region(TRAIL, Rect2(-TRAIL_FRAME_SIZE * 0.5, TRAIL_FRAME_SIZE), Rect2(Vector2(trail_frame * TRAIL_FRAME_SIZE.x, 0), TRAIL_FRAME_SIZE), trail_tint)
			draw_set_transform(Vector2.ZERO)
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
