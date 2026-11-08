extends DirectedWeaponRuntime
class_name PatternFlightRuntime
## One recipe owns its bodies, hit budgets and hierarchy. Child procs never recompile it.
var plan: AttackPatternPlan
var live_source: WeaponInstance
var units: Array[Dictionary] = []
var period := 1.0
var reach := 200.0
var origin := Vector2.ZERO
var last_center := Vector2.ZERO
var satellite_radius := 40.0
var hit_count := 0
var completed_circles := 0
var fragment := false
var _shape := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()

func initialize(source: WeaponInstance, original: WeaponInstance, recipe: AttackPatternPlan, start: Vector2, aim: Vector2, target_offset: Vector2 = Vector2.INF) -> void:
	bind_weapon(source, "pattern_flights")
	live_source = original
	plan = recipe
	origin = start
	global_position = start
	last_center = source.owner_player.global_position
	heading = aim.normalized()
	period = source.get_active_cooldown_seconds()
	reach = source.get_attack_range()
	satellite_radius = recipe.get_satellite_radius(source)
	var angles := recipe.angles(source)
	for i in recipe.units.size():
		var copy := source.make_cast_copy()
		copy.attack_context = source.attack_context
		recipe.apply_unit(copy, i)
		var direction := heading if recipe.satellite else heading.rotated(deg_to_rad(angles[i]))
		var body := {"weapon": copy, "event": copy.calculate_damage_events()[0], "position": start,
			"direction": direction, "left": reach, "hits": {}, "budget": copy.get_pierce_hit_limit(),
			"ticks": 0, "tick_left": 0.0, "split": false, "alive": true, "spent": false, "released": false,
			"speed": maxf(copy.get_projectile_speed(), 1.0), "hold": 0.0,
			"trail": [], "plasma": null, "phase": TAU * i / maxi(recipe.units.size(), 1)}
		if source.is_grenade():
			var pointer := heading * reach if target_offset == Vector2.INF else target_offset
			body["landing"] = start + recipe.grenade_landing(copy, i, pointer)
		if recipe.orbit:
			body.position = last_center + _orbit_offset(float(body.phase))
		if recipe.satellite and i > 0:
			body.phase = TAU * (i - 1) / maxi(recipe.units.size() - 1, 1)
			body.position = (units[0].position as Vector2) + AttackFootprint.project(Vector2.from_angle(float(body.phase)) * satellite_radius)
		if str(source.weapon_data.get("projectile_behavior", "")) == "plasma":
			var visual := load("res://scripts/effects/plasma_ball_visual.gd").new() as Node2D
			add_child(visual)
			visual.initialize(copy, "pattern_%d" % i)
			body.plasma = visual
		units.append(body)
	_query.collision_mask = 4
	_query.collide_with_areas = false
	queue_redraw()

func is_attacking() -> bool:
	# A persistent orbit must not keep the weapon stuck in its casting animation.
	return not cancelled and age < 0.18

func _orbit_offset(angle: float) -> Vector2:
	return AttackFootprint.project(Vector2.from_angle(angle) * reach)

func _physics_process(delta: float) -> void:
	if not ready_to_tick(): return
	if plan.orbit and (live_source == null or not live_source.has_effect("orbit")):
		cancel()
		return
	# Sample the curve itself, including during a slow frame, not just its chord.
	var steps := maxi(1, ceili(delta / minf(1.0 / 60.0, period / 96.0)))
	for step in steps:
		if cancelled: break
		_advance(delta / steps)
	queue_redraw()

