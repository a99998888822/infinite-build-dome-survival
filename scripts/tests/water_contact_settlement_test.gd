extends "res://scripts/tests/lightning_settlement_test.gd"

class WetCallbackEnemy extends EnemyController:
	var callback := ""
	func apply_wet(duration: float = 5.0, slow: float = 0.8, power: float = -1.0) -> void:
		super.apply_wet(duration, slow, power)
		if callback == "holy": apply_burning(3, 7, "callback", true, false)
		if callback == "dark": apply_burning(3, 7, "callback", false, true)
		if callback == "freeze_light":
			apply_freeze(1, {}, 0)
			apply_light(5)
		if callback == "dead": alive = false

func exercise_water(native: bool, actor: String, status: String, duration: float, slow: float, callback := "") -> Dictionary:
	seed(731)
	var host := Node2D.new()
	add_child(host)
	var enemy: EnemyController
	if actor == "callback":
		enemy = WetCallbackEnemy.new()
		enemy.callback = callback
	else: enemy = load("res://scenes/enemy/" + actor + ".tscn").instantiate()
	host.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.current_hp = 10000
	prepare(enemy, status)
	if status == "slowed": enemy.apply_slow(3, 0.6, 0)
	var event := DamageEvent.create({"damage":20,"original_damage":20,"control_power":40,"source_weapon_id":"water_probe"})
	var audio: RefCounted = AudioManager.begin_combat_audio()
	var rows: Array = []
	for step in 5:
		if native:
			AFTER.apply_water_contact(enemy, host, event, duration, slow)
		else:
			AFTER.apply_element(enemy, "water", {"parent":host,"hit_position":enemy.global_position,
				"source_id":event.source_weapon_id,"damage":event.damage,
				"original_damage":event.get_elemental_base_damage(),"damage_event":event,
				"wet_duration":duration,"wet_slow_multiplier":slow})
		rows.append(state_of(enemy))
	var result := {"states":rows,"random":randf(),"requests":audio.requests.duplicate(true),
		"suppressed":audio.suppressed_cues.duplicate(true),"reactions":audio.reactions.duplicate(true)}
	AudioManager.end_combat_audio()
	host.free()
	return result

func run() -> void:
	CampProgression.begin_transient_session()
	for actor in ["mutated_grub", "elite_rusher", "underworld_wolf"]:
		for status in ["plain","wet","burn","wet_burn","holy_burn","dark_burn","slowed","frozen","light_frozen","dead"]:
			for values in [[5.0,0.8],[-1.0,2.0],[0.2,-1.0]]:
				check(exercise_water(false,actor,status,values[0],values[1]) == exercise_water(true,actor,status,values[0],values[1]), "water state/audio/RNG equivalence " + actor + " " + status)
	for callback in ["holy","dark","freeze_light","dead"]:
		check(exercise_water(false,"callback","plain",5,0.8,callback) == exercise_water(true,"callback","plain",5,0.8,callback), "water callback equivalence " + callback)
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("WATER_CONTACT_SETTLEMENT checks=",checks," failures=",failures)
	get_tree().quit(0 if failures == 0 else 1)
