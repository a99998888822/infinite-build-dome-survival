extends Node
## Staged crowds, native right-click movement and key/left-click weapon casts.
const FPS := 60
const HAMMER := "weapon_earth_hammer"
const SPEAR := "weapon_nightwatch_spear"
var take := "before"
var output_dir := ""
var total := 210
var session: RecordingSession
var battle: BattleRoot
var player: PlayerController
var controller: ActiveCombatController
var aim := Vector2.ZERO
var frame := 0
var failures: Array[String] = []
var report := {"fps": FPS, "events": [], "samples": [], "staged_crowd": true,
	"controls": "right-click movement, number-key selection, left-click cast"}
var enemies: Array[EnemyController] = []
var watched := {}
var kill_count := 0
var shard_count := 0
var chain_count := 0
var ground_count := 0
var seen_rays := 0
var seen_thrusts := 0
var cast_count := 0
var start_hp := 0
var hitstop_end_frame := -1
var stage_offset := Vector2.ZERO
var camera: Camera2D
var move_heading := Vector2.LEFT
var native_deaths := 0
var lightning_deaths := 0
var native_survivors := {}
var damage_rows: Array[Dictionary] = []
var enemy_points: Array[Vector2] = []
var calibrate_hammer := false
var health_profile: Array = []
var omitted_candidates: Array = []
const HEALTH_PROFILE := "res://scripts/debug/fixtures/pickup_hammer_health.json"
const BEFORE_CASTS := [[12, 1], [95, 0], [230, 1], [415, 0], [485, 1]]


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--take="): take = arg.trim_prefix("--take=")
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--calibrate-hammer": calibrate_hammer = true
	if take not in ["before", "hammer", "spear"] or output_dir.is_empty() or not "--transient-session" in OS.get_cmdline_user_args():
		push_error("Requires --take=before|hammer|spear --capture-dir --transient-session")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		push_error("Use the private desktop helper")
		get_tree().quit(2)
		return
	total = 600 if take == "before" else (180 if take == "hammer" else 180)
	DirAccess.make_dir_recursive_absolute(output_dir)
	if take == "hammer" and not calibrate_hammer and FileAccess.file_exists(HEALTH_PROFILE):
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HEALTH_PROFILE))
		health_profile = fixture.health
		omitted_candidates = fixture.omit.map(func(value): return int(value))
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	seed(10242026)
	get_tree().node_added.connect(func(node: Node):
		if node is CavernPopulationBackdrop: node.population_seed = 20261024)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	CombatSettings.set_option("show_hints", false, false)
	for id in [HAMMER, SPEAR]: CombatSettings.set_weapon_auto_cast(id, false, false)
	for bus in [AudioManager.BUS_MASTER, AudioManager.BUS_SFX]:
		AudioManager.set_bus_volume(bus, 100, false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), false)
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 0, false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_BGM), true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"wave": 1, "level": 10, "countdown": 0, "hud": true, "relics": []}, true)
	if take == "before":
		config.weapons = [{"id": HAMMER, "level": 5, "attachments": []}, {"id": SPEAR, "level": 5, "attachments": []}]
	elif take == "hammer":
		config.weapons = [{"id": HAMMER, "level": 5, "attachments": ["scroll_multishot", "scroll_electric_spark"]}]
		config.relics = [{"id": "relic_twin_chamber_magazine", "count": 3}]
	else:
		config.weapons = [{"id": SPEAR, "level": 5, "attachments": ["scroll_multishot", "scroll_split", "scroll_lightning"]}]
	report["take"] = take
	report["config"] = config
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		await _finish()
		return
	check(session.begin(), "Could not start battle")
	battle = session.battle
	player = battle.player
	controller = battle.active_controller
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	controller.set_process(false)
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	stage_offset = Vector2.ZERO if take == "before" else Vector2(0, -190)
	player.global_position = (Vector2(0, 40) if take == "before" else Vector2(-340, 40)) + stage_offset
	if take != "before":
		var weapon := battle.loadout.weapon_instances[0]
		var original := weapon.get_attack_range()
		var base := weapon.get_base_attack_range()
		var extended_base := (original + 100.0) / (original / base)
		weapon.weapon_data = weapon.weapon_data.duplicate(true)
		if take == "hammer":
			weapon.weapon_data.ground_node_spacing += (extended_base - base) / (weapon.get_ground_node_count() - 1)
		else:
			weapon.weapon_data.attack_range = extended_base
		report["range_before"] = original
		report["range_after"] = weapon.get_attack_range()
		check(is_equal_approx(weapon.get_attack_range(), original + 100.0), "Range must increase by exactly 100")
	player._clear_move_input()
	player._invincibility_timer = 0.0
	start_hp = player.current_hp
	player.health_damage_taken.connect(func(previous, remaining, _maximum): _event("damage", {"before": previous, "after": remaining}))
	camera = Camera2D.new()
	player.get_parent().add_child(camera)
	camera.global_position = Vector2(-20, 5) + stage_offset
	camera.zoom = Vector2(1.25, 1.25)
	camera.make_current()
	_place_enemies()
	report["enemy_start"] = enemies.size()
	check(enemies.size() == (120 if take == "before" else (68 if take == "hammer" and not calibrate_hammer else 82)), "Wrong staged crowd size")
	report["native_enemy_hp"] = enemies[0].current_hp
	report["weapon_stats"] = battle.loadout.weapon_instances.map(func(w): return {
		"id": w.weapon_id, "projectiles": w.get_stat("projectile_count"), "damage": w.get_base_attack_damage(),
		"range": w.get_attack_range(), "attachments": w.get_attached_item_instances().map(func(i): return i.base_item_id)})
	if take != "before": check(int(battle.loadout.weapon_instances[0].get_stat("projectile_count")) == (6 if take == "hammer" else 3), "Wrong projectile count")
	for index in 15: await get_tree().process_frame
	for node in [battle.hud.stats_drawer, battle.hud._weapon_damage_meter, battle.hud._performance_line,
		battle.hud._economy_log_layer, battle.hud.battle_top_bar, battle.hud.exp_panel, battle.hud._wave_toast]:
		if is_instance_valid(node): node.hide()
	battle.hud.set_process(false)
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	# MovieWriter advances simulation frames independently of wall time. Preserve
	# the native 50 ms hitstop as three output frames, including headless rehearsal.
	CombatHitFeedback.feedback_started.connect(_on_hitstop)
	aim = player.global_position + Vector2(500, 0)
	_move(player.global_position + (Vector2(-90, -20) if take == "before" else Vector2(0, -18)))
	_key(KEY_2 if take == "before" else KEY_1)
	_point(aim)
	report["start_frame"] = Engine.get_frames_drawn()
	for index in total:
		frame = index
		if hitstop_end_frame >= 0 and frame >= hitstop_end_frame:
			CombatHitFeedback.hitstop_until_usec = 0
			hitstop_end_frame = -1
		_choreograph()
		if take == "before": camera.global_position = camera.global_position.lerp(player.global_position + Vector2(35, -35), 0.018)
		_point(aim)
		controller._update_indicator()
		controller._update_cursor_icon()
		_watch_effects()
		_update_bar()
		if index % 12 == 0:
			report.samples.append({"frame": frame, "kills": kill_count, "hp": player.current_hp,
				"tree_paused": get_tree().paused, "hitstop": CombatHitFeedback._owns_pause,
				"runtime_paused": GameGlobal.get_runtime_flag("battle_runtime_paused", false), "flow": session.flow.current_state,
				"player": [player.global_position.x, player.global_position.y], "shards": shard_count, "chains": chain_count, "ground_strikes": ground_count})
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame in [0, 10, 18, 24, 32, 40, 55, 70, 85, 100, 115, 130, 145, 160, 175, 195, 209, 260, 320, 380, 440, 500, 560] or frame == total - 1:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	check(player.alive, "Player died during the take")
	check(cast_count == (BEFORE_CASTS.size() if take == "before" else 1), "Unexpected cast count")
	if take == "before":
		check(enemies.size() - kill_count >= 35, "Before take should retain crowd pressure after ten seconds")
	elif not calibrate_hammer:
		check(kill_count >= enemies.size() * 0.5 and kill_count <= enemies.size() * 0.92, "Enhanced take should clear most, with survivors")
		if take == "hammer":
			check(seen_rays == 6 and ground_count >= 18, "Six hammer rays must trigger ground lightning")
			check(native_deaths == 0 and lightning_deaths == kill_count and native_survivors.size() >= 20, "Hammer victims must survive native hits and die to lightning")
		else:
			check(seen_thrusts == 3 and shard_count >= 24 and chain_count >= 16, "Spear needs three thrusts, many child projectiles and chains")
	await _finish()