func _advance(delta: float) -> void:
	var old_age := age
	age += delta
	var center := weapon.owner_player.global_position
	var teleported := center.distance_to(last_center) > maxf(80.0, weapon.owner_player.velocity.length() * delta * 3.0)
	var circle := int(age / period)
	if plan.orbit and circle > completed_circles:
		completed_circles = circle
		weapon.begin_attack()
		for unit in units:
			# An infinite orbit must pick up damage upgrades at the next revolution.
			if is_instance_valid(live_source.owner_player):
				for stat in StatDefinitions.get_all_stat_ids():
					if stat != "projectile_count": unit.weapon._cast_stats[stat] = live_source.get_stat(stat)
					unit.weapon._cast_player_stats[stat] = live_source.owner_player.get_stat(stat)
				unit.weapon._cast_principal = live_source.get_current_principal()
			unit.weapon.attack_context = weapon.attack_context
			unit.event = unit.weapon.calculate_damage_events()[0]
			unit.hits.clear()
			unit.budget = (unit.weapon as WeaponInstance).get_pierce_hit_limit()
			unit.ticks = 0
			unit.tick_left = 0.0
			unit.spent = false
			unit.split = false
	for i in units.size():
		var unit := units[i]
		if not unit.alive: continue
		unit.tick_left = maxf(0.0, float(unit.tick_left) - delta)
		var start: Vector2 = unit.position
		var end := start
		if plan.satellite and i > 0 and not unit.released:
			if not units[0].alive and not weapon.is_grenade():
				unit.released = true
			else:
				end = (units[0].position as Vector2) + plan.satellite_position(i, age, weapon)
		if plan.orbit and not (plan.satellite and i > 0):
			end = center + _orbit_offset(float(unit.phase) + age * TAU / period)
		elif not (plan.satellite and i > 0 and not unit.released):
			if weapon.is_grenade():
				end = origin.lerp(unit.landing, clampf(age / _grenade_seconds(), 0, 1))
			elif weapon.is_meteor_flail() and not fragment:
				end = center + Vector2.from_angle(heading.angle() + lerpf(-1.2, 1.2, clampf(age / 0.6, 0, 1))) * reach
			elif weapon.is_nightwatch_spear() and not fragment:
				end = center + heading * reach * sin(clampf(age / 0.5, 0, 1) * PI)
			else:
				var flight_speed := maxf(weapon.get_projectile_speed(), 450.0 if fragment else 1.0)
				var recovery_delta := maxf(0.0, delta - float(unit.hold))
				unit.hold = maxf(0.0, float(unit.hold) - delta)
				unit.speed = move_toward(float(unit.speed), flight_speed, flight_speed * recovery_delta / maxf(0.001, float(weapon.weapon_data.get("plasma_speed_recovery_ms", 120.0)) / 1000.0))
				end = start + (unit.direction as Vector2) * minf(float(unit.speed) * delta, float(unit.left))
		if teleported and plan.orbit:
			start += center - last_center
			unit.trail.clear()
		var motion := end - start
		if motion.length_squared() > 0.001: unit.direction = motion.normalized()
		unit.position = end
		if not plan.orbit:
			# Orbiting satellites share forward range; rotation must not eat it.
			if plan.satellite and i > 0 and not unit.released: unit.left = units[0].left
			else: unit.left = maxf(0.0, float(unit.left) - motion.length())
		# Subdivide angular motion, so high speed cannot skip narrow targets.
		var steps := maxi(1, ceili(motion.length() / maxf((unit.weapon as WeaponInstance).get_hit_radius(), 6.0)))
		for step in steps:
			if not unit.alive or unit.spent: break
			_contact(unit, start.lerp(end, float(step) / steps), start.lerp(end, float(step + 1) / steps))
		if weapon.is_grenade() and not plan.orbit and age >= _grenade_seconds() and unit.alive:
			_detonate(unit)
		if not plan.orbit and not weapon.is_grenade():
			# Vector2 precision can leave a positive subpixel remainder at the endpoint.
			if float(unit.left) <= 0.01 or (not fragment and ((weapon.is_meteor_flail() and age >= 0.6) or (weapon.is_nightwatch_spear() and age >= 0.5))): unit.alive = false
		if unit.plasma != null:
			unit.plasma.global_position = unit.position
			unit.plasma.visible = bool(unit.alive)
			unit.plasma.modulate.a = 0.5 if unit.spent else 1.0
			unit.plasma.advance(delta)
		var trail: Array = unit.trail
		if age - old_age > 0 and (trail.is_empty() or (trail.back() as Vector2).distance_to(end) > 6): trail.append(end)
		while trail.size() > 8: trail.pop_front()
	last_center = center
	if not plan.orbit and units.all(func(unit): return not unit.alive): cancel()
	queue_redraw()

func _grenade_seconds() -> float:
	return maxf(0.01, float(weapon.weapon_data.get("grenade_flight_seconds", 0.45)))

