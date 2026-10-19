extends Node
## Production entry and first bow/lightning contact, with wall-clock frame timings.
var samples: Array[float] = []
var previous := 0
var measuring := false
var report: Dictionary = {}
var failures := 0
var output := "user://battle_entry_performance.json"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	run.call_deferred()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if measuring and previous > 0: samples.append(float(now - previous) / 1000.0)
	previous = now

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func finish_sample(key: String) -> void:
	measuring = false
	samples.sort()
	report[key] = {"max_ms": samples.back() if not samples.is_empty() else 0.0,
		"median_ms": samples[samples.size() / 2] if not samples.is_empty() else 0.0}
	samples.clear()

func run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_weapon_auto_cast("weapon_void_blade", false, false)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu._on_start_battle_pressed()
	await frames(6)
	measuring = true
	var began := Time.get_ticks_usec()
	menu._on_character_confirm_pressed()
	report.click_return_ms = float(Time.get_ticks_usec() - began) / 1000.0
	while bool(GameGlobal.get_runtime_flag("battle_loading", false)):
		await frames(1)
	await frames(12)
	report.entry_ms = float(Time.get_ticks_usec() - began) / 1000.0
	finish_sample("entry_frames")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	var weapon := battle.loadout.get_weapon_instance("weapon_void_blade")
	for attempt in 2:
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", battle.player.global_position + Vector2(95, 0))
		enemy.set_physics_process(false)
		enemy.current_hp = 100000
		battle.loadout.active_casting.states.clear()
		await frames(5)
		measuring = true
		began = Time.get_ticks_usec()
		var fired := battle.loadout.cast_weapon(weapon, weapon.get_auto_target_position(enemy))
		if not fired: failures += 1
		report["cast_%d" % attempt] = {"fired": fired, "cpu_ms": float(Time.get_ticks_usec() - began) / 1000.0}
		await frames(100)
		if enemy.current_hp >= 100000: failures += 1
		finish_sample("attack_%d_frames" % attempt)
		battle.wave_manager.clear_enemies()
		await frames(5)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BATTLE_ENTRY_PERFORMANCE ", JSON.stringify(report))
	game.get_main_flow_coordinator().enter_start_page()
	await frames(8)
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)
