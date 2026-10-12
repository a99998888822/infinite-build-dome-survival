extends RefCounted
class_name WeaponUpgradeRules

const RARITIES := ["common", "uncommon", "rare", "epic", "mythic", "legendary"]
const PRINCIPAL_COSTS := {2: 100, 3: 200, 4: 350, 5: 500}


static func gold_cost(upgrade: Dictionary) -> int:
	return 2 * (10 + maxi(0, RARITIES.find(str(upgrade.get("rarity", "common")))) * 5)


static func principal_cost(target_level: int) -> int:
	return int(PRINCIPAL_COSTS.get(target_level, 0))
