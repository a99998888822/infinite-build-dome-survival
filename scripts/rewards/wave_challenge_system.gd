extends RefCounted
class_name WaveChallengeSystem
## One stable offer per preparation; effects and telemetry live with the run.

const CONFIG_PATH := "res://data_config/wave_challenges.json"
var config: Dictionary = {}
var offer: Dictionary = {}
var prepared_wave := -1
var decided_wave := -1
var active: Dictionary = {}
var totals: Dictionary = {}
var pressure: Dictionary = {}
var preparation_baseline: Dictionary = {}
var _baseline_wave := -1
var _observed := 0.0
var _low_health_seconds := 0.0
var _minimum_health := 1.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary: config = parsed
	else: push_error("Invalid wave challenge config: " + CONFIG_PATH)
	_rng.randomize()


func reset() -> void:
	offer.clear()
	active.clear()
	totals.clear()
	pressure.clear()
	preparation_baseline.clear()
	prepared_wave = -1
	decided_wave = -1
	_baseline_wave = -1
	begin_combat()


func definition(id: String) -> Dictionary:
	for entry: Dictionary in config.get("challenges", []):
		if str(entry.id) == id: return entry.duplicate(true)
	return {}


func begin_combat() -> void:
	_observed = 0.0
	_low_health_seconds = 0.0
	_minimum_health = 1.0
	pressure.clear()


func record_health(hp: int, maximum: int) -> void:
	if maximum > 0: _minimum_health = minf(_minimum_health, float(hp) / maximum)


func sample_health(delta: float, hp: int, maximum: int) -> void:
	if delta <= 0 or maximum <= 0: return
	_observed += delta
	record_health(hp, maximum)
	if float(hp) / maximum < 0.5: _low_health_seconds += delta


func finish_combat(trade_pressure: Dictionary) -> void:
	pressure = trade_pressure.duplicate(true)
	var rules: Dictionary = config.pressure
	pressure.struggling = bool(pressure.get("struggling", false)) or _low_health_seconds >= float(rules.sustained_low_health_seconds)
	pressure.comfortable = not pressure.struggling and _observed >= float(rules.minimum_observed_seconds) and _minimum_health >= float(rules.comfortable_minimum_health_ratio) and int(pressure.get("low_health_episodes", 0)) == 0 and float(pressure.get("remaining_average", 0)) < float(pressure.get("enemy_threshold", 1)) * float(rules.comfortable_crowd_threshold_ratio)
	pressure.observed_seconds = _observed
	pressure.low_health_seconds = _low_health_seconds
	pressure.minimum_health_ratio = _minimum_health


func begin_preparation(wave: int, player: PlayerController, loadout: WeaponLoadout) -> void:
	if wave <= _baseline_wave: return
	_baseline_wave = wave
	preparation_baseline = combat_snapshot(player, loadout)


## Deterministic comparison, not a prediction of survival or a combat RNG roll.
static func combat_snapshot(player: PlayerController, loadout: WeaponLoadout) -> Dictionary:
	if player == null or loadout == null: return {}
	var offense := 0.0
	for weapon in loadout.get_weapon_instances():
		var damage := maxf(1, weapon.get_base_attack_damage() * (1 + weapon.get_stat("damage_percent") / 100.0))
		var critical := 1 + clampf(weapon.get_stat("crit_chance") / 100.0, 0, 1) * maxf(0, weapon.get_stat("crit_damage") / 100.0 - 1)
		var coverage := sqrt(maxf(1, weapon.get_stat("projectile_count"))) if weapon.get_attack_kind() != "melee" else 1.0
		# Equipped effect instances include control/elemental utility beyond raw damage.
		var effects := 1.0 + 0.2 * weapon.get_attached_item_instances().size()
		offense += damage * critical * coverage * effects / weapon.get_actual_attack_interval_seconds()
	# damage_taken_percent already includes armor in the player's derived stats.
	var durability := maxf(1, player.get_stat("max_hp") + player.get_stat("shield"))
	durability /= maxf(0.01, player.get_stat("damage_taken_percent", 100) / 100.0)
	durability += maxf(0, player.get_stat("hp_regen")) * 5.0
	return {"offense": offense, "durability": durability, "mobility": maxf(1, player.get_stat("move_speed")), "control": 100 + player.get_stat("control_power")}


