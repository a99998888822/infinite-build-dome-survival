extends RefCounted
class_name GoblinTradeSystem
## Run-owned offer state. Closing the presentation never revokes accepted effects.

const CONFIG_PATH := "res://data_config/goblin_trades.json"
var config: Dictionary = {}
var offer: Dictionary = {}
var preparation_wave := -1
var accepted_waves: Dictionary = {}
var strong_refresh := false
var single_slot_wave := -1
var _accepting := false
var interest_pact_count := 0
var interest_pact: bool:
	get: return interest_pact_count > 0
var interest_sanity_paid := 0
var customer_sanity_paid := 0
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
	single_slot_wave = -1
	_accepting = false
	interest_pact_count = 0
	interest_sanity_paid = 0
	customer_sanity_paid = 0
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
	var candidates: Array[Dictionary] = []
	var wave := int(context.get("wave", 0))
	if wave < 1 or not bool(context.get("has_next_wave", false)): return candidates
	var gold := int(context.get("gold", 0))
	var principal := int(context.get("principal", 0))
	var struggling := bool(context.get("struggling", false))
	for entry in config.trades:
		var id := str(entry.id)
		if bool(entry.get("once_per_run", false)) and accepted_waves.has(id): continue
		# Skip the configured number of preparation visits after acceptance.
		if accepted_waves.has(id) and wave - int(accepted_waves[id]) <= int(entry.get("cooldown_waves", 0)): continue
		var eligible := false
		match id:
			"strong_refresh": eligible = struggling and gold >= int(entry.minimum_gold) and not strong_refresh and bool(context.get("can_bank", true)) and bool(context.get("epic_available", true))
			"principal_advance": eligible = struggling
			"cash_price": eligible = struggling and principal >= int(entry.minimum_principal) and principal >= gold * float(entry.principal_gold_ratio)
			"interest_pact": eligible = float(context.get("sanity", 100)) >= float(entry.minimum_sanity)
			"spending_money": eligible = gold >= int(entry.minimum_gold) and principal <= gold * float(entry.maximum_principal_ratio) and bool(context.get("can_bank", true))
			"exclusive_relic": eligible = bool(context.get("high_pressure", false)) and gold >= maxf(float(entry.minimum_gold), float(context.get("shelf_median", 0)) * float(entry.shelf_price_ratio)) and not context.get("epic_candidates", []).is_empty()
			"weapon_buyout": eligible = wave >= int(entry.minimum_completed_waves) and bool(context.get("comfortable", false)) and gold < wave * int(entry.gold_per_completed_wave) and principal < int(entry.principal_below) and not context.get("weapon_quotes", []).is_empty()
			"sanity_buyback": eligible = float(context.get("sanity", 100)) <= float(entry.maximum_sanity) and principal >= int(entry.minimum_principal) and float(context.get("interest_loss", 0)) >= float(entry.minimum_interest_loss) and not context.get("sanity_quote", {}).is_empty()
			"preferred_customer": eligible = bool(context.get("high_pressure", false)) and gold >= maxf(float(entry.minimum_gold), float(context.get("shelf_median", 0)) * float(entry.shelf_price_ratio)) and principal >= int(entry.minimum_principal) and float(context.get("sanity", 100)) >= float(entry.minimum_sanity) and int(context.get("remaining_waves", 0)) >= int(entry.minimum_remaining_waves)
			"capital_protection": eligible = bool(context.get("high_pressure", false)) and principal >= int(entry.minimum_principal) and (float(context.get("minimum_health_ratio", 1)) <= float(entry.maximum_minimum_health_ratio) or float(context.get("low_health_seconds", 0)) >= float(entry.minimum_low_health_seconds))
		if not eligible: continue
		var candidate: Dictionary = entry.duplicate(true)
		candidates.append(candidate)
	return candidates


