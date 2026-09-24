extends Node
class_name MainFlowCoordinator

signal mode_changed(previous_mode: String, current_mode: String)
signal state_changed(previous_state: String, current_state: String)
signal modal_requested(modal_state: String, payload: Dictionary)
signal modal_closed(modal_state: String)
signal interest_notice_requested(payload: Dictionary)
signal battle_result_changed(victory: bool, summary: Dictionary)
signal flow_reset
signal preparation_changed(payload: Dictionary)

var _economy_refresh_queued := false

const MODE_BOOT: String = "boot"
const MODE_BATTLE: String = "battle"
const MODE_CAMP: String = "camp"
const MODE_TALENTS: String = "talents"

const STATE_START_PAGE: String = "start_page"
const STATE_CHARACTER_SELECT: String = "character_select"
const STATE_BATTLE_PREPARE: String = "battle_prepare"
const STATE_WAVE_COMBAT: String = "wave_combat"
const STATE_SHARED_REWARD_SHOP_POPUP: String = "shared_reward_shop_popup"
const STATE_WAVE_END_ABSORB: String = "wave_end_absorb"
const STATE_INTEREST_SETTLEMENT: String = "interest_settlement"
const STATE_SHOP_POPUP: String = "shop_popup"
const STATE_ESC_OVERLAY: String = "esc_overlay"
const STATE_BATTLE_UTILITY: String = "battle_utility"
const STATE_FINANCE_POPUP: String = "finance_popup"
const STATE_ZONE_SELECT: String = "zone_select"
const STATE_ZONE_HARVEST_RESULT: String = "zone_harvest_result"
const STATE_BATTLE_RESULT: String = "battle_result"
const STATE_CAMP_ENTRY: String = "camp_entry"
const STATE_TALENTS: String = "talents"
const BASE_SHOP_OFFER_COUNT: int = 3

var current_mode: String = MODE_BOOT
var current_state: String = STATE_START_PAGE
var current_wave_index: int = -1
var current_wave_id: String = ""
var current_wave_duration_seconds: int = 0
var current_character_id: String = ""
var current_start_weapon_ids: Array[String] = []
var current_outgame_modifiers: Array = []
var current_difficulty_id: String = "standard"
var current_battle_summary: Dictionary = {}
var current_victory: bool = false
var battle_resolved: bool = false

var _resume_state_after_modal: String = STATE_START_PAGE
var _utility_resume_state: String = STATE_START_PAGE
var _utility_resume_paused: bool = false
var _utility_page: String = ""
var _active_level_up_level: int = 0
var _pending_level_up_levels: Array[int] = []
var _pending_relic_choices: Array[String] = []
var _active_relic_choice: String = ""
var _relic_choice_selected: bool = false
var _weapon_upgrade_miss_count: int = 0
var _wave_end_ready: bool = false
var _active_zone_selection_wave_number: int = 0
var _pending_zone_harvest_payload: Dictionary = {}
var _pending_interest_payload: Dictionary = {}
var _pending_finance_payload: Dictionary = {}
var _pending_wave_start_after_finance: bool = false
var _stat_preview: Dictionary = {}
var _active_shop_offer_ids: Array[String] = []
var _active_shop_offers: Dictionary = {}
var _wave_refresh_count: int = 0
var _total_refresh_count: int = 0
var _shop_generation: int = 0
var _preparation_offers: Array = []
var _transaction_busy: bool = false
var _trade_service := InventoryTradeService.new()

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
	current_difficulty_id = "standard"
	current_wave_index = -1
	current_wave_id = ""
	current_wave_duration_seconds = 0
	current_battle_summary.clear()
	current_victory = false
	battle_resolved = false
	_resume_state_after_modal = STATE_START_PAGE
	_utility_resume_state = STATE_START_PAGE
	_utility_resume_paused = false
	_utility_page = ""
	_active_level_up_level = 0
	_pending_level_up_levels.clear()
	_pending_relic_choices.clear()
	_active_relic_choice = ""
	_relic_choice_selected = false
	_weapon_upgrade_miss_count = 0
	_wave_end_ready = false
	_active_zone_selection_wave_number = 0
	_pending_zone_harvest_payload.clear()
	_pending_interest_payload.clear()
	_pending_finance_payload.clear()
	_pending_wave_start_after_finance = false
	_stat_preview.clear()
	_active_shop_offer_ids.clear()
	_active_shop_offers.clear()
	_wave_refresh_count = 0
	_total_refresh_count = 0
	_preparation_offers.clear()
	_transaction_busy = false
	_set_battle_runtime_paused(false)
	_set_mode(MODE_BOOT)
	_set_state(STATE_START_PAGE)
	_sync_bgm_for_flow()
	flow_reset.emit()


