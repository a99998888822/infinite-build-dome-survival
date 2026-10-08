extends RefCounted
## Test fixtures configure each skill through the production preference API.

static func apply(automatic_attacks: bool) -> void:
	CombatSettings.reset_weapon_auto_cast(false)
	if not automatic_attacks:
		for record: Dictionary in DataRegistry.get_table("weapons"):
			CombatSettings.set_weapon_auto_cast(str(record.id), false, false)
