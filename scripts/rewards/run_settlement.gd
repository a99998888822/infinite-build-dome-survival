extends RefCounted
class_name RunSettlement
## Frozen receipt: both presentation and persistent award use this single calculation.

const CONFIG_PATH := "res://data_config/run_settlement.json"


static func configuration() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return data if data is Dictionary else {}


static func build(statistics: Dictionary, victory: bool, difficulty_id: String = BattleDifficulty.DEFAULT_ID) -> Dictionary:
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
	# Apply once to the subtotal, after contribution caps; display and payment share this receipt.
	report["camp_currency"] = roundi(float(report.base_camp_currency) * float(report.difficulty_multiplier))
	report["difficulty_bonus"] = int(report.camp_currency) - int(report.base_camp_currency)
	report["interest_capped"] = raw_interest >= interest_cap and raw_interest > 0
	report["victory"] = victory
	report["reaction"] = ("victory_" if victory else "death_") + ("followed" if bool(statistics.get("followed", false)) else "refused") if bool(statistics.get("has_advice", false)) else ""
	report["paid"] = false
	return report
