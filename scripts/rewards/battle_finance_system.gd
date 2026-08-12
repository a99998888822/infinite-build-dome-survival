extends RefCounted
class_name BattleFinanceSystem

signal finance_changed(snapshot: Dictionary)
signal interest_settled(result: Dictionary)

const DEFAULT_INTEREST_RATE: float = 5.0
const ACTION_NONE: String = "none"
const ACTION_DEPOSIT: String = "deposit"
const ACTION_WITHDRAW: String = "withdraw"
const SETTLE_WAVE_END: String = "wave_end"
const SETTLE_MANUAL: String = "manual"
const SETTLE_PERIODIC: String = "periodic"
const SETTLE_ANNUITY: String = "annuity"

var player: PlayerController = null
var principal: int = 0
var interest_rate_bonus: float = 0.0
var wave_counter: int = 0
var current_wave_number: int = 0
var last_action_wave_number: int = 0
var last_deposit_wave_number: int = 0
var locked_until_wave_number: int = 0
var has_deposited_before_current_wave: bool = false
var annuity_timer: float = 0.0
var last_settlement_result: Dictionary = {}
var last_settlement_results: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _gold_getter: Callable = Callable()
var _gold_delta_applier: Callable = Callable()


func initialize(target_player: PlayerController, gold_getter: Callable, gold_delta_applier: Callable) -> void:
	player = target_player
	_gold_getter = gold_getter
	_gold_delta_applier = gold_delta_applier
	principal = 0
	interest_rate_bonus = 0.0
	wave_counter = 0
	current_wave_number = 0
	last_action_wave_number = 0
	last_deposit_wave_number = 0
	locked_until_wave_number = 0
	has_deposited_before_current_wave = false
	annuity_timer = 0.0
	last_settlement_result.clear()
	last_settlement_results.clear()
	_rng.randomize()
	_emit_changed()


func tick(delta: float) -> void:
	var annuity_count := _get_relic_count("relic_perpetual_annuity_scroll")
	if player == null or principal <= 0 or annuity_count <= 0:
		return
	annuity_timer += maxf(delta, 0.0)
	while annuity_timer >= 1.0:
		annuity_timer -= 1.0
		for _index in range(annuity_count):
			settle_interest(SETTLE_ANNUITY)


func begin_wave(wave_number: int) -> Dictionary:
	current_wave_number = maxi(1, wave_number)
	wave_counter += 1
	has_deposited_before_current_wave = false
	annuity_timer = 0.0
	_apply_wave_start_relics()
	_emit_changed()
	return build_finance_popup_payload("wave_start")


func build_finance_popup_payload(source: String = "wave_start") -> Dictionary:
	return {
		"source": source,
		"wave_number": current_wave_number,
		"gold": get_current_gold(),
		"principal": principal,
		"interest_rate": get_interest_rate(),
		"estimated_interest": get_estimated_interest(),
		"can_withdraw": get_withdrawable_principal() > 0,
		"withdrawable_principal": get_withdrawable_principal(),
		"locked_until_wave_number": locked_until_wave_number,
		"last_deposit_wave_number": last_deposit_wave_number,
		"has_high_yield_contract": _has_relic("relic_high_yield_contract"),
		"requires_deposit_for_interest": _has_relic("relic_high_yield_contract"),
		"has_deposited_before_current_wave": has_deposited_before_current_wave,
	}


func apply_finance_operation(action: String, amount: int) -> Dictionary:
	var sanitized_action := str(action).strip_edges()
	var sanitized_amount := maxi(0, amount)
	match sanitized_action:
		ACTION_DEPOSIT:
			return deposit(sanitized_amount)
		ACTION_WITHDRAW:
			return withdraw(sanitized_amount)
		ACTION_NONE, "":
			var result := _build_operation_result(true, ACTION_NONE, 0, "no_operation")
			_emit_changed()
			return result
		_:
			return _build_operation_result(false, sanitized_action, sanitized_amount, "invalid_action")