func _contact(unit: Dictionary, start: Vector2, end: Vector2) -> void:
	var source: WeaponInstance = unit.weapon
	if source.weapon_id in AttackPatternPlan.ORBIT_MELEE:
		# The original physical melee contact can hit every body it sweeps.
		unit.budget = 2147483647
	_shape.radius = maxf(4.0, source.get_hit_radius())
	_query.shape = _shape
	_query.transform = Transform2D(0, start)
	_query.motion = end - start
	var space := get_world_2d().direct_space_state
	var wall := not space.intersect_shape(_query, 1).is_empty() or space.cast_motion(_query)[0] < 1.0
	if wall:
		if plan.orbit: return # Orbit keeps its phase, but cannot hit through terrain.
		unit.alive = false
		return
	ProjectileGuard.intercept_segment(self, source, start, end, _shape.radius)
	if weapon.is_grenade() and not plan.orbit: return
	var plasma := str(weapon.weapon_data.get("projectile_behavior", "")) == "plasma"
	if plasma and float(unit.tick_left) > 0: return
	var hits: Array[Dictionary] = []
	for enemy in EnemyRegistry.get_registered_enemies():
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		if not plasma and unit.hits.has(enemy.get_instance_id()): continue
		if plan.orbit and not clear_path(self, weapon.owner_player.global_position, enemy.global_position): continue
		var entry := AttackFootprint.body_entry_fraction(_shape, Transform2D(0, start), end - start, enemy)
		if not is_inf(entry): hits.append({"enemy": enemy, "entry": entry})
	hits.sort_custom(func(a, b): return a.entry < b.entry)
	for hit in hits:
		var enemy: EnemyController = hit.enemy
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		if weapon.is_grenade():
			_detonate(unit)
			break
		_hit(unit, enemy, plasma)
		if not plasma:
			unit.budget -= 1
			if int(unit.budget) <= 0 and weapon.weapon_id not in AttackPatternPlan.ORBIT_MELEE:
				if plan.orbit: unit.spent = true
				else: unit.alive = false
				break
	if plasma and not hits.is_empty():
		unit.speed = maxf(1.0, float(weapon.weapon_data.get("plasma_contact_speed", 20.0)))
		unit.hold = float(weapon.weapon_data.get("plasma_contact_hold_ms", 160.0)) / 1000.0
		unit.ticks += 1
		unit.tick_left = float(weapon.weapon_data.get("plasma_tick_interval", 0.1))
		# Radial plasma remains damaging throughout its flight; keep the native
		# tick cadence and contact slowdown, without a five-tick expiry.
		if int(unit.ticks) >= 5 and not (plan.radial and not plan.orbit):
			if plan.orbit: unit.spent = true
			else: unit.alive = false

func _hit(unit: Dictionary, enemy: EnemyController, plasma: bool) -> void:
	unit.hits[enemy.get_instance_id()] = true
	var event: DamageEvent = unit.event.duplicate_event()
	event.hit_position = enemy.global_position
	if weapon.is_meteor_flail() and enemy.global_position.distance_to(weapon.owner_player.global_position) >= reach * float(weapon.weapon_data.get("flail_outer_threshold", 0.8)):
		var power := float(weapon.weapon_data.get("flail_outer_multiplier", 1.5))
		event.damage = maxi(1, roundi(event.damage * power))
		event.elemental_damage_scale *= power
	var effect_event := event.duplicate_event()
	if plasma:
		effect_event.damage = maxi(1, roundi(effect_event.damage * 0.2))
		effect_event.elemental_damage_scale *= 0.2
	EFFECTS.trigger_weapon_impact(get_parent(), unit.weapon, effect_event, event.hit_position, unit.direction, enemy)
	if not unit.split:
		unit.split = true
		_spawn_splits(unit, event, enemy)
	enemy.take_attack_damage(event.damage, event, event.is_critical, unit.direction)
	weapon.play_projectile_hit_sfx(str(unit.phase))
	hit_count += 1
	target_hit.emit(enemy.get_instance_id(), event.damage, false)

func _spawn_splits(unit: Dictionary, event: DamageEvent, enemy: EnemyController) -> void:
	var source: WeaponInstance = unit.weapon
	for profile in source.get_split_profiles():
		for i in int(profile.child_count):
			var child_event := event.continue_after_split(profile)
			var power := float(profile.damage_multiplier)
			child_event.damage = maxi(1, roundi(event.damage * power))
			child_event.original_damage = maxi(1, roundi(event.original_damage * power))
			child_event.element_damage_bonus = roundi(event.element_damage_bonus * power)
			var direction: Vector2 = (unit.direction as Vector2).rotated(deg_to_rad(lerpf(-float(profile.spread_angle), float(profile.spread_angle), float(i + 1) / (int(profile.child_count) + 1))))
			if source.weapon_id in AttackPatternPlan.ORBIT_MELEE:
				var child := PatternFlightRuntime.new()
				var recipe := AttackPatternPlan.new()
				recipe.units.append({"mass":source.pattern_damage_scale,"size":source.pattern_size_scale * 0.65,"merged":false})
				get_parent().add_child(child)
				child.fragment = true
				child.initialize(source, live_source, recipe, enemy.global_position, direction)
				child.units[0].event = child_event
				child.units[0].hits = unit.hits.duplicate()
				child.units[0].split = true
				child.units[0].left = reach * 0.65
				child.units[0].speed = 450.0
			elif source.is_coin_purse() or source.is_hand_cannon():
				var coin := CannonPellet.new() if source.is_hand_cannon() else CoinProjectile.new()
				get_parent().add_child(coin)
				coin.initialize(source, child_event, enemy.global_position, direction, unit.hits, 1)
			else:
				var child := ProjectileInstance.new()
				get_parent().add_child(child)
				var texture := load(str(source.weapon_data.get("projectile_texture", "res://assets/sprites/weapons/projectiles/projectile_wood_arrow.png"))) as Texture2D
				child.initialize(source, child_event, "pattern_split", enemy.global_position, direction, reach * 0.65, texture, 0.65, Callable(), unit.hits, 1)

