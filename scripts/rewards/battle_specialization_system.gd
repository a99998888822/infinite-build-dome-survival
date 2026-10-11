extends RefCounted
class_name BattleSpecializationSystem
## Run-owned quotes. A private RNG keeps these offers independent of other trades.

const CONFIG_PATH := "res://data_config/battle_specializations.json"
var config: Dictionary = {}
var offer: Dictionary = {}
var purchase_count := 0
var prepared_wave := -1
var decided_wave := -1
var history: Array[Dictionary] = []
var _run_serial := 0
var _purchasing := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary: config = parsed
	else: push_error("Invalid battle specialization config: " + CONFIG_PATH)
	_rng.randomize()


func reset() -> void:
	_run_serial += 1
	purchase_count = 0
	prepared_wave = -1
	decided_wave = -1
	offer.clear()
	history.clear()
	_purchasing = false
	_rng.randomize()


func prepare(wave: int, principal: int, has_next_wave: bool) -> void:
	if _purchasing or wave < prepared_wave: return
	if wave != prepared_wave:
		prepared_wave = wave
		offer.clear()
	if not has_next_wave or decided_wave == wave or purchase_count >= config.prices.size(): return
	var price := int(config.prices[purchase_count])
	# A later deposit may qualify once. A failed roll remains failed this wave.
	if principal < maxi(int(config.minimum_principal), price): return
	decided_wave = wave
	if _rng.randf() >= float(config.offer_chance): return
	var candidates: Array[Dictionary] = []
	for choice: Dictionary in config.choices:
		if wave >= int(choice.minimum_wave): candidates.append(choice.duplicate(true))
	var choices: Array[Dictionary] = []
	while not candidates.is_empty() and choices.size() < int(config.choice_count):
		choices.append(candidates.pop_at(_rng.randi_range(0, candidates.size() - 1)))
	if choices.is_empty(): return
	offer = {"token": "%d:%d:%d:%d" % [get_instance_id(), _run_serial, wave, purchase_count],
		"wave": wave, "price": price, "purchase_index": purchase_count, "choices": choices,
		"purchased": false, "selected_id": ""}


func purchase(token: String, choice_id: String, finance: BattleFinanceSystem) -> Dictionary:
	if _purchasing: return {"success": false, "reason": "transaction_busy"}
	if offer.is_empty() or token != str(offer.token) or int(offer.wave) != finance.current_wave_number or finance._started_wave_number >= int(offer.wave):
		return {"success": false, "reason": "specialization_expired"}
	if bool(offer.purchased) or purchase_count >= config.prices.size():
		return {"success": false, "reason": "already_purchased"}
	var choice: Dictionary = {}
	for candidate: Dictionary in offer.choices:
		if str(candidate.id) == choice_id: choice = candidate
	if choice.is_empty() or int(choice.minimum_wave) > int(offer.wave):
		return {"success": false, "reason": "specialization_expired"}
	var price := int(offer.price)
	if int(offer.purchase_index) != purchase_count or price != int(config.prices[purchase_count]):
		return {"success": false, "reason": "specialization_expired"}
	if finance.principal < price: return {"success": false, "reason": "insufficient_principal"}
	var player := finance.player
	if not is_instance_valid(player) or not player.is_alive(): return {"success": false, "reason": "specialization_expired"}
	_purchasing = true
	var source := "purchase_%d" % purchase_count
	# Stage the complete group before charging; suppress intermediate stat callbacks.
	player.begin_modifier_update()
	for stat: String in choice.stats:
		var applied := player.add_runtime_modifier({"id": "specialization_%s_%s" % [source, stat],
			"source_type": "battle_specialization", "source_id": source, "target_scope": "player",
			"stat": stat, "operation": Modifier.OPERATION_ADD_FLAT, "value": float(choice.stats[stat]),
			"duration": Modifier.PERMANENT_DURATION, "stack_rule": Modifier.STACK_RULE_UNIQUE})
		if not applied:
			player.remove_runtime_modifiers_by_source("battle_specialization", source)
			player.end_modifier_update()
			_purchasing = false
			return {"success": false, "reason": "specialization_effect_blocked"}
	# Reserve before finance or journal callbacks can reenter the purchase.
	offer.purchased = true
	offer.selected_id = choice_id
	purchase_count += 1
	if not finance.consume_specialization_principal(price):
		offer.purchased = false
		offer.selected_id = ""
		purchase_count -= 1
		player.remove_runtime_modifiers_by_source("battle_specialization", source)
		player.end_modifier_update()
		_purchasing = false
		return {"success": false, "reason": "transaction_busy"}
	var result := {"success": true, "token": token, "choice_id": choice_id, "name_key": str(choice.name_key),
		"price": price, "principal": finance.principal, "wave": int(offer.wave), "purchase_count": purchase_count}
	history.append(result.duplicate(true))
	player.end_modifier_update()
	finance.record_specialization_activity(L10n.message("log.finance.specialization_purchased", [str(choice.name_key), price, finance.principal]))
	_purchasing = false
	return result


func snapshot() -> Dictionary:
	return {"purchase_count": purchase_count, "prepared_wave": prepared_wave, "decided_wave": decided_wave,
		"offer": offer.duplicate(true), "history": history.duplicate(true)}