func deposit(amount: int, free_principal: bool = false, reason: String = "manual") -> Dictionary:
	var sanitized_amount := maxi(0, amount)
	if sanitized_amount <= 0:
		return _build_operation_result(false, ACTION_DEPOSIT, sanitized_amount, "amount_must_be_positive")
	if not free_principal:
		var current_gold := get_current_gold()
		if sanitized_amount > current_gold:
			return _build_operation_result(false, ACTION_DEPOSIT, sanitized_amount, "amount_exceeds_gold")
		if not _apply_gold_delta(-sanitized_amount, "finance_deposit"):
			return _build_operation_result(false, ACTION_DEPOSIT, sanitized_amount, "gold_delta_failed")
	principal += sanitized_amount
	last_action_wave_number = current_wave_number
	last_deposit_wave_number = current_wave_number
	if not free_principal and reason == "manual":
		has_deposited_before_current_wave = true
	if _has_relic("relic_fixed_deposit_certificate") and reason == "manual":
		locked_until_wave_number = maxi(locked_until_wave_number, current_wave_number)
	_emit_changed()
	return _build_operation_result(true, ACTION_DEPOSIT, sanitized_amount, reason)


func withdraw(amount: int) -> Dictionary:
	var sanitized_amount := maxi(0, amount)
	if sanitized_amount <= 0:
		return _build_operation_result(false, ACTION_WITHDRAW, sanitized_amount, "amount_must_be_positive")
	var withdrawable := get_withdrawable_principal()
	if sanitized_amount > withdrawable:
		return _build_operation_result(false, ACTION_WITHDRAW, sanitized_amount, "amount_exceeds_principal_or_locked")
	principal -= sanitized_amount
	last_action_wave_number = current_wave_number
	if not _apply_gold_delta(sanitized_amount, "finance_withdraw"):
		principal += sanitized_amount
		return _build_operation_result(false, ACTION_WITHDRAW, sanitized_amount, "gold_delta_failed")
	_emit_changed()
	return _build_operation_result(true, ACTION_WITHDRAW, sanitized_amount, "manual")


func settle_interest(source: String = SETTLE_WAVE_END) -> Dictionary:
	var result := _build_settlement_result(source)
	if principal <= 0:
		result["reason"] = "no_principal"
		result["principal_after"] = principal
		last_settlement_result = result.duplicate(true)
		interest_settled.emit(result.duplicate(true))
		_emit_changed()
		return result
	if _is_blocked_by_high_yield_contract(source):
		result["blocked"] = true
		result["reason"] = "high_yield_requires_wave_start_deposit"
		result["principal_after"] = principal
		last_settlement_result = result.duplicate(true)
		interest_settled.emit(result.duplicate(true))
		_emit_changed()
		return result

	var base_gain := _calculate_gain_for_source(source)
	var final_gain := _apply_interest_gain_relics(base_gain, source, result)
	result["success"] = true
	result["gain"] = final_gain
	if final_gain <= 0:
		result["reason"] = "zero_interest_gain"
	else:
		principal += final_gain
		result["reason"] = "interest_collected"
		_apply_after_successful_interest_relics()
	_apply_after_interest_settlement_relics()
	result["principal_after"] = principal
	result["interest_rate_after"] = get_interest_rate()
	last_settlement_result = result.duplicate(true)
	interest_settled.emit(result.duplicate(true))
	_emit_changed()
	return result


func process_wave_end_settlements() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(settle_interest(SETTLE_WAVE_END))
	var periodic_count := _get_relic_count("relic_periodic_dividend_clock")
	if periodic_count > 0 and wave_counter % 3 == 0:
		for _index in range(periodic_count):
			results.append(settle_interest(SETTLE_PERIODIC))
	last_settlement_results.clear()
	for result in results:
		last_settlement_results.append(result.duplicate(true))
	_emit_changed()
	return results


func trigger_manual_interest(source: String = SETTLE_MANUAL) -> Dictionary:
	return settle_interest(source)


func on_relic_added(relic_id: String) -> void:
	match relic_id:
		"relic_dividend_check":
			trigger_manual_interest("dividend_check")
		"relic_fixed_deposit_certificate":
			var bonus_principal := 50 * maxi(1, current_wave_number)
			principal += bonus_principal
			_emit_changed()
		_:
			_emit_changed()


func add_interest_rate_bonus(amount: float, reason: String = "") -> void:
	interest_rate_bonus += amount
	_emit_changed()


func get_interest_rate() -> float:
	var base_rate := DEFAULT_INTEREST_RATE
	if player != null:
		base_rate = player.get_stat("interest_rate", DEFAULT_INTEREST_RATE)
	return StatDefinitions.clamp_stat_value("interest_rate", base_rate + interest_rate_bonus)


func get_estimated_interest() -> int:
	return StatDefinitions.calculate_finance_interest_gain(principal, get_interest_rate())


func get_current_gold() -> int:
	if _gold_getter.is_valid():
		return maxi(0, int(_gold_getter.call()))
	return 0


