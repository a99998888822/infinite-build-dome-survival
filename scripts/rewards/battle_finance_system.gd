extends RefCounted
class_name BattleFinanceSystem

signal finance_changed(snapshot: Dictionary)
signal interest_settled(result: Dictionary)

const DEFAULT_INTEREST_RATE: float = 5.0
const MAX_ANNUITY_ACCUMULATED: float = 2.0
const ACTION_NONE: String = "none"
const ACTION_DEPOSIT: String = "deposit"
const ACTION_WITHDRAW: String = "withdraw"
const SETTLE_WAVE_END: String = "wave_end"
const SETTLE_MANUAL: String = "manual"
const SETTLE_PERIODIC: String = "periodic"
const SETTLE_ANNUITY: String = "annuity"

const TRIGGER_WAVE_START: String = "wave_start"
const TRIGGER_ON_ACQUIRE: String = "on_acquire"
const TRIGGER_DEPOSIT: String = "deposit"
const TRIGGER_WAVE_END: String = "wave_end"
const TRIGGER_INTEREST_SETTLE: String = "interest_settle"
const TRIGGER_INTEREST_SUCCESS: String = "interest_success"
const TRIGGER_COMBAT_TICK: String = "combat_tick"

const EFFECT_ADD_PRINCIPAL_FLAT: String = "add_principal_flat"
const EFFECT_ADD_PRINCIPAL_FROM_GOLD_PERCENT: String = "add_principal_from_gold_percent"
const EFFECT_ADD_PRINCIPAL_PER_WAVE: String = "add_principal_per_wave"
const EFFECT_LOCK_PRINCIPAL_FOR_WAVES: String = "lock_principal_for_waves"
const EFFECT_SETTLE_INTEREST_ONCE: String = "settle_interest_once"
const EFFECT_SPECULATIVE_INTEREST: String = "speculative_interest"
const EFFECT_ADD_INTEREST_RATE_BONUS: String = "add_interest_rate_bonus"
const EFFECT_SETTLE_INTEREST_EVERY_N_WAVES: String = "settle_interest_every_n_waves"
const EFFECT_REQUIRE_WAVE_START_DEPOSIT: String = "require_wave_start_deposit_for_interest"
const EFFECT_PER_SECOND_INTEREST: String = "per_second_interest"

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
	if player == null or principal <= 0:
		return
	var combat_effects := _collect_runtime_effects(TRIGGER_COMBAT_TICK)
	if combat_effects.is_empty():
		return
	annuity_timer = minf(annuity_timer + maxf(delta, 0.0), MAX_ANNUITY_ACCUMULATED)
	while annuity_timer >= 1.0:
		annuity_timer -= 1.0
		_trigger_combat_tick(combat_effects)


func _trigger_combat_tick(combat_effects: Array[Dictionary]) -> void:
	for effect in combat_effects:
		match str(effect.get("effect", "")):
			EFFECT_PER_SECOND_INTEREST:
				for _index in range(int(effect.get("relic_count", 1))):
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
		"has_high_yield_contract": _has_wave_end_deposit_requirement(),
		"requires_deposit_for_interest": _has_wave_end_deposit_requirement(),
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
	if reason == "manual":
		_apply_deposit_trigger_effects()
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
		_apply_after_successful_interest_relics(source)
	_apply_after_interest_settlement_relics(source)
	result["principal_after"] = principal
	result["interest_rate_after"] = get_interest_rate()
	last_settlement_result = result.duplicate(true)
	interest_settled.emit(result.duplicate(true))
	_emit_changed()
	return result


func process_wave_end_settlements() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(settle_interest(SETTLE_WAVE_END))
	for effect in _collect_runtime_effects(TRIGGER_WAVE_END):
		match str(effect.get("effect", "")):
			EFFECT_SETTLE_INTEREST_EVERY_N_WAVES:
				var interval := int(effect.get("interval_waves", 3))
				if interval > 0 and wave_counter % interval == 0:
					for _index in range(int(effect.get("relic_count", 1))):
						results.append(settle_interest(SETTLE_PERIODIC))
	last_settlement_results.clear()
	for result in results:
		last_settlement_results.append(result.duplicate(true))
	_emit_changed()
	return results


func trigger_manual_interest(source: String = SETTLE_MANUAL) -> Dictionary:
	return settle_interest(source)


