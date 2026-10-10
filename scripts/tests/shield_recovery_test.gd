extends Node

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	CampProgression.begin_transient_session()
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.current_shield = 10
	player.current_shield_capacity = 10
	player.take_damage(7)
	check(player.current_shield == 3 and player.current_shield_capacity == 10, "damage retains established shield capacity")
	var observed: Array[Vector2i] = []
	player.hp_changed.connect(func(_hp, _maximum, shield): observed.append(Vector2i(shield, player.current_shield_capacity)))
	check(player.grant_shield(4) == 4 and player.current_shield == 7 and player.current_shield_capacity == 10, "3/10 plus 4 refills to 7/10")
	player.grant_shield(5)
	check(player.current_shield == 12 and player.current_shield_capacity == 12, "7/10 plus 5 overflows to 12/12")
	player.grant_shield(3)
	check(player.current_shield == 15 and player.current_shield_capacity == 15, "full shield grows current and capacity together")
	check(observed == [Vector2i(7,10), Vector2i(12,12), Vector2i(15,15)], "HUD signals expose refill and overflow capacity after each grant")
	check(player.grant_shield(0) == 0 and player.grant_shield(-1) == 0 and observed.size() == 3, "invalid grants do not mutate shield or emit changes")
	player.current_shield = 0
	player.current_shield_capacity = 2
	player.modifier_stack.set_base_stat("shield_regen", 2.0)
	player._shield_regen_remainder = 0
	player._process_regeneration(0.25)
	check(player.current_shield == 0 and player.current_shield_capacity == 2, "fractional regeneration waits for a whole shield point")
	player._process_regeneration(0.25)
	check(player.current_shield == 1 and player.current_shield_capacity == 2, "whole regeneration refills missing shield first")
	player._process_regeneration(1.0)
	check(player.current_shield == 3 and player.current_shield_capacity == 3, "regeneration grows only after closing deficit")
	player.reset_wave_shield()
	check(player.current_shield == player.get_stat("shield") and player.current_shield_capacity == player.get_stat("shield") and player._shield_regen_remainder == 0, "next wave resets current capacity from the current stat and clears fractional remainder")
	player.current_shield = 0
	player.current_shield_capacity = 0
	player.grant_shield(2)
	check(player.current_shield == 2 and player.current_shield_capacity == 2, "zero-capacity shield can still be generated")
	player.alive = false
	check(player.grant_shield(4) == 0 and player.current_shield == 2 and player.current_shield_capacity == 2, "dead player cannot gain shield")
	player.free()
	CampProgression.end_transient_session()
	print("SHIELD_RECOVERY_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