func get_withdrawable_principal() -> int:
	if current_wave_number <= locked_until_wave_number:
		return 0
	return principal


func get_state_snapshot() -> Dictionary:
	return {
		"principal": principal,
		"interest_rate": get_interest_rate(),
		"interest_rate_bonus": interest_rate_bonus,
		"estimated_interest": get_estimated_interest(),
		"wave_counter": wave_counter,
		"current_wave_number": current_wave_number,
		"last_action_wave_number": last_action_wave_number,
		"last_deposit_wave_number": last_deposit_wave_number,
		"locked_until_wave_number": locked_until_wave_number,
		"withdrawable_principal": get_withdrawable_principal(),
		"has_deposited_before_current_wave": has_deposited_before_current_wave,
		"last_settlement_result": last_settlement_result.duplicate(true),
		"last_settlement_results": _duplicate_result_array(last_settlement_results),
	}


func _apply_wave_start_relics() -> void:
	var piggy_count := _get_relic_count("relic_piggy_bank")
	if piggy_count > 0:
		deposit(10 * piggy_count, true, "piggy_bank")
	var bank_printer_count := _get_relic_count("relic_goblin_central_bank_printer")
	if bank_printer_count > 0:
		deposit(int(ceil(float(get_current_gold()) * 0.10)) * bank_printer_count, true, "goblin_central_bank_printer")
	var brass_printer_count := _get_relic_count("relic_goblin_coin_printer")
	if brass_printer_count > 0:
		deposit(int(ceil(float(get_current_gold()) * 0.10)) * brass_printer_count, true, "goblin_coin_printer")


func _apply_interest_gain_relics(base_gain: int, source: String, result: Dictionary) -> int:
	var final_gain := base_gain
	if _has_relic("relic_speculative_chip"):
		var roll := _rng.randf()
		result["speculative_chip_roll"] = roll
		if roll <= 0.55:
			final_gain *= 2
			result["speculative_chip_outcome"] = "double"
		else:
			final_gain = 0
			result["speculative_chip_outcome"] = "zero"
	return maxi(0, final_gain)


func _is_blocked_by_high_yield_contract(source: String) -> bool:
	if not _has_relic("relic_high_yield_contract") or has_deposited_before_current_wave:
		return false
	return source == SETTLE_WAVE_END or source == SETTLE_PERIODIC


func _apply_after_successful_interest_relics() -> void:
	var compounding_count := _get_relic_count("relic_compound_interest_tome")
	if compounding_count > 0:
		interest_rate_bonus += 0.2 * float(compounding_count)


func _apply_after_interest_settlement_relics() -> void:
	var printer_count := _get_relic_count("relic_goblin_coin_printer")
	if printer_count > 0:
		interest_rate_bonus += 0.3 * float(printer_count)


func _calculate_gain_for_source(source: String) -> int:
	if source == SETTLE_ANNUITY:
		return int(ceil(float(principal) * 0.001))
	return StatDefinitions.calculate_finance_interest_gain(principal, get_interest_rate())


func _build_settlement_result(source: String) -> Dictionary:
	return {
		"success": false,
		"blocked": false,
		"source": source,
		"wave_number": current_wave_number,
		"principal_before": principal,
		"interest_rate": get_interest_rate(),
		"base_gain": _calculate_gain_for_source(source),
		"gain": 0,
		"principal_after": principal,
		"reason": "",
	}


func _build_operation_result(success: bool, action: String, amount: int, reason: String) -> Dictionary:
	return {
		"success": success,
		"action": action,
		"amount": amount,
		"reason": reason,
		"wave_number": current_wave_number,
		"gold": get_current_gold(),
		"principal": principal,
		"interest_rate": get_interest_rate(),
		"withdrawable_principal": get_withdrawable_principal(),
	}


func _duplicate_result_array(results: Array[Dictionary]) -> Array[Dictionary]:
	var duplicated_results: Array[Dictionary] = []
	for result in results:
		duplicated_results.append(result.duplicate(true))
	return duplicated_results


func _apply_gold_delta(delta: int, reason: String) -> bool:
	if not _gold_delta_applier.is_valid():
		return false
	return bool(_gold_delta_applier.call(delta, reason))


func _emit_changed() -> void:
	finance_changed.emit(get_state_snapshot())


func _get_relic_count(relic_id: String) -> int:
	if player == null or not player.has_method("get_relic_count"):
		return 0
	return int(player.get_relic_count(relic_id))


func _has_relic(relic_id: String) -> bool:
	return _get_relic_count(relic_id) > 0
