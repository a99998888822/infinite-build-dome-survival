extends Node
## Guards the phone profile: one switch decides presentation, input model and
## the weapon pool. Every check is written against the current profile, so the
## same scene passes on desktop, on a device, and under `--mobile-ui`.

var checks := 0
var failures := 0


func _ready() -> void:
	_begin.call_deferred()


func _begin() -> void:
	# WindowSettings applies the scale over two deferred hops; the window probe
	# below has to wait for that before it can see the result.
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + note)


func _run() -> void:
	var mobile := MobileProfile.is_mobile()
	check(MobileProfile.uses_pointer() == not mobile, "pointer model stays desktop-only")
	check(MobileProfile.ui_scale > 1.0 if mobile else is_equal_approx(MobileProfile.ui_scale, 1.0), "ui scale follows the profile")
	check(MobileProfile.weapon_available("weapon_void_blade"), "ordinary weapons stay available everywhere")
	check(MobileProfile.bottom_inset() > 0.0 if mobile else is_equal_approx(MobileProfile.bottom_inset(), 0.0), "bottom inset follows the profile")
	# The profile reaches the real window, not just the widgets.
	check(is_equal_approx(get_tree().root.content_scale_factor, MobileProfile.ui_scale), "window content scale follows the profile")
	var expected_aspect := Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP
	check(get_tree().root.content_scale_aspect == expected_aspect, "window aspect follows the profile")

	var mobility_ids := _mobility_weapon_ids()
	check(not mobility_ids.is_empty(), "mobility behaviours map to real weapons")
	for weapon_id in mobility_ids:
		check(MobileProfile.weapon_available(weapon_id) == not mobile, "steering weapon follows the profile: " + weapon_id)

	# Shared character data keeps the desktop starter; phones filter it at runtime.
	var starter := PlayerController.new()
	var novice := DataRegistry.get_record("characters", "character_void_hunter")
	var resolved: Array[String] = starter._resolve_start_weapons(novice, [])
	check(resolved.has("weapon_void_blade"), "novice keeps the wooden bow")
	check(resolved.has("weapon_dash_blade") == not mobile, "novice dash blade follows the platform")
	starter.free()

	# The shelf and the level-up rewards must not offer what the phone cannot aim.
	var generator := ShopOfferGenerator.new()
	var candidates := generator.build_shop_candidate_pool({
		"owned_weapon_ids": ["weapon_void_blade"],
		"equipped_weapons": [{"weapon_id": "weapon_void_blade", "level": 1}],
		"current_load": int(DataRegistry.get_record("weapons", "weapon_void_blade").get("load_cost", 0)),
		"load_capacity": 100,
		"luck": 0,
	})
	var offered: Array[String] = []
	for candidate in candidates:
		if str(candidate.get("offer_type", "")) == ShopOfferGenerator.OFFER_NEW_WEAPON:
			offered.append(str(candidate.get("target_id", "")))
	check(not offered.is_empty(), "shop pool still offers ordinary weapons")
	for weapon_id in mobility_ids:
		# Release-locked weapons never reach a pool, so only the open ones prove
		# that the profile is what keeps a steering weapon off the shelf.
		if bool(DataRegistry.get_record("weapons", weapon_id).get("release_locked", false)):
			continue
		check(offered.has(weapon_id) == not mobile, "shop pool follows the profile: " + weapon_id)

	print("MOBILE_PROFILE_TEST checks=%d failures=%d mode=%s" % [checks, failures, "mobile" if mobile else "desktop"])
	get_tree().quit(0)


func _mobility_weapon_ids() -> Array[String]:
	var result: Array[String] = []
	for record in DataRegistry.get_table("weapons"):
		if str(record.get("projectile_behavior", "")) in WeaponInstance.MOBILITY_BEHAVIORS:
			result.append(str(record.get("id", "")))
	return result
