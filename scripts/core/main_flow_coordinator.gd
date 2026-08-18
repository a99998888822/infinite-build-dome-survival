extends Node
class_name MainFlowCoordinator

signal mode_changed(previous_mode: String, current_mode: String)
signal state_changed(previous_state: String, current_state: String)
signal modal_requested(modal_state: String, payload: Dictionary)
signal modal_closed(modal_state: String)
signal battle_result_changed(victory: bool, summary: Dictionary)
signal flow_reset

const MODE_BOOT: String = "boot"
const MODE_BATTLE: String = "battle"
const MODE_CAMP: String = "camp"

const STATE_START_PAGE: String = "start_page"
const STATE_CHARACTER_SELECT: String = "character_select"
const STATE_BATTLE_PREPARE: String = "battle_prepare"
const STATE_WAVE_COMBAT: String = "wave_combat"
const STATE_SHARED_REWARD_SHOP_POPUP: String = "shared_reward_shop_popup"
const STATE_WAVE_END_ABSORB: String = "wave_end_absorb"
const STATE_INTEREST_SETTLEMENT: String = "interest_settlement"
const STATE_SHOP_POPUP: String = "shop_popup"
const STATE_ESC_OVERLAY: String = "esc_overlay"
const STATE_FINANCE_POPUP: String = "finance_popup"
const STATE_ZONE_SELECT: String = "zone_select"
const STATE_ZONE_HARVEST_RESULT: String = "zone_harvest_result"
const STATE_BATTLE_RESULT: String = "battle_result"
const STATE_CAMP_ENTRY: String = "camp_entry"

var current_mode: String = MODE_BOOT
var current_state: String = STATE_START_PAGE
var current_wave_index: int = -1
var current_wave_id: String = ""
var current_wave_duration_seconds: int = 0
var current_character_id: String = ""
var current_start_weapon_ids: Array[String] = []
var current_outgame_modifiers: Array = []
var current_battle_summary: Dictionary = {}
var current_victory: bool = false
var battle_resolved: bool = false

var _resume_state_after_modal: String = STATE_START_PAGE
var _active_level_up_level: int = 0
var _pending_level_up_levels: Array[int] = []
var _weapon_upgrade_miss_count: int = 0
var _wave_end_ready: bool = false
var _active_zone_selection_wave_number: int = 0
var _pending_zone_harvest_payload: Dictionary = {}
var _pending_interest_payload: Dictionary = {}
var _pending_finance_payload: Dictionary = {}
var _pending_wave_start_after_finance: bool = false
var _stat_preview: Dictionary = {}

var _bound_player: PlayerController = null
var _bound_loadout: WeaponLoadout = null
var _bound_wave_manager: WaveManager = null
var _bound_camp_root: CampRoot = null


func _ready() -> void:
	reset_flow()


func reset_flow() -> void:
	var previous_player := _bound_player
	_unbind_battle_context()
	ZoneProgression.reset_state(previous_player)
	_bound_camp_root = null
	current_character_id = ""
	current_start_weapon_ids.clear()
	current_outgame_modifiers.clear()
	current_wave_index = -1
	current_wave_id = ""
	current_wave_duration_seconds = 0
	current_battle_summary.clear()
	current_victory = false
	battle_resolved = false
	_resume_state_after_modal = STATE_START_PAGE
	_active_level_up_level = 0
	_pending_level_up_levels.clear()
	_weapon_upgrade_miss_count = 0
	_wave_end_ready = false
	_active_zone_selection_wave_number = 0
	_pending_zone_harvest_payload.clear()
	_pending_interest_payload.clear()
	_pending_finance_payload.clear()
	_pending_wave_start_after_finance = false
	_stat_preview.clear()
	_set_battle_runtime_paused(false)
	_set_mode(MODE_BOOT)
	_set_state(STATE_START_PAGE)
	flow_reset.emit()


func enter_start_page() -> void:
	reset_flow()