func enter_start_page() -> void:
	reset_flow()


func enter_battle_selection(character_id: String = "", start_weapon_ids: Array[String] = [], outgame_modifiers: Array = [], difficulty_id: String = "standard") -> void:
	current_character_id = _sanitize_text(character_id)
	current_start_weapon_ids = _sanitize_string_array(start_weapon_ids)
	current_outgame_modifiers = outgame_modifiers.duplicate(true)
	current_difficulty_id = _sanitize_text(difficulty_id)
	if current_difficulty_id.is_empty():
		current_difficulty_id = "standard"
	_set_mode(MODE_BATTLE)
	_set_state(STATE_CHARACTER_SELECT)


func confirm_character_selection() -> bool:
	if _bound_player == null or _bound_loadout == null:
		push_error("[MainFlowCoordinator] missing battle context before character confirm.")
		return false

	if current_character_id.is_empty():
		current_character_id = PlayerController.DEFAULT_CHARACTER_ID

	var player_ok := _bound_player.initialize_from_character(current_character_id, current_outgame_modifiers, current_start_weapon_ids)
	var loadout_ok: bool = _bound_loadout.initialize(_bound_player, _bound_wave_manager.finance_system if _bound_wave_manager != null else null)
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
	var started := request_next_wave()
	if started and CampProgression != null and CampProgression.has_method("has_unlock") and CampProgression.has_unlock("run_start_double_level"):
		request_shared_reward_shop_popup(2, "camp_start_level")
		request_shared_reward_shop_popup(3, "camp_start_level")
	return started


func bind_battle_context(player: PlayerController, loadout: WeaponLoadout, wave_manager: WaveManager = null) -> void:
	_unbind_battle_context()
	_bound_player = player
	_bound_loadout = loadout
	if _bound_player != null:
		var player_callable := Callable(self, "_on_player_died")
		if not _bound_player.died.is_connected(player_callable):
			_bound_player.died.connect(player_callable)
		if not _bound_player.stats_changed.is_connected(_queue_economy_refresh):
			_bound_player.stats_changed.connect(_queue_economy_refresh)
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
	if not _bound_wave_manager.relic_choice_requested.is_connected(_on_relic_choice_requested):
		_bound_wave_manager.relic_choice_requested.connect(_on_relic_choice_requested)


func bind_camp_context(camp_root: CampRoot) -> void:
	_bound_camp_root = camp_root


func enter_camp_flow(camp_root: CampRoot = null) -> void:
	if camp_root != null:
		bind_camp_context(camp_root)
	_set_mode(MODE_CAMP)
	_set_state(STATE_CAMP_ENTRY)


func enter_talents_flow() -> void:
	_set_mode(MODE_TALENTS)
	_set_state(STATE_TALENTS)


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
	return _request_wave_end_finance()


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
	_resume_state_after_modal = STATE_SHOP_POPUP if _wave_end_ready else current_state
	_set_battle_runtime_paused(true)
	_set_state(STATE_SHARED_REWARD_SHOP_POPUP)
	modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(level, source, false))


func close_shared_reward_shop_popup() -> void:
	if current_state != STATE_SHARED_REWARD_SHOP_POPUP:
		return
	if _active_relic_choice.is_empty():
		_restore_player_full_health()
	elif _bound_wave_manager != null:
		_bound_wave_manager.complete_relic_choice(_active_relic_choice, _relic_choice_selected)
	_active_relic_choice = ""
	_relic_choice_selected = false
	_active_shop_offers.clear()
	_active_shop_offer_ids.clear()
	modal_closed.emit(STATE_SHARED_REWARD_SHOP_POPUP)
	if not _pending_level_up_levels.is_empty():
		var next_level := int(_pending_level_up_levels.pop_front())
		_active_level_up_level = next_level
		modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(next_level, "queued", true))
		return
	_active_level_up_level = 0
	if _open_next_relic_choice():
		return
	if _wave_end_ready:
		_set_battle_runtime_paused(false)
		_finish_wave_rewards()
	else:
		_set_state(_resume_state_after_modal)
		_set_battle_runtime_paused(false)


func _on_relic_choice_requested(reward_id: String) -> void:
	if current_mode != MODE_BATTLE or battle_resolved or reward_id.is_empty():
		return
	if reward_id == _active_relic_choice or _pending_relic_choices.has(reward_id):
		return
	_pending_relic_choices.append(reward_id)
	if current_state in [STATE_WAVE_COMBAT, STATE_BATTLE_PREPARE] and not _transaction_busy:
		_resume_state_after_modal = current_state
		_open_next_relic_choice()


