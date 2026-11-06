extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	CampProgression.begin_transient_session()
	var player := preload("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	add_child(player)
	player.set_physics_process(false)
	var hp := player.current_hp
	check(player.take_damage(1, "contact_a") == 1, "ordinary damage is accepted")
	check(is_equal_approx(player._invincibility_timer, 0.1), "ordinary damage grants 0.1 seconds of protection")
	check(player.take_damage(1, "contact_b") == 0 and player.current_hp == hp - 1, "another source in the same frame is blocked")
	player._physics_process(0.09)
	check(player.take_damage(1, "projectile") == 0, "projectiles respect remaining protection")
	var remaining := player._invincibility_timer
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	player._physics_process(1.0)
	check(is_equal_approx(player._invincibility_timer, remaining), "menu pause preserves protection time")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	player._physics_process(0.02)
	check(player.take_damage(1) == 1 and player.current_hp == hp - 2, "ordinary damage resumes after expiry")
	player._physics_process(0.11)
	player.current_shield = 2
	check(player.take_damage(1) == 1 and player.current_shield == 1 and player.current_hp == hp - 2, "shield absorbs the accepted hit")
	check(player.take_damage(2) == 0 and player.current_shield == 1, "shield hits also grant shared protection")
	player._physics_process(0.11)
	player.add_relic("relic_costly_seed_of_life")
	player.take_damage(99999)
	check(player.alive and is_equal_approx(player._invincibility_timer, 1.0), "revival retains its full one-second protection")
	check(player.take_damage(1) == 0, "revival protection blocks further damage")
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	var total := 0
	for index in 16:
		var duration := manager.calculate_wave_duration(index)
		check(duration == mini(25 + index * 5, 45), "configured duration for wave " + str(index + 1))
		total += duration
	check(total == 670 and DataRegistry.get_table("waves").size() == 16, "sixteen waves total eleven minutes ten seconds")
	manager.queue_free()
	player.queue_free()
	await get_tree().process_frame
	CampProgression.end_transient_session()
	print("PLAYER_DAMAGE_GRACE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