func _on_hitstop(tier: int, count: int) -> void:
	if not CombatHitFeedback._owns_pause: return
	var duration: float = CombatHitFeedback.HITSTOP_SECONDS[tier]
	hitstop_end_frame = frame + ceili(duration * FPS)
	CombatHitFeedback.hitstop_until_usec = Time.get_ticks_usec() + 3600000000
	_event("hitstop", {"tier": tier, "targets": count, "duration_frames": ceili(duration * FPS)})


func _place_enemies() -> void:
	var formation := RandomNumberGenerator.new()
	formation.seed = 8247
	if take == "before":
		for attempt in 6000:
			if enemies.size() >= 120: break
			var point := Vector2(formation.randf_range(-650, 650), formation.randf_range(-460, 460))
			if point.distance_to(player.global_position) < 150 or (point / Vector2(660, 470)).length() > 1.0: continue
			if _spaced(point, 49): _spawn(point)
	else:
		for attempt in 6000:
			if enemies.size() >= 82: break
			var local := Vector2(formation.randf_range(135, 710), formation.randf_range(-250, 250))
			if ((local - Vector2(410, 0)) / Vector2(320, 275)).length() > 1.0: continue
			var point := player.global_position + local
			if _spaced(point, 46): _spawn(point)
	# Complete the same candidate setup first, preserving the attack's RNG state.
	# Thin selected outliers before filming to leave a dispersed, readable crowd.
	for index in range(enemies.size() - 1, -1, -1):
		if index in omitted_candidates:
			enemies[index].free()
			enemies.remove_at(index)
			enemy_points.remove_at(index)
	report["spawn_points"] = enemy_points.map(func(p): return [p.x, p.y])
	report["initial_enemy_health"] = enemies.map(func(e): return e.current_hp)


