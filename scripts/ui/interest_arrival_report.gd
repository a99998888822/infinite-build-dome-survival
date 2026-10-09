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
	report["source_payload"] = {"settlement_results": results.duplicate(true), "combat_gold_earned": report.combat}
	var running := 0.0
	var growth: Dictionary = {}
	for result: Dictionary in results:
		if bool(result.get("blocked", false)): continue
		if not bool(result.get("success", false)):
			if int(result.get("principal_before", 0)) > 0:
				_add(report, "notice", L10n.text("ui.interest.not_settled"), "", running)
			continue
		var base := int(result.get("base_gain", 0))
		var nominal := int(result.get("nominal_gain", base))
		var relic_id := str(result.get("source_relic_id", ""))
		var label := L10n.text("ui.interest.base")
		if str(result.get("source", "")) != BattleFinanceSystem.SETTLE_WAVE_END:
			label = L10n.text("ui.interest.extra_by_source") % _relic_name(relic_id, L10n.text("ui.common.relic"))
			report.special = true
		running += base
		_add(report, "base", label, "+%d" % base, running, relic_id)
		if bool(result.get("dividend_double_triggered", false)):
			report.special = true
			running += nominal - base
			var dividend_id := str(result.get("dividend_relic_id", "relic_dividend_check"))
			_add(report, "bonus", "%s ×%d" % [_relic_name(dividend_id, L10n.text("ui.interest.dividend_check")), int(result.get("dividend_multiplier", 2))], "+%d" % (nominal - base), running, dividend_id)
		report.total += int(result.get("gain", 0))
		for event: Dictionary in result.get("rate_growth_events", []):
			var id := str(event.get("relic_id", ""))
			growth[id] = float(growth.get(id, 0)) + float(event.get("delta", 0))
	# Reconcile the visible whole-coin receipt with the amount actually credited.
	# Fractional accrual remains in the finance system, without its own UI row.
	var loss := maxi(0, int(running) - int(report.total))
	if loss > 0:
		_add(report, "loss", L10n.text("ui.interest.sanity_loss"), "−%d" % loss, float(report.total))
	for id: String in growth:
		var delta := float(growth[id])
		var amount := "+%s%%" % HumanityEconomy.number(delta)
		_add(report, "growth", L10n.text("ui.interest.rate_growth") % _relic_name(id, L10n.text("ui.common.relic")), amount, float(report.total), id)
	# No principal means no payout ceremony; the bank still shows its zero estimate.
	var loan: Dictionary = last.get("loan_settlement",{})
	if not loan.is_empty() and not report.steps.is_empty():
		if str(loan.get("action",""))=="paid":
			_add(report,"notice",L10n.text("ui.interest.loan_repaid"),L10n.text("ui.interest.gold_spent") % int(loan.amount),float(report.total))
		elif str(loan.get("action",""))=="rollover":
			_add(report,"notice",L10n.text("ui.interest.loan_compounded"),L10n.text("ui.interest.loan_due") % int(loan.due),float(report.total))
	var challenge: Dictionary = last.get("challenge_settlement", {})
	if challenge.has("deposited"):
		report["auto_deposit"] = true
		_add(report, "growth", L10n.text("ui.interest.auto_deposit"), L10n.text("ui.loan.gold_amount") % int(challenge.deposited), float(report.total))
		_add(report, "growth", L10n.text("ui.interest.challenge_reward"), L10n.text("ui.interest.challenge_bonus") % [int(challenge.principal_bonus), int(challenge.luck_bonus)], float(report.total))
	elif challenge.has("principal_returned"):
		var returned := int(challenge.principal_returned)
		_add(report, "growth" if returned > 0 else "loss", L10n.text("ui.challenge.custody_returned" if returned > 0 else "ui.challenge.custody_lost"),
			L10n.text("ui.challenge.principal_amount") % (returned if returned > 0 else int(challenge.principal_lost)), float(report.total))
	elif challenge.has("principal_bonus"):
		_add(report, "growth", L10n.text("ui.interest.challenge_reward"), L10n.text("ui.challenge.principal_amount") % int(challenge.principal_bonus), float(report.total))
	return report if not report.steps.is_empty() else {}


static func _add(report: Dictionary, kind: String, label: String, amount: String, target: float, relic_id: String = "") -> void:
	report.steps.append({"kind": kind, "label": label, "amount": amount, "target": maxf(0, target),
		"icon": str(DataRegistry.get_record("relics", relic_id).get("icon", "")) if not relic_id.is_empty() else ""})


static func _relic_name(id: String, fallback: String) -> String:
	return L10n.source(str(DataRegistry.get_record("relics", id).get("display_name", fallback))) if not id.is_empty() else fallback
