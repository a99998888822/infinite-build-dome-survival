extends RefCounted
class_name RunSettlement
## Frozen receipt: both presentation and persistent award use this single calculation.
##
## 50% waves / 20% kills / 20% damage / 10% survival time. Each counter is measured
## against a reference value and pushed through a soft tail above it, then the whole
## base is scaled once by the outcome and the difficulty. Gold and interest no longer
## buy Talent Points, so a runaway economy can never unbalance the payout.

const CONFIG_PATH := "res://data_config/run_settlement.json"
const COMPENSATION_DEFAULTS := {"max_points": 200.0, "points_per_kill": 4.0, "falloff_waves": 10.0}
const DEFAULT_BUDGET := 12000.0
const DEFAULT_SOFT_TAIL := 0.25
## Display and receipt order: waves, kills, damage, survival seconds.
const COUNTER_KEYS: Array[String] = ["waves", "kills", "damage", "seconds"]


static func configuration() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return data if data is Dictionary else {}


static func budget_of(config: Dictionary) -> float:
	return maxf(0.0, float(config.get("budget", DEFAULT_BUDGET)))


static func weights_of(config: Dictionary) -> Dictionary:
	var weights: Variant = config.get("weights", {})
	return weights if weights is Dictionary else {}


static func references_of(config: Dictionary) -> Dictionary:
	var references: Variant = config.get("references", {})
	return references if references is Dictionary else {}


static func soft_tail_factor(config: Dictionary) -> float:
	return maxf(0.0, float(config.get("soft_tail_factor", DEFAULT_SOFT_TAIL)))


static func soft_tail_share(value: float, reference: float, factor: float) -> float:
	## Linear up to the reference, then logarithmic: every doubling above the
	## reference still pays, but each one pays less than the previous doubling.
	if reference <= 0.0:
		return 0.0
	var ratio := maxf(0.0, value) / reference
	if ratio <= 1.0:
		return ratio
	return 1.0 + factor * log(ratio) / log(2.0)


static func contribution(value: float, reference: float, weight: float, budget: float, factor: float, scale: float = 1.0) -> int:
	return maxi(0, roundi(budget * maxf(0.0, weight) * maxf(0.0, scale) * soft_tail_share(value, reference, factor)))


static func defeat_compensation(config: Dictionary, kills: int, waves: int, outcome: String) -> int:
	# Early expeditions pay little from the counters alone, so a capped per-kill
	# compensation fades out as waves complete. Late clears keep their total.
	if outcome != "defeat":
		return 0
	var settings: Dictionary = config.get("defeat_compensation", {})
	var maximum := float(settings.get("max_points", COMPENSATION_DEFAULTS["max_points"]))
	var per_kill := float(settings.get("points_per_kill", COMPENSATION_DEFAULTS["points_per_kill"]))
	var falloff := maxf(1.0, float(settings.get("falloff_waves", COMPENSATION_DEFAULTS["falloff_waves"])))
	if maximum <= 0.0 or per_kill <= 0.0:
		return 0
	var earned := minf(maximum, float(maxi(0, kills)) * per_kill)
	return roundi(earned * clampf(1.0 - float(maxi(0, waves)) / falloff, 0.0, 1.0))


static func build(statistics: Dictionary, victory: bool, difficulty_id: String = BattleDifficulty.DEFAULT_ID, retreated: bool = false) -> Dictionary:
	var config := configuration()
	var weights := weights_of(config)
	var references := references_of(config)
	var budget := budget_of(config)
	var factor := soft_tail_factor(config)
	var report := statistics.duplicate(true)
	var waves := maxi(0, int(statistics.get("waves", 0)))
	var kills := maxi(0, int(statistics.get("kills", 0)))
	var damage := maxi(0, int(statistics.get("damage", 0)))
	var seconds := maxf(0.0, float(statistics.get("seconds", 0.0)))
	# Survival time is capped per completed wave, so stalling in a cleared wave
	# cannot farm the ten percent share.
	var seconds_cap := maxf(0.0, float(config.get("seconds_per_wave_cap", 90.0))) * float(maxi(1, waves))
	seconds = minf(seconds, seconds_cap)
	var values: Array[int] = [waves, kills, damage, roundi(seconds)]
	var parts: Array[int] = []
	var shares: Array = []
	# Every counter is measured against the bar it should have reached by that
	# wave, then scaled by progress. Thresholds still scale linearly, so thick
	# late-wave enemies do not hand out points for free, and a short run cannot
	# bank a full-run counter.
	var wave_scale := float(maxi(1, waves)) / maxf(1.0, float(references.get("waves", 12.0)))
	for index in COUNTER_KEYS.size():
		var key := COUNTER_KEYS[index]
		var reference := float(references.get(key, 0.0)) * wave_scale
		var share := soft_tail_share(float(values[index]), reference, factor)
		shares.append(share)
		parts.append(contribution(float(values[index]), reference, float(weights.get(key, 0.0)), budget, factor, wave_scale))
	report["values"] = values
	report["wave_scale"] = wave_scale
	report["contributions"] = parts
	report["shares"] = shares
	report["budget"] = budget
	report["weights"] = weights.duplicate(true)
	report["references"] = references.duplicate(true)
	report["difficulty_id"] = BattleDifficulty.normalize(difficulty_id)
	report["difficulty_multiplier"] = float(config.difficulty_multipliers.get(report.difficulty_id, 1.0))
	report["base_camp_currency"] = parts[0] + parts[1] + parts[2] + parts[3]
	var outcomes: Dictionary = config.outcome_multipliers
	var outcome := "retreat" if retreated else ("victory" if victory else "defeat")
	report["outcome"] = outcome
	report["outcome_multiplier"] = float(outcomes[outcome])
	report["reward_multiplier"] = float(report.difficulty_multiplier) * float(report.outcome_multiplier)
	var difficulty_base := float(report.base_camp_currency) * float(report.difficulty_multiplier)
	report["difficulty_bonus"] = roundi(difficulty_base) - int(report.base_camp_currency)
	# The compensation never scales with difficulty, so a fast hard-mode death
	# cannot be farmed for multiplied consolation points.
	var compensation := defeat_compensation(config, kills, waves, "defeat" if retreated else outcome)
	if retreated:
		compensation = roundi(compensation * float(config.retreat_compensation_multiplier))
	report["compensation"] = compensation
	report["camp_currency"] = roundi(float(report.base_camp_currency) * float(report.reward_multiplier)) + compensation
	report["victory"] = victory and not retreated
	report["reaction"] = ""
	if not retreated:
		if bool(statistics.get("has_advice", false)):
			report["reaction"] = ("victory_" if victory else "death_") + ("followed" if bool(statistics.get("followed", false)) else "refused")
		else:
			report["reaction"] = "victory_followed" if victory else "death_no_advice"
	report["paid"] = false
	return report