func enter_battle_selection(character_id: String = "", start_weapon_ids: Array[String] = [], outgame_modifiers: Array = []) -> void:
	current_character_id = _sanitize_text(character_id)
	current_start_weapon_ids = _sanitize_string_array(start_weapon_ids)
	current_outgame_modifiers = outgame_modifiers.duplicate(true)
	_set_mode(MODE_BATTLE)
	_set_state(STATE_CHARACTER_SELECT)


func confirm_character_selection() -> bool:
	if _bound_player == null or _bound_loadout == null:
		push_error("[MainFlowCoordinator] missing battle context before character confirm.")
		return false

	if current_character_id.is_empty():
		current_character_id = PlayerController.DEFAULT_CHARACTER_ID

	var player_ok := _bound_player.initialize_from_character(current_character_id, current_outgame_modifiers, current_start_weapon_ids)
	var loadout_ok := _bound_loadout.initialize(_bound_player)
	if _bound_wave_manager != null:
		_bound_wave_manager.initialize(_bound_player)

	if not player_ok or not loadout_ok:
		return false

	battle_resolved = false
	current_victory = false
	current_battle_summary.clear()
	_active_level_up_level = 0
	_pending_level_up_levels.clear()
	_wave_end_ready = false
	_set_mode(MODE_BATTLE)
	_set_state(STATE_BATTLE_PREPARE)
	return request_next_wave()


func bind_battle_context(player: PlayerController, loadout: WeaponLoadout, wave_manager: WaveManager = null) -> void:
	_unbind_battle_context()
	_bound_player = player
	_bound_loadout = loadout
	if _bound_player != null:
		var player_callable := Callable(self, "_on_player_died")
		if not _bound_player.died.is_connected(player_callable):
			_bound_player.died.connect(player_callable)
	bind_wave_manager(wave_manager)


func bind_wave_manager(wave_manager: WaveManager) -> void:
	if _bound_wave_manager == wave_manager:
		return
	_unbind_wave_manager()
	_bound_wave_manager = wave_manager
	if _bound_wave_manager == null:
		return
	var wave_started_callable := Callable(self, "_on_wave_started")
	var wave_finished_callable := Callable(self, "_on_wave_finished")
	var wave_absorb_started_callable := Callable(self, "_on_wave_end_absorb_started")
	var shared_reward_callable := Callable(self, "_on_shared_reward_shop_requested")
	if not _bound_wave_manager.wave_started.is_connected(wave_started_callable):
		_bound_wave_manager.wave_started.connect(wave_started_callable)
	if not _bound_wave_manager.wave_finished.is_connected(wave_finished_callable):
		_bound_wave_manager.wave_finished.connect(wave_finished_callable)
	if not _bound_wave_manager.wave_end_absorb_started.is_connected(wave_absorb_started_callable):
		_bound_wave_manager.wave_end_absorb_started.connect(wave_absorb_started_callable)
	if not _bound_wave_manager.shared_reward_shop_requested.is_connected(shared_reward_callable):
		_bound_wave_manager.shared_reward_shop_requested.connect(shared_reward_callable)


func bind_camp_context(camp_root: CampRoot) -> void:
	_bound_camp_root = camp_root


func enter_camp_flow(camp_root: CampRoot = null) -> void:
	if camp_root != null:
		bind_camp_context(camp_root)
	_set_mode(MODE_CAMP)
	_set_state(STATE_CAMP_ENTRY)


func request_next_wave() -> bool:
	if _bound_wave_manager == null:
		return false
	if current_mode != MODE_BATTLE or battle_resolved:
		return false
	if current_state != STATE_BATTLE_PREPARE:
		return false
	var next_wave_number := _get_next_wave_number()
	if not _has_next_wave():
		return false
	if next_wave_number <= 1:
		_pending_wave_start_after_finance = true
		_pending_finance_payload.clear()
		return _start_prepared_wave()
	_pending_wave_start_after_finance = true
	_pending_finance_payload = _bound_wave_manager.prepare_finance_for_wave(next_wave_number)
	_set_state(STATE_FINANCE_POPUP)
	modal_requested.emit(STATE_FINANCE_POPUP, _pending_finance_payload.duplicate(true))
	return true


func finish_current_wave() -> void:
	if _bound_wave_manager != null:
		_set_state(STATE_WAVE_END_ABSORB)
		_bound_wave_manager.finish_current_wave()