func _open_next_relic_choice() -> bool:
	if _pending_relic_choices.is_empty() or battle_resolved:
		return false
	_active_relic_choice = _pending_relic_choices.pop_front()
	_relic_choice_selected = false
	_active_level_up_level = 0
	_set_battle_runtime_paused(true)
	_set_state(STATE_SHARED_REWARD_SHOP_POPUP)
	modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(0, "miniboss_relic", true))
	return true


func _finish_wave_rewards() -> void:
	if not _has_next_wave():
		var gold := _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0
		present_battle_result(true, {"reason": "all_waves_cleared", "gold": gold})
	else:
		_enter_wave_end_shop()


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
	if _transaction_busy:
		return {"success": false, "reason": "transaction_busy"}
	if action not in ["deposit", "withdraw"]:
		return {"success": false, "reason": "invalid_action"}
	_transaction_busy = true
	var before := _bound_wave_manager.get_finance_popup_payload()
	var result := _bound_wave_manager.apply_finance_operation(action, amount)
	_transaction_busy = false
	result["source_balance_before"] = int(before.get("gold" if action == "deposit" else "principal", 0))
	_notify_preparation_changed()
	return result


func close_finance_popup() -> void:
	if current_state != STATE_FINANCE_POPUP or _transaction_busy:
		return
	clear_stat_preview()
	modal_closed.emit(STATE_FINANCE_POPUP)
	_pending_finance_payload.clear()
	_wave_end_ready = false
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
		_request_wave_end_finance()
	else:
		_set_state(STATE_BATTLE_PREPARE)


func request_esc_overlay() -> void:
	if current_mode != MODE_BATTLE or battle_resolved or _transaction_busy:
		return
	if current_state not in [STATE_WAVE_COMBAT, STATE_BATTLE_PREPARE, STATE_FINANCE_POPUP]:
		return
	_resume_state_after_modal = current_state
	clear_stat_preview()
	_set_battle_runtime_paused(true)
	_set_state(STATE_ESC_OVERLAY)
	modal_requested.emit(STATE_ESC_OVERLAY, {})


func close_esc_overlay() -> void:
	if current_state != STATE_ESC_OVERLAY:
		return
	modal_closed.emit(STATE_ESC_OVERLAY)
	_set_battle_runtime_paused(_resume_state_after_modal == STATE_FINANCE_POPUP)
	_set_state(_resume_state_after_modal)


func can_open_battle_utility(page: String) -> bool:
	if current_mode != MODE_BATTLE or battle_resolved or _transaction_busy:
		return false
	if page == "settings":
		return current_state in [STATE_WAVE_COMBAT, STATE_BATTLE_PREPARE, STATE_ESC_OVERLAY, STATE_SHARED_REWARD_SHOP_POPUP, STATE_FINANCE_POPUP, STATE_SHOP_POPUP]
	return page == "encyclopedia" and current_state in [STATE_WAVE_COMBAT, STATE_BATTLE_PREPARE]


func get_battle_display_state() -> String:
	return _utility_resume_state if current_state == STATE_BATTLE_UTILITY else current_state


func request_battle_utility(page: String) -> void:
	if not can_open_battle_utility(page):
		return
	# Keep the underlying reward/ESC return state intact when stacking settings.
	_utility_resume_state = current_state
	_utility_resume_paused = bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	_utility_page = page
	_set_battle_runtime_paused(true)
	_set_state(STATE_BATTLE_UTILITY)
	modal_requested.emit(STATE_BATTLE_UTILITY, {"page": page, "return_state": _utility_resume_state})


func close_battle_utility() -> void:
	if current_state != STATE_BATTLE_UTILITY:
		return
	var resume_state := _utility_resume_state
	var resume_paused := _utility_resume_paused
	modal_closed.emit(STATE_BATTLE_UTILITY)
	_utility_page = ""
	_set_state(resume_state)
	_set_battle_runtime_paused(resume_paused)


func return_to_main_menu_from_settings() -> void:
	if current_state != STATE_BATTLE_UTILITY or _utility_page != "settings" or _transaction_busy:
		return
	battle_resolved = true
	if _bound_wave_manager != null:
		_bound_wave_manager.running = false
		_bound_wave_manager.drop_reward_system.begin_wave()
		_bound_wave_manager.clear_battle_entities()
	for modal in [STATE_BATTLE_UTILITY, STATE_SHARED_REWARD_SHOP_POPUP, STATE_SHOP_POPUP, STATE_FINANCE_POPUP, STATE_ESC_OVERLAY]:
		modal_closed.emit(modal)
	# Abandon the run without invoking victory/loss settlement or granting choices.
	reset_flow()


