extends Node
## Diagnostic fixture only: disable text, retain production damage and effects.

class NoTextEnemy extends EnemyController:
	func _spawn_damage_number(_damage: int, _critical := false, _index := 0, _count := 1, _amplified := false, _base := 0) -> void:
		pass

class BenchmarkManager extends WaveManager:
	func _process(delta: float) -> void:
		_process_pending_rewards(delta)

var output := ""
var smoke := false
var reaction_only := false
var thunder_visuals := "adaptive"
var compare_thunder := false
var rows: Array = []
var hits := 0
var dealt := 0
var failures := 0
var previous_frame := 0
var frame_times: Array[float] = []
var sampling := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		if arg == "--smoke": smoke = true
		if arg == "--reaction-only": reaction_only = true
		if arg == "--compare-thunder": compare_thunder = true
		if arg.begins_with("--thunder-visuals="): thunder_visuals = arg.trim_prefix("--thunder-visuals=")
	_run.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if sampling:
		frame_times.append((now - previous_frame) / 1000.0)
	previous_frame = now


func frames(count := 3) -> void:
	for index in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("NO_TEXT_BENCHMARK " + message)


func _record_damage(_source: String, damage: int) -> void:
	hits += 1
	dealt += damage


func _run() -> void:
	CampProgression.begin_transient_session()
	WindowSettings._startup_applied = true
	get_window().size = Vector2i(1152, 648)
	get_window().content_scale_size = Vector2i(1152, 648)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var previous_texts: Variant = GameGlobal.get_runtime_flag("element_reaction_text_r04_enabled", true)
	var previous_pause: Variant = GameGlobal.get_runtime_flag("battle_runtime_paused", false)
	var had_visual_mode := GameGlobal.has_runtime_flag("thunder_fire_visual_mode")
	var previous_visual_mode: Variant = GameGlobal.get_runtime_flag("thunder_fire_visual_mode")
	GameGlobal.set_runtime_flag("thunder_fire_visual_mode", thunder_visuals)
	GameGlobal.set_runtime_flag("element_reaction_text_r04_enabled", false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	if compare_thunder:
		# Exclude cold shader/resource initialization from the comparative sample.
		GameGlobal.set_runtime_flag("thunder_fire_visual_mode", "full")
		await _case("lightning_burning", 12, -1)
		rows.clear()
		var modes := ["full", "off", "adaptive"]
		for repeat in 3:
			for count in [32, 96]:
				for offset in 3:
					GameGlobal.set_runtime_flag("thunder_fire_visual_mode", modes[(repeat + offset) % 3])
					await _case("lightning_burning", count, repeat)
	else:
		for repeat in (1 if smoke else 2):
			for count in ([12] if smoke else [32, 96]):
				for kind in (["lightning_burning"] if reaction_only else ["idle", "direct", "lightning", "lightning_burning", "death_with_drops"]):
					await _case(kind, count, repeat)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	GameGlobal.set_runtime_flag("element_reaction_text_r04_enabled", previous_texts)
	GameGlobal.set_runtime_flag("battle_runtime_paused", previous_pause)
	if had_visual_mode: GameGlobal.set_runtime_flag("thunder_fire_visual_mode", previous_visual_mode)
	else: GameGlobal.clear_runtime_flag("thunder_fire_visual_mode")
	var result := {"headless": DisplayServer.get_name() == "headless", "rows": rows, "failures": failures,
		"thunder_visuals": thunder_visuals,
		"compare_thunder": compare_thunder,
		"method": "No damage/reaction text; native enemy damage, ground strike, reaction explosions, WaveManager damage/kill callbacks and drops; stationary enemies inside radius 32; one burst per fresh fixture; 1s frame sampling; no HUD or autonomous attacks"}
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("NO_TEXT_BENCHMARK ", JSON.stringify(result))
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)


