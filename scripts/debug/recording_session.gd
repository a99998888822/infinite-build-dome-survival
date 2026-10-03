extends Node
class_name RecordingSession
## Owns a disposable production GameRoot; configuration never edits game data.

var game: GameRoot
var flow: MainFlowCoordinator
var battle: BattleRoot
var config: Dictionary = {}
var hud_visible := true
var paused := false


func _ready() -> void:
	# Run after the production HUD's normal visibility refresh.
	process_priority = 100


func _process(_delta: float) -> void:
	_apply_hud_visibility()


static func default_config() -> Dictionary:
	return {"wave": 5, "difficulty": "1", "character": "character_void_hunter",
		"level": 10, "gold": 200, "principal": 1000, "sanity_delta": 0, "erosion_delta": 0,
		"countdown": 3, "hud": true, "entry": "combat",
		"weapons": [{"id": "weapon_nightwatch_spear", "level": 3, "attachments": ["scroll_split", "scroll_fire"]}],
		"relics": [{"id": "relic_steel_vault", "count": 1}]}


static func presets() -> Dictionary:
	var combat := default_config()
	var bank := default_config()
	bank.merge({"entry": "bank", "gold": 0, "weapons": [{"id": "weapon_rentier_purse", "level": 3, "attachments": ["scroll_lightning"]}]}, true)
	var erosion := default_config()
	erosion.merge({"wave": 8, "level": 18, "erosion_delta": 30, "relics": [
		{"id": "relic_steel_vault", "count": 1}, {"id": "relic_sleepless_ledger", "count": 1},
		{"id": "relic_soul_keeper_face_stone", "count": 1}]}, true)
	return {"长枪 · 分裂与火焰": combat, "本金依赖 · 银行开场": bank, "理智与侵蚀 · 第8波": erosion}


static func validate(data: Dictionary) -> String:
	for key in ["wave", "level", "gold", "principal", "sanity_delta", "erosion_delta", "countdown"]:
		if not data.has(key) or not (data[key] is int or data[key] is float): return "数值字段无效：" + key
		if not is_finite(float(data[key])) or float(data[key]) != floorf(float(data[key])): return "请输入整数：" + key
	if int(data.wave) < 1 or int(data.wave) > DataRegistry.get_table("waves").size(): return "波次超出当前关卡范围。"
	if int(data.level) < 1 or int(data.level) > 200: return "角色等级应为 1–200。"
	for key in ["gold", "principal"]:
		if int(data[key]) < 0 or int(data[key]) > 10000000: return "金币与本金应为 0–10000000。"
	for key in ["sanity_delta", "erosion_delta"]:
		if absi(int(data[key])) > 10000: return "理智与侵蚀调整应为 −10000–10000。"
	if int(data.countdown) < 0 or int(data.countdown) > 10: return "倒计时应为 0–10 秒。"
	if str(data.get("difficulty", "")) not in BattleDifficulty.IDS: return "难度无效。"
	var character := DataRegistry.get_record("characters", str(data.get("character", "")))
	if character.is_empty() or not bool(character.get("enabled", true)): return "角色不可用。"
	if data.get("entry", "") not in ["combat", "bank"]: return "开场位置无效。"
	if not data.get("weapons") is Array or data.weapons.is_empty() or data.weapons.size() > 12: return "请选择 1–12 把不同武器。"
	var used: Array[String] = []
	for row in data.weapons:
		if not row is Dictionary: return "武器配置无效。"
		var id := str(row.get("id", ""))
		var weapon := DataRegistry.get_record("weapons", id)
		if weapon.is_empty(): return "武器不存在：" + id
		if id in used: return "不能重复装备：" + str(weapon.display_name)
		used.append(id)
		if not (row.get("level") is int or row.get("level") is float): return "武器等级无效。"
		if float(row.level) != floorf(float(row.level)) or int(row.level) < 1 or int(row.level) > int(weapon.get("max_level", 1)): return "武器等级超限：" + str(weapon.display_name)
		if not row.get("attachments") is Array or row.attachments.size() > 2: return "每把武器最多配置两个附魔。"
		var rarity := str(weapon.get("rarity", "common"))
		for level in range(2, int(row.level) + 1):
			rarity = str(weapon.get("level_upgrades", {}).get(str(level), {}).get("rarity", rarity))
		if row.attachments.size() > WeaponInstance.get_attachment_slots_for_rarity(rarity): return "%s 当前品质只有一个附魔槽，请升级或移除附魔2。" % weapon.display_name
		for item_id in row.attachments:
			var item := DataRegistry.get_record("augmentations", str(item_id))
			if item.is_empty() or str(item.get("category", "")) not in WeaponLoadout.ATTACHABLE_ITEM_CATEGORIES: return "附魔不存在：" + str(item_id)
			for effect in item.get("effect_ids", []):
				if effect in weapon.get("unsupported_effects", []): return "%s 不支持 %s。" % [weapon.display_name, item.display_name]
	if not data.get("relics") is Array or data.relics.size() > 200: return "遗物配置无效。"
	var counts: Dictionary = {}
	for id in character.get("start_relics", []): counts[id] = int(counts.get(id, 0)) + 1
	for row in data.relics:
		if not row is Dictionary or not (row.get("count") is int or row.get("count") is float): return "遗物数量无效。"
		var id := str(row.get("id", ""))
		var relic := DataRegistry.get_record("relics", id)
		if relic.is_empty(): return "遗物不存在：" + id
		if float(row.count) != floorf(float(row.count)) or int(row.count) < 1 or int(row.count) > 100: return "每行遗物数量应为 1–100。"
		counts[id] = int(counts.get(id, 0)) + int(row.count)
		var maximum := int(relic.get("max_stack", 0))
		if maximum > 0 and int(counts[id]) > maximum: return "%s 超过持有上限 %d（含角色自带）。" % [relic.display_name, maximum]
	return ""


