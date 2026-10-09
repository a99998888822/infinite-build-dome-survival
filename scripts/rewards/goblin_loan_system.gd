extends RefCounted
class_name GoblinLoanSystem
## Owns one run's immutable quotes and debt, independently of UI lifetime.

const CONFIG_PATH := "res://data_config/goblin_loans.json"
const MAX_DEBT: int = 9223372036854775807
var config: Dictionary = {}
var preparation_wave := -1
var clicks := 0
var quote: Dictionary = {}
var debt: Dictionary = {}
var dialog_open := false
var accepted_this_visit := false
var paid_this_visit := false
var last_settlement: Dictionary = {}
var _last_settled_wave := -1
var _run_token := ""
var _busy := false


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary: config = parsed
	else: push_error("Invalid goblin loan config: " + CONFIG_PATH)
	reset()


func reset() -> void:
	preparation_wave = -1
	clicks = 0
	quote.clear()
	debt.clear()
	dialog_open = false
	accepted_this_visit = false
	paid_this_visit = false
	last_settlement.clear()
	_last_settled_wave = -1
	_busy = false
	_run_token = Crypto.new().generate_random_bytes(8).hex_encode()


func prepare(wave: int) -> void:
	if wave <= preparation_wave: return
	preparation_wave = wave
	clicks = 0
	quote.clear()
	dialog_open = false
	accepted_this_visit = false
	paid_this_visit = false


func can_offer() -> bool:
	return bool(config.get("enabled", false)) and preparation_wave > 0 and debt.is_empty() and quote.is_empty() and not accepted_this_visit and not paid_this_visit and not _busy


func record_attempt(finance: BattleFinanceSystem, stats: RunStatistics) -> bool:
	if not can_offer() or finance == null: return false
	clicks += 1
	if clicks < int(config.get("trigger_clicks", 3)): return false
	var options: Array[Dictionary] = []
	var baseline := finance.project_next_wave_interest(0, false)
	for entry: Dictionary in config.get("offers", []):
		var amount := int(entry.amount)
		var rate := float(entry.rate_percent)
		# Compare incremental proceeds, including conditional deposit bonuses on
		# existing principal. Holding borrowed cash can also affect wave-start gifts.
		var extra := maxf(0, maxf(finance.project_next_wave_interest(amount, true), finance.project_next_wave_interest(amount, false)) - baseline)
		var base_cost := float(amount) * rate / 100.0
		if extra > base_cost + 0.000001:
			var step := maxf(1, float(config.pricing.rate_step_percent))
			rate = ceilf((extra * 100.0 / amount + float(config.pricing.safety_margin_percent)) / step) * step
		options.append({"amount":amount, "rate_percent":rate, "due":compound(amount,rate),
			"icon":str(entry.icon), "adjusted":rate > float(entry.rate_percent), "projected_extra_interest":extra})
	if options.is_empty(): return false
	quote = {"token":"%s:%d" % [_run_token,preparation_wave], "speech":str(config.speech), "options":options, "due_wave":preparation_wave}
	dialog_open = true
	stats.show_advice("loan", str(quote.token))
	return true


func reopen() -> bool:
	if quote.is_empty() or not debt.is_empty() or accepted_this_visit or paid_this_visit: return false
	dialog_open = true
	return true


func dismiss() -> void:
	dialog_open = false


func leave_preparation(stats: RunStatistics) -> void:
	dialog_open = false
	# A dismissal is reversible. Only leaving without borrowing is a refusal.
	if not quote.is_empty() and not accepted_this_visit:
		stats.decide_advice("loan",str(quote.token),false)


func accept(token: String, index: int, finance: BattleFinanceSystem, stats: RunStatistics) -> Dictionary:
	if _busy or not dialog_open or quote.is_empty() or token != str(quote.token) or not debt.is_empty() or accepted_this_visit or paid_this_visit:
		return {"success":false,"reason":"loan_expired"}
	var options: Array = quote.options
	if index < 0 or index >= options.size(): return {"success":false,"reason":"loan_expired"}
	_busy = true
	var chosen: Dictionary = options[index].duplicate(true)
	debt = chosen
	debt["loan_id"] = str(quote.token)
	debt["due_wave"] = preparation_wave
	debt["rollovers"] = 0
	accepted_this_visit = true
	dialog_open = false
	if not finance.apply_loan_gold_delta(int(chosen.amount)):
		debt.clear()
		accepted_this_visit = false
		dialog_open = true
		_busy = false
		return {"success":false,"reason":"transaction_failed"}
	stats.decide_advice("loan",token,true)
	finance.record_loan_activity(L10n.message("log.loan.borrowed", [chosen.amount,preparation_wave,chosen.due,HumanityEconomy.number(float(chosen.rate_percent))]))
	_busy = false
	return {"success":true,"amount":chosen.amount,"due":chosen.due}