func request_shared_reward_shop_popup(level: int, source: String = "wave_manager") -> void:
	if current_mode != MODE_BATTLE or battle_resolved or level <= 0:
		return
	if current_state == STATE_WAVE_END_ABSORB:
		if not _pending_level_up_levels.has(level):
			_pending_level_up_levels.append(level)
		return
	if current_state == STATE_SHARED_REWARD_SHOP_POPUP:
		if level == _active_level_up_level:
			return
		if not _pending_level_up_levels.has(level):
			_pending_level_up_levels.append(level)
		return

	_active_level_up_level = level
	_resume_state_after_modal = STATE_INTEREST_SETTLEMENT if _wave_end_ready else current_state
	_set_battle_runtime_paused(true)
	_set_state(STATE_SHARED_REWARD_SHOP_POPUP)
	modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(level, source, false))


func close_shared_reward_shop_popup() -> void:
	if current_state != STATE_SHARED_REWARD_SHOP_POPUP:
		return
	modal_closed.emit(STATE_SHARED_REWARD_SHOP_POPUP)
	if not _pending_level_up_levels.is_empty():
		var next_level := int(_pending_level_up_levels.pop_front())
		_active_level_up_level = next_level
		modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(next_level, "queued", true))
		return
	_active_level_up_level = 0
	if _wave_end_ready:
		_set_battle_runtime_paused(false)
		_enter_wave_end_shop()
	else:
		_set_state(_resume_state_after_modal)
		_set_battle_runtime_paused(false)


func request_zone_select_popup(source: String = "wave_manager") -> bool:
	if current_mode != MODE_BATTLE or battle_resolved:
		return false
	if not ZoneProgression.has_zone_records():
		return false
	_active_zone_selection_wave_number = _get_next_wave_number()
	if _active_zone_selection_wave_number <= 1:
		return false
	_set_state(STATE_ZONE_SELECT)
	modal_requested.emit(STATE_ZONE_SELECT, ZoneProgression.build_zone_selection_payload(_active_zone_selection_wave_number))
	return true


func confirm_zone_selection(zone_id: String) -> bool:
	if current_state != STATE_ZONE_SELECT:
		return false
	var selection_result := ZoneProgression.select_zone(zone_id, _active_zone_selection_wave_number, _bound_player)
	if not bool(selection_result.get("success", false)):
		return false
	modal_closed.emit(STATE_ZONE_SELECT)
	if bool(selection_result.get("harvested", false)):
		_pending_zone_harvest_payload = (selection_result.get("harvest_payload", {}) as Dictionary).duplicate(true)
		_set_state(STATE_ZONE_HARVEST_RESULT)
		modal_requested.emit(STATE_ZONE_HARVEST_RESULT, _pending_zone_harvest_payload.duplicate(true))
	else:
		_pending_zone_harvest_payload.clear()
		_set_state(STATE_BATTLE_PREPARE)
		_start_prepared_wave()
	return true


func close_zone_harvest_result_popup() -> void:
	if current_state != STATE_ZONE_HARVEST_RESULT:
		return
	modal_closed.emit(STATE_ZONE_HARVEST_RESULT)
	ZoneProgression.acknowledge_harvest_result()
	_pending_zone_harvest_payload.clear()
	_set_state(STATE_BATTLE_PREPARE)
	_start_prepared_wave()


func submit_finance_operation(action: String, amount: int) -> Dictionary:
	if current_state != STATE_FINANCE_POPUP or _bound_wave_manager == null:
		return {"success": false, "reason": "finance_popup_not_active"}
	var result := _bound_wave_manager.apply_finance_operation(action, amount)
	if bool(result.get("success", false)) or str(action) == "none":
		_pending_finance_payload.clear()
		close_finance_popup()
	return result


func close_finance_popup() -> void:
	if current_state != STATE_FINANCE_POPUP:
		return
	modal_closed.emit(STATE_FINANCE_POPUP)
	_pending_finance_payload.clear()
	_wave_end_ready = false
	if request_zone_select_popup():
		return
	if not _start_prepared_wave():
		_set_state(STATE_BATTLE_PREPARE)


