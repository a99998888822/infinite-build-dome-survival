extends "res://scripts/tests/pixel_combat_effect_test.gd"
const BEFORE = preload("res://scripts/tests/fixtures/thunder_baseline_chain.gd")
const CURRENT = preload("res://scripts/effects/lightning_particle_effect.gd")
const PARAMS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const OLD_PARAMS = preload("res://scripts/tests/fixtures/thunder_baseline_parameter_resolver.gd")

class CustomWeapon extends WeaponInstance:
	var custom_damage := 20.0
	func get_attached_item_instances() -> Array[Dictionary]:
		return [{"effect_ids": ["thunder_fire"], "effect_parameters": {"damage": custom_damage}}]

func signature(context: RefCounted) -> Array:
	return [context.effect_id, context.source_weapon_id, context.parameters, context.modifiers, context.tags, context.color_override,
		context.get_resolved_parameter("damage"), context.get_resolved_parameter("radius")]

func check_contexts() -> void:
	var input := {"damage": 18.0, "radius": 72.0}
	weapon.weapon_data = {"tags": ["ranged"]}
	weapon._attached_item_instances = [{"item_instance_id": "first", "effect_ids": ["thunder_fire"], "effect_parameters": {"damage": 25.0}, "rolled_parameters": {"radius": 75.0}}]
	for scenario in 10:
		match scenario:
			1: weapon._attached_item_instances[0].effect_parameters.damage = 31.0
			2: weapon._attached_item_instances[0].rolled_parameters.radius = 90.0
			3: weapon.effect_modifiers.append({"effect_id": "thunder_fire", "channel": "damage", "operation": "add_flat", "value": 4.0})
			4: weapon.effect_modifiers[0].value = 13.0
			5: weapon.runtime_stats["control_power"] = 80.0
			6: weapon.weapon_data.tags.append("fire")
			7: weapon.weapon_data.rarity = "epic"
			8: input.damage = 42.0
			9: weapon._attached_item_instances.clear()
		var expected := OLD_PARAMS.build_weapon_context(weapon, "thunder_fire", input)
		var actual := PARAMS.build_cached_weapon_context(weapon, "thunder_fire", input)
		check(signature(actual) == signature(expected), "context observes direct nested mutation %d" % scenario)
		check(actual == PARAMS.build_cached_weapon_context(weapon, "thunder_fire", input), "unchanged context is reused %d" % scenario)
	var custom := CustomWeapon.new()
	for damage in [20.0, 33.0]:
		custom.custom_damage = damage
		check(PARAMS.build_cached_weapon_context(custom, "thunder_fire", input).get_resolved_parameter("damage") == damage, "custom getter remains authoritative")

func check_selection(old: Node, updated: Node, origin: Vector2, label: String) -> void:
	check(old._find_farthest_enemy(origin) == updated._find_farthest_enemy(origin), label + " farthest and tie order")
	seed(10202026)
	var expected: Array = []
	for i in 12: expected.append(old._find_random_enemy(origin))
	var random_after := randf()
	seed(10202026)
	var actual: Array = []
	for i in 12: actual.append(updated._find_random_enemy(origin))
	check(actual == expected and randf() == random_after, label + " random choices and RNG")

func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2(170, 0), Vector2(-170, 0), Vector2(20, 0), Vector2(171, 0)])
	check_contexts()
	var old := BEFORE.new()
	var updated := CURRENT.new()
	add_child(old)
	add_child(updated)
	old.set_process(false)
	updated.set_process(false)
	old._jump_radius = 170.0
	updated._jump_radius = 170.0
	check_selection(old, updated, Vector2.ZERO, "initial boundaries")
	old._visited[enemies[1].get_instance_id()] = true
	updated._visited[enemies[1].get_instance_id()] = true
	check_selection(old, updated, Vector2.ZERO, "independent visited ledger")
	enemies[0].alive = false
	check_selection(old, updated, Vector2.ZERO, "death without geometry change")
	enemies[0].alive = true
	check_selection(old, updated, Vector2.ZERO, "revival without geometry change")
	enemies[3].position = Vector2(1, 0)
	check_selection(old, updated, Vector2.ZERO, "local transform invalidation")
	host.position = Vector2(80, 0)
	check_selection(old, updated, Vector2.ZERO, "ancestor transform invalidation")
	EnemyRegistry.unregister_enemy(enemies[2])
	check_selection(old, updated, Vector2.ZERO, "registry index removal")
	EnemyRegistry.register_enemy(enemies[2])
	check_selection(old, updated, Vector2.ZERO, "registry append")
	for i in CURRENT.RANGE_QUERY.MAX_QUERIES + 2:
		CURRENT.RANGE_QUERY.candidates(Vector2(i, i), 170.0)
	check(CURRENT.RANGE_QUERY._queries.size() <= CURRENT.RANGE_QUERY.MAX_QUERIES, "chain query cache is bounded")
	check_selection(old, updated, Vector2.ZERO, "cache capacity fallback")
	await frames()
	check_selection(old, updated, Vector2.ZERO, "next frame")
	old.queue_free()
	updated.queue_free()
	host.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("THUNDER_FIRE_OPTIMIZATION checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