func has_low_gain(snapshot: Dictionary) -> bool:
	if preparation_baseline.is_empty() or snapshot.is_empty(): return false
	for key in preparation_baseline:
		if float(snapshot.get(key, 0)) >= maxf(0.01, float(preparation_baseline[key])) * (1 + float(config.preparation.significant_gain_ratio)):
			return false
	return true


func eligible_offers(snapshot: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var risky := bool(pressure.get("struggling", false)) or has_low_gain(snapshot)
	for entry: Dictionary in config.challenges:
		if (str(entry.condition) == "comfortable" and bool(pressure.get("comfortable", false))) or (str(entry.condition) == "pressure_or_low_gain" and risky):
			candidates.append(entry.duplicate(true))
	return candidates


func prepare(wave: int, snapshot: Dictionary) -> Dictionary:
	if wave <= prepared_wave: return offer.duplicate(true)
	prepared_wave = wave
	offer.clear()
	if wave <= 1: return {}
	var candidates := eligible_offers(snapshot)
	var total := 0
	for candidate in candidates: total += int(candidate.weight)
	if total <= 0: return {}
	var roll := _rng.randi_range(1, total)
	for candidate in candidates:
		roll -= int(candidate.weight)
		if roll > 0: continue
		offer = candidate
		offer.wave = wave
		offer.token = "%d:%s" % [wave, str(offer.id)]
		break
	return offer.duplicate(true)


func decide(token: String, accepted: bool, player: PlayerController, finance: BattleFinanceSystem) -> bool:
	if offer.is_empty() or token != str(offer.token) or decided_wave == prepared_wave or player == null or not player.is_alive(): return false
	decided_wave = prepared_wave
	var chosen := offer.duplicate(true)
	offer.clear()
	if not accepted: return true
	active = chosen
	if str(chosen.id) == "rising_tide":
		player.begin_modifier_update()
		_add_stat(player, "divinity", float(chosen.erosion))
		_add_stat(player, "interest_rate", float(chosen.interest_rate))
		_add_stat(player, "luck", float(chosen.luck))
		player.end_modifier_update()
		finance.deposit(int(chosen.principal), true, "wave_challenge")
	finance.record_trade_activity({"message_parts": ["log.challenge.accepted_prefix", L10n.message(L10n.key_for_source(str(chosen.body)))]})
	return true


func extra_elites(wave: int) -> int:
	return int(active.get("elite_count", 0)) if int(active.get("wave", -1)) == wave and str(active.get("id", "")) == "extra_elites" else 0


func settle_wave(wave: int, player: PlayerController, finance: BattleFinanceSystem) -> Dictionary:
	if int(active.get("wave", -1)) != wave: return {}
	var completed := active.duplicate(true)
	active.clear() # Claim before callbacks: settlement is once-only, including death.
	if player == null or not player.is_alive() or str(completed.id) != "all_in": return {}
	var transferred := finance.get_current_gold()
	# This is a future contractual transfer; current preparation restrictions do not apply.
	if transferred > 0 and not bool(finance.deposit(transferred, false, "wave_challenge").get("success", false)):
		push_error("Wave challenge automatic deposit failed")
		return {}
	finance.deposit(int(completed.principal), true, "wave_challenge")
	_add_stat(player, "luck", float(completed.luck))
	finance.record_trade_activity(L10n.message("log.challenge.completed", [transferred, int(completed.principal), int(completed.luck)]))
	return {"deposited": transferred, "principal_bonus": int(completed.principal), "luck_bonus": int(completed.luck)}


func _add_stat(player: PlayerController, stat: String, amount: float) -> void:
	totals[stat] = float(totals.get(stat, 0)) + amount
	player.add_runtime_modifier({"id": "wave_challenge_" + stat, "source_type": "wave_challenge", "source_id": "wave_challenge",
		"target_scope": "player", "stat": stat, "operation": Modifier.OPERATION_ADD_FLAT, "value": float(totals[stat]),
		"duration": Modifier.PERMANENT_DURATION, "stack_rule": Modifier.STACK_RULE_REPLACE_SAME_SOURCE})