func close_interest_settlement() -> void:
	if current_state != STATE_INTEREST_SETTLEMENT:
		return
	modal_closed.emit(STATE_INTEREST_SETTLEMENT)
	_request_wave_end_finance()


func close_shop_popup() -> void:
	if current_state != STATE_SHOP_POPUP:
		return
	modal_closed.emit(STATE_SHOP_POPUP)
	if _wave_end_ready:
		# 利息提示只是异步通知，不再作为必须等待的流程状态。
		modal_requested.emit(STATE_INTEREST_SETTLEMENT, _pending_interest_payload.duplicate(true))
		if not _request_wave_end_finance():
			_wave_end_ready = false
			_set_state(STATE_BATTLE_PREPARE)
	else:
		_set_state(STATE_BATTLE_PREPARE)


func request_esc_overlay() -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	if current_state != STATE_WAVE_COMBAT and current_state != STATE_BATTLE_PREPARE:
		return
	_resume_state_after_modal = current_state
	_set_battle_runtime_paused(true)
	_set_state(STATE_ESC_OVERLAY)
	modal_requested.emit(STATE_ESC_OVERLAY, {})


func close_esc_overlay() -> void:
	if current_state != STATE_ESC_OVERLAY:
		return
	modal_closed.emit(STATE_ESC_OVERLAY)
	_set_state(_resume_state_after_modal)
	_set_battle_runtime_paused(false)


func submit_shop_purchase(offer: Dictionary, mode: String) -> Dictionary:
	if current_state != STATE_SHOP_POPUP and current_state != STATE_SHARED_REWARD_SHOP_POPUP:
		return {"success": false, "reason": "shop_not_active"}
	var sanitized_mode := str(mode).strip_edges()
	var offer_type := str(offer.get("offer_type", ""))
	var target_id := str(offer.get("target_id", ""))
	if offer_type.is_empty() or target_id.is_empty():
		return {"success": false, "reason": "invalid_offer"}
	if sanitized_mode == "shop" and not _try_pay_shop_cost(offer):
		return {"success": false, "reason": "insufficient_gold"}
	var applied := _apply_shop_offer(offer_type, target_id, offer)
	if not applied:
		if sanitized_mode == "shop":
			_refund_shop_cost(offer)
		return {"success": false, "reason": "purchase_failed"}
	if sanitized_mode == "free":
		close_shared_reward_shop_popup()
	else:
		close_shop_popup()
	return {"success": true, "action": "purchase", "offer_id": str(offer.get("offer_id", "")), "offer_type": offer_type, "target_id": target_id}


func mark_wave_end_ready() -> void:
	_wave_end_ready = true
	_pending_interest_payload = _bound_wave_manager.get_finance_snapshot() if _bound_wave_manager != null else {}
	_pending_interest_payload["settlement_results"] = _pending_interest_payload.get("last_settlement_results", [])
	if not _pending_level_up_levels.is_empty() and not battle_resolved:
		var next_level := int(_pending_level_up_levels.pop_front())
		_active_level_up_level = next_level
		_resume_state_after_modal = STATE_SHOP_POPUP
		_set_battle_runtime_paused(true)
		_set_state(STATE_SHARED_REWARD_SHOP_POPUP)
		modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(next_level, "wave_end_absorb", false))
	elif current_state != STATE_SHARED_REWARD_SHOP_POPUP and not battle_resolved:
		_enter_wave_end_shop()
	elif current_state == STATE_SHARED_REWARD_SHOP_POPUP:
		_resume_state_after_modal = STATE_SHOP_POPUP


func advance_wave_end_phase() -> void:
	if current_state == STATE_INTEREST_SETTLEMENT:
		modal_closed.emit(STATE_INTEREST_SETTLEMENT)
		_request_wave_end_finance()
		return
	if current_state == STATE_SHOP_POPUP:
		close_shop_popup()
		return
	if current_state == STATE_FINANCE_POPUP:
		close_finance_popup()
		return


