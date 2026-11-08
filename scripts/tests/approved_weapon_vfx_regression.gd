extends "res://scripts/tests/pixel_combat_effect_test.gd"
const STRIKE = preload("res://scripts/effects/lightning_particle_effect.gd")
const BUDGET = preload("res://scripts/effects/effect_visual_budget.gd")

func _run() -> void:
	CampProgression.begin_transient_session()
	var outcomes: Array = []
	for adaptive in [false, true]:
		await setup([Vector2.ZERO])
		GameGlobal.set_runtime_flag("review_visual_adaptive", adaptive)
		weapon.weapon_id = "vfx_contact_test"
		weapon._attached_item_instances.clear()
		for i in 40:
			WaterWaveEffect.spawn(host, Vector2.ZERO, weapon, event)
		check(enemies[0].current_hp == 8200, "all forty water contacts settle despite display suppression")
		var suppressed := 0
		for i in 24:
			var strike := STRIKE.spawn_ground_strike(host, Vector2.ZERO, weapon, event)
			strike.set_process(false)
			strike._strike_ground(Vector2.ZERO)
			if strike._baked_strike.tier == BUDGET.Tier.SUPPRESSED:
				suppressed += 1
				check(strike._baked_strike.get_child_count() == 0, "suppressed strike owns no render children")
		check(suppressed > 0 if adaptive else suppressed == 0, "density admission follows adaptive setting")
		outcomes.append([enemies[0].current_hp, enemies[0].has_status("wet"), enemies[0].has_status("stunned")])
	check(outcomes[0] == outcomes[1], "full and suppressed playback retain identical damage/status outcomes")
	GameGlobal.set_runtime_flag("review_visual_adaptive", true)
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("APPROVED_WEAPON_VFX_REGRESSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
