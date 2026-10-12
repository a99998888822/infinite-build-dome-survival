extends Node

const SLOT_CURVES := {
	"weapon_void_blade": [1, 1, 2, 3, 3],
	"weapon_rentier_purse": [1, 1, 2, 3, 3],
	"weapon_camp_dagger": [1, 1, 2, 3, 3],
	"weapon_kunyu_ritual_tome": [1, 2, 3, 3, 3],
	"weapon_earth_hammer": [1, 2, 2, 3, 3],
	"weapon_mutant_tentacle": [1, 2, 2, 3, 3],
	"weapon_copper_lamp": [1, 2, 2, 3, 3],
	"weapon_iron_grenade_cannon": [1, 2, 2, 3, 3],
	"weapon_plasma_cannon": [1, 2, 2, 3, 3],
	"weapon_nightwatch_spear": [1, 2, 2, 3, 3],
	"weapon_meteor_flail": [1, 2, 2, 3, 3],
	"weapon_dash_blade": [1, 2, 2, 3, 3],
	"weapon_hand_cannon": [1, 2, 2, 3, 3],
	"weapon_star_tome": [1, 2, 2, 3, 3],
}

var checks := 0
var failures := 0
var player: PlayerController


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)


func _run() -> void:
	CampProgression.begin_transient_session()
	check(DataRegistry.get_load_errors().is_empty(), "weapon data validates")
	check(DataRegistry.get_table("weapons").size() == SLOT_CURVES.size(), "all weapons covered")
	player = load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	for id in SLOT_CURVES:
		_check_weapon(id)
	_check_independent_config()
	_check_loadout()
	player.queue_free()
	await get_tree().process_frame
	CampProgression.end_transient_session()
	print("WEAPON_ATTACHMENT_PROGRESSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check_weapon(id: String) -> void:
	var weapon := WeaponInstance.new()
	check(weapon.initialize(id, player), "initialize " + id)
	for index in 5:
		var expected: int = SLOT_CURVES[id][index]
		if index > 0:
			var snapshot := weapon.make_cast_copy()
			var attachments := weapon.get_attached_item_instances()
			check(weapon.upgrade(), "upgrade " + id)
			check(weapon.get_attached_item_instances() == attachments, "upgrade preserves attachment order " + id)
			check(snapshot.get_attachment_slot_count() == SLOT_CURVES[id][index - 1]
				and snapshot.make_bounce_copy(Vector2.ZERO).get_attachment_slot_count() == SLOT_CURVES[id][index - 1], "in-flight casts keep old capacity " + id)
		check(weapon.get_attachment_slot_count() == expected, "%s level %d capacity" % [id, index + 1])
		while weapon.get_attached_item_instances().size() < expected:
			var item := player.item_inventory.add_item_from_base("scroll_fire", "slot_test")
			if not weapon.attach_item_instance(item):
				check(false, "new slot can be filled " + id)
				break
		var extra := player.item_inventory.add_item_from_base("scroll_ice", "slot_test")
		check(not weapon.attach_item_instance(extra), "full capacity rejects another enchantment " + id)
		check(weapon.get_attached_item_instances().size() == expected, "every unlocked slot works " + id)
		check(weapon.build_full_stats_text().count("[img=") == expected, "tooltip displays all slots " + id)
		if index < 4:
			_check_offer(id, index + 1, SLOT_CURVES[id][index + 1] > expected)
	check(not weapon.upgrade() and weapon.get_attachment_slot_count() == 3, "max level cannot grant more slots " + id)
	weapon.initialize(id, player)
	check(weapon.get_attachment_slot_count() == 1 and weapon.get_attached_item_instances().is_empty(), "reinitialize restores one empty slot " + id)


func _check_offer(id: String, level: int, grants_slot: bool) -> void:
	var offers := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity": 1000, "current_load": 0,
		"owned_weapon_ids": [id], "equipped_weapons": [{"weapon_id": id, "level": level}], "luck": 350})
	var upgrades := offers.filter(func(offer): return offer.offer_type == "weapon_upgrade" and offer.target_id == id)
	check(upgrades.size() == 1, "next upgrade offered " + id)
	if upgrades.is_empty(): return
	var description := str(upgrades[0].description)
	for locale in ["zh_CN", "en"]:
		L10n.set_locale(locale, false)
		var translated := L10n.source(description)
		var line := "附魔槽 [color=#7FD88F]+1[/color]" if locale == "zh_CN" else "Enchantment Slots [color=#7FD88F]+1[/color]"
		check(translated.contains(line) == grants_slot, "upgrade slot text matches reward " + id + " " + locale)
	L10n.set_locale("zh_CN", false)


func _check_independent_config() -> void:
	var data := {"attachment_slots": 2, "max_level": 4, "rarity": "legendary", "level_upgrades": {
		"2": {"rarity": "common", "effects": []},
		"4": {"rarity": "common", "effects": [{"field": "attachment_slots", "value": 2}]}}}
	check(WeaponInstance.get_attachment_slots_for_level(data, 1) == 2
		and WeaponInstance.get_attachment_slots_for_level(data, 3) == 2
		and WeaponInstance.get_attachment_slots_for_level(data, 4) == 4, "capacity depends only on per-weapon settings")
	for value in [-1, 1.5]:
		var record := DataRegistry.get_record("weapons", "weapon_void_blade").duplicate(true)
		record.level_upgrades["2"].effects.append({"field": "attachment_slots", "value": value})
		var validator := DataValidator.new()
		validator._validate_weapon_level_upgrades(record, "test")
		check(not validator.errors.is_empty(), "invalid slot increment rejected")


func _check_loadout() -> void:
	var loadout := WeaponLoadout.new()
	add_child(loadout)
	loadout.set_physics_process(false)
	check(loadout.initialize(player) and loadout.equip_weapon("weapon_void_blade"), "real loadout initializes")
	var weapon := loadout.get_weapon_instance("weapon_void_blade")
	var ids: Array[String] = []
	for base_id in ["scroll_fire", "scroll_ice", "scroll_lightning", "scroll_fire"]:
		ids.append(str(player.item_inventory.add_item_from_base(base_id, "loadout_slot_test").item_instance_id))
	check(loadout.attach_item_to_weapon(weapon.weapon_id, ids[0]), "loadout fills starter slot")
	check(not loadout.attach_item_to_weapon(weapon.weapon_id, ids[1]), "loadout rejects locked second slot")
	for target_level in range(2, 5):
		check(loadout.upgrade_weapon(weapon.weapon_id), "loadout upgrades")
		if target_level >= 3:
			check(loadout.attach_item_to_weapon(weapon.weapon_id, ids[target_level - 2]), "loadout fills newly unlocked slot")
	check(not loadout.attach_item_to_weapon(weapon.weapon_id, ids[3])
		and str(player.item_inventory.find_item(ids[3]).get("equipped_weapon_id", "")).is_empty(), "full loadout preserves inventory ownership")
	check(weapon.move_attachment_instance(ids[2], 0) and str(weapon.get_attached_item_instances()[0].item_instance_id) == ids[2], "third enchantment can be reordered")
	loadout.remove_weapon(weapon.weapon_id)
	for id in ids:
		check(str(player.item_inventory.find_item(id).get("equipped_weapon_id", "")).is_empty(), "removing weapon returns every enchantment")
	loadout.queue_free()
