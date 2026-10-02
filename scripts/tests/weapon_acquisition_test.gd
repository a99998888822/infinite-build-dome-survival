extends Node

var checks := 0
var failures := 0
var output := ""
var baseline_path := ""
var pools: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		if arg.begins_with("--baseline-script="): baseline_path = arg.trim_prefix("--baseline-script=")
	_run.call_deferred()


func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(note)


func context_for(owned: Array) -> Dictionary:
	var equipped: Array = []
	var total_load := 0
	for id in owned:
		equipped.append({"weapon_id":id, "level":1})
		total_load += int(DataRegistry.get_record("weapons", id).load_cost)
	return {"owned_weapon_ids":owned.duplicate(), "equipped_weapons":equipped,
		"current_load":total_load, "load_capacity":100, "luck":0}


func _run() -> void:
	var generator := ShopOfferGenerator.new()
	var owned: Array = ["weapon_void_blade"]
	var context := context_for(owned)
	var candidates := generator.build_shop_candidate_pool(context)
	context.candidate_pool = candidates
	var paid := generator.get_shop_type_weights(context)
	context.offer_mode = "free"
	var free := generator.get_shop_type_weights(context)
	check(free.new_weapon < paid.new_weapon, "free rewards must be less weapon-heavy than paid shelves")
	check(float(free.new_weapon) / (free.new_weapon + free.relic + free.weapon_upgrade) < 0.1, "opening free weapon slot chance stays below ten percent")
	for id in ["weapon_camp_dagger", "weapon_nightwatch_spear", "weapon_mutant_tentacle"]:
		owned.append(id)
		var next := context_for(owned)
		next.candidate_pool = generator.build_shop_candidate_pool(next)
		next.offer_mode = "free"
		var weights := generator.get_shop_type_weights(next)
		check(weights.new_weapon <= free.new_weapon, "owning more weapons never raises their reward weight")
		free = weights
		next.zone_target_pools = ["weapon", "relic"]
		next.zone_tag_weight_bonus = 2000
		check(generator.get_shop_type_weights(next).new_weapon == free.new_weapon, "zone streak cannot erase the ownership reduction")
	var rarity := generator.get_shop_rarity_weights(0)
	var pressure := {"new_weapon":1000000,"relic":1,"weapon_upgrade":1}
	var valid_batches := true
	var unique_shelves := true
	for i in 100:
		for mode in ["free", "shop"]:
			var offers := generator.roll_shop_offers(rarity, pressure, candidates, 8) if mode == "free" else generator.roll_paid_offers(rarity, pressure, candidates, 8, i)
			valid_batches = valid_batches and offers.size() == 8 and offers.filter(func(o): return o.offer_type == "new_weapon").size() <= 1
			var ids := {}
			for offer in offers: ids[offer.offer_id] = true
			unique_shelves = unique_shelves and ids.size() == offers.size()
	check(valid_batches, "large batches keep at most one new weapon and fill remaining slots with other rewards")
	check(unique_shelves, "offer identities remain unique")
	var empty: Dictionary = context.duplicate(true)
	empty.candidate_pool = []
	empty.zone_target_pools = ["weapon", "relic"]
	empty.zone_tag_weight_bonus = 2000
	check(generator.get_shop_type_weights(empty).values().all(func(w): return w == 0), "zone bias does not revive unavailable types")
	var mythic := generator.get_shop_rarity_weights(200)
	var strong := generator.roll_paid_offers(mythic, paid, candidates, 3, 999, [], "epic")
	check(strong.size() == 3 and strong[0].offer_type == "relic" and strong[0].rarity == "epic", "strong refresh retains guaranteed epic relic")
	var report := {"scenario":"500 seeded runs, eight first-wave free choices then four per wave, one paid shelf per wave; always take new weapons; no affordability, combat or relic-stat simulation", "after": simulate(generator)}
	if not baseline_path.is_empty():
		var old_script: Script = load(baseline_path)
		report.before = simulate(old_script.new())
		check(report.after.mean_owned[0] < report.before.mean_owned[0], "first-wave acquisition slows versus previous code")
		check(report.after.five_by_wave_eight < report.before.five_by_wave_eight * 0.5, "early five-weapon snowball drops by more than half")
	check(report.after.five_by_wave_one < 0.01, "five weapons in the first wave is no longer a normal outcome")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("ACQUISITION_REPORT ",JSON.stringify(report))
	print("WEAPON_ACQUISITION_TEST checks=",checks," failures=",failures)
	get_tree().quit(0 if failures == 0 else 1)


func simulate(generator: RefCounted) -> Dictionary:
	var sums: Array[int] = [0,0,0,0,0,0,0,0]
	var first_full := 0
	var eighth_full := 0
	var rarity: Dictionary = generator.get_shop_rarity_weights(0)
	for run in 500:
		seed(20260930 + run)
		var owned: Array = ["weapon_void_blade"]
		for wave in 8:
			var rewards := 8 if wave == 0 else 4
			for ticket in rewards + 1:
				var mode := "shop" if ticket == rewards else "free"
				var context := context_for(owned)
				var key := str(owned)
				if not pools.has(key): pools[key] = generator.build_shop_candidate_pool(context)
				var candidates: Array = pools[key]
				context.candidate_pool = candidates
				context.offer_mode = mode
				context.zone_target_pools = ["weapon", "relic"]
				context.zone_tag_weight_bonus = wave * 20
				var weights: Dictionary = generator.get_shop_type_weights(context)
				var offers: Array = generator.roll_paid_offers(rarity, weights, candidates, 3, ticket) if mode == "shop" else generator.roll_shop_offers(rarity, weights, candidates, 3)
				for offer in offers:
					if offer.offer_type != "new_weapon": continue
					var current_load := int(context_for(owned).current_load)
					if not owned.has(offer.target_id) and current_load + int(offer.load_cost) <= 100: owned.append(offer.target_id)
					if mode == "free": break
			sums[wave] += owned.size()
			if wave == 0 and owned.size() >= 5: first_full += 1
			if wave == 7 and owned.size() >= 5: eighth_full += 1
	var means: Array = []
	for total in sums: means.append(float(total) / 500)
	return {"mean_owned":means,"five_by_wave_one":float(first_full)/500,"five_by_wave_eight":float(eighth_full)/500}
