extends "res://scripts/tests/bounce_test.gd"

const IDS := ["might", "wisdom", "multishot", "domain", "precision", "lethality", "haste"]
const BONUS_KEYS := ["all_damage_percent", "element_damage_percent", "projectile_count", "damage_area_size", "crit_chance", "crit_damage", "attack_speed"]
const AMOUNTS := [20, 30, 1, 30, 25, 50, 25]


func room(source: WeaponInstance) -> void:
	while source.get_attachment_slot_count() < 2:
		if not source.upgrade():
			check(false, "cannot unlock second slot")
			return


func equip_bonus(source: WeaponInstance, id: String) -> Dictionary:
	var item := player.item_inventory.add_item_from_base("scroll_" + id, "attribute_test")
	check(loadout.attach_item_to_weapon(source.weapon_id, item.item_instance_id), "equip " + id)
	return item


func state(source: WeaponInstance) -> Array:
	var event := source.calculate_damage_events(true)[0]
	return [event.damage, event.get_elemental_base_damage(), source.get_stat("projectile_count"), source.get_stat("damage_area_size"),
		source.get_stat("crit_chance"), source.get_stat("crit_damage"), source.get_actual_attack_interval_seconds()]


func normalize_damage(source: WeaponInstance) -> void:
	for stat in ["melee_damage", "ranged_damage", "element_damage", "damage_percent", "crit_chance"]:
		player.modifier_stack.set_base_stat(stat, 0)
		source.runtime_stats[stat] = 0
	source.runtime_stats[source.get_damage_stat_id()] = 100
	source.runtime_stats.crit_damage = 150


