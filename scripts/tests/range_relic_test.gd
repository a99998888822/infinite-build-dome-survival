extends Node

var checks := 0
var failures := 0
const IDS := ["relic_old_brass_telescope", "relic_cracked_bronze_bell", "relic_long_focus_eyepiece", "relic_diffusion_nozzle", "relic_range_tripod", "relic_aftershock_hourglass", "relic_golden_rangefinder", "relic_abyssal_echo_shell", "relic_folded_star_chart", "relic_horizon_orrery"]
const STATIC := [
	{"area_size": 15, "ranged_damage": 1}, {"damage_area_size": 15, "element_damage": 1},
	{"area_size": 35, "ranged_damage": 3, "attack_speed": -8},
	{"damage_area_size": 30, "damage_percent": 15, "attack_speed": -6}, {"attack_speed": 12},
	{"damage_area_size": 20, "damage_percent": 12}, {},
	{"damage_area_size": 40, "element_damage": 8, "humanity": -15},
	{"area_size": 25, "damage_area_size": 25, "damage_percent": 20, "divinity": 5},
	{"area_size": 40, "damage_percent": 30, "damage_area_size": 20},
]

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func player() -> PlayerController:
	var p := PlayerController.new()
	p.auto_initialize_on_ready = false
	add_child(p)
	p.initialize_from_character("character_void_hunter")
	p.set_physics_process(false)
	return p

func bank_for(p: PlayerController) -> BattleFinanceSystem:
	var bank := BattleFinanceSystem.new()
	var wallet := {"value": 20000}
	bank.initialize(p, func(): return wallet.value, func(delta, _reason): wallet.value += delta; return true)
	p.relic_added.connect(bank.on_relic_added)
	return bank

func modify(p: PlayerController, stat: String, amount: float) -> void:
	p.add_runtime_modifier({"id": "test_" + stat, "source_type": "test", "source_id": "test", "target_scope": "player", "stat": stat, "operation": "add_flat", "value": amount, "duration": -1, "stack_rule": "replace_same_source"})

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	_test_catalog()
	_test_stationary()
	_test_wave_growth()
	_test_conversion()
	_test_rangefinder_cap()
	_test_bank_preview()
	_test_validation()
	await _test_tooltip_bounds()
	print("RANGE_RELIC_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_catalog() -> void:
	check(DataRegistry.get_load_errors().is_empty(), "catalog loads")
	var generator := ShopOfferGenerator.new()
	var pool := generator.build_shop_candidate_pool({})
	for i in IDS.size():
		var id: String = IDS[i]
		var p := player()
		var before := {}
		for stat in StatDefinitions.get_all_stat_ids(): before[stat] = p.get_stat(stat)
		check(pool.any(func(offer): return offer.get("target_id", "") == id), id + " in shop pool")
		check(ResourceLoader.exists(str(DataRegistry.get_record("relics", id).icon)), id + " imported icon")
		p.add_relic(id)
		for stat in STATIC[i]: check(is_equal_approx(p.get_stat(stat) - before[stat], STATIC[i][stat]), id + " " + stat)
		var cap := 3 if i < 2 else 1
		for n in range(1, cap): check(p.add_relic(id), id + " stack")
		check(not p.add_relic(id), id + " cap")
		check(generator.build_shop_candidate_pool({"owned_relic_counts": p.get_relic_counts()}).all(func(offer): return offer.get("target_id", "") != id), id + " capped offer removed")
		p.free()

func _test_stationary() -> void:
	var p := player()
	p._physics_process(20)
	p.add_relic("relic_range_tripod")
	check(p.get_stat("area_size") == 0, "acquiring tripod does not count earlier idle time")
	p._physics_process(0.99)
	check(p.get_stat("area_size") == 0, "tripod waits full second")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	p._physics_process(20)
	check(p.get_stat("area_size") == 0, "pause cannot charge tripod")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	p._physics_process(0.02)
	check(p.get_stat("area_size") == 40 and p.get_stat("damage_percent") == 20 and p.get_stat("attack_speed") == 12, "tripod activates after one combat second")
	var changes := [0]
	p.stats_changed.connect(func(): changes[0] += 1)
	for i in 120: p._physics_process(1.0 / 60.0)
	check(changes[0] == 0 and p.get_stat("area_size") == 40, "sustained idle does not rebuild or stack each frame")
	var preview := StatPreviewBuilder.build_offer_stat_preview({"offer_type": "relic", "target_id": "relic_horizon_orrery"}, p)
	check(preview.get("area_size") == 80 and preview.get("damage_area_size") == 40 and p.get_stat("area_size") == 40, "preview preserves charged tripod without mutating live stats")
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.pressed = true
	p._input(event)
	check(p.get_stat("area_size") == 0 and p.get_stat("damage_percent") == 0 and p.get_stat("attack_speed") == 12, "keyboard immediately cancels only conditional bonuses")
	modify(p, "move_speed", -p.get_stat("move_speed"))
	p._physics_process(5)
	check(p.get_stat("area_size") == 0, "blocked movement input cannot charge tripod")
	event.pressed = false
	p._input(event)
	p._physics_process(1)
	p.set_mobile_move_direction(Vector2.RIGHT)
	check(p.get_stat("area_size") == 0, "mobile input immediately cancels tripod")
	p.set_mobile_move_direction(Vector2.ZERO)
	p._physics_process(1)
	p.global_position += Vector2(10, 0)
	p._physics_process(0.01)
	check(p.get_stat("area_size") == 0, "external displacement resets tripod")
	p._physics_process(1)
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_END)
	check(p.get_stat("area_size") == 0, "wave end clears stance")
	p._physics_process(1)
	p.process_relic_runtime_trigger(BattleFinanceSystem.TRIGGER_WAVE_START)
	check(p.get_stat("area_size") == 0, "new wave starts uncharged")
	p._physics_process(1)
	p.take_damage(100000)
	check(not p.alive and p.get_stat("area_size") == 0, "death clears stance")
	p.initialize_from_character("character_void_hunter")
	p.add_relic("relic_range_tripod")
	check(p.get_stat("area_size") == 0, "new run starts uncharged")
	p.free()

