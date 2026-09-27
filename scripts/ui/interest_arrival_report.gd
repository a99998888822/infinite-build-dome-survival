extends RefCounted
class_name InterestArrivalReport
## Read-only presentation data. Never grants gold or rerolls relic effects.


static func build(payload: Dictionary) -> Dictionary:
	var results: Array = payload.get("settlement_results", [])
	if results.is_empty(): return {}
	var first: Dictionary = results[0]
	var last: Dictionary = results.back()
	var report := {"id": str(first.get("settlement_id", "")), "wave": int(first.get("wave_number", 0)),
		"principal": int(first.get("principal_before", 0)), "rate": float(first.get("interest_rate", 0)),
		"rate_after": float(last.get("interest_rate_after", first.get("interest_rate", 0))),
		"total": 0, "combat": int(payload.get("combat_gold_earned", 0)), "steps": [], "special": false}
	var running := 0.0
	var growth: Dictionary = {}
	for result: Dictionary in results:
		if bool(result.get("blocked", false)): continue
		if not bool(result.get("success", false)):
			if int(result.get("principal_before", 0)) > 0:
				_add(report, "notice", "本次未结息", "", running)
			continue
		var base := int(result.get("base_gain", 0))
		var nominal := int(result.get("nominal_gain", base))
		var relic_id := str(result.get("source_relic_id", ""))
		var label := "基础利息"
		if str(result.get("source", "")) != BattleFinanceSystem.SETTLE_WAVE_END:
			label = "%s · 额外结息" % _relic_name(relic_id, "遗物")
			report.special = true
		running += base
		_add(report, "base", label, "+%d" % base, running, relic_id)
		if bool(result.get("dividend_double_triggered", false)):
			report.special = true
			running += nominal - base
			var dividend_id := str(result.get("dividend_relic_id", "relic_dividend_check"))
			_add(report, "bonus", "%s ×%d" % [_relic_name(dividend_id, "分红支票"), int(result.get("dividend_multiplier", 2))], "+%d" % (nominal - base), running, dividend_id)
		report.total += int(result.get("gain", 0))
		for event: Dictionary in result.get("rate_growth_events", []):
			var id := str(event.get("relic_id", ""))
			growth[id] = float(growth.get(id, 0)) + float(event.get("delta", 0))
	# Reconcile the visible whole-coin receipt with the amount actually credited.
	# Fractional accrual remains in the finance system, without its own UI row.
	var loss := maxi(0, int(running) - int(report.total))
	if loss > 0:
		_add(report, "loss", "理智折损", "−%d" % loss, float(report.total))
	for id: String in growth:
		var delta := float(growth[id])
		var amount := "+%s%%" % HumanityEconomy.number(delta)
		_add(report, "growth", "%s · 利率成长" % _relic_name(id, "遗物"), amount, float(report.total), id)
	# No principal means no payout ceremony; the bank still shows its zero estimate.
	return report if not report.steps.is_empty() else {}


static func _add(report: Dictionary, kind: String, label: String, amount: String, target: float, relic_id: String = "") -> void:
	report.steps.append({"kind": kind, "label": label, "amount": amount, "target": maxf(0, target),
		"icon": str(DataRegistry.get_record("relics", relic_id).get("icon", "")) if not relic_id.is_empty() else ""})


static func _relic_name(id: String, fallback: String) -> String:
	return str(DataRegistry.get_record("relics", id).get("display_name", fallback)) if not id.is_empty() else fallback