func _spaced(point: Vector2, distance: float) -> bool:
	for other in enemy_points:
		if point.distance_to(other) < distance: return false
	return true


func _spawn(point: Vector2) -> void:
	var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", point)
	if enemy == null:
		check(false, "Could not create staged enemy")
		return
	enemies.append(enemy)
	enemy.set_meta("pickup_id", enemies.size() - 1)
	enemy_points.append(point)
	if take == "hammer":
		var health := int(health_profile[enemies.size() - 1]) if health_profile.size() >= enemies.size() else 10000
		enemy.add_runtime_modifier({"id": "pickup_health", "source_type": "recording", "source_id": "pickup",
			"target_scope": "enemy", "stat": "max_hp", "operation": "multiply", "value": float(health) / enemy.get_stat("max_hp"), "duration": -1, "stack_rule": "replace_same_source"})
		enemy.current_hp = int(enemy.get_stat("max_hp"))
	enemy.damage_received.connect(_on_enemy_damage.bind(enemy))
	enemy.died.connect(func(_enemy, _drop, _position): kill_count += 1)


func _on_enemy_damage(source: String, amount: int, enemy: EnemyController) -> void:
	var lightning := false
	for entry in get_stack():
		if str(entry.source).ends_with("lightning_particle_effect.gd"): lightning = true
	var id := int(enemy.get_meta("pickup_id"))
	if take == "hammer" and not lightning and enemy.current_hp > 0: native_survivors[id] = true
	if enemy.current_hp <= 0:
		if lightning: lightning_deaths += 1
		else: native_deaths += 1
	damage_rows.append({"frame": frame, "enemy": id, "source": source, "lightning": lightning, "damage": amount, "remaining": enemy.current_hp})


func _choreograph() -> void:
	if take == "before":
		if frame % 24 == 0: _steer_retreat()
		for beat in BEFORE_CASTS:
			if frame >= beat[0] - 10 and frame <= beat[0]:
				aim = _threat_target()
				if controller.selected_weapon == null: _key(KEY_1 if beat[1] == 0 else KEY_2)
			if frame == beat[0]: _cast(beat[1])
	else:
		if frame == 12: _cast(0)
		if frame == 30: _move(Vector2(-385, 18) + stage_offset)


func _threat_target() -> Vector2:
	var target := player.global_position + move_heading * 200
	var closest := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive: continue
		var distance := player.global_position.distance_squared_to(enemy.global_position)
		if distance < closest:
			closest = distance
			target = enemy.global_position
	return target


func _steer_retreat() -> void:
	# Choose a short, continuous escape direction, then issue an actual RMB move.
	var waypoints := [Vector2(-180, -100), Vector2(40, -200), Vector2(220, 0), Vector2(30, 160), Vector2(-180, 80)]
	var desired := player.global_position.direction_to(waypoints[mini(frame / 120, 4)])
	var best := -INF
	var chosen := move_heading
	for index in 24:
		var direction := Vector2.RIGHT.rotated(TAU * index / 24.0)
		var next := player.global_position + direction * 92
		var clearance := 200.0
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy.alive: continue
			for t: float in [0.25, 0.5, 0.75]:
				var future := enemy.global_position + enemy.global_position.direction_to(player.global_position) * enemy.get_stat("move_speed") * t
				clearance = minf(clearance, (player.global_position + direction * 140 * t).distance_to(future))
		var score := minf(clearance, 115) * 2.0 + direction.dot(desired) * 24 + direction.dot(move_heading) * 22 - maxf(next.length() - 370, 0) * 0.8
		if score > best:
			best = score
			chosen = direction
	move_heading = chosen
	_move(player.global_position + chosen * 92)


