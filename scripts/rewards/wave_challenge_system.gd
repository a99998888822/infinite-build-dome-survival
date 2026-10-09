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
var accepted: Dictionary = {}
var spawn_frequency_bonus := 0.0
var vault_intact := false
var _enemy_clock := 0.0
var _enemy_birth_times: Dictionary = {}
var _enemy_spawned_count := 0
var _dead_enemy_lifetime := 0.0
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
	accepted.clear()
	spawn_frequency_bonus = 0.0
	vault_intact = false
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
	_enemy_clock = 0.0
	_enemy_birth_times.clear()
	_enemy_spawned_count = 0
	_dead_enemy_lifetime = 0.0
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


func finish_combat(trade_pressure: Dictionary, cleanup_timed_out := false, remaining_enemies := 0) -> void:
	pressure = trade_pressure.duplicate(true)
	var rules: Dictionary = config.pressure
	pressure.struggling = bool(pressure.get("struggling", false)) or _low_health_seconds >= float(rules.sustained_low_health_seconds)
	pressure.comfortable = not pressure.struggling and _observed >= float(rules.minimum_observed_seconds) and _minimum_health >= float(rules.comfortable_minimum_health_ratio) and int(pressure.get("low_health_episodes", 0)) == 0 and float(pressure.get("remaining_average", 0)) < float(pressure.get("enemy_threshold", 1)) * float(rules.comfortable_crowd_threshold_ratio)
	pressure.observed_seconds = _observed
	pressure.low_health_seconds = _low_health_seconds
	pressure.minimum_health_ratio = _minimum_health
	var total_lifetime := _dead_enemy_lifetime
	for born_at in _enemy_birth_times.values():
		total_lifetime += maxf(0.0, _enemy_clock - float(born_at))
	pressure.enemy_spawned_count = _enemy_spawned_count
	pressure.average_enemy_lifetime = total_lifetime / _enemy_spawned_count if _enemy_spawned_count > 0 else 0.0
	pressure.cleanup_timed_out = cleanup_timed_out
	pressure.cleanup_remaining_enemies = maxi(0, remaining_enemies)


func advance_enemy_lifetimes(delta: float) -> void:
	# WaveManager supplies active simulation time, clamped at each phase deadline.
	_enemy_clock += maxf(0.0, delta)


func record_enemy_spawn(instance_id: int) -> void:
	if _enemy_birth_times.has(instance_id): return
	_enemy_birth_times[instance_id] = _enemy_clock
	_enemy_spawned_count += 1


func record_enemy_death(instance_id: int) -> void:
	if not _enemy_birth_times.has(instance_id): return
	_dead_enemy_lifetime += maxf(0.0, _enemy_clock - float(_enemy_birth_times[instance_id]))
	_enemy_birth_times.erase(instance_id)


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


func eligible_offers(_snapshot: Dictionary, context: Dictionary = {}) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var risky := bool(pressure.get("struggling", false))
	for entry: Dictionary in config.challenges:
		if bool(entry.get("once_per_run", false)) and accepted.has(str(entry.id)): continue
		var eligible := false
		match str(entry.condition):
			"comfortable": eligible = bool(pressure.get("comfortable", false))
			"pressure": eligible = risky
			"comfortable_expansion": eligible = bool(pressure.get("comfortable", false)) and int(context.get("remaining_waves", 0)) >= int(entry.minimum_remaining_waves)
			"pressured_cleanup": eligible = risky and bool(pressure.get("cleanup_timed_out", false)) and int(pressure.get("cleanup_remaining_enemies", 0)) > 0 and int(pressure.get("enemy_spawned_count", 0)) > 0 and float(pressure.get("average_enemy_lifetime", 0)) >= float(entry.minimum_average_lifetime_seconds)
			"pressured_capital": eligible = bool(pressure.get("struggling", false)) and int(context.get("principal", 0)) >= int(entry.minimum_principal)
			"medium_pressure": eligible = float(pressure.get("observed_seconds", 0)) >= float(config.pressure.minimum_observed_seconds) and not risky and not bool(pressure.get("comfortable", false))
			"outstanding_debt": eligible = int(context.get("debt_due", 0)) > 0 and not str(context.get("debt_id", "")).is_empty() and not boss_templates(entry).is_empty()
		if eligible:
			candidates.append(entry.duplicate(true))
	return candidates


