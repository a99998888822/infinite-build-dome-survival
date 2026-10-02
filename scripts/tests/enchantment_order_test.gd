extends "res://scripts/tests/attribute_enchantment_test.gd"

var born: Array[ProjectileInstance] = []
var chain_events: Array[DamageEvent] = []

func record_chain(node: Node) -> void:
	if node is LightningParticleEffect: record_initialized_chain.call_deferred(node)

func record_initialized_chain(node: LightningParticleEffect) -> void:
	if is_instance_valid(node): chain_events.append(node._damage_event)

func remember(node: Node) -> void:
	if node is ProjectileInstance:
		born.append(node)
		node.set_physics_process(false)

func arrow_order(attachments: Array, primary_count: int, child_count: int) -> void:
	await fixture(BOW, [Vector2(60, 0), Vector2(140, 55), Vector2(140, -55)])
	for id in attachments: attach(weapon, id)
	normalize_damage(weapon)
	born.clear()
	host.child_entered_tree.connect(remember)
	loadout._try_attack_with_weapon(weapon)
	check(born.size() == 1, "one parent arrow")
	born[0]._on_body_entered(enemies[0])
	check(effect_count(LightningParticleEffect) == primary_count, "main chain count for " + str(attachments))
	await get_tree().process_frame
	var branches: Array[ProjectileInstance] = []
	for node in born:
		if is_instance_valid(node) and node._split_depth == 1: branches.append(node)
	check(branches.size() == 2 * attachments.count("scroll_split"), "one generation per split copy")
	var before := effect_count(LightningParticleEffect)
	for i in branches.size():
		var child := branches[i]
		check(child.damage_event.split_child and is_equal_approx(child.damage_event.get_elemental_base_damage(), 45), "child scope and elemental damage scale")
		var target := enemies[1] if not child.hit_targets.has(enemies[1].get_instance_id()) else enemies[2]
		child._on_body_entered(target)
	check(effect_count(LightningParticleEffect) - before == child_count, "child chain count for " + str(attachments))
	await get_tree().process_frame
	check(born.size() == branches.size() + 1, "children never recurse")

func _run() -> void:
	CampProgression.begin_transient_session()
	await arrow_order(["scroll_lightning", "scroll_split"], 1, 0)
	await arrow_order(["scroll_split", "scroll_lightning"], 0, 2)
	await arrow_order(["scroll_split", "scroll_split"], 0, 0)
	# Ground branches are legitimate empty-ground impact points, with the same suffix.
	for reversed in [false, true]:
		await fixture(HAMMER, [], ["scroll_split", "scroll_electric_spark"] if reversed else ["scroll_electric_spark", "scroll_split"])
		var quake := hammer()
		advance(quake, 1.1)
		check(effect_count(ElectricSparkEffect) == (10 if reversed else 5), "ground warning count follows order")
		check(quake.nodes.size() == 15, "five main nodes and ten nonrecursive cracks")
	# All native contact styles must pass a continuation, including persistent beams.
	for id in [LAMP, TENTACLE, DAGGER, "weapon_meteor_flail", "weapon_kunyu_ritual_tome", "weapon_rentier_purse", "weapon_iron_grenade_cannon", "weapon_plasma_cannon"]:
		await fixture(id, [Vector2(40, 0), Vector2(62, 8), Vector2(62, -8), Vector2(150, 0), Vector2(200, 20)], ["scroll_split", "scroll_lightning"])
		chain_events.clear()
		host.child_entered_tree.connect(record_chain)
		loadout.tick(0.01)
		await get_tree().create_timer(1.8).timeout
		check(not chain_events.is_empty(), "native child contact creates chain for " + id)
		check(chain_events.all(func(e): return e.split_child and e.enchantment_start > 0), "only child chains for " + id)
		check(enemies.any(func(e): return e.current_hp < 10000), "native damage for " + id)
	# Main pierce contacts may repeat the prefix, but never steal the suffix.
	await fixture(BOW, [Vector2(60, 0)])
	for id in ["scroll_split", "scroll_fire"]: attach(weapon, id)
	var hit := weapon.calculate_damage_events()[0]
	CombatEffectWorld.trigger_weapon_impact(host, weapon, hit, enemies[0].position, Vector2.RIGHT, enemies[0])
	check(not enemies[0].has_status("burning"), "prefix stops exactly at split")
	CombatEffectWorld.trigger_weapon_impact(host, weapon, hit.continue_after_split(weapon.get_split_profiles()[0]), enemies[0].position, Vector2.RIGHT, enemies[0])
	check(enemies[0].has_status("burning"), "child contact applies fire suffix")
	# The VFX budget must never become a damage budget.
	var victim := enemies[0]
	victim.clear_burning()
	var hp := victim.current_hp
	for _i in 400: victim.take_damage(1, weapon.weapon_id)
	check(victim.current_hp == hp - 400 and EnemyController.active_damage_numbers <= EnemyController.MAX_DAMAGE_NUMBERS, "bounded popup count preserves every hit")
	host.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 0, "scene cleanup releases every popup budget slot")
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("ENCHANTMENT_ORDER_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