func _test_wave_growth() -> void:
	var p := player()
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(p)
	manager.start_next_wave()
	manager.finish_current_wave()
	p.add_relic("relic_aftershock_hourglass")
	check(p.get_stat("damage_area_size") == 20, "hourglass has no retroactive wave growth")
	for i in 3:
		manager.start_next_wave()
		check(p.get_stat("damage_area_size") == 20 + i * 2, "wave start does not grow hourglass")
		manager.finish_current_wave()
		manager.finish_current_wave()
		check(p.get_stat("damage_area_size") == 22 + i * 2, "completed wave adds exactly two despite duplicate finish")
	var preview := p.create_stat_preview_copy()
	preview.add_relic("relic_cracked_bronze_bell")
	check(preview.get_stat("damage_area_size") == 41 and p.get_stat("damage_area_size") == 26, "preview includes earned wave growth without adding waves")
	preview.free()
	p.initialize_from_character("character_void_hunter")
	p.add_relic("relic_aftershock_hourglass")
	check(p.get_stat("damage_area_size") == 20, "new run clears permanent in-run growth")
	manager.free()
	p.free()

func _test_conversion() -> void:
	for reverse in [false, true]:
		var p := player()
		var bank := bank_for(p)
		var order := ["relic_horizon_orrery", "relic_golden_rangefinder", "relic_range_tripod"]
		if reverse: order.reverse()
		for id in order: p.add_relic(id)
		bank.deposit(99, true)
		check(p.get_stat("area_size") == 40 and p.get_stat("damage_area_size") == 20, "orrery includes its own range and ignores incomplete principal tier")
		bank.deposit(1, true)
		check(p.get_stat("area_size") == 43 and p.get_stat("damage_percent") == 33, "rangefinder full principal tier")
		bank.deposit(900, true)
		check(p.get_stat("area_size") == 70 and p.get_stat("damage_area_size") == 35, "principal range feeds orrery regardless of acquisition order")
		p._physics_process(1)
		check(p.get_stat("area_size") == 110 and p.get_stat("damage_area_size") == 55 and p.get_stat("damage_percent") == 80, "tripod and principal feed orrery together")
		bank.withdraw(901)
		check(p.get_stat("area_size") == 80 and p.get_stat("damage_area_size") == 40 and p.get_stat("damage_percent") == 50, "withdrawal revokes both principal bonuses and derived area immediately")
		p.set_mobile_move_direction(Vector2.RIGHT)
		check(p.get_stat("area_size") == 40 and p.get_stat("damage_area_size") == 20, "movement revokes tripod-derived area")
		modify(p, "area_size", -31)
		check(p.get_stat("area_size") == 9 and p.get_stat("damage_area_size") == 0, "orrery requires full ten points")
		modify(p, "area_size", -100)
		check(p.get_stat("area_size") == -60 and p.get_stat("damage_area_size") == 0, "negative range cannot subtract damage area")
		p.free()