func submit_shop_purchase(offer: Dictionary, mode: String) -> Dictionary:
	if current_state not in [STATE_FINANCE_POPUP, STATE_SHOP_POPUP, STATE_SHARED_REWARD_SHOP_POPUP] or _transaction_busy:
		return {"success": false, "reason": "shop_not_active"}
	var sanitized_mode := str(mode).strip_edges()
	var expected_mode := "free" if current_state == STATE_SHARED_REWARD_SHOP_POPUP else "shop"
	if sanitized_mode != expected_mode:
		return {"success": false, "reason": "invalid_shop_mode"}
	var offer_id := str(offer.get("offer_id", "")).strip_edges()
	if offer_id.is_empty() or not _active_shop_offers.has(offer_id):
		return {"success": false, "reason": "invalid_offer"}
	var canonical_offer: Dictionary = _active_shop_offers.get(offer_id, {})
	if sanitized_mode == "shop":
		var shown_cost := int(offer.get("shop_cost", 0))
		HumanityEconomy.reprice_offer(canonical_offer, _get_shop_stat("humanity"))
		if shown_cost != int(canonical_offer.get("shop_cost", 0)):
			_notify_preparation_changed()
			return {"success": false, "reason": "shop_price_changed"}
	var offer_type := str(canonical_offer.get("offer_type", ""))
	var target_id := str(canonical_offer.get("target_id", ""))
	if offer_type.is_empty() or target_id.is_empty():
		return {"success": false, "reason": "invalid_offer"}
	var unavailable := get_offer_unavailable_reason(canonical_offer, false)
	if not unavailable.is_empty():
		return {"success": false, "reason": unavailable}
	_transaction_busy = true
	if sanitized_mode == "shop" and not _try_pay_shop_cost(canonical_offer):
		_transaction_busy = false
		return {"success": false, "reason": "insufficient_gold"}
	var applied := _apply_shop_offer(offer_type, target_id, canonical_offer)
	if not applied:
		if sanitized_mode == "shop":
			_refund_shop_cost(canonical_offer)
		_transaction_busy = false
		return {"success": false, "reason": "purchase_failed"}
	if sanitized_mode == "shop" and _bound_loadout != null:
		var bought_weapon := _bound_loadout.get_weapon_instance(target_id)
		if bought_weapon != null:
			if offer_type == ShopOfferGenerator.OFFER_NEW_WEAPON:
				bought_weapon.trade_base_basis = int(canonical_offer.get("shop_cost", 0))
			elif offer_type == ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
				bought_weapon.trade_upgrade_basis[bought_weapon.level] = int(canonical_offer.get("shop_cost", 0))
	_active_shop_offers.erase(offer_id)
	canonical_offer["purchased"] = true
	_transaction_busy = false
	clear_stat_preview()
	if sanitized_mode == "free":
		_relic_choice_selected = not _active_relic_choice.is_empty()
		close_shared_reward_shop_popup()
	else:
		_notify_preparation_changed()
	return {"success": true, "action": "purchase", "offer_id": offer_id, "offer_type": offer_type, "target_id": target_id}


func mark_wave_end_ready() -> void:
	_wave_end_ready = true
	_pending_interest_payload = _bound_wave_manager.get_finance_snapshot() if _bound_wave_manager != null else {}
	_pending_interest_payload["settlement_results"] = _pending_interest_payload.get("last_settlement_results", [])
	if current_state == STATE_SHARED_REWARD_SHOP_POPUP:
		_resume_state_after_modal = STATE_SHOP_POPUP
		return
	_resume_state_after_modal = STATE_SHOP_POPUP
	if not _pending_level_up_levels.is_empty() and not battle_resolved:
		var next_level := int(_pending_level_up_levels.pop_front())
		_active_level_up_level = next_level
		_resume_state_after_modal = STATE_SHOP_POPUP
		_set_battle_runtime_paused(true)
		_set_state(STATE_SHARED_REWARD_SHOP_POPUP)
		modal_requested.emit(STATE_SHARED_REWARD_SHOP_POPUP, _build_shared_reward_shop_payload(next_level, "wave_end_absorb", false))
	elif _open_next_relic_choice():
		return
	elif not battle_resolved:
		_finish_wave_rewards()


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
	_pending_relic_choices.clear()
	_active_relic_choice = ""
	_relic_choice_selected = false
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
	var finance := _bound_wave_manager.finance_system if _bound_wave_manager != null else null
	var cost := 0 if current_state == STATE_SHARED_REWARD_SHOP_POPUP else int(offer.get("shop_cost", 0))
	_stat_preview = StatPreviewBuilder.build_offer_stat_preview(offer, _bound_player, finance, cost)


