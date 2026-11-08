extends Node
## Effective enemy damage per wave: the early-wave ramp versus the unchanged late wave.

const ENEMIES := [
	{"id": "enemy_mutated_grub", "stat": "melee_damage"},
	{"id": "enemy_echo_bat", "stat": "ranged_damage"},
	{"id": "enemy_elite_rusher", "stat": "melee_damage"},
]
const PLAYER_HP := 10.0

var output := ""
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var manager := WaveManager.new()
	add_child(manager)
	manager.set_process(false)
	manager.initialize(player)
	for wave in range(1, DataRegistry.get_table("waves").size() + 1):
		# start_next_wave() advances the index, so seed the wave before it.
		manager.current_wave_index = wave - 2
		manager.start_next_wave()
		var scale := BattleDifficulty.early_damage_scale(manager.current_wave_index)
		for enemy_entry in ENEMIES:
			var enemy: EnemyController = manager.spawn_enemy(str(enemy_entry.id), Vector2(900, 0))
			if enemy == null:
				check(false, "spawn %s wave %d" % [enemy_entry.id, wave])
				continue
			enemy.set_physics_process(false)
			var stat := float(enemy.get_stat(str(enemy_entry.stat)))
			var damage_percent := 1.0 + float(enemy.get_stat("damage_percent")) / 100.0
			var legacy_hit := roundi(stat * damage_percent / maxf(scale, 0.0001))
			var hit := roundi(stat * damage_percent)
			rows.append({"wave": wave, "enemy": enemy_entry.id, "stat": stat, "hit": hit,
				"legacy_hit": legacy_hit, "scale": scale, "hits_to_die": snappedf(PLAYER_HP / float(maxi(1, hit)), 0.01)})
			if wave == 1:
				check(hit < legacy_hit or hit <= 2, "wave one %s hit is reduced: %d vs %d" % [enemy_entry.id, hit, legacy_hit])
			if wave > BattleDifficulty.EARLY_DAMAGE_SCALE.size() - 1:
				check(hit == legacy_hit, "wave %d %s keeps its previous damage: %d" % [wave, enemy_entry.id, hit])
			enemy.free()
		manager.finish_current_wave()
	print("DAMAGE_CURVE_ROWS ", JSON.stringify(rows.filter(func(r): return r.wave <= 8)))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("damage_curve.json"), FileAccess.WRITE).store_string(JSON.stringify({
			"curve": BattleDifficulty.EARLY_DAMAGE_SCALE, "player_hp": PLAYER_HP, "rows": rows}, "\t"))
	check(BattleDifficulty.early_damage_scale(0) == 0.5 and BattleDifficulty.early_damage_scale(99) == 1.0, "curve starts at half damage and reaches one")
	manager.free()
	player.free()
	print("ENEMY_DAMAGE_CURVE checks=%d failures=%d rows=%d" % [checks, failures, rows.size()])
	get_tree().quit(0 if failures == 0 else 1)