func _test_rangefinder_cap() -> void:
	var p := player()
	var bank := bank_for(p)
	p.add_relic("relic_golden_rangefinder")
	for sample in [[0, 0], [99, 0], [100, 3], [999, 27], [1000, 30], [1100, 30], [100000000, 30]]:
		if sample[0] > bank.principal:
			bank.deposit(sample[0] - bank.principal, true)
		check(p.get_stat("area_size") == sample[1] and p.get_stat("damage_percent") == sample[1], "rangefinder caps both attributes at principal %d" % sample[0])
	var preview_player := p.create_stat_preview_copy()
	var preview_bank := bank.create_preview_copy(preview_player)
	preview_bank.withdraw(preview_bank.principal - 999)
	check(preview_player.get_stat("area_size") == 27 and preview_player.get_stat("damage_percent") == 27, "preview correctly drops below rangefinder cap")
	check(p.get_stat("area_size") == 30 and bank.principal == 100000000, "capped withdrawal preview preserves real state")
	preview_player.free()
	modify(p, "area_size", 20000)
	modify(p, "damage_percent", 200000)
	check(p.get_stat("area_size") == 20030 and p.get_stat("damage_percent") == 200030, "rangefinder cap does not clamp other sources beyond former global limits")
	for sample in [[1000, 30], [999, 27], [99, 0], [0, 0]]:
		bank.withdraw(bank.principal - sample[0])
		check(p.get_stat("area_size") == 20000 + sample[1] and p.get_stat("damage_percent") == 200000 + sample[1], "withdrawal removes only rangefinder tiers at principal %d" % sample[0])
	p.free()

func _test_bank_preview() -> void:
	var p := player()
	var bank := bank_for(p)
	p.add_relic("relic_golden_rangefinder")
	p.add_relic("relic_horizon_orrery")
	bank.prepare_wave(2)
	bank.deposit(1000, true)
	var manager := WaveManager.new()
	manager.player = p
	manager.finance_system = bank
	var flow := MainFlowCoordinator.new()
	flow._bound_player = p
	flow._bound_wave_manager = manager
	var before := bank.get_state_snapshot()
	var preview := flow.get_bank_stat_preview("withdraw", 901)
	check(preview.contains("攻击距离：70 → 40") and preview.contains("伤害范围：35 → 20"), "bank preview includes exact range and derived area changes")
	check(bank.get_state_snapshot() == before and p.get_stat("area_size") == 70, "bank hover preserves live principal and stats")
	bank.withdraw(901)
	check(p.get_stat("area_size") == 40 and p.get_stat("damage_area_size") == 20, "withdrawal agrees with bank preview")
	flow.free()
	manager.free()
	p.free()

func _test_validation() -> void:
	var valid: Dictionary = DataRegistry.get_record("relics", "relic_range_tripod").runtime_effects[0]
	var validator := DataValidator.new()
	validator._validate_relic_runtime_effect(valid, "tripod")
	check(validator.errors.is_empty(), "stationary condition validates")
	for threshold in [0, -1, INF]:
		var invalid := valid.duplicate(true)
		invalid.threshold = threshold
		validator = DataValidator.new()
		validator._validate_relic_runtime_effect(invalid, "tripod")
		check(not validator.errors.is_empty(), "invalid stationary threshold rejected")
	var invalid: Dictionary = DataRegistry.get_record("relics", "relic_horizon_orrery").runtime_effects[0].duplicate(true)
	invalid.positive_source_only = "true"
	validator = DataValidator.new()
	validator._validate_relic_runtime_effect(invalid, "orrery")
	check(not validator.errors.is_empty(), "invalid source clamp rejected")

func _test_tooltip_bounds() -> void:
	var esc := load("res://scenes/ui/esc/esc_overlay.tscn").instantiate() as EscOverlay
	add_child(esc)
	var cell := Control.new()
	esc.add_child(cell)
	cell.size = Vector2(48, 48)
	for viewport in [Vector2i(1152, 768), Vector2i(640, 360)]:
		get_tree().root.size = viewport
		get_tree().root.content_scale_size = viewport
		for i in 3: await get_tree().process_frame
		var safe := esc._get_modal_safe_rect()
		cell.global_position = safe.end - cell.size
		esc._show_relic_tooltip(DataRegistry.get_record("relics", "relic_horizon_orrery"), cell)
		for i in 4: await get_tree().process_frame
		check(safe.encloses(esc.relic_tooltip.get_global_rect()), "right-edge relic tooltip avoids stats drawer at " + str(viewport))
		check(esc.relic_tooltip_label.get_parsed_text().contains("伤害范围 +5"), "orrery tooltip retains full description")
	esc.free()
