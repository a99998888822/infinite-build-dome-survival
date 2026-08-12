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
const STATE_LEVEL_UP_POPUP: String = STATE_SHARED_REWARD_SHOP_POPUP
const STATE_WAVE_END_ABSORB: String = "wave_end_absorb"
const STATE_INTEREST_SETTLEMENT: String = "interest_settlement"
const STATE_SHOP_POPUP: String = "shop_popup"
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
var _wave_end_ready: bool = false
var _active_zone_selection_wave_number: int = 0
var _pending_zone_harvest_payload: Dictionary = {}
var _pending_interest_payload: Dictionary = {}
var _pending_finance_payload: Dictionary = {}
var _pending_wave_start_after_finance: bool = false

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
	_wave_end_ready = false
	_active_zone_selection_wave_number = 0
	_pending_zone_harvest_payload.clear()
	_pending_interest_payload.clear()
	_pending_finance_payload.clear()
	_pending_wave_start_after_finance = false
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
	return true


func bind_battle_context(player: PlayerController, loadout: WeaponLoadout, wave_manager: WaveManager = null) -> void:
	_unbind_battle_context()
	_bound_player = player
	_bound_loadout = loadout
	if _bound_player != null:
		var player_callable := Callable(self, "_on_player_died")
		if not _bound_player.died.is_connected(player_callable):
			_bound_player.died.connect(player_callable)
	bind_wave_manager(wave_manager)


func unbind_battle_context() -> void:
	_unbind_battle_context()


func bind_wave_manager(wave_manager: WaveManager) -> void:
	if _bound_wave_manager == wave_manager:
		return
	_unbind_wave_manager()
	_bound_wave_manager = wave_manager
	if _bound_wave_manager == null:
		return
	var wave_started_callable := Callable(self, "_on_wave_started")
	var wave_finished_callable := Callable(self, "_on_wave_finished")
	var shared_reward_callable := Callable(self, "_on_shared_reward_shop_requested")
	if not _bound_wave_manager.wave_started.is_connected(wave_started_callable):
		_bound_wave_manager.wave_started.connect(wave_started_callable)
	if not _bound_wave_manager.wave_finished.is_connected(wave_finished_callable):
		_bound_wave_manager.wave_finished.connect(wave_finished_callable)
	if not _bound_wave_manager.shared_reward_shop_requested.is_connected(shared_reward_callable):
		_bound_wave_manager.shared_reward_shop_requested.connect(shared_reward_callable)
	if not _bound_wave_manager.free_shop_requested.is_connected(shared_reward_callable):
		_bound_wave_manager.free_shop_requested.connect(shared_reward_callable)


func unbind_wave_manager() -> void:
	_unbind_wave_manager()


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
	if not _has_next_wave():
		return false
	_pending_wave_start_after_finance = true
	_pending_finance_payload = _bound_wave_manager.prepare_finance_for_wave(_get_next_wave_number())
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
	if current_state == STATE_SHARED_REWARD_SHOP_POPUP:
		if level == _active_level_up_level:
			return
		if not _pending_level_up_levels.has(level):
			_pending_level_up_levels.append(level)
		return

	_active_level_up_level = level
	_resume_state_after_modal = STATE_INTEREST_SETTLEMENT if _wave_end_ready else current_state
	_set_state(STATE_SHARED_REWARD_SHOP_POPUP)
	modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(level, source, false))


func request_level_up_popup(level: int, source: String = "wave_manager") -> void:
	request_shared_reward_shop_popup(level, source)


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
		_set_state(STATE_INTEREST_SETTLEMENT)
		modal_requested.emit(STATE_INTEREST_SETTLEMENT, _pending_interest_payload.duplicate(true))
	else:
		_set_state(_resume_state_after_modal)


func close_level_up_popup() -> void:
	close_shared_reward_shop_popup()


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
	_set_state(STATE_SHOP_POPUP)


func mark_wave_end_ready() -> void:
	_wave_end_ready = true
	_pending_interest_payload = _bound_wave_manager.get_finance_snapshot() if _bound_wave_manager != null else {}
	_pending_interest_payload["settlement_results"] = _pending_interest_payload.get("last_settlement_results", [])
	if current_state != STATE_SHARED_REWARD_SHOP_POPUP and not battle_resolved:
		_set_state(STATE_INTEREST_SETTLEMENT)
		modal_requested.emit(STATE_INTEREST_SETTLEMENT, _pending_interest_payload.duplicate(true))
	elif current_state == STATE_SHARED_REWARD_SHOP_POPUP:
		_resume_state_after_modal = STATE_INTEREST_SETTLEMENT


func advance_wave_end_phase() -> void:
	if current_state == STATE_INTEREST_SETTLEMENT:
		modal_closed.emit(STATE_INTEREST_SETTLEMENT)
		_set_state(STATE_SHOP_POPUP)
		return
	if current_state == STATE_SHOP_POPUP:
		_wave_end_ready = false
		_pending_interest_payload.clear()
		_set_state(STATE_BATTLE_PREPARE)
		return
	if current_state == STATE_FINANCE_POPUP:
		close_finance_popup()
		return


func present_battle_result(victory: bool, summary: Dictionary = {}) -> void:
	ZoneProgression.reset_state(_bound_player)
	battle_resolved = true
	current_victory = victory
	current_battle_summary = summary.duplicate(true)
	_pending_level_up_levels.clear()
	_wave_end_ready = false
	_active_zone_selection_wave_number = 0
	_pending_zone_harvest_payload.clear()
	_set_mode(MODE_BATTLE)
	_set_state(STATE_BATTLE_RESULT)
	battle_result_changed.emit(victory, current_battle_summary.duplicate(true))


func confirm_battle_result() -> void:
	enter_start_page()


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
		"active_level_up_level": _active_level_up_level,
		"pending_level_up_levels": _pending_level_up_levels.duplicate(),
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


func _on_wave_started(wave_id: String, duration_seconds: int) -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	current_wave_index += 1
	current_wave_id = wave_id
	current_wave_duration_seconds = duration_seconds
	_pending_finance_payload.clear()
	_pending_wave_start_after_finance = false
	_set_state(STATE_WAVE_COMBAT)


func _on_wave_finished(wave_id: String) -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	current_wave_id = wave_id
	mark_wave_end_ready()


func _on_shared_reward_shop_requested(level: int) -> void:
	request_shared_reward_shop_popup(level, "shared_reward_shop_requested")


func _on_player_died() -> void:
	present_battle_result(false, {"reason": "player_died"})


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
	if _bound_wave_manager.shared_reward_shop_requested.is_connected(shared_reward_callable):
		_bound_wave_manager.shared_reward_shop_requested.disconnect(shared_reward_callable)
	if _bound_wave_manager.free_shop_requested.is_connected(shared_reward_callable):
		_bound_wave_manager.free_shop_requested.disconnect(shared_reward_callable)
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
	return {
		"level": level,
		"source": source,
		"queued": queued,
		"resume_state": _resume_state_after_modal,
	}


func _build_level_up_payload(level: int, source: String, queued: bool) -> Dictionary:
	return _build_shared_reward_shop_payload(level, source, queued)
