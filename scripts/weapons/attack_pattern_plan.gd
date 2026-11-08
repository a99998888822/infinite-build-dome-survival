extends RefCounted
class_name AttackPatternPlan
## A cast recipe, evaluated in attachment order before any bodies are spawned.
const IDS := ["radial", "orbit", "giant", "guard", "satellite"]
const FLIGHT := ["weapon_void_blade", "weapon_plasma_cannon", "weapon_iron_grenade_cannon", "weapon_rentier_purse", "weapon_hand_cannon"]
const ORBIT_MELEE := ["weapon_camp_dagger", "weapon_nightwatch_spear", "weapon_meteor_flail", "weapon_mutant_tentacle", "weapon_earth_hammer"]
const NO_RADIAL := ["weapon_kunyu_ritual_tome", "weapon_furnace", "weapon_dash_blade", "weapon_star_tome"]
var units: Array[Dictionary] = []
var radial := false
var orbit := false
var satellite := false
var guard := false
var changed := false
var initial_count := 1

static func supports(weapon_id: String, effect: String) -> bool:
	match effect:
		"radial": return weapon_id not in NO_RADIAL
		"orbit": return weapon_id in FLIGHT or weapon_id in ORBIT_MELEE
		"satellite": return weapon_id in FLIGHT or weapon_id in ["weapon_nightwatch_spear", "weapon_meteor_flail"]
		"guard": return weapon_id != "weapon_kunyu_ritual_tome"
	return true

static func effect_name(id: String) -> String:
	return L10n.text("enchantment." + id + ".name") if id in IDS else id

static func build(weapon: WeaponInstance) -> AttackPatternPlan:
	var plan := AttackPatternPlan.new()
	plan.initial_count = maxi(1, int(weapon.get_stat("projectile_count")))
	for i in plan.initial_count: plan.units.append(_unit())
	for entry in weapon.get_enchantment_sequence():
		var effect := str(entry.effect_id)
		if effect not in IDS or not supports(weapon.weapon_id, effect): continue
		plan.changed = true
		match effect:
			"radial":
				plan.units.append(_unit())
				plan.units.append(_unit())
				plan.radial = true
			"orbit": plan.orbit = true
			"guard": plan.guard = true
			"satellite":
				plan.units.append(_unit())
				plan.satellite = true
			"giant":
				var mass := 0.0
				for unit in plan.units: mass += float(unit.mass)
				# The tome spends count + 2 marks; merge that actual native budget.
				if weapon.is_ritual_tome() and not plan.units[0].get("merged", false): mass += 2.0
				plan.units.assign([{"mass": mass, "size": sqrt(mass), "merged": true}])
				plan.satellite = false
				plan.radial = false
	return plan

static func _unit() -> Dictionary:
	return {"mass": 1.0, "size": 1.0, "merged": false}

func apply_unit(weapon: WeaponInstance, index: int) -> void:
	weapon.pattern_damage_scale = float(units[index].mass)
	weapon.pattern_size_scale = float(units[index].size)
	weapon._cast_stats["projectile_count"] = 1.0
	weapon.pattern_radial = false
	weapon.pattern_merged = bool(units[index].merged)

func total_mass() -> float:
	var result := 0.0
	for unit in units: result += float(unit.mass)
	return result

func changes_shape() -> bool:
	return radial or orbit or satellite or units.any(func(unit): return bool(unit.merged))

func get_satellite_radius(source: WeaponInstance) -> float:
	return maxf(42.0, source.get_hit_radius() * (float(units[0].size) + 1.0) + 12.0)

func orbit_position(index: int, seconds: float, source: WeaponInstance) -> Vector2:
	# Orbit bodies sweep a circle on the ground plane, so the offset is projected.
	return AttackFootprint.project(Vector2.from_angle(TAU * index / maxi(units.size(), 1) + seconds * TAU / source.get_active_cooldown_seconds()) * source.get_attack_range())

func satellite_position(index: int, seconds: float, source: WeaponInstance) -> Vector2:
	var phase := TAU * (index - 1) / maxi(units.size() - 1, 1)
	return AttackFootprint.project(Vector2.from_angle(phase + seconds * TAU / maxf(0.45, source.get_active_cooldown_seconds() * 0.3)) * get_satellite_radius(source))

func grenade_landing(unit: WeaponInstance, index: int, pointer: Vector2) -> Vector2:
	if radial: pointer = pointer.rotated(TAU * index / units.size())
	return AttackFootprint.grenade_landings(unit, pointer)[0]

func saber_degrees(index: int) -> float:
	if radial: return 360.0 * index / units.size()
	var step := (index + 1) / 2
	return minf(float(step) * 3.0, 15.0) * (1.0 if index % 2 == 1 else -1.0)

func angles(weapon: WeaponInstance) -> Array[float]:
	var result: Array[float] = []
	if radial:
		for i in units.size(): result.append(360.0 * i / units.size())
	else:
		var gap := float(weapon.weapon_data.get("projectile_spacing_degrees", weapon.get_spread_angle() / maxf(units.size() - 1, 1)))
		for i in units.size(): result.append((i - (units.size() - 1) * 0.5) * gap)
	return result