func _event(action: String, data := {}) -> void:
	data.merge({"frame": frame, "action": action}, true)
	report.events.append(data)


func _point(target: Vector2) -> void:
	var world := player.get_viewport()
	controller._has_pointer_position = true
	controller._pointer_position = (world.get_canvas_transform() * target) * get_viewport().get_visible_rect().size / world.get_visible_rect().size


func _key(code: Key) -> void:
	var input := InputEventKey.new()
	input.physical_keycode = code
	input.pressed = true
	controller._unhandled_input(input)
	input.pressed = false
	controller._unhandled_input(input)
	_event("key", {"keycode": code})


func _click(button: MouseButton) -> void:
	var input := InputEventMouseButton.new()
	input.button_index = button
	input.position = controller._pointer_position
	input.pressed = true
	controller._input(input)
	controller._unhandled_input(input)
	input.pressed = false
	controller._input(input)
	controller._unhandled_input(input)
	_event("click", {"button": button})


func _move(target: Vector2) -> void:
	_point(target)
	_click(MOUSE_BUTTON_RIGHT)


func _cast(slot: int) -> void:
	var weapon := battle.loadout.weapon_instances[slot]
	var ready := battle.loadout.active_casting.can_cast(weapon)
	if controller.selected_weapon != weapon: _key(KEY_1 if slot == 0 else KEY_2)
	_point(aim)
	_click(MOUSE_BUTTON_LEFT)
	check(ready and controller.selected_weapon == null, "Cast failed at frame " + str(frame))
	cast_count += 1
	_event("cast", {"weapon": weapon.weapon_id})
	_watch_effects()


func _watch_effects() -> void:
	for group in ["earth_hammers", "nightwatch_spears", "nightwatch_spear_shards", "combat_particle_counters"]:
		for node in get_tree().get_nodes_in_group(group):
			var id: int = node.get_instance_id()
			if watched.has(id): continue
			if node is EarthHammer:
				seen_rays = maxi(seen_rays, node.rays.size())
			elif node is NightwatchSpear:
				seen_thrusts = maxi(seen_thrusts, node.thrusts.size())
				node.shard_launched.connect(func(_shard): shard_count += 1)
			elif node is LightningParticleEffect:
				if node._is_ground_strike: ground_count += 1
				else: chain_count += 1
			watched[id] = true


func _update_bar() -> void:
	for index in battle.loadout.weapon_instances.size():
		var weapon := battle.loadout.weapon_instances[index]
		var state := battle.loadout.active_casting.state_for(weapon)
		battle.hud.combat_bar.update_slot(index, float(state.remaining), float(state.total), bool(state.executing), controller.selected_weapon == weapon)


func _finish() -> void:
	report.merge({"frames": total, "failures": failures, "kills": kill_count, "shards": shard_count,
		"native_deaths": native_deaths, "lightning_deaths": lightning_deaths, "native_survivors": native_survivors.size(), "damage_log": damage_rows,
		"chains": chain_count, "ground_strikes": ground_count, "hammer_rays": seen_rays, "spear_thrusts": seen_thrusts,
		"casts": cast_count, "hp_start": start_hp, "hp_end": player.current_hp if is_instance_valid(player) else -1}, true)
	report["audio"] = {"sfx_percent": 100, "bgm_percent": 0,
		"sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),
		"bgm_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")),
		"bgm_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM"))}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PICKUP_DONE ", take, " failures=", failures.size(), " kills=", kill_count, " shards=", shard_count, " chains=", chain_count, " ground=", ground_count)
	CombatHitFeedback.clear()
	# Legacy weapon hit sounds use the general SFX pool, outside combat voices.
	# Stop these after the selected frame range so MovieWriter can release them.
	for voice in AudioManager._sfx_players:
		voice.stop()
		voice.stream = null
	enemies.clear()
	controller = null
	player = null
	battle = null
	if is_instance_valid(session):
		await session.dispose()
		session.queue_free()
	for index in 8: await get_tree().process_frame
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
