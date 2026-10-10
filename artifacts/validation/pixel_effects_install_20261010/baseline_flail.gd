extends MeteorFlail
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
		if local_time < 0 or local_time >= end + RECOVER:
			continue
		var fade := minf(1.0, local_time / 0.045) * (1.0 - clampf((local_time - end) / RECOVER, 0, 1))
		var head := head_position(swing, age)
		if local_time >= float(swing.windup) and local_time <= end:
			var current_angle := heading.angle_to(head)
			var half_arc := deg_to_rad(AttackFootprint.FLAIL_ARC * 0.5)
			var trailing_angle := clampf(current_angle - float(swing.sign) * deg_to_rad(25), -half_arc, half_arc)
			var fan := PackedVector2Array()
			for i in 17:
				fan.append(heading.rotated(lerpf(trailing_angle, current_angle, i / 16.0)) * weapon.get_attack_range())
			for i in range(16, -1, -1):
				fan.append(heading.rotated(lerpf(trailing_angle, current_angle, i / 16.0)) * 20)
			if absf(trailing_angle - current_angle) > 0.001:
				draw_colored_polygon(fan, Color(tint, 0.16 * fade))
			draw_arc(Vector2.ZERO, weapon.get_attack_range(), heading.angle() + minf(trailing_angle, current_angle), heading.angle() + maxf(trailing_angle, current_angle), 20, Color(tint, 0.6 * fade), 2, true)
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
