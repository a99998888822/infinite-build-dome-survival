extends RefCounted
## Legal item stacks shared by the attachment and combat takes.
const TOME := "weapon_kunyu_ritual_tome"
const ITEMS := ["scroll_multishot", "scroll_domain", "scroll_electric_spark"]


static func config(combat: bool) -> Dictionary:
	var result := RecordingSession.default_config()
	result.merge({"entry": "combat" if combat else "bank", "wave": 4, "countdown": 0, "level": 10,
		"principal": 1000, "gold": 200,
		"weapons": [{"id": TOME, "level": 5, "attachments": ITEMS.duplicate() if combat else []}],
		"relics": [{"id": "relic_twin_chamber_magazine", "count": 1},
			{"id": "relic_old_brass_telescope", "count": 3},
			{"id": "relic_long_focus_eyepiece", "count": 1},
			{"id": "relic_horizon_orrery", "count": 1},
			{"id": "relic_folded_star_chart", "count": 1},
			{"id": "relic_golden_rangefinder", "count": 1}]}, true)
	return result


static func split_config() -> Dictionary:
	var result := config(true)
	result.wave = 2
	result.weapons[0].attachments = ["scroll_multishot", "scroll_split", "scroll_electric_spark"]
	# Player has a native projectile stat of 1; two legal magazines make it 3.
	result.relics[0].count = 2
	return result


static func advance_config() -> Dictionary:
	var result := config(true)
	result.wave = 2
	result.weapons[0].attachments = ["scroll_split", "scroll_split", "scroll_electric_spark"]
	# Five additional projectiles; the player's native one remains included.
	# Range relics give 80 instead of 175, keeping the seal closer to the action.
	result.relics = [{"id": "relic_twin_chamber_magazine", "count": 5},
		{"id": "relic_old_brass_telescope", "count": 1},
		{"id": "relic_horizon_orrery", "count": 1},
		{"id": "relic_folded_star_chart", "count": 1},
		{"id": "relic_runaway_amplifier", "count": 1},
		{"id": "relic_gilded_trigger", "count": 1},
		{"id": "relic_pain_vessel", "count": 1},
		{"id": "relic_abyssal_echo_shell", "count": 1},
		{"id": "relic_aftershock_hourglass", "count": 1},
		{"id": "relic_diffusion_nozzle", "count": 1},
		{"id": "relic_cracked_bronze_bell", "count": 3}]
	return result
