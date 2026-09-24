extends "res://scripts/tests/pixel_combat_effect_test.gd"

var heard: Array[String] = []
var gains: Dictionary = {}
var projectile_serial := 0


func reset_audio() -> void:
	AudioManager.stop_combat_sfx()
	AudioManager._combat_last_ms.clear()
	AudioManager._combat_bursts.clear()
	heard.clear()
	gains.clear()


func prepare(ids: Array, positions: Array = [Vector2.ZERO]) -> void:
	await setup(positions)
	reset_audio()
	weapon.weapon_id = "weapon_void_blade"
	weapon.weapon_data = DataRegistry.get_record("weapons", weapon.weapon_id).duplicate(true)
	weapon._attached_item_instances.clear()
	for id in ids:
		var item: Dictionary = DataRegistry.get_record("augmentations", id).duplicate(true)
		item["item_instance_id"] = "audio_test_" + str(id)
		weapon._attached_item_instances.append(item)
	weapon._rebuild_attachment_effects()


func hit(enemy: EnemyController) -> void:
	var projectile := ProjectileInstance.new()
	host.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.weapon = weapon
	projectile.damage_event = event.duplicate_event()
	projectile_serial += 1
	projectile.projectile_id = "audio_test_" + str(projectile_serial)
	projectile.active = true
	projectile.remaining_target_hits = 99
	projectile.global_position = enemy.global_position
	projectile._on_body_entered(enemy)


func drain() -> void:
	# Exercise the real process ordering: deferred arms, first chain callback,
	# and a following explosion callback. Do not force an early batch flush.
	for i in range(4):
		await get_tree().process_frame
	AudioManager.flush_combat_audio(true)