func prepare(data: Dictionary) -> String:
	var error := validate(data)
	if not error.is_empty(): return error
	await dispose()
	config = data.duplicate(true)
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	add_child(game)
	for _frame in 4: await get_tree().process_frame
	flow = game.get_main_flow_coordinator()
	var weapon_ids: Array[String] = []
	for row in config.weapons: weapon_ids.append(str(row.id))
	flow.enter_battle_selection(str(config.character), weapon_ids, [], str(config.difficulty))
	for _frame in 2: await get_tree().process_frame
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	if battle == null: return "无法创建战斗场景。"
	var player := battle.player
	var manager := battle.wave_manager
	if not player.initialize_from_character(str(config.character), [], weapon_ids): return "角色初始化失败。"
	# Attachments are an explicit list; clear character defaults before equipping.
	player.item_inventory.clear()
	manager.initialize(player, str(config.difficulty))
	manager.current_wave_index = int(config.wave) - 2
	manager.player_level = int(config.level)
	player.set_run_level(manager.player_level)
	for pair in [["humanity", "sanity_delta"], ["divinity", "erosion_delta"]]:
		player.add_runtime_modifier({"id": "recording_" + pair[0], "source_type": "recording", "source_id": pair[0],
			"target_scope": "player", "stat": pair[0], "operation": "add_flat", "value": int(config[pair[1]]),
			"duration": -1, "stack_rule": "replace_same_source"})
	var bank := manager.finance_system
	bank.current_wave_number = int(config.wave)
	bank.wave_counter = int(config.wave) - 1
	for row in config.relics:
		for _copy in int(row.count):
			if not player.add_relic(str(row.id)): return "无法加入遗物：" + str(row.id)
	# Exact configured balances are installed after on-acquire gifts.
	bank.principal = int(config.principal)
	bank.has_principal_ever = bank.principal > 0
	bank._emit_changed()
	manager.current_gold = int(config.gold)
	manager.gold_changed.emit(manager.current_gold)
	if not battle.loadout.initialize(player, bank): return "武器总负载超过角色容量，请减少武器或加入负载遗物。"
	for row in config.weapons:
		for _level in range(1, int(row.level)):
			if not battle.loadout.upgrade_weapon(str(row.id)): return "武器升级失败。"
		for item_id in row.attachments:
			var item := player.item_inventory.add_item_from_base(str(item_id), "recording")
			if item.is_empty() or not battle.loadout.attach_item_to_weapon(str(row.id), str(item.item_instance_id)): return "附魔装填失败：" + str(item_id)
	player.restore_full_health()
	flow.current_wave_index = int(config.wave) - 2
	flow.current_wave_id = ""
	flow._set_state(MainFlowCoordinator.STATE_BATTLE_PREPARE)
	flow._pending_wave_start_after_finance = true
	flow._set_battle_runtime_paused(true)
	manager.economy_journal.clear()
	hud_visible = bool(config.get("hud", true))
	set_hud_visible(hud_visible)
	paused = false
	return ""


func begin() -> bool:
	if not is_instance_valid(flow): return false
	if config.entry == "bank": return flow._request_wave_end_finance()
	return flow._start_prepared_wave()


func set_hud_visible(value: bool) -> void:
	hud_visible = value
	if is_instance_valid(battle): battle.hud._refresh_visibility()
	_apply_hud_visibility()


func _apply_hud_visibility() -> void:
	# Keep bank, reward and result controls usable even with a clean combat frame.
	if not hud_visible and is_instance_valid(battle) and is_instance_valid(flow) and flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT:
		battle.hud.hide()
		battle.hud.get_node("EconomyLogLayer").hide()


func toggle_pause() -> void:
	if not is_instance_valid(flow): return
	if paused:
		paused = false
		flow._set_battle_runtime_paused(flow.current_state != MainFlowCoordinator.STATE_WAVE_COMBAT)
	elif flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT:
		paused = true
		flow._set_battle_runtime_paused(true)


func dispose() -> void:
	paused = false
	if is_instance_valid(game):
		GameGlobal.set_runtime_flag("battle_runtime_paused", true)
		if is_instance_valid(battle): battle.restore_world_nodes()
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	game = null
	flow = null
	battle = null
	AudioManager.stop_combat_sfx()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