func prepare(wave: int, snapshot: Dictionary, context: Dictionary = {}) -> Dictionary:
	if wave <= prepared_wave:
		if str(offer.get("id", "")) == "debt_hunter" and (str(context.get("debt_id", "")) != str(offer.debt_id) or int(context.get("debt_due", 0)) != int(offer.debt_due)):
			offer.clear()
		return offer.duplicate(true)
	prepared_wave = wave
	offer.clear()
	if wave <= 1: return {}
	var candidates := eligible_offers(snapshot, context)
	if candidates.is_empty(): return {}
	offer = candidates[_rng.randi_range(0, candidates.size() - 1)]
	offer.wave = wave
	offer.token = "%d:%s" % [wave, str(offer.id)]
	if str(offer.id) == "capital_custody":
		offer.stake = mini(int(offer.maximum_stake), floori(int(context.principal) * float(offer.stake_ratio)))
		offer.bonus = clampi(roundi(int(offer.stake) * float(offer.bonus_ratio)), int(offer.minimum_bonus), int(offer.maximum_bonus))
		offer.body_message = L10n.message(L10n.key_for_source(str(offer.body)), [int(offer.stake), int(offer.stake) + int(offer.bonus)])
		offer.body = str(offer.body) % [int(offer.stake), int(offer.stake) + int(offer.bonus)]
	if str(offer.id) in ["paid_overtime", "debt_hunter"]:
		var amount := 0
		if str(offer.id) == "paid_overtime":
			amount = int(offer.gold_base) + int(offer.gold_per_wave) * wave
			offer.gold_reward = amount
		else:
			var pool := boss_templates(offer)
			offer.boss_template = pool[_rng.randi_range(0, pool.size() - 1)]
			offer.debt_id = str(context.debt_id)
			offer.debt_due = int(context.debt_due)
			amount = int(offer.debt_due)
			offer.debt_amount = amount
		var replacements := {"动态值": amount}
		offer.body_message = L10n.message(L10n.key_for_source(str(offer.body)))
		offer.body_message["message_replacements"] = replacements
		offer.body = str(offer.body).format(replacements)
	return offer.duplicate(true)


func decide(token: String, accepted: bool, player: PlayerController, finance: BattleFinanceSystem, loans: GoblinLoanSystem = null) -> bool:
	if offer.is_empty() or token != str(offer.token) or decided_wave == prepared_wave or player == null or not player.is_alive(): return false
	if accepted and str(offer.id) == "debt_hunter":
		if loans == null or loans.debt_identity() != str(offer.debt_id) or int(loans.debt.get("due", 0)) != int(offer.debt_due): return false
	if accepted and str(offer.id) == "capital_custody":
		if finance == null or not finance.consume_trade_principal(int(offer.stake)): return false
	decided_wave = prepared_wave
	var chosen := offer.duplicate(true)
	offer.clear()
	if not accepted: return true
	active = chosen
	self.accepted[str(chosen.id)] = prepared_wave
	if str(chosen.id) == "business_expansion": spawn_frequency_bonus += float(chosen.frequency_bonus)
	if str(chosen.id) == "capital_custody": vault_intact = true
	if str(chosen.id) == "rising_tide":
		player.begin_modifier_update()
		_add_stat(player, "divinity", float(chosen.erosion))
		_add_stat(player, "interest_rate", float(chosen.interest_rate))
		_add_stat(player, "luck", float(chosen.luck))
		player.end_modifier_update()
		finance.deposit(int(chosen.principal), true, "wave_challenge")
	finance.record_trade_activity({"message_parts": ["log.challenge.accepted_prefix", chosen.get("body_message", L10n.message(L10n.key_for_source(str(chosen.body))))]})
	return true


func extra_elites(wave: int) -> int:
	return int(active.get("elite_count", 0)) if int(active.get("wave", -1)) == wave and str(active.get("id", "")) == "extra_elites" else 0