func on_relic_added(relic_id: String) -> void:
	var handled := false
	for effect in _get_relic_runtime_effects(relic_id, TRIGGER_ON_ACQUIRE):
		match str(effect.get("effect", "")):
			EFFECT_SETTLE_INTEREST_ONCE:
				trigger_manual_interest(relic_id)
				handled = true
			EFFECT_ADD_PRINCIPAL_PER_WAVE:
				principal += int(effect.get("value_per_wave", 0)) * maxi(1, current_wave_number)
				handled = true
				_emit_changed()
	if not handled:
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
	if player == null:
		return
	for relic_id in player.get_relic_ids():
		var relic_count := player.get_relic_count(relic_id)
		if relic_count <= 0:
			continue
		for effect in _get_relic_runtime_effects(relic_id, TRIGGER_WAVE_START):
			match str(effect.get("effect", "")):
				EFFECT_ADD_PRINCIPAL_FLAT:
					deposit(int(effect.get("value", 0)) * relic_count, true, relic_id)
				EFFECT_ADD_PRINCIPAL_FROM_GOLD_PERCENT:
					var bonus_principal := int(ceil(float(get_current_gold()) * float(effect.get("value_percent", 0)) / 100.0))
					deposit(bonus_principal * relic_count, true, relic_id)


func _apply_deposit_trigger_effects() -> void:
	for effect in _collect_runtime_effects(TRIGGER_DEPOSIT):
		match str(effect.get("effect", "")):
			EFFECT_LOCK_PRINCIPAL_FOR_WAVES:
				var lock_waves := int(effect.get("waves", 1))
				locked_until_wave_number = maxi(locked_until_wave_number, current_wave_number + maxi(0, lock_waves - 1))


func _apply_interest_gain_relics(base_gain: int, source: String, result: Dictionary) -> int:
	var final_gain := base_gain
	for effect in _collect_runtime_effects(TRIGGER_INTEREST_SETTLE):
		match str(effect.get("effect", "")):
			EFFECT_SPECULATIVE_INTEREST:
				var double_chance := float(effect.get("double_chance_percent", 55)) / 100.0
				var roll := _rng.randf()
				result["speculative_chip_roll"] = roll
				if roll <= double_chance:
					final_gain *= 2
					result["speculative_chip_outcome"] = "double"
				else:
					final_gain = 0
					result["speculative_chip_outcome"] = "zero"
	return maxi(0, final_gain)


func _is_blocked_by_high_yield_contract(source: String) -> bool:
	if not _has_wave_end_deposit_requirement() or has_deposited_before_current_wave:
		return false
	return source == SETTLE_WAVE_END or source == SETTLE_PERIODIC


func _apply_after_successful_interest_relics(source: String) -> void:
	if not _is_wave_end_settlement_source(source):
		return
	for effect in _collect_runtime_effects(TRIGGER_INTEREST_SUCCESS):
		match str(effect.get("effect", "")):
			EFFECT_ADD_INTEREST_RATE_BONUS:
				interest_rate_bonus += float(effect.get("value", 0.0)) * float(effect.get("relic_count", 1))


func _apply_after_interest_settlement_relics(source: String) -> void:
	if not _is_wave_end_settlement_source(source):
		return
	for effect in _collect_runtime_effects(TRIGGER_INTEREST_SETTLE):
		match str(effect.get("effect", "")):
			EFFECT_ADD_INTEREST_RATE_BONUS:
				interest_rate_bonus += float(effect.get("value", 0.0)) * float(effect.get("relic_count", 1))


func _calculate_gain_for_source(source: String) -> int:
	if source == SETTLE_ANNUITY:
		var annuity_percent := 0.1
		for effect in _collect_runtime_effects(TRIGGER_COMBAT_TICK):
			if str(effect.get("effect", "")) == EFFECT_PER_SECOND_INTEREST:
				annuity_percent = float(effect.get("principal_percent", annuity_percent))
				break
		return int(ceil(float(principal) * annuity_percent / 100.0))
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


func _get_relic_runtime_effects(relic_id: String, trigger: String = "") -> Array[Dictionary]:
	var relic_data := DataRegistry.get_record("relics", relic_id)
	if relic_data.is_empty():
		return []
	var result: Array[Dictionary] = []
	var effects: Variant = relic_data.get("runtime_effects", [])
	if not (effects is Array):
		return result
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_data: Dictionary = effect
		if not trigger.is_empty() and str(effect_data.get("trigger", "")) != trigger:
			continue
		result.append(effect_data.duplicate(true))
	return result


func _collect_runtime_effects(trigger: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player == null:
		return result
	for relic_id in player.get_relic_ids():
		var relic_count := player.get_relic_count(relic_id)
		if relic_count <= 0:
			continue
		for effect in _get_relic_runtime_effects(relic_id, trigger):
			var entry := effect.duplicate(true)
			entry["relic_id"] = relic_id
			entry["relic_count"] = relic_count
			result.append(entry)
	return result


func _is_wave_end_settlement_source(source: String) -> bool:
	return source == SETTLE_WAVE_END or source == SETTLE_PERIODIC


func _has_wave_end_deposit_requirement() -> bool:
	if player == null:
		return false
	for relic_id in player.get_relic_ids():
		if player.get_relic_count(relic_id) <= 0:
			continue
		for effect in _get_relic_runtime_effects(relic_id, TRIGGER_WAVE_END):
			if str(effect.get("effect", "")) == EFFECT_REQUIRE_WAVE_START_DEPOSIT:
				return true
	return false
