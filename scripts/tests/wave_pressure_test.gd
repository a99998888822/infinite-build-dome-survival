extends Node

var failures := 0
var checks := 0
var spawned := 0
# Measured before the density increase, using the same real 20-second scheduler.
const PREVIOUS_SPAWNS := {
	"1": {1: 40, 5: 57, 10: 110, 15: 162, 20: 244},
	"2": {1: 57, 5: 90, 10: 186, 15: 273, 20: 386},
	"3": {1: 90, 5: 157, 10: 291, 15: 420, 20: 620},
}

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var rows: Array = []
	var previous_tier: Array = []
	for tier in BattleDifficulty.IDS:
		var p := PlayerController.new()
		p.auto_initialize_on_ready = false
		add_child(p)
		p.initialize_from_character("character_void_hunter")
		p.set_physics_process(false)
		var manager := WaveManager.new()
		add_child(manager)
		manager.set_process(false)
		manager.initialize(p, tier)
		manager.child_entered_tree.connect(func(node):
			if node is EnemyController: spawned += 1)
		var tier_rows: Array = []
		var last_hp := 0
		var last_rate := 0.0
		for wave in range(1, 21):
			manager.current_wave_index = wave - 2
			manager.start_next_wave()
			var sample := manager.spawn_enemy("enemy_mutated_grub", Vector2(900, 0))
			var hp := sample.current_hp
			var damage := sample.get_stat("melee_damage")
			sample.free()
			var rate := 0.0
			for group: Dictionary in manager.current_wave.spawn_groups:
				rate += manager.calculate_enemy_spawn_count(int(group.count_per_spawn)) * 1000.0 / manager.calculate_spawn_interval(float(group.spawn_interval_ms))
			check(hp > last_hp, "HP increases every wave: tier %s wave %d" % [tier, wave])
			check(rate > last_rate, "density increases every wave: tier %s wave %d" % [tier, wave])
			check(damage <= 2, "base contact damage remains modest: tier %s wave %d" % [tier, wave])
			last_hp = hp
			last_rate = rate
			spawned = 0
			# Exercise real timer scheduling. Remove spawned enemies without rewards
			# so the count measures supply rather than the live safety cap.
			for frame in 1200:
				manager._process(1.0 / 60.0)
				for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
			var row := {"difficulty": tier, "wave": wave, "hp": hp, "damage": damage, "spawned_20s": spawned, "rate": snappedf(rate, 0.01), "cap": manager._difficulty.enemy_limit}
			tier_rows.append(row)
			if not previous_tier.is_empty():
				check(spawned >= previous_tier[wave - 1].spawned_20s * 1.25, "at least 25 percent more actual spawns than prior tier at wave " + str(wave))
			if PREVIOUS_SPAWNS[tier].has(wave):
				check(spawned == int(PREVIOUS_SPAWNS[tier][wave]) * 2, "actual spawns doubled: tier %s wave %d" % [tier, wave])
				rows.append(row)
		check(tier_rows[19].hp > tier_rows[0].hp * 40, "late HP grows much faster than damage")
		check(tier_rows[19].spawned_20s > tier_rows[0].spawned_20s * 3, "late density exceeds three times opening density")
		previous_tier = tier_rows
		manager.free()
		p.free()
	print("WAVE_PRESSURE_ROWS ", JSON.stringify(rows))
	print("WAVE_PRESSURE_COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
