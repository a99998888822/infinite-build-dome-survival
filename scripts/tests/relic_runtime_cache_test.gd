extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func compare_uncached(player: PlayerController, context: String) -> void:
	var actual := {}
	for stat in StatDefinitions.get_all_stat_ids(): actual[stat] = player.get_stat(stat)
	player.modifier_stack.cache_enabled = false
	var equal := true
	for stat in actual: equal = equal and is_equal_approx(actual[stat], player.get_stat(stat))
	player.modifier_stack.cache_enabled = true
	check(equal, "cached player stats equal uncached resolution: " + context)

func _run() -> void:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	check(player.modifier_stack.cache_enabled, "live player enables stat caching")
	var bank := BattleFinanceSystem.new()
	var wallet := {"gold": 5000}
	bank.initialize(player, func(): return wallet.gold, func(delta, _reason): wallet.gold += delta; return true)
	player.relic_added.connect(bank.on_relic_added)
	bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_DERIVED)
	player.add_relic("relic_coin_heart")
	check(not bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_DERIVED).is_empty(), "finance cache sees newly acquired derived effect")
	bank.deposit(1000, true)
	compare_uncached(player, "deposit and principal-derived maximum HP")
	var maximum := player.get_stat("max_hp")
	bank.withdraw(500)
	check(player.get_stat("max_hp") == maximum - 5, "withdrawal changes warmed maximum HP immediately")
	compare_uncached(player, "withdrawal")
	player.add_relic("relic_reincarnation_hellfire_candle")
	check(player._is_stat_increase_blocked("humanity"), "new blocker enters cached index")
	var effects := player.get_active_relic_runtime_effects()
	for effect in effects: effect.clear()
	check(player._is_stat_increase_blocked("humanity") and player.get_active_relic_runtime_effects().any(func(effect): return not effect.is_empty()), "external effect snapshot mutation cannot corrupt cache")
	var preview := player.create_stat_preview_copy()
	check(preview._is_stat_increase_blocked("humanity"), "detached preview rebuilds its own blocker index")
	preview.relic_system.remove_relic("relic_reincarnation_hellfire_candle")
	check(not preview._is_stat_increase_blocked("humanity") and player._is_stat_increase_blocked("humanity"), "preview removal invalidates only its own cache")
	preview.free()
	player.relic_system.remove_relic("relic_reincarnation_hellfire_candle")
	check(not player._is_stat_increase_blocked("humanity"), "selling blocker permits stat growth again")
	player.relic_system.remove_relic("relic_coin_heart")
	check(bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_DERIVED).is_empty(), "finance cache drops sold effect")
	compare_uncached(player, "relic removal")
	player.add_relic("relic_piggy_bank")
	bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_WAVE_START)
	player.add_relic("relic_piggy_bank")
	var stacked := bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_WAVE_START)
	check(stacked.size() == 1 and stacked[0].relic_count == 2, "duplicate acquisition invalidates cached stack counts")
	stacked[0].relic_count = 99
	check(bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_WAVE_START)[0].relic_count == 2, "finance snapshots cannot mutate cached counts")
	player.relic_system.remove_relic("relic_piggy_bank")
	check(bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_WAVE_START)[0].relic_count == 1, "selling one stack refreshes cached counts")
	var base_armor := player.get_stat("armor")
	player.add_runtime_modifier({"id":"cache_expiry", "source_type":"test", "source_id":"cache", "target_scope":"player", "stat":"armor", "operation":"add_flat", "value":20, "duration":0.1, "stack_rule":"unique"})
	check(player.get_stat("armor") == base_armor + 20, "temporary buff replaces warmed stat")
	player.get_stat("damage_taken_percent")
	player.modifier_stack.tick(0.2)
	check(player.get_stat("armor") == base_armor, "expiry invalidates warmed stat")
	compare_uncached(player, "temporary armor expiry and dependent damage reduction")
	player.add_relic("relic_coin_heart")
	bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_DERIVED)
	player.relic_system.clear()
	check(bank._collect_runtime_effects(BattleFinanceSystem.TRIGGER_DERIVED).is_empty() and player.get_active_relic_runtime_effects().is_empty(), "clear invalidates both runtime and finance caches")
	player.free()
	print("RELIC_RUNTIME_CACHE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(failures)