func present_battle_result(victory: bool, summary: Dictionary = {}) -> void:
	ZoneProgression.reset_state(_bound_player)
	battle_resolved = true
	current_victory = victory
	current_battle_summary = summary.duplicate(true)
	var settlement_gold := int(current_battle_summary.get("gold", 0))
	if settlement_gold > 0 and CampProgression != null and CampProgression.has_method("apply_final_settlement"):
		CampProgression.apply_final_settlement(settlement_gold)
	_pending_level_up_levels.clear()
	_wave_end_ready = false
	_active_zone_selection_wave_number = 0
	_pending_zone_harvest_payload.clear()
	_set_mode(MODE_BATTLE)
	_set_battle_runtime_paused(false)
	_set_state(STATE_BATTLE_RESULT)
	battle_result_changed.emit(victory, current_battle_summary.duplicate(true))


func confirm_battle_result() -> void:
	enter_start_page()


func set_stat_preview_from_offer(offer: Dictionary) -> void:
	_stat_preview = StatPreviewBuilder.build_offer_stat_preview(offer, _bound_player)


func clear_stat_preview() -> void:
	_stat_preview.clear()


func get_stat_preview() -> Dictionary:
	return _stat_preview.duplicate(true)


func get_bound_player() -> PlayerController:
	return _bound_player


func get_bound_loadout() -> WeaponLoadout:
	return _bound_loadout


func get_current_mode() -> String:
	return current_mode


func get_current_state() -> String:
	return current_state


func get_state_snapshot() -> Dictionary:
	return {
		"mode": current_mode,
		"state": current_state,
		"wave_index": current_wave_index,
		"wave_id": current_wave_id,
		"wave_duration_seconds": current_wave_duration_seconds,
		"character_id": current_character_id,
		"start_weapon_ids": current_start_weapon_ids.duplicate(),
		"outgame_modifiers": current_outgame_modifiers.duplicate(true),
		"battle_resolved": battle_resolved,
		"victory": current_victory,
		"wave_end_ready": _wave_end_ready,
		"active_shared_reward_shop_level": _active_level_up_level,
		"pending_shared_reward_shop_levels": _pending_level_up_levels.duplicate(),
		"weapon_upgrade_miss_count": _weapon_upgrade_miss_count,
		"zone_state": ZoneProgression.get_state_snapshot(),
		"active_zone_selection_wave_number": _active_zone_selection_wave_number,
		"pending_zone_harvest_payload": _pending_zone_harvest_payload.duplicate(true),
		"pending_interest_payload": _pending_interest_payload.duplicate(true),
		"pending_finance_payload": _pending_finance_payload.duplicate(true),
		"pending_wave_start_after_finance": _pending_wave_start_after_finance,
		"finance_state": _bound_wave_manager.get_finance_snapshot() if _bound_wave_manager != null else {},
	}


func _get_next_wave_number() -> int:
	return maxi(current_wave_index + 2, 1)


func _has_next_wave() -> bool:
	return current_wave_index + 1 < DataRegistry.get_table("waves").size()


func _start_prepared_wave() -> bool:
	if not _pending_wave_start_after_finance:
		return false
	if _bound_wave_manager == null:
		_pending_wave_start_after_finance = false
		return false
	if _bound_wave_manager.start_next_wave():
		_pending_wave_start_after_finance = false
		return true
	_pending_wave_start_after_finance = false
	return false


func _enter_wave_end_shop() -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	_set_battle_runtime_paused(false)
	_set_state(STATE_SHOP_POPUP)
	modal_requested.emit(STATE_SHOP_POPUP, _build_shop_payload("shop", 0))


func _request_wave_end_finance() -> bool:
	if current_mode != MODE_BATTLE or battle_resolved or _bound_wave_manager == null:
		return false
	if not _has_next_wave():
		return false
	var next_wave_number := _get_next_wave_number()
	_pending_interest_payload.clear()
	_pending_wave_start_after_finance = true
	_pending_finance_payload = _bound_wave_manager.prepare_finance_for_wave(next_wave_number)
	_set_state(STATE_FINANCE_POPUP)
	modal_requested.emit(STATE_FINANCE_POPUP, _pending_finance_payload.duplicate(true))
	return true


