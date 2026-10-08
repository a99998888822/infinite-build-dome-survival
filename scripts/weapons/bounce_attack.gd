extends Node2D

# Owns exactly one native replay. Its source weapon remains the trade/cleanup key.
var weapon: WeaponInstance
var replay: WeaponInstance
var cancelled := false
var age := 0.0
var lifetime := 8.0


func initialize(source: WeaponInstance, point: Vector2, direction: Vector2, body: Node) -> void:
	weapon = source
	replay = source.make_bounce_copy(point)
	global_position = point
	add_to_group("weapon_runtime_effects")
	add_to_group("bounce_attacks")
	var heading := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var scale_time := 1.0 if replay.use_active_range_rules else replay.get_actual_attack_interval_seconds() / maxf(float(replay.attack_interval_ms) / 1000.0, 0.001)
	lifetime = maxf(8.0, replay.get_actual_attack_interval_seconds() * 3.0)
	if replay.is_mobility_weapon():
		var mobility := MobilityWeaponRuntime.new()
		add_child(mobility)
		mobility.initialize_replay(replay, point, heading, body as EnemyController)
	elif replay.is_grenade():
		var grenade := GrenadeProjectile.new()
		add_child(grenade)
		grenade.initialize(replay, replay.calculate_damage_events()[0], point, point)
		grenade.elliptical_blast = replay.use_active_range_rules
		grenade._detonate()
	elif replay.is_earth_hammer():
		# The first repeated ground node lands exactly on the captured impact.
		var nodes := replay.get_ground_node_count()
		var base_range := float(replay.weapon_data.ground_first_offset) + (nodes - 1) * float(replay.weapon_data.ground_node_spacing)
		replay.fixed_attack_origin = point - heading * float(replay.weapon_data.ground_first_offset) * replay.get_attack_range() / base_range
		var hammer := EarthHammer.new()
		add_child(hammer)
		hammer.initialize(replay, heading)
		hammer._physics_process(hammer.appear + hammer.slam + 0.00001)
	elif replay.is_mutant_tentacle():
		replay.fixed_attack_origin = point - heading * replay.get_attack_range() * 0.5
		var tentacle := MutantTentacle.new()
		add_child(tentacle)
		tentacle.initialize(replay)
		tentacle.try_attack(heading)
		tentacle._physics_process((tentacle.hit_time + 0.00001) * scale_time)
	elif replay.is_camp_dagger():
		replay.fixed_attack_origin = point - heading * replay.get_attack_range() * 0.55
		var dagger := CampDagger.new()
		add_child(dagger)
		dagger.initialize(replay, heading)
		if replay.use_active_range_rules:
			dagger.configure_continuous_combo()
		var cut: Dictionary = dagger.cuts[0]
		dagger._physics_process((float(cut.windup) + float(cut.sweep) * 0.5) * dagger.time_scale)
	elif replay.is_nightwatch_spear():
		replay.fixed_attack_origin = point - heading * replay.get_attack_range() * 0.5
		var spear := NightwatchSpear.new()
		add_child(spear)
		spear.initialize(replay, heading)
		spear._physics_process((spear.windup + spear.extend) * spear.time_scale)
	elif replay.is_meteor_flail():
		replay.fixed_attack_origin = point - heading * replay.get_attack_range()
		var flail := MeteorFlail.new()
		add_child(flail)
		flail.initialize(replay, heading)
		flail._physics_process((MeteorFlail.WINDUP + MeteorFlail.SWEEP * 0.5) * flail.time_scale)
	elif replay.is_copper_lamp():
		replay.fixed_attack_origin = point - heading * 16
		var lamp := CopperLamp.new()
		add_child(lamp)
		lamp.initialize(replay)
		lamp.manual_control = replay.use_active_range_rules
		lamp.manual_direction = heading
		lamp.externally_driven = true
		lamp.burst_active = true
		lamp._physics_process(0.00001)
		lifetime = lamp.burst_duration + 0.1
	elif replay.is_ritual_tome():
		# Tome attacks are pinpoint contacts, not a second player-following domain.
		preload("res://scripts/weapons/ritual_coin_hit.gd").spawn(self, replay, point, true)
		if body is EnemyController and body.is_alive():
			var event := replay.calculate_damage_events()[0]
			CombatEffectWorld.trigger_weapon_impact(self, replay, event, point, heading, body)
			body.take_damage(event.damage, event.source_weapon_id, event.is_critical, heading)
	else:
		var shared_hits: Dictionary = {}
		var angles := replay.get_projectile_angles()
		for angle in angles:
			var aim := heading.rotated(deg_to_rad(angle))
			var event := replay.calculate_damage_events()[0]
			if replay.is_coin_purse():
				var coin := CoinProjectile.new()
				add_child(coin)
				coin.initialize(replay, event, point, aim, shared_hits)
				if body is EnemyController and body.is_alive() and not shared_hits.has(body.get_instance_id()):
					coin._hit_enemy(body)
			else:
				_spawn_projectile(replay, event, aim, replay.get_attack_range(), point, {}, 0, body)


func _spawn_projectile(source: WeaponInstance, event: DamageEvent, direction: Vector2, reach: float, point: Vector2, ignored: Dictionary = {}, depth: int = 0, body: Node = null) -> bool:
	var projectile := ProjectileInstance.new()
	add_child(projectile)
	var path := str(source.weapon_data.get("projectile_texture", ""))
	var texture := load(path) as Texture2D if not path.is_empty() else null
	projectile.initialize(source, event, "bounce_%d" % projectile.get_instance_id(), point, direction, reach, texture, 1.0, _spawn_projectile, ignored, depth)
	if body is EnemyController and body.is_alive():
		if projectile._is_plasma_projectile():
			projectile._process_plasma_tick([body])
		else:
			projectile._on_body_entered(body)
	return true


func _physics_process(delta: float) -> void:
	if cancelled:
		return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	age += delta
	# Persistent equipped runtimes must not leave idle ghost weapons behind.
	# Let already-spawned companion effects finish their own lifetime.
	for child in get_children():
		if child is MeteorFlail:
			lifetime = maxf(lifetime, age + maxf(0, child.sequence_duration() - child.age) * child.time_scale + 0.1)
		if child is MutantTentacle and not child.attacking:
			child.cancel()
		elif child is CopperLamp and not child.burst_active:
			child.cancel()
	if age >= lifetime or get_child_count() == 0:
		cancel()


func cancel() -> void:
	cancelled = true
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	queue_free()