func repay(finance: BattleFinanceSystem, automatic := false) -> Dictionary:
	if _busy or debt.is_empty(): return {"success":false,"reason":"loan_not_active"}
	var amount := int(debt.due)
	if finance.get_current_gold() < amount: return {"success":false,"reason":"loan_insufficient_gold"}
	_busy = true
	var previous := debt.duplicate(true)
	debt.clear() # Reserve before synchronous wallet signals, restore on failure.
	if not finance.apply_loan_gold_delta(-amount):
		debt = previous
		_busy = false
		return {"success":false,"reason":"transaction_failed"}
	paid_this_visit = true
	dialog_open = false
	finance.record_loan_activity(L10n.message("log.loan.repaid", ["log.loan.repayment.automatic" if automatic else "log.loan.repayment.manual",amount]))
	_busy = false
	return {"success":true,"action":"paid","amount":amount,"borrowed":previous.amount}


func debt_identity() -> String:
	if debt.is_empty(): return ""
	return str(debt.get("loan_id", "%s:%s:%s" % [_run_token, debt.get("amount", 0), debt.get("rate_percent", 0)]))


func adjust_challenge_debt(loan_id: String, delta: int, finance: BattleFinanceSystem) -> Dictionary:
	if _busy or debt.is_empty() or loan_id != debt_identity(): return {}
	_busy = true
	var before := int(debt.due)
	var after := before + mini(delta, MAX_DEBT - before) if delta > 0 else maxi(0, before + delta)
	debt.due = after
	if after == 0:
		debt.clear()
		paid_this_visit = true
	finance.record_loan_activity(L10n.message("log.challenge.debt_changed", [before, after]))
	_busy = false
	return {"debt_before": before, "debt_after": after, "debt_delta": after - before}


func settle_wave(wave: int, finance: BattleFinanceSystem) -> Dictionary:
	if wave <= _last_settled_wave: return last_settlement.duplicate(true) if int(last_settlement.get("wave",-1)) == wave else {}
	_last_settled_wave = wave
	if debt.is_empty() or wave < int(debt.due_wave): return {}
	var result: Dictionary
	if finance.get_current_gold() >= int(debt.due):
		result = repay(finance,true)
	else:
		var before := int(debt.due)
		debt.due = compound(before,float(debt.rate_percent))
		debt.due_wave = wave+1
		debt.rollovers = int(debt.rollovers)+1
		result = {"success":true,"action":"rollover","before":before,"due":debt.due,"interest":int(debt.due)-before,"gold":finance.get_current_gold()}
		finance.record_loan_activity(L10n.message("log.loan.unpaid", [result.gold,before,result.interest,result.due]))
	result["wave"] = wave
	last_settlement = result.duplicate(true)
	return result


func snapshot(gold: int) -> Dictionary:
	var state := "hidden"
	if not debt.is_empty(): state = "compound" if int(debt.rollovers)>0 else "borrowed"
	elif not quote.is_empty() and not accepted_this_visit: state = "available"
	elif paid_this_visit or (str(last_settlement.get("action",""))=="paid" and int(last_settlement.get("wave",-2))==preparation_wave-1): state = "paid"
	return {"state":state,"gold":gold,"quote":quote.duplicate(true),"debt":debt.duplicate(true),"dialog_open":dialog_open,
		"can_repay":not debt.is_empty() and gold>=int(debt.get("due",0))}


static func compound(amount: int, rate: float) -> int:
	var result := ceilf(float(amount)*(1.0+rate/100.0)-0.000000001)
	return MAX_DEBT if result >= float(MAX_DEBT) else maxi(amount,int(result))