func _run() -> void:
	AudioManager.combat_sfx_played.connect(func(cue: String, _path: String):
		heard.append(cue)
		for player: AudioStreamPlayer in AudioManager._combat_players:
			if player.playing and str(player.get_meta("cue_id", "")) == cue:
				gains[cue] = player.volume_db)
	await prepare(["scroll_water", "scroll_ice"], [Vector2.ZERO, Vector2(30, 0)])
	hit(enemies[0])
	check(enemies[0].current_hp == 9810 and enemies[1].current_hp == 9910, "audio batching does not delay or alter water/ice/weapon damage")
	check(heard.is_empty(), "base audio waits for reaction resolution")
	await drain()
	check(heard.count("reaction_freeze") == 1 and not heard.has("water") and not heard.has("ice"), "multi-target water+ice uses freeze only")
	check(heard.count("wood_arrow") == 1 and is_equal_approx(float(gains.get("wood_arrow", 0)), -12.0), "reaction retains bow impact with 5 dB attenuation")
	check(enemies[0].has_status("frozen") and enemies[1].has_status("frozen"), "audio arbitration preserves every target's freeze")

	await prepare(["scroll_ice"])
	hit(enemies[0])
	await drain()
	check(heard.has("ice") and not heard.has("reaction_freeze"), "ordinary ice still sounds without a reaction")
	check(is_equal_approx(float(gains.get("wood_arrow", 0)), -7.0), "ordinary weapon hit retains its original gain")

	await prepare(["scroll_ice"], [Vector2.ZERO, Vector2(250, 0)])
	enemies[0].apply_wet(5.0, 0.8)
	hit(enemies[0])
	hit(enemies[1])
	await drain()
	check(heard.has("reaction_freeze") and heard.has("ice"), "different same-frame contacts never suppress each other's base effect")

	await prepare(["scroll_water"])
	enemies[0].apply_burning(3.0, 10.0, "audio_test")
	hit(enemies[0])
	await drain()
	check(heard.has("reaction_steam") and not heard.has("water"), "water on burning target substitutes steam")

	await prepare(["scroll_ice", "scroll_explosion"])
	enemies[0].apply_wet(5.0, 0.8)
	hit(enemies[0])
	await drain()
	check(heard.has("reaction_freeze") and heard.has("explosion") and not heard.has("ice"), "unrelated explosion remains audible alongside freeze: " + str(heard))

	await prepare(["scroll_water", "scroll_lightning"])
	hit(enemies[0])
	await drain()
	check(heard.count("reaction_conduct") == 1 and not heard.has("water") and not heard.has("lightning"), "deferred first lightning shares water contact and substitutes conduction")
	check(is_equal_approx(float(gains.get("wood_arrow", 0)), -12.0), "deferred conduction still attenuates the original weapon hit")

	await prepare(["scroll_fire", "scroll_lightning"])
	hit(enemies[0])
	await drain()
	check(heard.count("reaction_thunder_fire") == 1 and not heard.has("lightning") and not heard.has("explosion"), "scheduled thunder-fire suppresses lightning before either base can start")
	for child in host.get_children():
		if child is FireSeed:
			child.set_process(false)
			child._process(0.7)
	AudioManager.flush_combat_audio(true)
	check(not heard.has("fire"), "late fire-seed ignition cannot reintroduce a replaced base sound")

	await prepare(["scroll_ice"])
	enemies[0].apply_wet(5.0, 0.8)
	enemies[0].apply_light(5.0)
	hit(enemies[0])
	await drain()
	check(heard.has("reaction_reflection") and not heard.has("reaction_freeze") and not heard.has("water") and not heard.has("ice"), "light-ice reflection absorbs its same-contact freeze prelude: " + str(heard))

	await prepare(["scroll_black_hole"])
	hit(enemies[0])
	# Another light source tags the enemy after the arrow but before the hole arms.
	enemies[0].apply_light(5.0)
	await drain()
	check(heard.has("reaction_cancel") and not heard.has("black_hole"), "deferred black-hole arm substitutes light-dark cancellation: " + str(heard))

	await prepare(["scroll_fire", "scroll_black_hole"])
	hit(enemies[0])
	await drain()
	check(heard.has("reaction_dark_flame") and not heard.has("black_hole"), "dark flame replaces the black-hole onset")
	for child in host.get_children():
		if child is FireSeed:
			child.set_process(false)
			child._process(0.7)
	AudioManager.flush_combat_audio(true)
	check(not heard.has("fire"), "dark-flame fire seeds retain replacement after landing")

	await prepare(["scroll_light_sword"])
	enemies[0].apply_burning(3.0, 10.0, "audio_test")
	hit(enemies[0])
	for child in host.get_children():
		if child is LightSwordEffect:
			child.set_process(false)
			child._land()
	await drain()
	check(heard.has("reaction_holy") and not heard.has("light_sword"), "holy flame replaces ordinary sword impact")

	await prepare(["scroll_wind"], [Vector2.ZERO, Vector2(60, 0)])
	enemies[0].apply_wet(5.0, 0.8)
	hit(enemies[0])
	await drain()
	check(heard.has("reaction_wet_spread") and not heard.has("wind"), "wet propagation replaces its wind sound")

	await prepare(["scroll_ice", "scroll_wind"])
	hit(enemies[0])
	await drain()
	check(heard.has("reaction_ice_expand") and not heard.has("ice") and not heard.has("wind"), "wind-expanded frost replaces both participating base sounds")

	await prepare(["scroll_ice"])
	enemies[0].apply_wet(5.0, 0.8)
	AudioManager._combat_last_ms["reaction_freeze"] = AudioManager._combat_clock_ms
	hit(enemies[0])
	await drain()
	check(not heard.has("reaction_freeze") and not heard.has("ice") and heard.has("wood_arrow"), "reaction cooldown never brings back the replaced base sound")

	await prepare(["scroll_lightning"], [Vector2.ZERO, Vector2(120, 0)])
	enemies[0].apply_wet(5.0, 0.8)
	hit(enemies[0])
	await drain()
	AudioManager._combat_clock_ms += 200.0
	for child in host.get_children():
		if child is LightningParticleEffect:
			child._strike_chain(enemies[1].get_instance_id(), enemies[0].global_position)
	AudioManager.flush_combat_audio(true)
	check(heard.has("reaction_conduct") and heard.has("lightning"), "a later dry chain victim gets its own ordinary lightning cue")

	await prepare(["scroll_water", "scroll_electric_spark"])
	hit(enemies[0])
	var spark: ElectricSparkEffect
	for child in host.get_children():
		if child is ElectricSparkEffect:
			spark = child
			spark.set_process(false)
	await drain()
	check(heard.has("water") and heard.has("spark_charge") and not heard.has("electric_spark"), "water and spark charge remain audible in the earlier phase")
	reset_audio()
	spark._process(0.51)
	await drain()
	check(heard.has("reaction_conduct_strike") and not heard.has("reaction_conduct") and not heard.has("electric_spark") and not heard.has("spark_charge"), "later wet landing retains thunder inside its combined cue without replaying charge")

	await prepare(["scroll_electric_spark"], [Vector2.ZERO, Vector2(10, 0)])
	enemies[0].apply_wet(5.0, 0.8)
	enemies[1].apply_burning(3.0, 10.0, "audio_test")
	hit(enemies[0])
	for child in host.get_children():
		if child is ElectricSparkEffect:
			spark = child
			spark.set_process(false)
	await drain()
	reset_audio()
	spark._process(0.51)
	await drain()
	check(heard.count("reaction_thunder_fire_strike") == 1 and not heard.has("reaction_conduct_strike") and not heard.has("electric_spark") and not heard.has("reaction_thunder_fire"), "mixed wet and burning victims produce one combined thunder-fire landing")
	check(not enemies[0].has_status("wet") and not enemies[1].has_status("burning") and enemies[0].current_hp < 9900 and enemies[1].current_hp < 10000, "choosing one landing sound preserves both victims' reactions and damage")

	await prepare(["scroll_water", "scroll_ice"])
	hit(enemies[0])
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	AudioManager.flush_combat_audio(true)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await drain()
	check(heard.is_empty(), "pausing before playback discards pending contact sounds")
	check(AudioManager._audio_impact_stack.is_empty() and AudioManager._pending_audio_impacts.is_empty(), "all scopes balance and pending requests drain")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	print("COMBAT_AUDIO_REACTION_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)