func _detonate(unit: Dictionary) -> void:
	var grenade := GrenadeProjectile.new()
	get_parent().add_child(grenade)
	grenade.initialize(unit.weapon, unit.event, unit.position, unit.position)
	grenade.elliptical_blast = true
	grenade.elapsed = grenade.flight_seconds
	grenade._detonate()
	if plan.orbit: unit.spent = true
	else: unit.alive = false

func _draw() -> void:
	if cancelled: return
	for i in units.size():
		var unit := units[i]
		if not unit.alive: continue
		var source: WeaponInstance = unit.weapon
		var point: Vector2 = unit.position - global_position
		var alpha := 0.5 if unit.spent else 1.0
		var tint := Color(1, 1, 1, alpha)
		var radius := source.get_hit_radius()
		var size := source.get_projectile_visual_scale()
		var angle := (unit.direction as Vector2).angle()
		var trail: Array = unit.trail
		for t in range(1, trail.size()):
			draw_line((trail[t - 1] as Vector2) - global_position, (trail[t] as Vector2) - global_position, Color(0.65,0.76,1.0,0.12 * alpha), 2.0)
		if source.is_meteor_flail():
			var center := (units[0].position as Vector2) if plan.satellite and i > 0 else weapon.owner_player.global_position
			draw_line(center - global_position, point, Color(0.37,0.4,0.44,alpha), 3)
		if source.weapon_id == "weapon_plasma_cannon": continue
		if source.is_grenade():
			if not plan.orbit: point.y -= sin(clampf(age / _grenade_seconds(),0,1) * PI) * float(source.weapon_data.get("grenade_arc_height", 93))
			draw_set_transform(point.round(), angle, Vector2.ONE * size)
			draw_rect(Rect2(-6,-6,12,12), Color(0.11,0.14,0.13,alpha))
			draw_rect(Rect2(-4,-4,8,8), Color(0.45,0.52,0.43,alpha))
			draw_rect(Rect2(-2,-8,4,3), Color(0.9,0.65,0.3,alpha))
		elif source.is_coin_purse():
			draw_set_transform(point.round(), age * 2.0, Vector2.ONE * size)
			draw_texture_rect_region(CoinProjectile.COIN, Rect2(-8,-8,16,16), Rect2((int(age * 18) % 8) * 16,0,16,16), tint)
		elif source.is_hand_cannon():
			draw_set_transform(point.round(), angle, Vector2.ONE * size)
			draw_texture_rect_region(CannonPellet.ATLAS, Rect2(-24,-8,48,16), Rect2((int(age * 20) % 4)*48,0,48,16), tint)
		elif source.is_meteor_flail():
			draw_set_transform(point.round(), age * 4)
			draw_texture_rect(MeteorFlail.HEAD, Rect2(-radius,-radius,radius*2,radius*2), false, tint)
		elif source.is_earth_hammer():
			draw_atlas(EarthHammer.HAMMER, 64, 8, Vector2(46,49), point.round(), angle, Vector2.ONE * size * 2.2, alpha)
		elif source.is_mutant_tentacle():
			# A compact curled limb travels with the damaging tip; no fake line shield.
			draw_atlas(MutantTentacle.BODY, 128, 3, Vector2(66,68), point.round(), angle + PI / 2, Vector2.ONE * radius / 28.0, alpha)
		elif source.is_nightwatch_spear():
			draw_set_transform(point.round(), angle)
			draw_texture_rect_region(NightwatchSpear.SPEAR, Rect2(-48*size,-radius,96*size,radius*2), NightwatchSpear.SOURCE_RECT, tint)
		elif source.is_camp_dagger():
			draw_set_transform(point.round(), angle, Vector2.ONE * size * 2)
			draw_texture(CampDagger.BLADE, -CampDagger.BLADE.get_size()*0.5, tint)
		else:
			var texture := load(str(source.weapon_data.projectile_texture)) as Texture2D
			draw_set_transform(point.round(), angle, Vector2.ONE * size)
			draw_texture(texture, -texture.get_size()*0.5, tint)
		draw_set_transform(Vector2.ZERO)