func clear_stat_preview() -> void:
	_stat_preview.clear()


func get_stat_preview() -> Dictionary:
	return _stat_preview.duplicate(true)


func get_bound_player() -> PlayerController:
	return _bound_player


func get_bound_loadout() -> WeaponLoadout:
	return _bound_loadout


func get_current_gold() -> int:
	return _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0


func get_shop_refresh_cost() -> int:
	var wave_number := maxi(current_wave_index + 1, 1)
	var first_refresh_cost := 3.0 + float(wave_number) * 0.5 + float(_total_refresh_count) * 0.25
	var in_wave_refresh_count := float(_wave_refresh_count)
	var in_wave_growth := in_wave_refresh_count * 4.0 + in_wave_refresh_count * in_wave_refresh_count * 2.0
	return int(ceil(first_refresh_cost + in_wave_growth))


func request_shop_refresh() -> Dictionary:
	if current_state not in [STATE_FINANCE_POPUP, STATE_SHOP_POPUP, STATE_SHARED_REWARD_SHOP_POPUP] or _transaction_busy:
		return {"success": false, "reason": "shop_not_active"}
	var cost := get_shop_refresh_cost()
	if _bound_wave_manager == null or _bound_wave_manager.get_current_gold() < cost:
		return {"success": false, "reason": "insufficient_gold_for_refresh"}
	_transaction_busy = true
	if not _bound_wave_manager.apply_gold_delta(-cost, "shop_refresh"):
		_transaction_busy = false
		return {"success": false, "reason": "insufficient_gold_for_refresh"}
	_wave_refresh_count += 1
	_total_refresh_count += 1
	var payload: Dictionary = {}
	if current_state == STATE_SHARED_REWARD_SHOP_POPUP:
		payload = _build_shared_reward_shop_payload(_active_level_up_level, "refresh", false, _active_shop_offer_ids)
	else:
		var previous_ids: Array = []
		for previous in _preparation_offers:
			previous_ids.append(str(previous.get("candidate_id", "")))
		payload = _build_shop_payload("shop", 0, previous_ids)
	_transaction_busy = false
	clear_stat_preview()
	if current_state == STATE_FINANCE_POPUP:
		_preparation_offers = payload.get("offers", [])
		_notify_preparation_changed()
	else:
		modal_requested.emit(current_state, payload)
	return {"success": true, "cost": cost, "refresh_count": _wave_refresh_count, "total_refresh_count": _total_refresh_count}


func get_current_mode() -> String:
	return current_mode


func get_current_state() -> String:
	return current_state


func get_zone_selection_payload() -> Dictionary:
	if current_state != STATE_ZONE_SELECT or _active_zone_selection_wave_number <= 0:
		return {}
	return ZoneProgression.build_zone_selection_payload(_active_zone_selection_wave_number)


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
	_request_wave_end_finance()


func _request_wave_end_finance() -> bool:
	if current_mode != MODE_BATTLE or battle_resolved or _bound_wave_manager == null:
		return false
	if not _has_next_wave():
		return false
	var next_wave_number := _get_next_wave_number()
	_pending_wave_start_after_finance = true
	_pending_finance_payload = _bound_wave_manager.prepare_finance_for_wave(next_wave_number)
	_preparation_offers = _build_shop_payload("shop", 0).get("offers", [])
	_set_battle_runtime_paused(true)
	_set_state(STATE_FINANCE_POPUP)
	modal_requested.emit(STATE_FINANCE_POPUP, get_preparation_payload())
	return true


func _on_wave_started(wave_id: String, duration_seconds: int) -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	current_wave_index += 1
	_wave_refresh_count = 0
	current_wave_id = wave_id
	current_wave_duration_seconds = duration_seconds
	_pending_finance_payload.clear()
	_pending_wave_start_after_finance = false
	_set_battle_runtime_paused(false)
	_set_state(STATE_WAVE_COMBAT)


func _on_wave_finished(wave_id: String) -> void:
	if current_mode != MODE_BATTLE or battle_resolved:
		return
	_restore_player_full_health()
	current_wave_id = wave_id
	mark_wave_end_ready()


func _on_wave_end_absorb_started(_wave_id: String) -> void:
	if current_mode == MODE_BATTLE and not battle_resolved:
		_set_state(STATE_WAVE_END_ABSORB)


func _on_shared_reward_shop_requested(level: int) -> void:
	request_shared_reward_shop_popup(level, "shared_reward_shop_requested")


func _on_player_died() -> void:
	var gold := _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0
	present_battle_result(false, {"reason": "player_died", "gold": gold})


