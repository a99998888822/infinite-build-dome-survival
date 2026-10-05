extends "res://scripts/tests/weapon_trio_test.gd"

const BOW := "weapon_void_blade"
const DAGGER := "weapon_camp_dagger"


func attach(source: WeaponInstance, item_id: String) -> void:
	while not source.has_available_attachment_slot():
		if not source.upgrade():
			check(false, "cannot create attachment slot")
			return
	var item := player.item_inventory.add_item_from_base(item_id, "bounce_test")
	check(loadout.attach_item_to_weapon(source.weapon_id, item.item_instance_id), "attach " + item_id + " to " + source.weapon_id)


func freeze_nodes(node: Node) -> void:
	for child in node.get_children():
		child.set_physics_process(false)
		freeze_nodes(child)


func bounces() -> Array[Node]:
	return get_tree().get_nodes_in_group("bounce_attacks").filter(func(n): return not n.cancelled and not n.is_queued_for_deletion())


func _run() -> void:
	CampProgression.begin_transient_session()
	# Every shipped attack has a real native replay, at the captured impact.
	for data in DataRegistry.tables.weapons:
		var id := str(data.id)
		await fixture(id, [Vector2(60, 0)], ["scroll_bounce"])
		weapon.begin_attack()
		var native := weapon.calculate_damage_events()[0]
		var point := enemies[0].global_position
		CombatEffectWorld.trigger_weapon_impact(host, weapon, native, point, Vector2.RIGHT, enemies[0])
		check(bounces().size() == 1, id + " creates one replay synchronously")
		if bounces().size() == 1:
			var repeat := bounces()[0]
			check(repeat.global_position == point and repeat.get_child_count() > 0, id + " native replay is located at impact")
			check(not repeat.replay.has_effect("bounce") and repeat.replay.is_bounce_attack, id + " cannot recurse")
			check(enemies[0].current_hp < 10000, id + " extra native contact is immediate")
			var position_before: Vector2 = repeat.replay.get_attack_origin()
			player.position += Vector2(300, 200)
			check(repeat.replay.get_attack_origin() == position_before, id + " fixed origin survives player movement")
		CombatEffectWorld.trigger_weapon_impact(host, weapon, native.duplicate_event(), point + Vector2(30, 0), Vector2.RIGHT, enemies[0])
		check(bounces().size() == 1, id + " later contacts cannot add replays")
		CombatEffectWorld.trigger_weapon_impact(host, weapon, weapon.calculate_damage_events()[0], point, Vector2.RIGHT, enemies[0])
		check(bounces().size() == 1, id + " separately rolled volley hits still share the ledger")
		freeze_nodes(host)
		loadout.remove_weapon(id)
		check(bounces().is_empty(), id + " sale cancels replay")

	await fixture(BOW, [Vector2(60, 0)], ["scroll_bounce", "scroll_water"])
	check(loadout._try_attack_with_weapon(weapon), "real bow launches")
	var arrow: ProjectileInstance
	for child in host.get_children():
		if child is ProjectileInstance:
			arrow = child
	if arrow != null:
		arrow.set_physics_process(false)
		arrow._on_body_entered(enemies[0])
	check(bounces().size() == 1 and enemies[0].has_status("wet"), "real bow impact replays and keeps companion enchantment")
	var old_context := weapon.attack_context
	weapon.attack_timer = 0
	loadout._try_attack_with_weapon(weapon)
	check(not bool(weapon.attack_context.get("bounce_used", true)) and bool(old_context.bounce_used), "next volley gets independent ledger while older projectiles keep theirs")
	freeze_nodes(host)

	await fixture(BOW, [Vector2(60, 0), Vector2(100, 0)], ["scroll_bounce", "scroll_split"])
	loadout._try_attack_with_weapon(weapon)
	for child in host.get_children():
		if child is ProjectileInstance: arrow = child
	arrow._on_body_entered(enemies[0])
	for child in host.get_children():
		if child is ProjectileInstance and child.weapon == weapon and child._split_depth > 0:
			child._on_body_entered(enemies[1])
	check(bounces().size() == 1, "split children cannot cause another bounce")
	freeze_nodes(host)

	await fixture(LAMP, [Vector2(60, 0)], ["scroll_bounce"])
	loadout.tick(0.01)
	var source_lamp := loadout._ensure_directed_runtime(weapon) as CopperLamp
	source_lamp.set_physics_process(false)
	advance(source_lamp, 1.5)
	check(bounces().size() == 1, "many lamp ticks produce one replay per spray burst")
	freeze_nodes(host)

	await fixture(BOW, [Vector2(60, 0)], ["scroll_bounce"])
	loadout._try_attack_with_weapon(weapon)
	for child in host.get_children():
		if child is ProjectileInstance: arrow = child
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	arrow._on_body_entered(enemies[0])
	check(bounces().is_empty() and enemies[0].current_hp == 10000, "paused collision cannot replay or damage")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	arrow._physics_process(0)
	check(bounces().size() == 1, "paused collision resumes once without losing the first hit")
	freeze_nodes(host)

	await fixture(HAMMER, [], ["scroll_bounce", "scroll_electric_spark"])
	loadout._try_attack_with_weapon(weapon)
	var quake: EarthHammer
	for node in get_tree().get_nodes_in_group("earth_hammers"):
		if node.weapon == weapon: quake = node
	quake.set_physics_process(false)
	advance(quake, 1.03, 1.03)
	check(bounces().size() == 1, "five empty ground nodes share one bounce")
	var warnings := effect_count(ElectricSparkEffect)
	# Both first nodes occupy exactly the same point, then each wave continues.
	var repeated: EarthHammer = bounces()[0].get_child(0)
	check(repeated.next_node == 1 and repeated.nodes[0].point + repeated.global_position == Vector2(40, 0), "hammer replay starts at first ground point without windup")
	check(warnings == 5 and bounces()[0].get_children().filter(func(n): return n is ElectricSparkEffect).size() == 1, "five original lightning warnings plus one immediate replay warning")
	freeze_nodes(host)

	var validator := DataValidator.new()
	check(validator.validate_all(DataRegistry.tables, DataRegistry.records_by_id), "all configs validate with new scrolls")
	for id in ["scroll_bounce"]:
		var data := DataRegistry.get_record("augmentations", id)
		check(ResourceLoader.exists(data.icon), "icon imported " + id)
		var item := player.item_inventory.add_item_from_base(id, "test")
		check(not item.is_empty() and not ItemInventoryCard.EFFECT_LABELS.get(data.effect_ids[0], "").is_empty(), "inventory and effect label " + id)
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("BOUNCE_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
