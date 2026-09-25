extends Node2D

var checks := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	var player := load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.position = Vector2(1000, 0)
	player.set_physics_process(false)
	var normal := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
	var elite := load("res://scenes/enemy/elite_rusher.tscn").instantiate() as EliteRusher
	add_child(normal)
	add_child(elite)
	normal.initialize("enemy_mutated_grub", player)
	elite.initialize("enemy_elite_rusher", player)
	for enemy in [normal, elite]:
		enemy.set_physics_process(false)
		enemy.current_hp = 10000
	elite._process_special_behavior(0.75)
	normal.position = Vector2(80, 0)
	elite.position = Vector2(-80, 0)
	check(elite.sprite.scale == Vector2(0.7, 0.7) and elite.get_node("CollisionShape2D").shape.radius == 21.0, "boss visual and body are 0.7 of previous size")
	for enemy in [normal, elite]:
		enemy.apply_slow(3.0, 0.45)
		enemy.apply_wet(5.0, 0.8)
		enemy.apply_blind(2.0)
		enemy.apply_lightning_stun(0.65)
	check(is_equal_approx(elite._slowed_remaining, 0.3) and is_equal_approx(elite._slow_multiplier, 0.945), "frost duration and slow strength reduced by ninety percent")
	check(is_equal_approx(elite._wet_remaining, 0.5) and is_equal_approx(elite._wet_slow_multiplier, 0.98), "wet duration and slow strength reduced")
	check(is_equal_approx(elite._blinded_remaining, 0.2) and is_equal_approx(elite._stunned_remaining, 0.065), "blind and stun duration reduced")
	check(is_equal_approx(normal._slowed_remaining, 3.0) and is_equal_approx(normal._slow_multiplier, 0.45) and is_equal_approx(normal._wet_remaining, 5.0), "normal enemy control remains unchanged")
	elite.clear_blind()
	elite._stunned_remaining = 0
	elite.start_dash()
	elite.apply_freeze(1.0)
	elite._physics_process(0.01)
	check(elite.skill_state == "windup" and is_equal_approx(elite._frozen_remaining, 0.09), "short freeze preserves queued dash")
	elite._physics_process(0.11)
	check(elite.skill_state == "windup" and elite._state_time > 0, "dash continues after resisted freeze")
	elite.cancel_skill()
	elite.apply_knockback(Vector2.RIGHT, 900, 0.34)
	check(is_equal_approx(elite._knockback_velocity.length(), 90.0) and is_equal_approx(elite._knockback_timer, 0.034), "ordinary displacement strength and duration reduced")
	elite._knockback_timer = 0
	elite._knockback_velocity = Vector2.ZERO
	elite.velocity = Vector2.ZERO
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", player)
	var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": weapon.weapon_id})
	CombatEffectWorld._apply_wind(self, elite, weapon, event, elite.position, Vector2.RIGHT, "")
	check(elite._knockback_timer == 0 and elite.velocity == Vector2.ZERO and elite.current_hp < 10000, "direct wind deals damage with zero boss push")
	var blade := WindBladeEffect.new()
	add_child(blade)
	blade.set_process(false)
	blade._weapon = weapon
	blade._damage_event = event
	blade.position = elite.position
	var previous_hp := elite.current_hp
	blade._damage_path_enemies()
	check(elite.current_hp < previous_hp and elite._knockback_timer == 0 and elite.velocity == Vector2.ZERO, "travelling wind blade also cannot push boss")
	blade.queue_free()
	var hole := BlackHoleEffect.new()
	add_child(hole)
	hole.set_process(false)
	hole._targets = [normal, elite]
	hole._process(0.1)
	check(is_equal_approx(normal.position.x, 65.0) and is_equal_approx(elite.position.x, -78.5), "black hole pull reduced for boss only")
	hole.queue_free()
	await get_tree().physics_frame
	WaterWaveEffect.spawn(self, Vector2(600, 0), weapon, event)
	var water: WaterWaveEffect
	for child in get_children():
		if child is WaterWaveEffect:
			water = child
	check(water != null and is_equal_approx(water._radius, 23.1), "water footprint shrinks to seventy percent")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var age := water._elapsed
	water._process(1.0)
	check(water._elapsed == age, "repainted water still respects pause")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	print("ELITE_EFFECT_REVISION checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
