extends RefCounted
class_name GoblinTradeSystem
## Run-owned offer state. Closing the presentation never revokes accepted effects.

const CONFIG_PATH := "res://data_config/goblin_trades.json"
var config: Dictionary = {}
var offer: Dictionary = {}
var preparation_wave := -1
var accepted_waves: Dictionary = {}
var strong_refresh := false
var interest_pact_count := 0
var interest_pact: bool:
	get: return interest_pact_count > 0
var interest_sanity_paid := 0
var last_contract_wave := -1
var low_health_episodes := 0
var _health_armed := true
var _enemy_samples: Array[Vector2] = []
var _sample_duration := 0.0
var pressure_snapshot: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		config = parsed
	else:
		push_error("Invalid goblin trade config: " + CONFIG_PATH)
	_rng.randomize()


func reset() -> void:
	offer.clear()
	preparation_wave = -1
	accepted_waves.clear()
	strong_refresh = false
	interest_pact_count = 0
	interest_sanity_paid = 0
	last_contract_wave = -1
	begin_combat()


func definition(id: String) -> Dictionary:
	for entry in config.get("trades", []):
		if str(entry.id) == id: return entry
	return {}


func get_interest_pact_terms() -> Dictionary:
	var entry := definition("interest_pact")
	return {"count": interest_pact_count, "interest_bonus": interest_pact_count * float(entry.interest_bonus),
		"sanity_per_wave": interest_pact_count * int(entry.sanity_per_wave)}


func reward_amounts(wave: int, earned: int) -> Dictionary:
	var r: Dictionary = config.rewards
	var step := int(r.round_to)
	var amount := minf(float(r.principal_base) + float(r.principal_per_wave) * maxi(1, wave) + float(r.income_ratio) * maxi(0, earned), float(r.cap_base) + float(r.cap_per_wave) * maxi(1, wave))
	var principal := floori(amount / step) * step
	var cash := floori(maxf(float(r.cash_minimum), principal * float(r.cash_ratio)) / step) * step
	return {"principal": principal, "gold": cash}


func begin_combat() -> void:
	low_health_episodes = 0
	_health_armed = true
	_enemy_samples.clear()
	_sample_duration = 0.0
	pressure_snapshot.clear()


func record_health(hp: int, maximum: int, _shield: int = 0) -> void:
	if maximum > 0 and float(hp) / maximum >= float(config.pressure.rearm_health_ratio):
		_health_armed = true


func record_damage(before: int, after: int, maximum: int) -> void:
	if maximum <= 0: return
	if _health_armed and float(before) / maximum >= 0.5 and float(after) / maximum < 0.5:
		low_health_episodes += 1
		_health_armed = false


func sample_enemies(delta: float, count: int) -> void:
	if delta <= 0: return
	_enemy_samples.append(Vector2(delta, maxi(0, count)))
	_sample_duration += delta
	var excess := _sample_duration - float(config.pressure.window_seconds)
	while excess > 0.00001 and not _enemy_samples.is_empty():
		var removed := minf(excess, _enemy_samples[0].x)
		_enemy_samples[0].x -= removed
		_sample_duration -= removed
		excess -= removed
		if _enemy_samples[0].x <= 0.00001: _enemy_samples.pop_front()


func finish_combat(enemy_limit: int) -> Dictionary:
	var weighted := 0.0
	for sample in _enemy_samples: weighted += sample.x * sample.y
	var average := weighted / _sample_duration if _sample_duration > 0 else 0.0
	var threshold := maxi(int(config.pressure.enemy_minimum), ceili(enemy_limit * float(config.pressure.enemy_ratio)))
	# Wave challenges consume the original pressure flag. Broader trade eligibility
	# is recorded separately so this tuning only changes the banker's offers.
	var trade_rules: Dictionary = config.trade_pressure
	var trade_threshold := maxi(int(trade_rules.enemy_minimum), ceili(enemy_limit * float(trade_rules.enemy_ratio)))
	pressure_snapshot = {"remaining_average": average, "enemy_threshold": threshold, "low_health_episodes": low_health_episodes,
		"struggling": average >= threshold or low_health_episodes >= int(config.pressure.low_health_episodes),
		"trade_struggling": average >= trade_threshold or low_health_episodes >= int(trade_rules.low_health_episodes)}
	return pressure_snapshot.duplicate(true)


