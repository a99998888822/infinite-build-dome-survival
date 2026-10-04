extends DirectedWeaponRuntime
class_name CopperLamp

const FIRE := preload("res://assets/sprites/weapons/copper_lamp/copper_lamp.png")
signal spray_started
var heat := 0.0
var cooling := 0.0
var cooling_duration := 2.6
var firing := false
var target: EnemyController
var tick_left := 0.0
var proc_left := 0.0
var beams: Array[Dictionary] = []
var resonance_controlled := false
var burst_active := false
## Optional directed control for the active-combat review; automatic mode is unchanged.
var manual_control := false
var manual_direction := Vector2.RIGHT


func try_resonance_attack() -> bool:
	if burst_active:
		return false
	var next_target := nearest(weapon, weapon.get_attack_range())
	if next_target == null:
		return false
	# Followers use the leader's cooldown, including the lamp's heat lock.
	heat = 0
	cooling = 0
	tick_left = 0
	proc_left = 0
	burst_active = true
	target = next_target
	heading = weapon.get_attack_origin().direction_to(target.global_position)
	return true


func initialize(source: WeaponInstance) -> void:
	bind_weapon(source, "copper_lamps")


func _physics_process(delta: float) -> void:
	if not ready_to_tick():
		return
	age += delta
	global_position = weapon.get_attack_origin()
	if manual_control and not manual_direction.is_zero_approx():
		heading = manual_direction.normalized()
	proc_left = maxf(0, proc_left - delta)
	var was_firing := firing
	firing = false
	beams.clear()
	if cooling > 0:
		cooling = maxf(0, cooling - delta)
		heat = cooling / cooling_duration
		target = null
	else:
		target = null if manual_control else nearest(weapon, weapon.get_attack_range())
		if not burst_active and not resonance_controlled and weapon.attack_timer <= 0 and is_instance_valid(target):
			burst_active = true
		if burst_active:
			firing = true
			if not was_firing:
				if is_instance_valid(target):
					heading = global_position.direction_to(target.global_position)
				tick_left = 0
				if not resonance_controlled:
					weapon.begin_attack()
				spray_started.emit()
			elif is_instance_valid(target):
				var relative := target.global_position - global_position
				if not relative.is_zero_approx():
					var turn := deg_to_rad(float(weapon.weapon_data.get("lamp_turn_degrees_per_second", 180))) * delta
					heading = Vector2.from_angle(rotate_toward(heading.angle(), relative.angle(), turn))
			# A started burst burns for its full duration, even with no target.
			_build_beams()
			var available := maxf(0, (1.0 - heat) * float(weapon.weapon_data.lamp_spray_ms) / 1000.0)
			var firing_delta := minf(delta, available)
			heat = minf(1, heat + firing_delta * 1000.0 / float(weapon.weapon_data.lamp_spray_ms))
			tick_left -= firing_delta
			var interval := maxf(0.025, float(weapon.weapon_data.lamp_tick_ms) / 1000.0 * speed_scale())
			while tick_left <= 0:
				_tick_damage()
				tick_left += interval
			if heat >= 0.99999:
				cooling_duration = weapon.get_actual_attack_interval_seconds()
				cooling = cooling_duration
				firing = false
				burst_active = false
		else:
			heat = maxf(0, heat - delta / weapon.get_actual_attack_interval_seconds())
			tick_left = 0
	queue_redraw()


func _build_beams() -> void:
	for angle in weapon.get_projectile_angles():
		beams.append({"direction": heading.rotated(deg_to_rad(angle)), "reach": weapon.get_attack_range(), "power": 1.0, "child": false})
	# Side jets share the same uninterrupted burst; no recursive splitting.
	for profile in weapon.get_split_profiles():
		for i in int(profile.child_count):
			var fraction := float(i + 1) / float(int(profile.child_count) + 1)
			var angle := lerpf(-float(profile.spread_angle), float(profile.spread_angle), fraction)
			beams.append({"direction": heading.rotated(deg_to_rad(angle)), "reach": weapon.get_attack_range() * 0.65, "power": profile.damage_multiplier, "child": true, "enchantment_start": profile.enchantment_start})


func _tick_damage() -> void:
	var can_proc := proc_left <= 0
	# Sorting the registry's backing array changes target order for other weapons.
	var enemies := EnemyRegistry.get_registered_enemies().duplicate()
	enemies.sort_custom(func(a: Node, b: Node): return global_position.distance_squared_to((a as Node2D).global_position) < global_position.distance_squared_to((b as Node2D).global_position))
	AudioManager.begin_combat_audio()
	weapon.reset_hit_sfx_state()
	for beam in beams:
		var proc_used := false
		var event := weapon.calculate_damage_events()[0]
		event.split_child = bool(beam.child)
		event.enchantment_start = int(beam.get("enchantment_start", 0))
		event.damage = maxi(1, roundi(event.damage * float(beam.power)))
		event.elemental_damage_scale *= float(beam.power)
		var direction: Vector2 = beam.direction
		for node in enemies:
			var enemy := node as EnemyController
			if not is_instance_valid(enemy) or not enemy.is_alive():
				continue
			if not AttackFootprint.in_lamp_cone(enemy.global_position - global_position, direction, float(beam.reach), weapon.get_lamp_cone_degrees()):
				continue
			if not clear_path(self, global_position, enemy.global_position):
				continue
			if can_proc and not proc_used:
				var proc := event.duplicate_event()
				proc.elemental_damage_scale *= float(weapon.weapon_data.lamp_proc_percent) / 100.0
				EFFECTS.trigger_weapon_impact(get_parent(), weapon, proc, enemy.global_position, direction, enemy)
				proc_used = true
				proc_left = float(weapon.weapon_data.lamp_proc_ms) / 1000.0
			deal_hit(enemy, event, direction, bool(beam.child), false)
	AudioManager.end_combat_audio()


func _draw() -> void:
	if cancelled:
		return
	if firing:
		for beam in beams:
			var direction: Vector2 = beam.direction
			_draw_cone_flame(direction, float(beam.reach), bool(beam.child))
	if heat > 0:
		draw_rect(Rect2(-18, 32, 36, 4), Color("172022"))
		draw_rect(Rect2(-17, 33, 34 * heat, 2), Color("9c6545") if cooling > 0 else Color("e89c4f"))


func _draw_cone_flame(direction: Vector2, reach: float, child: bool) -> void:
	var half := deg_to_rad(weapon.get_lamp_cone_degrees()) * 0.5
	var origin := direction * 16.0
	# Pixel tongues travel along the same clipped rays as the real damage cone.
	for i in 90:
		var progress := fposmod(age * (1.1 + (i % 5) * 0.08) + i * 0.618034, 1.0)
		var angle := sin(i * 13.7) * half * 0.96
		var ray := direction.rotated(angle)
		var projection := origin.dot(ray)
		var extent := -projection + sqrt(maxf(0, projection * projection + reach * reach - origin.length_squared()))
		var point := origin + ray * extent * progress
		var size := (2.0 + progress * 5.0) * (0.7 if child else 1.0)
		var color := Color("ffdb85") if i % 3 == 0 else Color("ed8737")
		if i % 5 == 0:
			color = Color("ab4b2d")
		color.a = (1.0 - progress * 0.75) * (0.6 if child else 0.85)
		draw_rect(Rect2((point - Vector2.ONE * size * 0.5).snapped(Vector2(2, 2)), Vector2.ONE * snappedf(size, 2)), color)
