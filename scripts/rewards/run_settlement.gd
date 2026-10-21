extends RefCounted
class_name RunSettlement
## Frozen receipt: both presentation and persistent award use this single calculation.

const CONFIG_PATH := "res://data_config/run_settlement.json"


static func configuration() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return data if data is Dictionary else {}


static func build(statistics: Dictionary, victory: bool, difficulty_id: String = BattleDifficulty.DEFAULT_ID, retreated: bool = false) -> Dictionary:
	var config := configuration()
	var rates: Dictionary = config.formula
	var report := statistics.duplicate(true)
	var values: Array[int] = []
	for key in ["kills", "gold", "waves", "interest"]:
		values.append(maxi(0, int(statistics.get(key, 0))))
	var raw_interest := floori(float(values[3]) / float(rates.interest_per_coin))
	var interest_cap := values[2] * int(rates.interest_cap_per_wave)
	var parts: Array[int] = [floori(float(values[0]) / float(rates.kills_per_coin)),
		floori(float(values[1]) / float(rates.gold_per_coin)), values[2] * int(rates.coins_per_wave), mini(raw_interest, interest_cap)]
	report["values"] = values
	report["contributions"] = parts
	report["difficulty_id"] = BattleDifficulty.normalize(difficulty_id)
	report["difficulty_multiplier"] = float(config.difficulty_multipliers.get(report.difficulty_id, 1.0))
	report["base_camp_currency"] = parts[0] + parts[1] + parts[2] + parts[3]
	var outcomes: Dictionary = config.outcome_multipliers
	var outcome := "victory" if victory and not retreated else "defeat"
	report["outcome"] = "retreat" if retreated else outcome
	report["outcome_multiplier"] = float(outcomes[outcome])
	report["reward_multiplier"] = float(report.difficulty_multiplier) * float(report.outcome_multiplier)
	var difficulty_base := float(report.base_camp_currency) * float(report.difficulty_multiplier)
	report["difficulty_bonus"] = roundi(difficulty_base) - int(report.base_camp_currency)
	report["camp_currency"] = roundi(float(report.base_camp_currency) * float(report.reward_multiplier))
	# Retreat is exactly half of the payable defeat receipt, rounded down to coins.
	report["defeat_camp_currency"] = roundi(difficulty_base * float(outcomes.defeat))
	report["retreat_multiplier"] = float(outcomes.retreat_vs_defeat)
	if retreated:
		report.camp_currency = floori(int(report.defeat_camp_currency) * float(report.retreat_multiplier))
	report["interest_capped"] = raw_interest >= interest_cap and raw_interest > 0
	report["victory"] = victory and not retreated
	report["reaction"] = ""
	if not retreated:
		if bool(statistics.get("has_advice", false)):
			report["reaction"] = ("victory_" if victory else "death_") + ("followed" if bool(statistics.get("followed", false)) else "refused")
		else:
			report["reaction"] = "victory_followed" if victory else "death_no_advice"
	report["paid"] = false
	return report