func _run() -> void:
	CampProgression.begin_transient_session()
	for index in IDS.size():
		await fixture(BOW, [Vector2(100, 0)])
		room(weapon)
		player.modifier_stack.set_base_stat("load_capacity", 200)
		check(loadout.equip_weapon(TENTACLE), "equip isolated comparison weapon")
		var other := loadout.get_weapon_instance(TENTACLE)
		var player_before := {}
		for stat in StatDefinitions.get_all_stat_ids(): player_before[stat] = player.get_stat(stat)
		var before := state(weapon)
		var other_before := state(other)
		var permanent := weapon.runtime_stats.duplicate(true)
		var item := equip_bonus(weapon, IDS[index])
		check(weapon.get_attachment_bonus(BONUS_KEYS[index]) == AMOUNTS[index], "exact local value: " + IDS[index])
		check(state(weapon) != before and state(other) == other_before, "only carrier changes: " + IDS[index])
		check(weapon.runtime_stats == permanent, "attachment never edits permanent level stats")
		check(player_before.keys().all(func(stat): return player.get_stat(stat) == player_before[stat]), "player stats remain unchanged")
		check(loadout.attach_item_to_weapon(other.weapon_id, item.item_instance_id), "transfer item")
		check(state(weapon) == before and state(other) != other_before, "transfer removes old bonus and applies new one")
		loadout.detach_item_from_weapon(other.weapon_id, item.item_instance_id)
		check(state(other) == other_before and state(weapon) == before, "detach fully restores both weapons")
		check(loadout.attach_item_to_weapon(weapon.weapon_id, item.item_instance_id), "reattach item")
		var copy := weapon.make_bounce_copy(Vector2(400, 0))
		check(copy.get_attachment_bonus(BONUS_KEYS[index]) == AMOUNTS[index], "bounce inherits local bonus once")
		loadout.detach_item_from_weapon(weapon.weapon_id, item.item_instance_id)
		check(copy.get_attachment_bonus(BONUS_KEYS[index]) == AMOUNTS[index] and weapon.get_attachment_bonus(BONUS_KEYS[index]) == 0, "bounce snapshot and original stay independent")
		var texture := load(item.icon) as Texture2D
		check(texture != null and texture.get_size() == Vector2(64, 64), "installed 64px icon: " + IDS[index])
		var card := ItemInventoryCard.new()
		host.add_child(card)
		card.configure(item, false)
		check(card._get_effect_names() == item.display_name and card._build_tooltip().contains(item.description), "item card exposes name and scope")
		for table_id in ["drop_basic_enemy", "drop_elite_enemy", "drop_boss_enemy"]:
			check(DataRegistry.get_record("drop_tables", table_id).entries.any(func(entry): return entry.get("item_id", "") == item.base_item_id), "obtainable from " + table_id)

	# The same percentage is applied once on every native weapon type. Elemental
	# native attacks must not feed an already-amplified base back into attachments.
	for record in DataRegistry.get_table("weapons"):
		await fixture(str(record.id), [Vector2(100, 0)])
		room(weapon)
		normalize_damage(weapon)
		var plain := weapon.calculate_damage_events()[0]
		var plain_base := plain.get_elemental_base_damage()
		equip_bonus(weapon, "might")
		var mighty := weapon.calculate_damage_events()[0]
		check(mighty.damage == roundi(plain.damage * 1.2), "might boosts native " + str(record.id))
		check(is_equal_approx(mighty.get_elemental_base_damage(), plain_base * 1.2), "might boosts elemental base once")
		equip_bonus(weapon, "wisdom")
		var both := weapon.calculate_damage_events()[0]
		check(both.damage == roundi(plain.damage * (1.56 if weapon.get_attack_kind() == "element" else 1.2)), "wisdom affects only elemental native damage")
		check(is_equal_approx(both.get_elemental_base_damage(), plain_base * 1.56), "might and wisdom compose once each")
		var delayed := both.duplicate_event()
		delayed.elemental_damage_scale *= 0.6
		check(is_equal_approx(delayed.get_elemental_base_damage(), plain_base * 1.56 * 0.6), "child multiplier preserves local bonuses")
		for item in weapon.get_attached_item_instances(): loadout.detach_item_from_weapon(weapon.weapon_id, item.item_instance_id)
		check(is_equal_approx(both.get_elemental_base_damage(), plain_base * 1.56) and is_equal_approx(weapon.calculate_damage_events()[0].get_elemental_base_damage(), plain_base), "launched damage stays captured after removal")

	await fixture(BOW, [Vector2(10, 0)])
	room(weapon)
	normalize_damage(weapon)
	player.modifier_stack.set_base_stat("element_damage", 20)
	player.modifier_stack.set_base_stat("damage_percent", 50)
	equip_bonus(weapon, "might")
	var boosted := weapon.calculate_damage_events()[0]
	check(boosted.damage == 180 and is_equal_approx(boosted.get_elemental_base_damage(), 204), "might multiplies existing damage and flat elemental bonus")
	var steam := ElementReactionResolver.apply_element(enemies[0], "fire", {"original_damage": boosted.get_elemental_base_damage(), "source_id": BOW})
	check(is_equal_approx(enemies[0]._burn_damage_per_tick, 20.4), "burning receives increased elemental damage")
	steam = ElementReactionResolver.apply_element(enemies[0], "water", {"original_damage": boosted.get_elemental_base_damage(), "source_id": BOW})
	check(steam.steam_damage == 306, "element reaction receives increased damage exactly once")

	for bonus_id in ["might", "wisdom"]:
		await fixture(BOW, [Vector2(10, 0)], ["scroll_" + bonus_id, "scroll_water"])
		normalize_damage(weapon)
		player.modifier_stack.set_base_stat("element_damage", 20)
		WaterWaveEffect.spawn(host, Vector2.ZERO, weapon, weapon.calculate_damage_events()[0])
		await frames()
		check(enemies[0].current_hp == (9935 if bonus_id == "might" else 9930), "real water impact includes revised local bonus " + bonus_id)
	await fixture(BOW, [Vector2(10, 0)], ["scroll_might", "scroll_explosion"])
	ExplosionEffect.spawn(host, Vector2.ZERO, weapon, weapon.calculate_damage_events()[0])
	await frames()
	check(enemies[0].current_hp == 10000, "might never gives damage to pure shockwave control")

	await fixture(BOW, [Vector2(65, 0)], ["scroll_domain", "scroll_explosion"])
	var reach := weapon.get_attack_range()
	ExplosionEffect.spawn(host, Vector2.ZERO, weapon, weapon.calculate_damage_events()[0])
	await frames()
	check(enemies[0]._knockback_timer == 0, "domain does not expand a pure control shockwave")
	check(weapon.get_attack_range() == reach and weapon.get_stat("damage_area_size") == 30, "domain does not change attack range")

	await fixture(BOW, [Vector2(120, 0)], ["scroll_multishot"])
	check(weapon.get_projectile_angles().size() == 2 and loadout._try_attack_with_weapon(weapon), "multishot launches a real two-arrow volley")
	var projectiles := host.find_children("*", "ProjectileInstance", true, false)
	check(projectiles.size() == 2, "two independent projectile nodes exist")
	var multi := weapon.get_attached_item_instances()[0]
	loadout.upgrade_weapon(BOW)
	check(weapon.get_stat("projectile_count") == weapon.get_weapon_stat("projectile_count") + player.get_stat("projectile_count"), "upgrade does not bake or duplicate the extra projectile")
	var upgraded_count := weapon.get_stat("projectile_count")
	loadout.detach_item_from_weapon(BOW, multi.item_instance_id)
	check(weapon.get_stat("projectile_count") == upgraded_count - 1, "detach removes only the enchantment projectile and retains the upgrade")

	await fixture(BOW, [], ["scroll_precision", "scroll_lethality"])
	normalize_damage(weapon)
	check(weapon.get_stat("crit_chance") == 25 and weapon.get_stat("crit_damage") == 200, "crit bonuses use percentage points")
	check(weapon.calculate_damage_events(true)[0].damage == 200, "actual critical hit uses 200 percent")
	player.modifier_stack.set_base_stat("crit_chance", 90)
	check(weapon.get_stat("crit_chance") == 100, "crit chance clamps at 100 percent")
	check(player.get_stat("crit_chance") == 90, "crit clamp does not change player stats")

	var validator := DataValidator.new()
	check(validator.validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full production configuration validation")
	var bad := DataRegistry.get_record("augmentations", "scroll_might").duplicate(true)
	bad.weapon_bonuses = {"max_hp": 100}
	validator._validate_augmentation_records([bad])
	check(not validator.errors.is_empty(), "unsupported player-wide bonus rejected")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("ATTRIBUTE_ENCHANTMENT_TEST checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