func settle_wave(wave: int, player: PlayerController, finance: BattleFinanceSystem) -> Dictionary:
	if int(active.get("wave", -1)) != wave: return {}
	var completed := active.duplicate(true)
	active.clear() # Claim before callbacks: settlement is once-only, including death.
	if player == null or not player.is_alive(): return {}
	if str(completed.id) == "paid_overtime":
		var reward := int(completed.gold_reward)
		finance.grant_trade_gold(reward)
		finance.record_trade_activity(L10n.message("log.challenge.gold_granted", [reward]))
		return {"gold_bonus": reward}
	if str(completed.id) == "debt_hunter": return completed.get("debt_result", {})
	if str(completed.id) == "business_expansion":
		finance.deposit(int(completed.principal), true, "wave_challenge")
		return {"principal_bonus": int(completed.principal)}
	if str(completed.id) == "capital_custody":
		var returned := int(completed.stake) + int(completed.bonus) if vault_intact else 0
		vault_intact = false
		if returned > 0: finance.deposit(returned, true, "wave_challenge")
		return {"principal_returned": returned, "principal_lost": int(completed.stake) if returned == 0 else 0}
	if str(completed.id) != "all_in": return {}
	var transferred := finance.get_current_gold()
	# This is a future contractual transfer; current preparation restrictions do not apply.
	if transferred > 0 and not bool(finance.deposit(transferred, false, "wave_challenge").get("success", false)):
		push_error("Wave challenge automatic deposit failed")
		return {}
	finance.deposit(int(completed.principal), true, "wave_challenge")
	_add_stat(player, "luck", float(completed.luck))
	finance.record_trade_activity(L10n.message("log.challenge.completed", [transferred, int(completed.principal), int(completed.luck)]))
	return {"deposited": transferred, "principal_bonus": int(completed.principal), "luck_bonus": int(completed.luck)}


func gold_terms(wave: int) -> Dictionary:
	if int(active.get("wave", -1)) == wave and str(active.get("id", "")) == "fleeting_fortune":
		return {"multiplier": float(active.gold_multiplier), "lifetime": float(active.gold_lifetime)}
	return {}


func boss_templates(entry: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for id in entry.get("boss_templates", []):
		if str(DataRegistry.get_record("enemies", str(id)).get("enemy_type", "")) == "elite": pool.append(str(id))
	return pool


func enemy_modifiers(wave: int, debt_target := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(active.get("wave", -1)) != wave: return result
	var factors := {}
	if str(active.id) == "paid_overtime": factors.max_hp = float(active.health_multiplier)
	if str(active.id) == "debt_hunter" and debt_target:
		factors = {"max_hp": float(active.health_multiplier), "armor": float(active.armor_multiplier),
			"melee_damage": float(active.damage_multiplier), "ranged_damage": float(active.damage_multiplier), "element_damage": float(active.damage_multiplier)}
	for stat in factors:
		result.append({"id": "challenge_" + str(stat), "source_type": "wave_challenge", "source_id": str(active.id), "target_scope": "enemy", "stat": stat,
			"operation": Modifier.OPERATION_MULTIPLY, "value": float(factors[stat]), "duration": -1, "stack_rule": Modifier.STACK_RULE_UNIQUE})
	return result


func resolve_debt_target(wave: int, killed: bool, loans: GoblinLoanSystem, finance: BattleFinanceSystem) -> Dictionary:
	if str(active.get("id", "")) != "debt_hunter" or int(active.get("wave", -1)) != wave or bool(active.get("debt_resolved", false)): return {}
	active.debt_resolved = true
	var result := loans.adjust_challenge_debt(str(active.debt_id), int(active.debt_amount) * (-1 if killed else 1), finance)
	result["target_killed"] = killed
	active.debt_result = result
	return result


func _add_stat(player: PlayerController, stat: String, amount: float) -> void:
	totals[stat] = float(totals.get(stat, 0)) + amount
	player.add_runtime_modifier({"id": "wave_challenge_" + stat, "source_type": "wave_challenge", "source_id": "wave_challenge",
		"target_scope": "player", "stat": stat, "operation": Modifier.OPERATION_ADD_FLAT, "value": float(totals[stat]),
		"duration": Modifier.PERMANENT_DURATION, "stack_rule": Modifier.STACK_RULE_REPLACE_SAME_SOURCE})
