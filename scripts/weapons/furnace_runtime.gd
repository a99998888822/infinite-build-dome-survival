extends DirectedWeaponRuntime
class_name FurnaceRuntime
## Reactive pulses. Contacts run at the same 18 Hz as the approved pixel fire.
const ART = preload("res://scripts/effects/candidate_weapon_art.gd")
const PULSE_GAP := 11.0 / 60.0
const SPLIT_DELAY := 31.0 / 60.0
const FIRE_SECONDS := 0.72
const SPLIT_SECONDS := 0.62
var pulses: Array[Dictionary] = []
var queries := 0
var hit_count := 0
var knockback_count := 0
var reach := 160.0
var duration := FIRE_SECONDS
var _query := PhysicsShapeQueryParameters2D.new()
var _disk: ConvexPolygonShape2D

func initialize(source: WeaponInstance) -> void:
	bind_weapon(source, "furnace_runtimes")
	reach = source.get_hit_radius()
	_disk = AttackFootprint.projected_disk(1.0)
	_query.collision_mask = 2
	_query.collide_with_areas = false
	var profiles := source.get_split_profiles()
	for index in maxi(1, int(source.get_stat("projectile_count"))):
		var start := index * PULSE_GAP
		pulses.append(_pulse(start, false, 1.0, 0, 18, index * 0.23))
		for profile in profiles:
			# One complete outer ring per split attachment; its count changes density.
			pulses.append(_pulse(start + SPLIT_DELAY, true, float(profile.damage_multiplier), int(profile.enchantment_start), 9 * int(profile.child_count), index * 0.31))
	duration = (maxi(1, int(source.get_stat("projectile_count"))) - 1) * PULSE_GAP + (SPLIT_DELAY + SPLIT_SECONDS if not profiles.is_empty() else FIRE_SECONDS)
	_push_nearby()
	_advance_pulses()

func _pulse(start: float, split: bool, power: float, continuation: int, flares: int, phase: float) -> Dictionary:
	var event := weapon.calculate_damage_events()[0]
	event.split_child = split
	event.enchantment_start = continuation
	event.damage = maxi(1, roundi(event.damage * power))
	event.elemental_damage_scale *= power
	var excluded: Array[RID] = []
	return {"start": start, "split": split, "event": event, "flares": flares,
		"phase": phase, "hits": {}, "excluded": excluded, "tick": -1, "visual": null, "done": false}

func _contacts(shape: Shape2D, pose: Transform2D, excluded: Array[RID] = []) -> Array[EnemyController]:
	_query.shape = shape
	_query.transform = pose
	_query.exclude = excluded
	queries += 1
	var result: Array[EnemyController] = []
	var seen := {}
	for contact in get_world_2d().direct_space_state.intersect_shape(_query, maxi(32, EnemyRegistry.get_registered_enemies().size() * 2)):
		var enemy := contact.collider as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive() or seen.has(enemy.get_instance_id()): continue
		seen[enemy.get_instance_id()] = true
		result.append(enemy)
	return result

func _push_nearby() -> void:
	for enemy in _contacts(_disk, Transform2D(0.0, Vector2.ONE * reach, 0.0, global_position)):
		if not clear_path(self, global_position, enemy.global_position): continue
		var away := global_position.direction_to(enemy.global_position)
		enemy.apply_knockback(away if not away.is_zero_approx() else Vector2.RIGHT, 180.0, 0.18, weapon.get_stat("control_power"))
		knockback_count += 1

func _physics_process(delta: float) -> void:
	if not ready_to_tick(): return
	age += delta
	_advance_pulses()
	if age >= duration: cancel()

func _advance_pulses() -> void:
	for pulse in pulses:
		if bool(pulse.done): continue
		var elapsed := age - float(pulse.start)
		var seconds := SPLIT_SECONDS if bool(pulse.split) else FIRE_SECONDS
		if elapsed < 0.0: continue
		if pulse.visual == null and elapsed < seconds:
			pulse.visual = ART.ring(self, global_position, reach, bool(pulse.split), float(pulse.phase), int(pulse.flares))
			pulse.visual.manual_clock = true
		if is_instance_valid(pulse.visual): pulse.visual.sample(elapsed)
		var tick := floori(minf(elapsed, seconds - 0.001) * 18.0)
		if elapsed >= seconds:
			pulse.done = true
			if is_instance_valid(pulse.visual): pulse.visual.queue_free()
			pulse.visual = null
		if tick == int(pulse.tick): continue
		pulse.tick = tick
		var t := float(tick) / 18.0
		if bool(pulse.split):
			_hit_flares(pulse, t)
		else:
			var phase := t / FIRE_SECONDS
			var radius := lerpf(18.0, reach, 1.0 - pow(1.0 - minf(phase / 0.8, 1.0), 1.5))
			# The broad band includes its hot outer lip. Each pulse owns a hit set.
			var outer := radius + lerpf(40.0, 22.0, phase) * (1.0 - smoothstep(0.60, 1.0, phase)) * 0.82
			outer = minf(reach, outer)
			for enemy in _contacts(_disk, Transform2D(0.0, Vector2.ONE * outer, 0.0, global_position), pulse.excluded):
				_hit(pulse, enemy)

func _hit_flares(pulse: Dictionary, t: float) -> void:
	var phase := t / SPLIT_SECONDS
	var growth := sin(clampf(phase * 1.2, 0.0, 1.0) * PI)
	if growth < 0.08: return
	var length := 10.0 + growth * 22.0
	var release := 1.0 - smoothstep(0.60, 1.0, phase)
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for side in [1.0, -1.0]:
		for i in 9:
			var along := float(i if side > 0 else 8 - i) / 8.0
			if side < 0 and (i == 0 or i == 8): continue
			points.append(Vector2(lerpf(-12, length, along), side * (13.0 + growth * 7.0) * pow(maxf(sin(along * PI), 0.0), 0.65) * release))
	shape.points = points
	for i in int(pulse.flares):
		var angle := TAU * i / float(pulse.flares) - PI + float(pulse.phase) * 0.03
		var forward := Vector2.from_angle(angle)
		var ground := Transform2D(forward * Vector2(1, AttackFootprint.ELLIPSE_RATIO), forward.orthogonal() * Vector2(1, AttackFootprint.ELLIPSE_RATIO), global_position + forward * (reach + 13.0 + phase * 12.0) * Vector2(1, AttackFootprint.ELLIPSE_RATIO))
		for enemy in _contacts(shape, ground, pulse.excluded): _hit(pulse, enemy)

func _hit(pulse: Dictionary, enemy: EnemyController) -> void:
	var id := enemy.get_instance_id()
	if pulse.hits.has(id) or not clear_path(self, global_position, enemy.global_position): return
	pulse.hits[id] = true
	pulse.excluded.append(enemy.get_rid())
	var event: DamageEvent = pulse.event
	# Native fire participates in the existing wet/light/dark reaction rules.
	CombatEffectWorld._apply_element(enemy, "fire", get_parent(), event, enemy.global_position)
	deal_hit(enemy, event, global_position.direction_to(enemy.global_position), bool(pulse.split))
	hit_count += 1

func is_attacking() -> bool:
	return not cancelled and age < duration