func _on_wave_started(wave_id: String, duration_seconds: int) -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	current_wave_index += 1
	current_wave_id = wave_id
	current_wave_duration_seconds = duration_seconds
	_pending_finance_payload.clear()
	_pending_wave_start_after_finance = false
	_set_battle_runtime_paused(false)
	_set_state(STATE_WAVE_COMBAT)


func _on_wave_finished(wave_id: String) -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	current_wave_id = wave_id
	if not _has_next_wave():
		var gold := _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0
		present_battle_result(true, {"reason": "all_waves_cleared", "gold": gold})
		return
	mark_wave_end_ready()


func _on_wave_end_absorb_started(_wave_id: String) -> void:
	if current_mode == MODE_BATTLE and not battle_resolved:
		_set_state(STATE_WAVE_END_ABSORB)


func _on_shared_reward_shop_requested(level: int) -> void:
	request_shared_reward_shop_popup(level, "shared_reward_shop_requested")


func _on_player_died() -> void:
	var gold := _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0
	present_battle_result(false, {"reason": "player_died", "gold": gold})


func _set_mode(next_mode: String) -> void:
	var sanitized_mode := _sanitize_text(next_mode)
	if sanitized_mode.is_empty() or current_mode == sanitized_mode:
		return
	var previous_mode := current_mode
	current_mode = sanitized_mode
	GameGlobal.set_game_mode(current_mode)
	GameGlobal.set_runtime_flag("main_flow_mode", current_mode)
	mode_changed.emit(previous_mode, current_mode)


func _set_state(next_state: String) -> void:
	var sanitized_state := _sanitize_text(next_state)
	if sanitized_state.is_empty() or current_state == sanitized_state:
		return
	var previous_state := current_state
	current_state = sanitized_state
	GameGlobal.set_runtime_flag("main_flow_state", current_state)
	state_changed.emit(previous_state, current_state)


func _set_battle_runtime_paused(paused: bool) -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", paused)


func _unbind_battle_context() -> void:
	_unbind_player()
	_unbind_wave_manager()
	_bound_loadout = null


func _unbind_player() -> void:
	if _bound_player == null:
		return
	var player_callable := Callable(self, "_on_player_died")
	if _bound_player.died.is_connected(player_callable):
		_bound_player.died.disconnect(player_callable)
	_bound_player = null


func _unbind_wave_manager() -> void:
	if _bound_wave_manager == null:
		return
	if _bound_wave_manager.has_method("clear_battle_entities"):
		_bound_wave_manager.clear_battle_entities()
	var wave_started_callable := Callable(self, "_on_wave_started")
	var wave_finished_callable := Callable(self, "_on_wave_finished")
	var shared_reward_callable := Callable(self, "_on_shared_reward_shop_requested")
	if _bound_wave_manager.wave_started.is_connected(wave_started_callable):
		_bound_wave_manager.wave_started.disconnect(wave_started_callable)
	if _bound_wave_manager.wave_finished.is_connected(wave_finished_callable):
		_bound_wave_manager.wave_finished.disconnect(wave_finished_callable)
	var wave_absorb_started_callable := Callable(self, "_on_wave_end_absorb_started")
	if _bound_wave_manager.wave_end_absorb_started.is_connected(wave_absorb_started_callable):
		_bound_wave_manager.wave_end_absorb_started.disconnect(wave_absorb_started_callable)
	if _bound_wave_manager.shared_reward_shop_requested.is_connected(shared_reward_callable):
		_bound_wave_manager.shared_reward_shop_requested.disconnect(shared_reward_callable)
	_bound_wave_manager = null


func _sanitize_text(value: Variant) -> String:
	return str(value).strip_edges()