func prepare(context: Dictionary) -> void:
	var wave := int(context.get("wave", 0))
	if wave <= preparation_wave: return
	preparation_wave = wave
	offer.clear()
	var candidates := eligible_offers(context)
	if candidates.is_empty(): return
	# Every eligible offer shares one uniform pool; reopening never rerolls it.
	offer = candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	var amounts := reward_amounts(wave, int(context.get("earned", 0)))
	var amount := 0
	var args: Array = []
	match str(offer.id):
		"strong_refresh": amount = int(context.gold)
		"principal_advance": amount = int(amounts.principal)
		"cash_price": amount = int(amounts.gold)
		"spending_money": amount = int(offer.gold_reward)
		"preferred_customer": offer["minimum_offer_gold"] = ceili(maxf(float(offer.minimum_gold), float(context.get("shelf_median", 0)) * float(offer.shelf_price_ratio)))
		"exclusive_relic":
			var pool: Array = context.epic_candidates
			offer["relic"] = pool[_rng.randi_range(0, pool.size() - 1)].duplicate(true)
		"weapon_buyout":
			var quotes: Array = context.weapon_quotes
			offer.merge(quotes[_rng.randi_range(0, quotes.size() - 1)], true)
			amount = int(offer.amount)
			args = [amount, str(offer.weapon_name)]
		"sanity_buyback":
			offer["sanity_quote"] = context.sanity_quote.duplicate(true)
			args = [HumanityEconomy.number(float(context.sanity_quote.gain)), int(context.sanity_quote.cost)]
	if args.is_empty() and amount > 0: args = [amount]
	offer["amount"] = amount
	offer["token"] = "%d:%s" % [wave, str(offer.id)]
	offer["body_message"] = L10n.message(L10n.key_for_source(str(offer.body)), args)
	if not args.is_empty(): offer.body = str(offer.body) % args
	if str(offer.id) == "capital_protection":
		var replacements := {"单价": int(offer.principal_per_damage)}
		offer.body_message["message_replacements"] = replacements
		offer.body = str(offer.body).format(replacements)


func cancel() -> void:
	offer.clear()


func accept(token: String, player: PlayerController, finance: BattleFinanceSystem, loadout: WeaponLoadout = null) -> Dictionary:
	if _accepting or offer.is_empty() or token != str(offer.token): return {"success": false, "reason": "trade_expired"}
	_accepting = true
	var result := _accept_locked(player, finance, loadout)
	_accepting = false
	return result


func _accept_locked(player: PlayerController, finance: BattleFinanceSystem, loadout: WeaponLoadout) -> Dictionary:
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
		"exclusive_relic":
			var relic_id := str(accepted.relic.target_id)
			var relic := DataRegistry.get_record("relics", relic_id)
			var limit := int(relic.get("max_stack", 0))
			if relic.is_empty() or str(relic.get("rarity", "")) != "epic" or (limit > 0 and player.get_relic_count(relic_id) >= limit): return {"success": false, "reason": "trade_expired"}
			if not player.add_relic(relic_id): return {"success": false, "reason": "transaction_failed"}
			single_slot_wave = preparation_wave
		"weapon_buyout":
			if not GoblinSpecialTrades.accept_weapon(accepted, player, finance, loadout): return {"success": false, "reason": "trade_expired"}
		"sanity_buyback":
			if not GoblinSpecialTrades.accept_sanity(accepted, player, finance): return {"success": false, "reason": "trade_expired"}
		"preferred_customer":
			if accepted_waves.has(id) or finance.get_current_gold() < int(accepted.minimum_offer_gold) or finance.principal < int(accepted.minimum_principal) or player.get_stat("humanity") < float(accepted.minimum_sanity): return {"success": false, "reason": "trade_expired"}
			apply_stat(player, id, "shop_price_percent", float(accepted.discount_percent))
		"capital_protection":
			if finance.principal < int(accepted.minimum_principal): return {"success": false, "reason": "trade_expired"}
			finance.arm_capital_protection(preparation_wave + 1, float(accepted.damage_reduction), int(accepted.principal_per_damage))
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


func record_paid_purchase(player: PlayerController) -> void:
	if not accepted_waves.has("preferred_customer"): return
	customer_sanity_paid += int(definition("preferred_customer").sanity_per_purchase)
	apply_stat(player, "preferred_customer", "humanity", -customer_sanity_paid)


static func apply_stat(player: PlayerController, source: String, stat: String, value: float) -> void:
	player.add_runtime_modifier({"id": "goblin_%s_%s" % [source, stat], "source_type": "goblin_trade", "source_id": source,
		"target_scope": "player", "stat": stat, "operation": Modifier.OPERATION_ADD_FLAT, "value": value,
		"duration": Modifier.PERMANENT_DURATION, "stack_rule": Modifier.STACK_RULE_REPLACE_SAME_SOURCE})
