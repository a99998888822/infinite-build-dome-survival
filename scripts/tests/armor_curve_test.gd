extends Node
## Exercise the shared curve through actual player, enemy, and vault damage.

var checks := 0
var failures := 0
var output := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	CampProgression.begin_transient_session()
	var bootstrap := load("res://scripts/core/bootstrap.gd").new() as Node
	check(bootstrap._run_modifier_stack_checks(), "existing bootstrap modifier checks use the updated curve")
	bootstrap.free()
	var stack := ModifierStack.new()
	var expected := {0: 100, 15: 95, 30: 91, 50: 86, 100: 75, 200: 60, 300: 50,
		500: 38, 900: 25, 2700: 10, 5154: 6, 5155: 5, 5700: 5, 100000: 5,
		-50: 120, -100: 150, -150: 200, -270: 1000, -300: 1000, -1000: 1000}
	for armor: int in expected:
		stack.set_base_stat("armor", armor)
		check(stack.get_stat("damage_taken_percent") == expected[armor], "actual damage taken at armor " + str(armor))
	check(is_equal_approx(StatDefinitions.calculate_damage_taken_from_armor(15), 95.238095238), "low armor continuous formula")
	check(is_equal_approx(StatDefinitions.calculate_damage_taken_from_armor(5700), 5.0), "continuous curve reaches floor at 5700")
	var prior := INF
	var monotone := true
	var bounded := true
	var first_cap := -1
	var csv: FileAccess
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		csv = FileAccess.open(output.path_join("armor_curve.csv"), FileAccess.WRITE)
		csv.store_line("armor,formula_reduction_percent,actual_reduction_percent")
	for armor in range(-350, 6001):
		stack.set_base_stat("armor", armor)
		var damage := stack.get_stat("damage_taken_percent")
		monotone = monotone and damage <= prior
		bounded = bounded and damage >= 5 and damage <= 1000
		prior = damage
		if armor >= 0 and damage == 5 and first_cap < 0: first_cap = armor
		if csv != null: csv.store_line("%d,%.9f,%.9f" % [armor, 100.0 - StatDefinitions.calculate_damage_taken_from_armor(armor), 100.0 - damage])
	if csv != null: csv.close()
	check(monotone and bounded, "whole curve is monotone and bounded across negative singularity")
	check(first_cap == 5155, "actual 95 percent floor begins at 5155 armor")
	stack.set_base_stat("armor", 300)
	stack.set_base_stat("damage_taken_percent", 80)
	check(stack.get_stat("damage_taken_percent") == 40, "other damage modifiers still multiply after armor")
	stack.set_base_stat("armor", 100000)
	check(stack.get_stat("damage_taken_percent") == 5, "final damage floor still applies after other modifiers")
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.modifier_stack.set_base_stat("max_hp", 1000)
	player.modifier_stack.set_base_stat("armor", 100)
	player.restore_full_health()
	check(player.take_damage(100, "armor_curve_test") == 75 and player.current_hp == 925, "player 100 armor takes 75 from a 100 hit")
	player._invincibility_timer = 0
	player.grant_shield(50)
	var hp := player.current_hp
	check(player.take_damage(150, "armor_curve_test") == 125 and player.current_hp == hp - 75 and player.current_shield == 0, "shield takes raw damage and armor only mitigates overflow")
	player._invincibility_timer = 0
	check(player.take_damage(1, "armor_curve_test") == 1, "positive health hit retains minimum one damage")
	var enemy := EnemyController.new()
	enemy.auto_initialize_on_ready = false
	add_child(enemy)
	enemy.initialize("enemy_mutated_grub", player)
	enemy.set_physics_process(false)
	enemy.modifier_stack.set_base_stat("armor", 100)
	enemy.modifier_stack.set_base_stat("max_hp", 1000)
	enemy.current_hp = 1000
	check(enemy.take_damage(100, "armor_curve_test") == 75 and enemy.current_hp == 925, "enemy shares the new armor mitigation")
	var vault := load("res://scenes/battle/challenge_vault.tscn").instantiate() as ChallengeVault
	add_child(vault)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	vault.initialize(1000, 100)
	check(vault.take_enemy_damage(100) == 75 and vault.current_hp == 925, "vault shares the new continuous armor curve")
	vault.free()
	enemy.free()
	player.free()
	CampProgression.end_transient_session()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().process_frame
	print("ARMOR_CURVE_COMPLETE checks=%d failures=%d first_actual_cap=%d" % [checks, failures, first_cap])
	get_tree().quit(1 if failures else 0)
