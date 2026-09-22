extends RefCounted
class_name InventoryTradeService

const RULES_PATH := "res://data_config/inventory_trade_rules.json"
const RARITIES := ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
var rules: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if parsed is Dictionary:
		rules = parsed


func quote_weapon(weapon: WeaponInstance) -> Dictionary:
	if weapon == null:
		return {}
	var rarity := maxi(0, RARITIES.find(str(weapon.weapon_data.get("rarity", "common"))))
	var reference := 15 + rarity * 5
	var basis := reference if weapon.trade_base_basis < 0 else mini(reference, weapon.trade_base_basis)
	var base_value := floori(float(basis) * float(rules.get("weapon_sell_ratio", 0.5)))
	var upgrade_value := 0
	for level in range(2, weapon.level + 1):
		var upgrade: Dictionary = weapon.weapon_data.get("level_upgrades", {}).get(str(level), {})
		var upgrade_reference := 10 + maxi(0, RARITIES.find(str(upgrade.get("rarity", "common")))) * 5
		var paid := int(weapon.trade_upgrade_basis.get(level, upgrade_reference))
		upgrade_value += floori(float(mini(upgrade_reference, paid)) * float(rules.get("upgrade_sell_ratio", 0.5)))
	var title_bonus := maxi(0, int(weapon.battle_title.get("sale_bonus", 0)))
	var returned_items: Array[String] = []
	var returned_ids: Array[String] = []
	for item in weapon.get_attached_item_instances():
		returned_items.append(str(item.get("display_name", "")))
		returned_ids.append(str(item.get("item_instance_id", "")))
	return _with_token({
		"kind": "weapon", "target_id": weapon.weapon_id, "instance_id": weapon.instance_id,
		"display_name": str(weapon.weapon_data.get("display_name", weapon.weapon_id)),
		"level": weapon.level, "icon": str(weapon.weapon_data.get("icon", "")),
		"title": str(weapon.battle_title.get("display_name", "")),
		"base_value": base_value, "upgrade_value": upgrade_value, "title_bonus": title_bonus,
		"total": base_value + upgrade_value + title_bonus,
		"returned_items": returned_items, "returned_ids": returned_ids,
	})


func quote_item(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var rarity := maxi(0, RARITIES.find(str(item.get("rarity", "common"))))
	var basis := int(rules.get("enchantment_base_value", 15)) + rarity * int(rules.get("rarity_value_step", 5))
	var total := floori(float(basis) * float(rules.get("enchantment_sell_ratio", 0.5)))
	return _with_token({
		"kind": "enchantment", "target_id": str(item.get("item_instance_id", "")),
		"display_name": str(item.get("display_name", "")), "icon": str(item.get("icon", "")),
		"description": str(item.get("description", "")),
		"rolled_parameters": item.get("rolled_parameters", {}).duplicate(true),
		"equipped_weapon_id": str(item.get("equipped_weapon_id", "")), "total": total,
	})


func _with_token(quote: Dictionary) -> Dictionary:
	quote["quote_token"] = str(quote.hash())
	return quote
