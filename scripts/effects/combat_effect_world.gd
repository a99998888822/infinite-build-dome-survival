extends RefCounted
class_name CombatEffectWorld

const FIRE_SEED_SCRIPT = preload("res://scripts/effects/fire_seed.gd")
const EXPLOSION_EFFECT_SCRIPT = preload("res://scripts/effects/explosion_effect.gd")
const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/effects/lightning_particle_effect.gd")
const ELECTRIC_SPARK_EFFECT_SCRIPT = preload("res://scripts/effects/electric_spark_effect.gd")
const ICE_FIELD_EFFECT_SCRIPT = preload("res://scripts/effects/ice_field_effect.gd")
const WATER_WAVE_EFFECT_SCRIPT = preload("res://scripts/effects/water_wave_effect.gd")
const LIGHT_SWORD_EFFECT_SCRIPT = preload("res://scripts/effects/light_sword_effect.gd")
const BLACK_HOLE_EFFECT_SCRIPT = preload("res://scripts/effects/black_hole_effect.gd")
const WIND_BLADE_EFFECT_SCRIPT = preload("res://scripts/effects/wind_blade_effect.gd")
const ELEMENT_REACTION_RESOLVER_SCRIPT = preload("res://scripts/effects/element_reaction_resolver.gd")
const EFFECT_PARAMETER_RESOLVER_SCRIPT = preload("res://scripts/effects/effect_parameter_resolver.gd")
const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const FIRE_PATCH_SCRIPT = preload("res://scripts/effects/fire_patch.gd")


static func trigger_weapon_impact(
	parent: Node, weapon: WeaponInstance, damage_event: DamageEvent,
	hit_position: Vector2, direction: Vector2 = Vector2.RIGHT,
	body: Node = null, _legacy_skip_lightning: bool = false, ground: bool = false
) -> void:
	if parent == null or weapon == null or damage_event == null:
		return
	AudioManager.begin_combat_audio()
	var visual_parent := _get_visual_parent(parent)
	var allow_bounce := not weapon.is_bounce_attack and not bool(damage_event.attack_context.get("bounce_used", false))
	var sequence := weapon.get_enchantment_sequence()
	for index in range(damage_event.enchantment_start, sequence.size()):
		var entry := sequence[index]
		var item_id := str(entry.item_instance_id)
		match str(entry.effect_id):
			"split":
				# Native weapon runtimes create one generation of branches. Only
				# their contacts continue the suffix after their own split slot.
				if not damage_event.split_child:
					break
			"bounce":
				if allow_bounce:
					damage_event.attack_context["bounce_used"] = true
					var replay := load("res://scripts/weapons/bounce_attack.gd").new() as Node2D
					visual_parent.add_child(replay)
					replay.initialize(weapon, hit_position, direction, body)
			"water": WATER_WAVE_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, item_id)
			"light_sword": LIGHT_SWORD_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, item_id)
			"black_hole": BLACK_HOLE_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, item_id)
			"fire":
				var result := _apply_element(body, "fire", visual_parent, damage_event, hit_position)
				if not bool(result.get("neutralized", false)):
					FIRE_SEED_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, direction, item_id)
			"explosion": EXPLOSION_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, item_id)
			"electric_spark": ELECTRIC_SPARK_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, item_id)
			"ice": ICE_FIELD_EFFECT_SCRIPT.spawn(visual_parent, hit_position, weapon, damage_event, item_id)
			"lightning":
				var target := body as EnemyController
				if ground:
					target = _ground_chain_target(weapon, hit_position, item_id)
				if target != null:
					LIGHTNING_EFFECT_SCRIPT.spawn(visual_parent, hit_position, target, weapon, damage_event, direction, item_id)
			"wind":
				if ground:
					_spawn_ground_wind(visual_parent, weapon, damage_event, hit_position, direction, item_id)
				elif body is EnemyController:
					_apply_wind(visual_parent, body, weapon, damage_event, hit_position, direction, item_id)
	AudioManager.end_combat_audio()


static func trigger_ground_weapon_impact(parent: Node, weapon: WeaponInstance, event: DamageEvent, point: Vector2, direction: Vector2) -> void:
	trigger_weapon_impact(parent, weapon, event, point, direction, null, false, true)


static func _ground_chain_target(weapon: WeaponInstance, point: Vector2, item_id: String) -> EnemyController:
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "lightning", {"jump_radius": 170.0}, item_id)
	var radius := maxf(32, context.get_resolved_parameter("jump_radius", 170) * context.get_resolved_parameter("attack_range_multiplier", 1))
	var nearest: EnemyController
	var distance := radius * radius + 0.001
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var next := point.distance_squared_to(enemy.global_position)
		if next < distance:
			nearest = enemy
			distance = next
	return nearest


static func _spawn_ground_wind(parent: Node, weapon: WeaponInstance, event: DamageEvent, point: Vector2, direction: Vector2, item_id: String) -> void:
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "wind", {
		"blade_speed": 480.0, "blade_lifetime": 0.46, "field_search_radius": 18.0, "field_radius_multiplier": 1.35,
	}, item_id)
	WIND_BLADE_EFFECT_SCRIPT.spawn(parent, point, direction, context.get_resolved_parameter("blade_speed", 480), context.get_resolved_parameter("blade_lifetime", 0.46), weapon, event, 0, _ground_wind_contact.bind(parent, weapon, event, direction, item_id), item_id)
	_expand_wind_fields(parent, point, context.get_resolved_parameter("field_search_radius", 18), context.get_resolved_parameter("field_radius_multiplier", 1.35))


