extends RefCounted
class_name ParticleMotionBehavior


static func create_state(origin: Vector2, direction: Vector2, options: Dictionary) -> Dictionary:
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	return {
		"motion_type": str(options.get("motion_type", "attached")),
		"position": origin,
		"origin": origin,
		"direction": safe_direction,
		"speed": maxf(float(options.get("motion_speed", options.get("speed", 0.0))), 0.0),
		"outbound_duration": maxf(float(options.get("outbound_duration", 0.25)), 0.01),
		"outbound_distance": maxf(float(options.get("outbound_distance", 160.0)), 1.0),
		"return_speed": maxf(float(options.get("return_speed", 360.0)), 0.0),
		"return_acceleration": maxf(float(options.get("return_acceleration", 900.0)), 0.0),
		"turn_rate": maxf(float(options.get("turn_rate", 8.0)), 0.0),
		"elapsed": 0.0,
		"phase": "outbound",
		"orbit_radius": maxf(float(options.get("orbit_radius", 40.0)), 0.0),
		"orbit_angle": float(options.get("orbit_angle", 0.0)),
		"angular_speed": float(options.get("angular_speed", 4.0)),
	}


static func advance(state: Dictionary, delta: float, anchor_position: Vector2 = Vector2.ZERO) -> Dictionary:
	var motion_type := str(state.get("motion_type", "attached"))
	if motion_type == "attached":
		return state
	var position: Vector2 = state.get("position", Vector2.ZERO)
	var direction: Vector2 = state.get("direction", Vector2.RIGHT)
	var elapsed := float(state.get("elapsed", 0.0)) + delta
	match motion_type:
		"linear":
			position += direction * float(state.get("speed", 0.0)) * delta
		"boomerang":
			var phase := str(state.get("phase", "outbound"))
			if phase == "outbound":
				position += direction * float(state.get("speed", 0.0)) * delta
				var distance := position.distance_to(state.get("origin", position))
				if elapsed >= float(state.get("outbound_duration", 0.25)) or distance >= float(state.get("outbound_distance", 160.0)):
					state["phase"] = "return"
			else:
				var desired_direction := position.direction_to(anchor_position)
				direction = direction.lerp(desired_direction, clampf(float(state.get("turn_rate", 8.0)) * delta, 0.0, 1.0)).normalized()
				var return_speed := move_toward(float(state.get("speed", 0.0)), float(state.get("return_speed", 360.0)), float(state.get("return_acceleration", 900.0)) * delta)
				state["speed"] = return_speed
				position += direction * return_speed * delta
		"orbit":
			var angle := float(state.get("orbit_angle", 0.0)) + float(state.get("angular_speed", 4.0)) * delta
			state["orbit_angle"] = angle
			position = anchor_position + Vector2.from_angle(angle) * float(state.get("orbit_radius", 40.0))
	state["position"] = position
	state["direction"] = direction
	state["elapsed"] = elapsed
	return state