func _case(kind: String, count: int, repeat: int) -> void:
	seed(20261012 + repeat)
	var room := Node2D.new()
	add_child(room)
	var player := preload("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	room.add_child(player)
	player.position = Vector2(2000, 2000)
	player.set_physics_process(false)
	player.set_process(false)
	if player.camera_2d != null: player.camera_2d.enabled = false
	var manager := preload("res://scenes/waves/wave_manager.tscn").instantiate() as WaveManager
	manager.set_script(BenchmarkManager)
	manager.auto_start = false
	room.add_child(manager)
	manager.initialize(player)
	manager.running = true
	manager.wave_time_left = 999
	var weapon := WeaponInstance.new()
	check(weapon.initialize("weapon_void_blade", player), "weapon initialization")
	var arena := manager.enemy_root
	var enemies: Array[EnemyController] = []
	for index in count:
		var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.set_script(NoTextEnemy)
		enemy.auto_initialize_on_ready = false
		arena.add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		# All targets are inside one impact. Every secondary radius also overlaps.
		var angle := TAU * index / count
		var radius := 32.0 * sqrt(float(index + 1) / count)
		enemy.global_position = Vector2(576, 324) + Vector2.from_angle(angle) * radius
		enemy.current_hp = 1000000
		enemy.set_physics_process(false)
		enemy.damage_received.connect(_record_damage)
		enemy.damage_received.connect(manager._on_enemy_damage_received)
		enemy.damage_received.connect(manager._on_enemy_pressure_damage.bind(enemy, manager.current_wave_index + 1))
		enemy.died.connect(manager._on_enemy_died)
		enemies.append(enemy)
	await get_tree().physics_frame
	await frames(5)
	if kind == "lightning_burning":
		for enemy in enemies: enemy.apply_burning(3.0, 0.0, weapon.weapon_id)
	hits = 0
	dealt = 0
	frame_times.clear()
	previous_frame = Time.get_ticks_usec()
	sampling = true
	var started := Time.get_ticks_usec()
	if kind in ["direct", "death_with_drops"]:
		for enemy in enemies:
			if kind == "death_with_drops": enemy.current_hp = 1
			enemy.take_damage_with_feedback(10, weapon.weapon_id, false, Vector2.RIGHT, &"heavy")
	elif kind in ["lightning", "lightning_burning"]:
		var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": weapon.weapon_id, "source_player": player})
		LightningParticleEffect.spawn_ground_strike(arena, Vector2(576, 324), weapon, event, "", 182.0, 40.0)
	var submit_ms := (Time.get_ticks_usec() - started) / 1000.0
	await get_tree().create_timer(1.0).timeout
	sampling = false
	check(EnemyController.active_damage_numbers == 0, "damage labels disabled")
	check(get_tree().get_nodes_in_group("element_reaction_texts").is_empty(), "reaction text disabled")
	check(hits >= count if kind != "idle" else hits == 0, "every target receives the expected primary hit")
	check(hits == count + count * count if kind == "lightning_burning" else hits == (0 if kind == "idle" else count), "damage event count remains exact")
	check(dealt == count * 6 + count * count * 18 if kind == "lightning_burning" else dealt == count * (6 if kind == "lightning" else 0 if kind == "idle" else 10), "total damage remains exact")
	check(manager._pending_reward_batches.is_empty(), "all queued drops materialize")
	frame_times.sort()
	var row := {"kind": kind, "targets": count, "repeat": repeat, "submit_ms": submit_ms,
		"thunder_visuals": str(GameGlobal.get_runtime_flag("thunder_fire_visual_mode", "adaptive")),
		"frame_median_ms": frame_times[frame_times.size() / 2], "frame_max_ms": frame_times[-1],
		"frame_p95_ms": frame_times[mini(int(frame_times.size() * 0.95), frame_times.size() - 1)],
		"damage_events": hits, "total_damage": dealt, "pickup_nodes": manager.pickup_root.get_child_count()}
	var visual_budget = arena.get_meta(&"thunder_fire_visual_budget") if arena.has_meta(&"thunder_fire_visual_budget") else null
	if is_instance_valid(visual_budget): row["visual_tiers"] = visual_budget.tier_counts.duplicate()
	rows.append(row)
	print("NO_TEXT_CASE ", JSON.stringify(row))
	room.queue_free()
	enemies.clear()
	await frames(5)
