extends RefCounted
class_name ActiveWeaponCasting
## Execution and cooldown belong to the weapon instance, never its slot number.
var loadout: Node
var states: Dictionary = {}

func state_for(weapon: WeaponInstance) -> Dictionary:
	if not states.has(weapon.instance_id):
		states[weapon.instance_id] = {"executing": false, "remaining": 0.0, "total": 0.0, "tail": 0.0, "body": null}
	return states[weapon.instance_id]

func can_cast(weapon: WeaponInstance) -> bool:
	var state := state_for(weapon)
	return not state.executing and float(state.remaining) <= 0.0

func auto_attack(all_weapons: bool = true) -> void:
	# Use the same snapshots, animation and cooldown as a manual cast.
	for weapon: WeaponInstance in loadout.weapon_instances:
		if not all_weapons and not weapon.is_copper_lamp():
			continue
		if not can_cast(weapon):
			continue
		var target := _auto_target(weapon)
		if target != null:
			cast(weapon, weapon.get_auto_target_position(target))

func _auto_target(weapon: WeaponInstance) -> EnemyController:
	if weapon.is_copper_lamp():
		# Acquisition and continuous tracking use the same range and line of sight.
		return DirectedWeaponRuntime.nearest(weapon, weapon.get_attack_range())
	var origin := weapon.get_attack_origin()
	var reach := weapon.get_attack_range()
	var nearest: EnemyController
	var nearest_distance := INF
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_alive():
			continue
		if enemy is EliteRusher and enemy.skill_state == "spawn":
			continue
		var offset := enemy.global_position - origin
		var distance := offset.length_squared()
		if distance >= nearest_distance:
			continue
		if weapon.is_ritual_tome():
			if (offset / weapon.get_domain_axes().max(Vector2.ONE)).length_squared() > 1.0:
				continue
		elif weapon.is_grenade():
			if (offset / AttackFootprint.grenade_range_axes(weapon).max(Vector2.ONE)).length_squared() > 1.0:
				continue
		elif distance > reach * reach:
			continue
		nearest = enemy
		nearest_distance = distance
	return nearest

func tick(delta: float) -> void:
	for weapon: WeaponInstance in loadout.weapon_instances:
		var state := state_for(weapon)
		if state.executing:
			state.tail = maxf(0.0, float(state.tail) - delta)
			var body: Variant = state.body.get_ref() if state.body is WeakRef else null
			var playing := false
			if is_instance_valid(body) and not body.cancelled:
				if body is CopperLamp:
					playing = body.burst_active
				elif body is MutantTentacle:
					playing = body.attacking
				elif body is MeteorFlail:
					playing = body.is_swinging()
				elif body.has_method("is_attacking"):
					playing = body.is_attacking()
			if not playing and float(state.tail) <= 0:
				_finish(weapon)
		else:
			state.remaining = maxf(0, float(state.remaining) - delta)

func _finish(weapon: WeaponInstance) -> void:
	var state := state_for(weapon)
	if not state.executing:
		return
	state.executing = false
	state.total = weapon.get_active_cooldown_seconds()
	state.remaining = state.total
	var body: Variant = state.body.get_ref() if state.body is WeakRef else null
	if is_instance_valid(body) and (body is CopperLamp or body is MutantTentacle):
		body.cancel()
	state.body = null

func interrupt(weapon: WeaponInstance) -> void:
	_finish(weapon)

func cast(source: WeaponInstance, point: Vector2) -> bool:
	if not can_cast(source) or not loadout.weapon_instances.has(source):
		return false
	if not is_instance_valid(loadout.owner_player) or not loadout.owner_player.alive or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return false
	if source.is_copper_lamp() and _auto_target(source) == null:
		return false
	var weapon := source.make_cast_copy()
	var origin: Vector2 = loadout.owner_player.global_position
	var offset := point - origin
	var aim: Vector2 = offset.normalized() if offset.length_squared() > 0.01 else loadout.owner_player.last_move_direction
	var root: Node = loadout._get_visual_root()
	var body: Node2D
	weapon.begin_attack()
	if weapon.is_copper_lamp():
		var lamp := CopperLamp.new()
		root.add_child(lamp)
		lamp.initialize(weapon)
		lamp.externally_driven = true
		lamp.burst_active = true
		body = lamp
	elif weapon.is_mutant_tentacle():
		var tentacle := MutantTentacle.new()
		root.add_child(tentacle)
		tentacle.initialize(weapon)
		tentacle.try_attack(aim)
		body = tentacle
	elif weapon.is_earth_hammer():
		var hammer := EarthHammer.new()
		root.add_child(hammer)
		hammer.initialize(weapon, aim)
		body = hammer
	elif weapon.is_camp_dagger():
		var dagger := CampDagger.new()
		root.add_child(dagger)
		dagger.initialize(weapon, aim)
		dagger.configure_continuous_combo()
		body = dagger
	elif weapon.is_nightwatch_spear():
		var spear := NightwatchSpear.new()
		root.add_child(spear)
		spear.initialize(weapon, aim)
		body = spear
	elif weapon.is_meteor_flail():
		var flail := MeteorFlail.new()
		root.add_child(flail)
		flail.initialize(weapon, aim)
		body = flail
	elif weapon.is_ritual_tome():
		var domain := RitualDomain.new()
		root.add_child(domain)
		domain.initialize(weapon, true)
		body = domain
	elif weapon.is_grenade():
		for landing in AttackFootprint.grenade_landings(weapon, offset):
			var grenade := GrenadeProjectile.new()
			root.add_child(grenade)
			grenade.initialize(weapon, weapon.calculate_damage_events()[0], origin, origin + landing)
			grenade.elliptical_blast = true
			grenade.blast_radius = AttackFootprint.grenade_blast_axes(weapon).x
		AudioManager.play_sfx_path(str(weapon.weapon_data.get("launch_sfx", "")), 100, "grenade_launch")
	elif weapon.is_coin_purse():
		loadout._fire_coins(weapon, aim)
	else:
		if not loadout._spawn_projectiles(weapon, weapon.calculate_damage_events()[0], origin + aim * weapon.get_attack_range(), weapon.get_attack_range()):
			return false
	if not weapon.is_coin_purse():
		loadout.weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
	source.volley_index += 1
	source.attack_context = weapon.attack_context
	source.attack_timer = 0
	var state := state_for(source)
	state.executing = true
	state.body = weakref(body) if body != null else null
	state.tail = float(weapon.weapon_data.get("active_recovery_ms", 180)) / 1000.0 if body == null else 0.0
	return true
