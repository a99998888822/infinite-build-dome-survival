extends RefCounted
class_name WeaponInstance

const DAMAGE_KIND_MELEE: String = "melee"
const DAMAGE_KIND_RANGED: String = "ranged"
const MIN_ATTACK_INTERVAL_SECONDS: float = 0.05

var weapon_id: String = ""
var weapon_data: Dictionary = {}
var owner_player: PlayerController = null
var level: int = 1
var runtime_stats: Dictionary = {}
var attack_interval_ms: int = 0
var attack_timer: float = 0.0
var _attack_hit_sfx_played: bool = false
var _projectile_hit_sfx_played: Dictionary = {}


func initialize(target_weapon_id: String, player: PlayerController) -> bool:
	var data := DataRegistry.get_record("weapons", target_weapon_id)
	if data.is_empty():
		push_error("[WeaponInstance] missing weapon config: %s" % target_weapon_id)
		return false

	weapon_id = target_weapon_id
	weapon_data = data
	owner_player = player
	level = 1
	runtime_stats = data.get("base_stats", {}).duplicate(true)
	attack_interval_ms = int(data.get("attack_interval_ms", 1000))
	attack_timer = 0.0
	reset_hit_sfx_state()
	return true


func tick(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)


func can_attack() -> bool:
	return attack_timer <= 0.0


func reset_attack_timer() -> void:
	attack_timer = get_actual_attack_interval_seconds()
	reset_hit_sfx_state()


func reset_hit_sfx_state() -> void:
	_attack_hit_sfx_played = false
	_projectile_hit_sfx_played.clear()


func get_hit_sfx_path() -> String:
	return str(weapon_data.get("hit_sfx", ""))


func play_attack_hit_sfx() -> bool:
	if _attack_hit_sfx_played:
		return false
	_attack_hit_sfx_played = true
	AudioManager.play_weapon_hit_sfx(weapon_id, 30)
	return true


func has_played_attack_hit_sfx() -> bool:
	return _attack_hit_sfx_played


func play_projectile_hit_sfx(projectile_id: String) -> bool:
	var key := projectile_id.strip_edges()
	if key.is_empty() or _projectile_hit_sfx_played.has(key):
		return false
	_projectile_hit_sfx_played[key] = true
	AudioManager.play_weapon_hit_sfx(weapon_id, 15)
	return true


func has_played_projectile_hit_sfx(projectile_id: String) -> bool:
	return _projectile_hit_sfx_played.has(projectile_id.strip_edges())


func upgrade() -> bool:
	var max_level := int(weapon_data.get("max_level", 1))
	if level >= max_level:
		return false
	level += 1
	_apply_level_upgrades(level)
	return true


func get_stat(stat_id: String) -> float:
	var default_value := StatDefinitions.get_default_value(stat_id)
	var weapon_value := float(runtime_stats.get(stat_id, default_value))
	var player_value := owner_player.get_stat(stat_id) if owner_player != null else default_value
	return StatDefinitions.clamp_stat_value(stat_id, weapon_value + player_value - default_value)


func get_weapon_stat(stat_id: String) -> float:
	return float(runtime_stats.get(stat_id, StatDefinitions.get_default_value(stat_id)))


func get_next_upgrade_rarity() -> String:
	var next_level := level + 1
	var upgrade_entry: Dictionary = weapon_data.get("level_upgrades", {}).get(str(next_level), {})
	return str(upgrade_entry.get("rarity", ""))


func get_load_cost() -> int:
	return int(weapon_data.get("load_cost", 0))


func get_hit_radius() -> float:
	var base_radius := float(weapon_data.get("hit_radius", 0))
	return StatDefinitions.calculate_attack_radius(base_radius, get_stat("area_size"))


func get_attack_range() -> float:
	var base_range := float(weapon_data.get("attack_range", weapon_data.get("hit_radius", 0)))
	return StatDefinitions.calculate_attack_radius(base_range, get_stat("area_size"))


