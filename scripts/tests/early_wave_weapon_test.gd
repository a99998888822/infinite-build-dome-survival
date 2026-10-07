extends Node
## Shared early-wave weapon guarantees, including legal stock and paid identities.

class OfferFlow extends MainFlowCoordinator:
	func _sync_bgm_for_flow() -> void:
		pass # This isolated offer test does not exercise audio playback.

var failures := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func weapons(offers: Array) -> Array:
	return offers.filter(func(offer: Dictionary): return offer.offer_type == ShopOfferGenerator.OFFER_NEW_WEAPON)

func _run() -> void:
	CampProgression.begin_transient_session()
	var player := preload("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var loadout := WeaponLoadout.new()
	add_child(loadout)
	loadout.initialize(player)
	var flow := OfferFlow.new()
	add_child(flow)
	flow.bind_battle_context(player, loadout)
	var generator := ShopOfferGenerator.new()
	for mode in ["free", "shop"]:
		for wave_index in [0, 1]:
			for sample in 64:
				seed(4100 + sample)
				flow.current_wave_index = wave_index
				flow._early_wave_weapon_offered.clear()
				var offers: Array = flow._build_shop_payload(mode, 2).offers
				check(offers.size() == 3 and weapons(offers).size() == 1, "first offer guarantees one new weapon at normal shelf size")
				for weapon: Dictionary in weapons(offers):
					check(loadout.get_weapon_instance(str(weapon.target_id)) == null, "guaranteed weapon is not owned")
					check(loadout.get_total_load_cost() + int(weapon.load_cost) <= loadout.get_load_capacity(), "guaranteed weapon fits remaining load")
					check(flow._active_shop_offers.has(str(weapon.offer_id)), "guaranteed offer is registered for normal purchase")
					if mode == "shop":
						check(str(weapon.offer_id).begins_with("shelf:") and weapon.has("candidate_id") and not weapon.purchased and int(weapon.shop_cost) > 0, "paid guarantee retains stock identity and price")
				check(flow._early_wave_weapon_offered.has(wave_index), "showing the weapon consumes this wave guarantee")
				var remembered := flow._early_wave_weapon_offered.duplicate()
				flow._build_shop_payload("shop" if mode == "free" else "free", 3)
				check(flow._early_wave_weapon_offered == remembered, "reward and shop share the same guarantee")
	flow._early_wave_weapon_offered = {0: true}
	flow.current_wave_index = 1
	check(weapons(flow._build_shop_payload("free", 3).offers).size() == 1 and flow._early_wave_weapon_offered.has(1), "second wave gets its own guarantee")
	flow._early_wave_weapon_offered.clear()
	flow._active_relic_choice = "boss_fixture"
	check(flow._build_shop_payload("free", 0).offers.all(func(offer): return offer.offer_type == ShopOfferGenerator.OFFER_RELIC), "boss reward remains relic only")
	check(flow._early_wave_weapon_offered.is_empty(), "boss reward cannot consume the weapon guarantee")
	flow._active_relic_choice = ""
	var capacity := player.get_stat("load_capacity")
	player.modifier_stack.set_base_stat("load_capacity", loadout.get_total_load_cost())
	check(weapons(flow._build_shop_payload("free", 2).offers).is_empty() and flow._early_wave_weapon_offered.is_empty(), "no illegal weapon when load is full, guarantee stays pending")
	player.modifier_stack.set_base_stat("load_capacity", capacity)
	check(weapons(flow._build_shop_payload("shop", 0).offers).size() == 1, "pending guarantee can fall back to the shop")
	var context := flow._build_shop_context()
	var candidates := generator.build_shop_candidate_pool(context)
	var rarity := generator.get_shop_rarity_weights(0)
	var relic_weights := {"new_weapon": 0, "weapon_upgrade": 0, "relic": 1}
	check(weapons(generator.roll_shop_offers(rarity, relic_weights, candidates, 3, true)).size() == 1, "guarantee bypasses low type odds")
	check(weapons(generator.roll_shop_offers(rarity, relic_weights, candidates, 3)).is_empty(), "ordinary rolls retain their weights")
	var strong := generator.roll_paid_offers(rarity, relic_weights, candidates, 3, 900, [], "epic", true)
	check(strong.size() == 3 and strong[0].rarity == "epic" and strong[0].offer_type == "relic" and weapons(strong).size() == 1, "strong refresh relic and weapon guarantees coexist")
	flow.current_wave_index = 2
	flow._early_wave_weapon_offered.clear()
	var ordinary_misses := 0
	for sample in 32:
		seed(7100 + sample)
		if weapons(flow._build_shop_payload("free", 5).offers).is_empty(): ordinary_misses += 1
	check(ordinary_misses > 0 and flow._early_wave_weapon_offered.is_empty(), "wave three uses ordinary probability")
	flow._early_wave_weapon_offered = {0: true, 1: true}
	flow.reset_flow()
	check(flow._early_wave_weapon_offered.is_empty(), "new run resets guarantee history")
	flow.queue_free()
	loadout.queue_free()
	player.queue_free()
	await get_tree().process_frame
	CampProgression.end_transient_session()
	print("EARLY_WAVE_WEAPON_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
