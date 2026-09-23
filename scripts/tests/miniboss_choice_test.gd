extends Node

class GuaranteedDrops extends DropRewardSystem:
	func _roll_drop_chance(chance: float) -> bool:
		return chance > 0.0

var failures: int = 0
var checks: int = 0
var flow: MainFlowCoordinator
var manager: WaveManager
var player: PlayerController
var loadout: WeaponLoadout
var last_payload: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("PASS " if value else "FAIL ", label)

func drop() -> RelicPickup:
	for action in manager.drop_reward_system.build_drop_actions("drop_elite_enemy", player):
		if action.type == "relic":
			return manager.drop_reward_system.spawn_action(action, Vector2(3000, 0), manager, player, manager.reward_snapshot) as RelicPickup
	return null

func remember(_state: String, payload: Dictionary) -> void:
	last_payload = payload

func all_relics() -> bool:
	if last_payload.get("offers", []).is_empty():
		return false
	for offer in last_payload.offers:
		if offer.offer_type != ShopOfferGenerator.OFFER_RELIC:
			return false
	return true

func choose() -> Dictionary:
	return flow.submit_shop_purchase(last_payload.offers[0], "free")

func _run() -> void:
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	loadout = WeaponLoadout.new()
	add_child(loadout)
	loadout.initialize(player)
	loadout.set_physics_process(false)
	manager = WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.drop_reward_system = GuaranteedDrops.new()
	manager.initialize(player)
	flow = MainFlowCoordinator.new()
	add_child(flow)
	flow.bind_battle_context(player, loadout, manager)
	flow.current_mode = MainFlowCoordinator.MODE_BATTLE
	flow.modal_requested.connect(remember)
	manager.start_next_wave()
	var first := drop()
	var second := drop()
	check(first != null and second != null and player.get_relic_counts().is_empty(), "ground drops do not select or grant a relic")
	check(first.collect(), "first pickup creates a choice")
	check(flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and all_relics(), "reuse upgrade popup with relic-only candidates")
	check(last_payload.offers.size() == 3 and last_payload.has("choice_id"), "default three choices carry an independent reward identity")
	check(bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)), "choice pauses combat")
	var first_offer: Dictionary = last_payload.offers[0].duplicate(true)
	check(second.collect() and flow._pending_relic_choices.size() == 1, "second pickup queues without overwriting current choices")
	flow.request_shared_reward_shop_popup(2)
	var level_before := manager.player_level
	var total_before := player.relic_system.get_total_relic_count()
	check(bool(choose().success) and player.relic_system.get_total_relic_count() == total_before + 1, "selecting grants exactly one free relic")
	check(flow._active_relic_choice.is_empty() and flow._active_level_up_level == 2, "queued level-up remains an ordinary upgrade reward")
	check(not flow.submit_shop_purchase(first_offer, "free").success, "previous relic card cannot select a following reward")
	flow.close_shared_reward_shop_popup()
	check(not flow._active_relic_choice.is_empty() and all_relics(), "next ground reward opens after queued upgrade")
	check(manager.player_level == level_before, "relic choice does not fabricate a level-up")
	var token := flow._active_relic_choice
	var old_ids: Array = flow._active_shop_offer_ids.duplicate()
	var upgrade_misses := flow._weapon_upgrade_miss_count
	manager.current_gold = 1000
	var gold_before := manager.current_gold
	var refresh_cost := flow.get_shop_refresh_cost()
	check(bool(flow.request_shop_refresh().success) and manager.current_gold == gold_before - refresh_cost, "reuse paid refresh at its displayed price")
	check(flow._active_relic_choice == token and all_relics() and flow._weapon_upgrade_miss_count == upgrade_misses, "refresh preserves choice token and does not affect weapon upgrade guarantee")
	check(not flow._active_shop_offer_ids.has(old_ids[0]), "refresh invalidates stale card IDs")
	var popup := load("res://scenes/ui/shop/shop_popup.tscn").instantiate() as ShopPopup
	add_child(popup)
	popup.set_bond_player(player)
	popup.set_loadout(loadout)
	popup.configure(last_payload)
	popup.show_popup()
	check(popup.title_label.text == last_payload.title and popup.get_mode() == "free", "existing popup shows miniboss title and free selection mode")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			get_tree().root.size = Vector2i(1280, 720)
			get_tree().root.content_scale_size = Vector2i(1280, 720)
			popup.set_safe_rect(Rect2(20, 20, 1240, 680))
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	popup.free()
	player.current_hp = 3
	flow.close_shared_reward_shop_popup()
	check(player.current_hp == 3 and manager._pending_relic_choices.is_empty(), "skipping consumes only one choice and gives no free heal")
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT, "queue completion resumes combat")
	drop()
	drop()
	manager.finish_current_wave()
	check(flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP and manager._pending_relic_choices.size() == 2, "wave-end auto-pickups become sequential choices before preparation")
	check(bool(choose().success) and flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP, "first wave-end choice leaves second open")
	check(bool(choose().success) and flow.current_state == MainFlowCoordinator.STATE_FINANCE_POPUP, "all choices complete before finance opens")
	check(manager.reward_snapshot.selected_relics == 3, "snapshot counts selected relics separately from collected tokens")
	manager.current_wave_index = 18
	flow.current_wave_index = 18
	manager.start_next_wave()
	drop()
	drop()
	manager.finish_current_wave()
	check(not flow.battle_resolved and flow.current_state == MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP, "final wave waits for reward choices before victory")
	choose()
	check(not flow.battle_resolved, "final victory still waits for last reward")
	choose()
	check(flow.battle_resolved and flow.current_victory, "final reward completes then victory appears")
	flow.reset_flow()
	check(flow._pending_relic_choices.is_empty() and flow._active_relic_choice.is_empty(), "reset clears all choice state")
	flow.free()
	manager.free()
	loadout.free()
	player.free()
	await get_tree().process_frame
	print("MINIBOSS_CHOICE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