func get_projectile_speed() -> float:
	return float(weapon_data.get("projectile_speed", 0))


func get_spread_angle() -> float:
	return float(weapon_data.get("spread_angle", 0))


func get_total_pierce_hits() -> int:
	return int(get_stat("pierce_count")) + 1


func get_actual_attack_interval_seconds() -> float:
	var base_interval := maxf(float(attack_interval_ms) / 1000.0, MIN_ATTACK_INTERVAL_SECONDS)
	if bool(weapon_data.get("use_cooldown_reduction_only", false)):
		return maxf(StatDefinitions.calculate_cooldown(base_interval, get_stat("cooldown_reduction")), MIN_ATTACK_INTERVAL_SECONDS)
	return maxf(StatDefinitions.calculate_attack_interval(base_interval, get_stat("attack_speed")), MIN_ATTACK_INTERVAL_SECONDS)


func calculate_damage_events(force_critical: bool = false) -> Array[DamageEvent]:
	var events: Array[DamageEvent] = []
	if _has_tag("mixed"):
		events.append(_build_damage_event(DAMAGE_KIND_MELEE, force_critical))
		events.append(_build_damage_event(DAMAGE_KIND_RANGED, force_critical))
		return events
	if _has_tag("melee"):
		events.append(_build_damage_event(DAMAGE_KIND_MELEE, force_critical))
		return events
	if _has_tag("ranged"):
		events.append(_build_damage_event(DAMAGE_KIND_RANGED, force_critical))
	return events


func get_projectile_angles() -> Array[float]:
	var projectile_count: int = maxi(1, int(get_stat("projectile_count")))
	var spread_angle := get_spread_angle()
	var angles: Array[float] = []
	if projectile_count == 1 or is_zero_approx(spread_angle):
		angles.append(0.0)
		return angles
	var start_angle := -spread_angle / 2.0
	var step := spread_angle / float(projectile_count - 1)
	for index in range(projectile_count):
		angles.append(start_angle + step * float(index))
	return angles


func _apply_level_upgrades(target_level: int) -> void:
	var upgrades: Dictionary = weapon_data.get("level_upgrades", {})
	var upgrade_entry: Dictionary = upgrades.get(str(target_level), {})
	var upgrade_list: Array = upgrade_entry.get("effects", [])
	for upgrade in upgrade_list:
		if not (upgrade is Dictionary):
			continue
		var value := int(upgrade.get("value", 0))
		if upgrade.has("stat"):
			var stat_id := str(upgrade["stat"])
			runtime_stats[stat_id] = StatDefinitions.clamp_stat_value(stat_id, get_weapon_stat(stat_id) + value)
		elif str(upgrade.get("field", "")) == "attack_interval_ms":
			attack_interval_ms = maxi(1, attack_interval_ms + value)


func _build_damage_event(damage_kind: String, force_critical: bool) -> DamageEvent:
	var base_damage := get_stat("melee_damage") if damage_kind == DAMAGE_KIND_MELEE else get_stat("ranged_damage")
	var damage := base_damage * (1.0 + get_stat("damage_percent") / 100.0)
	var critical := force_critical or randf() * 100.0 < get_stat("crit_chance")
	if critical:
		damage *= get_stat("crit_damage") / 100.0
	return DamageEvent.create({
		"source_player": owner_player,
		"source_weapon_id": weapon_id,
		"damage": maxi(1, int(roundi(damage))),
		"damage_kind": damage_kind,
		"is_critical": critical,
		"tags": _get_tags(),
		"hit_position": owner_player.global_position if owner_player != null else Vector2.ZERO,
	})


func _has_tag(tag: String) -> bool:
	return _get_tags().has(tag)


func _get_tags() -> Array[String]:
	var result: Array[String] = []
	for tag in weapon_data.get("tags", []):
		result.append(str(tag))
	return result