func _sanitize_string_array(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var sanitized := _sanitize_text(value)
		if sanitized.is_empty() or result.has(sanitized):
			continue
		result.append(sanitized)
	return result


func _build_shared_reward_shop_payload(level: int, source: String, queued: bool) -> Dictionary:
	var payload := _build_shop_payload("free", level)
	payload["source"] = source
	payload["queued"] = queued
	payload["resume_state"] = _resume_state_after_modal
	return payload


func _build_shop_payload(mode: String, level: int) -> Dictionary:
	var context := _build_shop_context()
	var offers: Array = []
	if not context.is_empty():
		var generator := ShopOfferGenerator.new()
		var candidates := generator.build_shop_candidate_pool(context)
		var rarity_weights := generator.get_shop_rarity_weights(int(_get_shop_stat("luck")), ZoneProgression.get_current_zone_rarity_bonus())
		context["candidate_pool"] = candidates
		var type_weights := generator.get_shop_type_weights(context)
		offers = generator.roll_shop_offers(rarity_weights, type_weights, candidates, 3)
		_update_weapon_upgrade_miss_count(candidates, offers)
	return {
		"mode": str(mode).strip_edges(),
		"level": maxi(0, level),
		"gold": _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0,
		"offers": offers,
		"resume_state": _resume_state_after_modal,
	}


func _build_shop_context() -> Dictionary:
	if _bound_player == null or _bound_loadout == null:
		return {}
	var owned_weapon_ids: Array[String] = []
	var equipped_weapons: Array[Dictionary] = []
	for weapon in _bound_loadout.get_weapon_instances():
		owned_weapon_ids.append(weapon.weapon_id)
		equipped_weapons.append({"weapon_id": weapon.weapon_id, "level": weapon.level})
	return {
		"owned_weapon_ids": owned_weapon_ids,
		"equipped_weapons": equipped_weapons,
		"unlocked_weapon_ids": [],
		"unlocked_relic_ids": [],
		"owned_relic_counts": _bound_player.get_relic_counts(),
		"current_load": _bound_loadout.get_total_load_cost(),
		"load_capacity": _bound_loadout.get_load_capacity(),
		"weapon_upgrade_miss_count": _weapon_upgrade_miss_count,
		"shop_price_percent": _get_shop_stat("shop_price_percent"),
		"zone_tendency_tags": ZoneProgression.get_current_zone_tendency_tags(),
		"zone_target_pools": ZoneProgression.get_current_zone_target_pools(),
		"zone_tag_weight_bonus": ZoneProgression.get_current_zone_tag_weight_bonus(),
	}


func _update_weapon_upgrade_miss_count(candidates: Array, offers: Array) -> void:
	var has_upgrade_candidate := false
	for candidate in candidates:
		if candidate is Dictionary and str(candidate.get("offer_type", "")) == ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
			has_upgrade_candidate = true
			break
	if not has_upgrade_candidate:
		return
	for offer in offers:
		if offer is Dictionary and str(offer.get("offer_type", "")) == ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
			_weapon_upgrade_miss_count = 0
			return
	_weapon_upgrade_miss_count += 1


func _get_shop_stat(stat_id: String) -> float:
	return _bound_player.get_stat(stat_id, 0.0) if _bound_player != null else 0.0


func _try_pay_shop_cost(offer: Dictionary) -> bool:
	var cost := int(offer.get("shop_cost", 0))
	if cost <= 0:
		return true
	if _bound_wave_manager == null or _bound_wave_manager.get_current_gold() < cost:
		return false
	return _bound_wave_manager.apply_gold_delta(-cost, "shop_purchase")


func _refund_shop_cost(offer: Dictionary) -> void:
	var cost := int(offer.get("shop_cost", 0))
	if cost <= 0 or _bound_wave_manager == null:
		return
	_bound_wave_manager.apply_gold_delta(cost, "shop_purchase_refund")


func _apply_shop_offer(offer_type: String, target_id: String, offer: Dictionary) -> bool:
	match offer_type:
		ShopOfferGenerator.OFFER_RELIC:
			return _bound_player != null and _bound_player.add_relic(target_id)
		ShopOfferGenerator.OFFER_NEW_WEAPON:
			return _bound_loadout != null and _bound_loadout.try_buy_weapon(target_id)
		ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
			if _bound_loadout == null:
				return false
			var weapon := _bound_loadout.get_weapon_instance(target_id)
			if weapon == null or weapon.level != int(offer.get("from_level", 0)):
				return false
			return _bound_loadout.upgrade_weapon(target_id)
		_:
			return false