func _restore_player_full_health() -> void:
	if _bound_player != null and _bound_player.is_alive():
		_bound_player.restore_full_health()


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
	_sync_bgm_for_flow()
	state_changed.emit(previous_state, current_state)


func _sync_bgm_for_flow() -> void:
	if AudioManager == null:
		return
	var bgm_id := "menu"
	if current_mode == MODE_BATTLE and current_state != STATE_CHARACTER_SELECT:
		bgm_id = "battle"
	AudioManager.play_bgm(bgm_id)


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
	if _bound_player.stats_changed.is_connected(_queue_economy_refresh):
		_bound_player.stats_changed.disconnect(_queue_economy_refresh)
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
	if _bound_wave_manager.relic_choice_requested.is_connected(_on_relic_choice_requested):
		_bound_wave_manager.relic_choice_requested.disconnect(_on_relic_choice_requested)
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


func _build_shared_reward_shop_payload(level: int, source: String, queued: bool, exclude_offer_ids: Array = []) -> Dictionary:
	var payload := _build_shop_payload("free", level, exclude_offer_ids)
	payload["source"] = source
	payload["queued"] = queued
	payload["resume_state"] = _resume_state_after_modal
	if not _active_relic_choice.is_empty():
		payload["title"] = "小 Boss 遗物奖励"
		payload["choice_id"] = _active_relic_choice
	return payload


func _build_shop_payload(mode: String, level: int, exclude_offer_ids: Array = []) -> Dictionary:
	var context := _build_shop_context()
	var offers: Array = []
	var relic_only := mode == "free" and not _active_relic_choice.is_empty()
	var offer_count := StatDefinitions.calculate_shop_offer_count(BASE_SHOP_OFFER_COUNT, _get_shop_stat("shop_offer_count_bonus"))
	_shop_generation += 1
	if mode == "shop":
		offer_count = maxi(3, offer_count)
	if not context.is_empty():
		var generator := ShopOfferGenerator.new()
		var candidates := generator.build_shop_candidate_pool(context)
		if relic_only:
			var relic_candidates: Array[Dictionary] = []
			for candidate in candidates:
				if str(candidate.get("offer_type", "")) == ShopOfferGenerator.OFFER_RELIC:
					relic_candidates.append(candidate)
			candidates = relic_candidates
		var exclude_set := {}
		for exclude_id in exclude_offer_ids:
			var exclude_text := str(_active_shop_offers.get(str(exclude_id), {}).get("base_offer_id", exclude_id)).strip_edges()
			if not exclude_text.is_empty():
				exclude_set[exclude_text] = true
		if mode == "free" and not exclude_set.is_empty():
			var filtered_candidates: Array[Dictionary] = []
			for candidate in candidates:
				if not exclude_set.has(str(candidate.get("offer_id", ""))):
					filtered_candidates.append(candidate)
			candidates = filtered_candidates
		var rarity_weights := generator.get_shop_rarity_weights(int(_get_shop_stat("luck")), ZoneProgression.get_current_zone_rarity_bonus())
		context["candidate_pool"] = candidates
		var type_weights := generator.get_shop_type_weights(context)
		if mode == "shop":
			offers = generator.roll_paid_offers(rarity_weights, type_weights, candidates, offer_count, _shop_generation, exclude_offer_ids)
		else:
			offers = generator.roll_shop_offers(rarity_weights, type_weights, candidates, offer_count)
		if not relic_only:
			_update_weapon_upgrade_miss_count(candidates, offers)
	_active_shop_offer_ids.clear()
	_active_shop_offers.clear()
	for offer in offers:
		if offer is Dictionary:
			if relic_only:
				offer["base_offer_id"] = str(offer.get("offer_id", ""))
				offer["offer_id"] = "%s:%d:%s" % [_active_relic_choice, _shop_generation, offer["base_offer_id"]]
			if mode == "shop" and str(offer.get("offer_type", "")) == ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
				var weapon := _bound_loadout.get_weapon_instance(str(offer.get("target_id", "")))
				if weapon != null: offer["weapon_instance_id"] = weapon.instance_id
			var active_offer_id := str(offer.get("offer_id", ""))
			if not active_offer_id.is_empty():
				_active_shop_offer_ids.append(active_offer_id)
				_active_shop_offers[active_offer_id] = offer
	return {
		"mode": str(mode).strip_edges(),
		"level": maxi(0, level),
		"gold": _bound_wave_manager.get_current_gold() if _bound_wave_manager != null else 0,
		"offers": offers,
		"offer_count": offer_count,
		"resume_state": _resume_state_after_modal,
		"refresh_cost": get_shop_refresh_cost(),
		"refresh_count": _wave_refresh_count,
		"total_refresh_count": _total_refresh_count,
	}