func eligible_offers(context: Dictionary) -> Array[Dictionary]:
	var crisis: Array[Dictionary] = []
	var ordinary: Array[Dictionary] = []
	var wave := int(context.get("wave", 0))
	if wave < 1 or not bool(context.get("has_next_wave", false)): return crisis
	var gold := int(context.get("gold", 0))
	var principal := int(context.get("principal", 0))
	var struggling := bool(context.get("struggling", false))
	for entry in config.trades:
		var id := str(entry.id)
		# A cooldown of three skips the next three preparation visits.
		if accepted_waves.has(id) and wave - int(accepted_waves[id]) <= int(entry.get("cooldown_waves", 0)): continue
		var eligible := false
		match id:
			"strong_refresh": eligible = struggling and gold >= int(entry.minimum_gold) and not strong_refresh and bool(context.get("can_bank", true)) and bool(context.get("epic_available", true))
			"principal_advance": eligible = struggling
			"cash_price": eligible = struggling and principal >= int(entry.minimum_principal) and principal >= gold * float(entry.principal_gold_ratio)
			"interest_pact": eligible = float(context.get("sanity", 100)) >= float(entry.minimum_sanity)
			"spending_money": eligible = gold >= int(entry.minimum_gold) and principal <= gold * float(entry.maximum_principal_ratio) and bool(context.get("can_bank", true))
		if not eligible: continue
		var candidate: Dictionary = entry.duplicate(true)
		if id == "principal_advance" and bool(context.get("principal_relic", false)):
			candidate.weight = int(entry.principal_relic_weight)
		if id in ["strong_refresh", "principal_advance", "cash_price"]: crisis.append(candidate)
		else: ordinary.append(candidate)
	return crisis if not crisis.is_empty() else ordinary


func prepare(context: Dictionary) -> void:
	var wave := int(context.get("wave", 0))
	if wave <= preparation_wave: return
	preparation_wave = wave
	offer.clear()
	var candidates := eligible_offers(context)
	var total := 0
	for candidate in candidates: total += int(candidate.weight)
	if total <= 0: return
	var roll := _rng.randi_range(1, total)
	for candidate in candidates:
		roll -= int(candidate.weight)
		if roll > 0: continue
		offer = candidate.duplicate(true)
		var amounts := reward_amounts(wave, int(context.get("earned", 0)))
		var amount := 0
		match str(offer.id):
			"strong_refresh": amount = int(context.gold)
			"principal_advance": amount = int(amounts.principal)
			"cash_price": amount = int(amounts.gold)
			"spending_money": amount = int(offer.gold_reward)
		offer["amount"] = amount
		offer["token"] = "%d:%s" % [wave, str(offer.id)]
		offer["body_message"] = L10n.message(L10n.key_for_source(str(offer.body)), [amount] if amount > 0 else [])
		if amount > 0: offer.body = str(offer.body) % amount
		break


func cancel() -> void:
	offer.clear()


func accept(token: String, player: PlayerController, finance: BattleFinanceSystem) -> Dictionary:
	if offer.is_empty() or token != str(offer.token): return {"success": false, "reason": "trade_expired"}
	var accepted := offer.duplicate(true)
	var id := str(accepted.id)
	var amount := int(accepted.amount)
	var result := {"success": true}
	match id:
		"strong_refresh":
			if strong_refresh or amount != finance.get_current_gold(): return {"success": false, "reason": "trade_expired"}
			result = finance.apply_finance_operation("deposit", amount)
			if bool(result.success): strong_refresh = true
		"principal_advance": result = finance.deposit(amount, true, "goblin_trade")
		"cash_price", "spending_money":
			if not finance.grant_trade_gold(amount): return {"success": false, "reason": "transaction_failed"}
			finance.trade_deposit_blocked = true
			if id == "cash_price":
				finance.trade_withdraw_blocked = true
				var times := int(accepted_waves.get("cash_price_count", 0)) + 1
				accepted_waves["cash_price_count"] = times
				player.begin_modifier_update()
				apply_stat(player, "cash_price", "humanity", -float(accepted.sanity_cost) * times)
				apply_stat(player, "cash_price", "luck", -float(accepted.luck_cost) * times)
				player.end_modifier_update()
		"interest_pact":
			interest_pact_count += 1
			apply_stat(player, id, "interest_rate", float(get_interest_pact_terms().interest_bonus))
	if not bool(result.get("success", false)): return result
	accepted_waves[id] = preparation_wave
	offer.clear()
	finance.record_trade_activity(accepted.get("body_message", str(accepted.body)))
	return {"success": true, "id": id, "amount": amount, "start_wave": id == "principal_advance"}


func settle_wave(wave: int, player: PlayerController, finance: BattleFinanceSystem) -> void:
	if not interest_pact or wave <= last_contract_wave or not player.is_alive(): return
	last_contract_wave = wave
	var cost := int(get_interest_pact_terms().sanity_per_wave)
	interest_sanity_paid += cost
	apply_stat(player, "interest_pact", "humanity", -interest_sanity_paid)
	finance.record_trade_activity(L10n.message("log.trade.sanity_cost", [cost, interest_sanity_paid]))


static func apply_stat(player: PlayerController, source: String, stat: String, value: float) -> void:
	player.add_runtime_modifier({"id": "goblin_%s_%s" % [source, stat], "source_type": "goblin_trade", "source_id": source,
		"target_scope": "player", "stat": stat, "operation": Modifier.OPERATION_ADD_FLAT, "value": value,
		"duration": Modifier.PERMANENT_DURATION, "stack_rule": Modifier.STACK_RULE_REPLACE_SAME_SOURCE})