static func _ground_wind_contact(enemy: EnemyController, parent: Node, weapon: WeaponInstance, event: DamageEvent, direction: Vector2, attachment_item_id: String) -> void:
	_apply_wind(parent, enemy, weapon, event, enemy.global_position, direction, attachment_item_id, false)


static func _get_visual_parent(parent: Node) -> Node:
	var render_world := PARTICLE_WORLD_SCRIPT.find_render_world(parent)
	return render_world if render_world != null else parent


static func _apply_element(enemy: Node, element_id: String, parent: Node, damage_event: DamageEvent, hit_position: Vector2) -> Dictionary:
	if enemy == null or not (enemy is EnemyController):
		return {}
	return ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(enemy, element_id, {
		"parent": parent,
		"hit_position": hit_position,
		"source_id": damage_event.source_weapon_id,
		"damage": damage_event.damage,
		"original_damage": damage_event.get_elemental_base_damage(),
		"element_damage_bonus": damage_event.element_damage_bonus,
		"source_player": damage_event.source_player,
		"damage_event": damage_event,
	})


static func _apply_wind(parent: Node, enemy: EnemyController, weapon: WeaponInstance, damage_event: DamageEvent, hit_position: Vector2, direction: Vector2, attachment_item_id: String, emit_blade: bool = true) -> void:
	var context := EFFECT_PARAMETER_RESOLVER_SCRIPT.build_weapon_context(weapon, "wind", {
		"damage_multiplier": 0.7,
		"knockback_speed": 450.0,
		"knockback_duration": 0.3,
		"blade_speed": 480.0,
		"blade_lifetime": 0.46,
		"field_search_radius": 18.0,
		"field_radius_multiplier": 1.35,
		"wet_propagation_radius": 92.0,
		"wet_propagation_limit": 4.0,
		"wet_duration": 3.0,
		"wet_slow_multiplier": 0.8,
	}, attachment_item_id)
	var away_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	if damage_event.source_player != null and is_instance_valid(damage_event.source_player):
		away_direction = damage_event.source_player.global_position.direction_to(enemy.global_position)
	if away_direction.is_zero_approx():
		away_direction = Vector2.RIGHT
	if emit_blade:
		WIND_BLADE_EFFECT_SCRIPT.spawn(parent, hit_position, away_direction, context.get_resolved_parameter("blade_speed", 480.0), context.get_resolved_parameter("blade_lifetime", 0.46), weapon, damage_event, enemy.get_instance_id(), Callable(), attachment_item_id)
	if enemy.can_be_pushed_by_wind():
		enemy.apply_knockback(away_direction, context.get_resolved_parameter("knockback_speed", 900.0), context.get_resolved_parameter("knockback_duration", 0.34))
	var wind_damage := damage_event.get_elemental_damage(context.get_resolved_parameter("damage_multiplier", 0.7))
	enemy.take_damage(wind_damage, damage_event.source_weapon_id, false, away_direction if enemy.can_be_pushed_by_wind() else Vector2.ZERO)
	var search_radius := maxf(context.get_resolved_parameter("field_search_radius", 18.0), 0.0)
	var field_multiplier := maxf(context.get_resolved_parameter("field_radius_multiplier", 1.35), 1.0)
	_expand_wind_fields(parent, enemy.global_position, search_radius, field_multiplier)
	if enemy.has_status("wet"):
		var propagation_radius := maxf(context.get_resolved_parameter("wet_propagation_radius", 92.0), 0.0)
		var propagation_limit := clampi(int(roundi(context.get_resolved_parameter("wet_propagation_limit", 4.0))), 0, 16)
		if propagation_limit == 0:
			return
		var propagated := 0
		for node in EnemyRegistry.get_registered_enemies():
			var other := node as EnemyController
			if other == null or other == enemy or not other.is_alive() or enemy.global_position.distance_to(other.global_position) > propagation_radius:
				continue
			ELEMENT_REACTION_RESOLVER_SCRIPT.apply_element(other, "water", {
				"parent": parent, "hit_position": other.global_position,
				"source_id": damage_event.source_weapon_id,
				"original_damage": damage_event.get_elemental_base_damage(),
				"damage_event": damage_event,
				"wet_duration": maxf(context.get_resolved_parameter("wet_duration", 3.0), 0.1),
				"wet_slow_multiplier": clampf(context.get_resolved_parameter("wet_slow_multiplier", 0.8), 0.05, 1.0),
			})
			ELEMENT_REACTION_RESOLVER_SCRIPT.emit_feedback(parent, "wet_spread", enemy.global_position, {"target": other.global_position})
			propagated += 1
			if propagated >= propagation_limit:
				break


static func _expand_wind_fields(parent: Node, point: Vector2, radius: float, multiplier: float) -> void:
	FIRE_PATCH_SCRIPT.expand_nearby_fields(point, radius, multiplier)
	for node in parent.get_tree().get_nodes_in_group("ice_fields"):
		var field := node as IceFieldEffect
		if is_instance_valid(field) and field.global_position.distance_to(point) <= radius + field._radius:
			field.expand_from_wind(multiplier)