func _build_shop_context() -> Dictionary:
	if _bound_player == null or _bound_loadout == null:
		return {}
	var owned_weapon_ids: Array[String] = []
	var equipped_weapons: Array[Dictionary] = []
	for weapon in _bound_loadout.get_weapon_instances():
		owned_weapon_ids.append(weapon.weapon_id)
		equipped_weapons.append({"weapon_id": weapon.weapon_id, "level": weapon.level})
	var relic_counts := _bound_player.get_relic_counts()
	return {
		"owned_weapon_ids": owned_weapon_ids,
		"equipped_weapons": equipped_weapons,
		"unlocked_weapon_ids": [],
		"unlocked_relic_ids": [],
		"owned_relic_counts": _bound_player.get_relic_counts(),
		"current_load": _bound_loadout.get_total_load_cost(),
		"load_capacity": _bound_loadout.get_load_capacity(),
		"luck": _get_shop_stat("luck"),
		"weapon_upgrade_miss_count": _weapon_upgrade_miss_count,
		"shop_price_percent": _get_shop_stat("shop_price_percent"),
		"humanity": _get_shop_stat("humanity"),
		"shop_price_discounts": _get_shop_discount_layers(),
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


func _get_shop_discount_layers() -> Array[float]:
	if _bound_player == null:
		return []
	return _bound_player.get_shop_price_discount_layers()


func _try_pay_shop_cost(offer: Dictionary) -> bool:
	var cost := int(offer.get("shop_cost", 0))
	if cost <= 0:
		return true
	if _bound_wave_manager == null or _bound_wave_manager.get_current_gold() < cost:
		return false
	return _bound_wave_manager.apply_gold_delta(-cost, "shop_purchase")


func get_preparation_payload() -> Dictionary:
	var payload := _bound_wave_manager.get_finance_popup_payload("preparation") if _bound_wave_manager != null else {}
	for offer in _preparation_offers:
		HumanityEconomy.reprice_offer(offer, _get_shop_stat("humanity"))
	payload["offers"] = _preparation_offers
	payload["offer_generation"] = _shop_generation
	payload["refresh_cost"] = get_shop_refresh_cost()
	payload["settlement_results"] = _pending_interest_payload.get("settlement_results", [])
	return payload


func _notify_preparation_changed() -> void:
	if current_state == STATE_FINANCE_POPUP:
		preparation_changed.emit(get_preparation_payload())


func _queue_economy_refresh() -> void:
	if current_state != STATE_FINANCE_POPUP or _transaction_busy or _economy_refresh_queued:
		return
	_economy_refresh_queued = true
	_refresh_economy_ui.call_deferred()


func _refresh_economy_ui() -> void:
	_economy_refresh_queued = false
	_notify_preparation_changed()


func get_bank_stat_preview(action: String, amount: int) -> String:
	if _bound_player == null or _bound_wave_manager == null or _bound_wave_manager.finance_system == null:
		return ""
	var preview_player := _bound_player.create_stat_preview_copy()
	var finance := _bound_wave_manager.finance_system
	var preview := finance.create_preview_copy(preview_player)
	var result := preview.apply_finance_operation(action, amount)
	var lines: Array[String] = []
	if bool(result.get("success", false)):
		lines.append("办理后本金：%d → %d" % [finance.principal, preview.principal])
		for stat_id in ["armor", "attack_speed", "damage_percent", "load_capacity"]:
			var before := _bound_player.get_stat(stat_id)
			var after := preview_player.get_stat(stat_id)
			if not is_equal_approx(before, after):
				var name := str(StatDefinitions.get_stat_definition(stat_id).get("display_name", stat_id))
				var unit := "%" if stat_id == "damage_percent" else ""
				lines.append("%s：%s%s → %s%s" % [name, HumanityEconomy.number(before), unit, HumanityEconomy.number(after), unit])
	preview_player.free()
	return "\n".join(lines)


func get_offer_unavailable_reason(offer: Dictionary, check_gold: bool = true) -> String:
	if bool(offer.get("purchased", false)):
		return "already_purchased"
	var target := str(offer.get("target_id", ""))
	match str(offer.get("offer_type", "")):
		ShopOfferGenerator.OFFER_NEW_WEAPON:
			if _bound_loadout == null or _bound_loadout.has_weapon(target):
				return "weapon_already_owned"
			if not _bound_loadout.can_add_weapon(target):
				return "load_capacity_exceeded"
		ShopOfferGenerator.OFFER_WEAPON_UPGRADE:
			var weapon := _bound_loadout.get_weapon_instance(target) if _bound_loadout != null else null
			if weapon == null or weapon.level != int(offer.get("from_level", 0)):
				return "upgrade_no_longer_available"
			if offer.has("weapon_instance_id") and str(offer["weapon_instance_id"]) != weapon.instance_id:
				return "upgrade_no_longer_available"
		ShopOfferGenerator.OFFER_RELIC:
			var record := DataRegistry.get_record("relics", target)
			var limit := int(record.get("max_stack", 0))
			if _bound_player != null and limit > 0 and _bound_player.get_relic_count(target) >= limit:
				return "relic_stack_limit"
	if check_gold and int(offer.get("shop_cost", 0)) > get_current_gold():
		return "insufficient_gold"
	return ""


func submit_enchantment_operation(action: String, weapon_id: String, item_id: String, target_index: int = -1) -> Dictionary:
	if current_state != STATE_FINANCE_POPUP or _bound_loadout == null or _transaction_busy:
		return {"success": false, "reason": "enchantment_page_required"}
	if action == "attach" and _bound_player != null:
		var weapon := _bound_loadout.get_weapon_instance(weapon_id)
		var item := _bound_player.item_inventory.find_item(item_id)
		if weapon != null and not weapon.get_attachment_incompatibility(item).is_empty():
			return {"success": false, "reason": "incompatible_enchantment"}
	_transaction_busy = true
	var success := false
	if action == "attach":
		success = _bound_loadout.request_manual_attachment(weapon_id, item_id)
	elif action == "detach":
		success = not _bound_loadout.request_manual_detachment(weapon_id, item_id).is_empty()
	elif action == "move":
		success = _bound_loadout.request_manual_attachment_move(weapon_id, item_id, target_index)
	_transaction_busy = false
	clear_stat_preview()
	_notify_preparation_changed()
	return {"success": success, "reason": "" if success else "attachment_failed"}


func get_inventory_sale_quote(kind: String, target_id: String) -> Dictionary:
	if current_state != STATE_FINANCE_POPUP or _bound_player == null or _bound_loadout == null:
		return {"success": false, "reason": "enchantment_page_required"}
	var quote: Dictionary = {}
	if kind == "weapon":
		if _bound_loadout.get_weapon_instances().size() <= 1:
			return {"success": false, "reason": "last_weapon"}
		quote = _trade_service.quote_weapon(_bound_loadout.get_weapon_instance(target_id), _bound_player.get_stat("humanity"))
	elif kind == "enchantment":
		var item := _bound_player.item_inventory.find_item(target_id)
		if not str(item.get("equipped_weapon_id", "")).is_empty():
			return {"success": false, "reason": "detach_before_sale"}
		quote = _trade_service.quote_item(item, _bound_player.get_stat("humanity"))
	if quote.is_empty():
		return {"success": false, "reason": "item_not_found"}
	quote["success"] = true
	return quote


func submit_inventory_sale(kind: String, target_id: String, quote_token: String) -> Dictionary:
	if _transaction_busy or _bound_wave_manager == null:
		return {"success": false, "reason": "transaction_busy"}
	var quote := get_inventory_sale_quote(kind, target_id)
	if not bool(quote.get("success", false)):
		return quote
	if str(quote.get("quote_token", "")) != quote_token:
		return {"success": false, "reason": "sale_quote_changed"}
	_transaction_busy = true
	var weapon: WeaponInstance = null
	var weapon_index := -1
	var item: Dictionary = {}
	if kind == "weapon":
		weapon_index = _bound_loadout.weapon_instances.find(_bound_loadout.get_weapon_instance(target_id))
		weapon = _bound_loadout.take_weapon_for_trade(target_id)
	else:
		item = _bound_player.item_inventory.take_unequipped_item_for_trade(target_id)
	var removed := weapon != null or not item.is_empty()
	var paid := removed and _bound_wave_manager.apply_gold_delta(int(quote.get("total", 0)), "inventory_sale")
	if not paid:
		if weapon != null:
			_bound_loadout.restore_traded_weapon(weapon, weapon_index)
		if not item.is_empty():
			_bound_player.item_inventory.restore_traded_item(item)
	elif weapon != null:
		_bound_loadout.finish_weapon_removal(weapon)
	else:
		_bound_player.item_inventory.items_changed.emit()
	_transaction_busy = false
	clear_stat_preview()
	_notify_preparation_changed()
	return {"success": paid, "reason": "" if paid else "sale_failed", "gold_gained": int(quote.get("total", 0)) if paid else 0}


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
			var weapon: WeaponInstance = _bound_loadout.get_weapon_instance(target_id)
			if weapon == null or weapon.level != int(offer.get("from_level", 0)):
				return false
			return _bound_loadout.upgrade_weapon(target_id)
		_:
			return false
