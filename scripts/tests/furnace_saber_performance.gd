extends Node
## Same static 300-enemy battlefield, deterministic casts; measure actual frames
## separately from the CPU time spent stepping player, native hits and burns.
var output := ""
var graphical := false
var session: RecordingSession
var battle: BattleRoot
var player: PlayerController
var loadout: WeaponLoadout
var furnace: WeaponInstance
var saber: WeaponInstance
var enemies: Array[EnemyController] = []
var report := {"enemy_count":300,"simulation_fps":60,"frames_per_case":360,"warmup_frames":120,"camera_zoom":1.0,"cases":[],"controlled_static_enemies":true}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	graphical = DisplayServer.get_name() != "headless"
	if output.is_empty() or (graphical and not "--background-capture" in OS.get_cmdline_user_args()):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()

func freeze() -> void:
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		node.set_physics_process(false)

func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().size = Vector2i(1920,1080)
	get_window().unfocusable = true
	Engine.max_fps = 0
	if graphical: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"countdown":0,"hud":false,"relics":[],"weapons":[{"id":"weapon_furnace","level":1,"attachments":[]},{"id":"weapon_saber","level":1,"attachments":[]}]}, true)
	var error := await session.prepare(config)
	if not error.is_empty() or not session.begin():
		push_error("BENCHMARK_SETUP " + error)
		get_tree().quit(1)
		return
	battle = session.battle
	battle.set_process(false)
	player = battle.player
	loadout = battle.loadout
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.set_process(false)
	loadout.set_process(false)
	player.set_physics_process(false)
	player.relic_system.clear()
	player.modifier_stack.clear()
	player.modifier_stack.set_base_stats({"max_hp":10000,"move_speed":150,"load_capacity":100,"crit_damage":150})
	player.global_position = Vector2.ZERO
	var camera := Camera2D.new()
	player.get_parent().add_child(camera)
	camera.position = Vector2(0,-20)
	camera.make_current()
	furnace = loadout.get_weapon_instance("weapon_furnace")
	saber = loadout.get_weapon_instance("weapon_saber")
	furnace.runtime_stats.crit_chance = 0
	saber.runtime_stats.crit_chance = 0
	for i in 300:
		var radius := 75.0 + (i % 6) * 66.0
		var angle := TAU * floori(i / 6.0) / 50.0
		var at := Vector2.from_angle(angle) * radius * Vector2(1.0,0.659091)
		var enemy := battle.wave_manager.spawn_enemy("enemy_mutated_grub", at)
		enemy.set_physics_process(false)
		enemy.current_hp = 10000000
		enemy.target_player = null
		enemies.append(enemy)
	for i in 12: await get_tree().process_frame
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	AudioServer.set_bus_mute(0,true)
	for spec in [["baseline",0,0,false],["furnace_single",1,0,false],["saber_single",0,1,false],["five_rings_split_five_cuts",5,5,true]]:
		await _case(spec)
	for weapon in loadout.weapon_instances: loadout._clear_weapon_runtime(weapon)
	for i in 12: await get_tree().process_frame
	report["runtimes_after_cleanup"] = get_tree().get_nodes_in_group("furnace_runtimes").size() + get_tree().get_nodes_in_group("saber_runtimes").size()
	report["rendering"] = RenderingServer.get_video_adapter_name() if graphical else "headless"
	report["resolution"] = [1920,1080]
	var file := FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	await session.dispose()
	session.queue_free()
	for i in 6: await get_tree().process_frame
	CampProgression.end_transient_session()
	print("FURNACE_SABER_PERFORMANCE_COMPLETE cleanup=",report.runtimes_after_cleanup)
	get_tree().quit(0 if report.runtimes_after_cleanup == 0 else 1)

func _case(spec: Array) -> void:
	for weapon in loadout.weapon_instances: loadout._clear_weapon_runtime(weapon)
	for i in 6: await get_tree().process_frame
	for enemy in enemies:
		enemy.clear_burning()
		enemy.current_hp = 10000000
	loadout.active_casting.states.clear()
	player.global_position = Vector2.ZERO
	player._clear_move_input()
	player.action_animator.reset()
	player.current_hp = 10000
	furnace.runtime_stats.projectile_count = maxi(1,int(spec[1]))
	saber.runtime_stats.projectile_count = maxi(1,int(spec[2]))
	if bool(spec[3]):
		var split := player.item_inventory.add_item_from_base("scroll_split","benchmark")
		furnace.attach_item_instance(split)
	var cpu: Array[float] = []
	var wall: Array[float] = []
	var calls: Array[float] = []
	var peaks := 0
	var last := Time.get_ticks_usec()
	var capture_at := 28 if str(spec[0]) == "saber_single" else 76 if bool(spec[3]) else 22
	for frame in 360:
		var begin := Time.get_ticks_usec()
		if frame % 120 == 0:
			player.global_position = Vector2.ZERO
			loadout.active_casting.states.clear()
			if int(spec[1]) > 0:
				player._invincibility_timer = 0.0
				player.take_damage(1,"benchmark_enemy")
			if int(spec[2]) > 0: loadout.cast_weapon(saber,Vector2(300,0))
			freeze()
		player._physics_process(1.0/60.0)
		for body in get_tree().get_nodes_in_group("weapon_runtime_effects"):
			if not body.is_queued_for_deletion() and body.has_method("_physics_process"):
				body._physics_process(1.0/60.0)
		freeze()
		loadout.active_casting.tick(1.0/60.0)
		for enemy in enemies: enemy._process_burning(1.0/60.0)
		var used := (Time.get_ticks_usec()-begin)/1000.0
		peaks = maxi(peaks,get_tree().get_nodes_in_group("candidate_weapon_art").size())
		if graphical:
			await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		# Skip cold frames and screenshot I/O from the measured distribution.
		if frame >= 120:
			cpu.append(used)
			wall.append((now-last)/1000.0)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if graphical and frame == capture_at:
			get_viewport().get_texture().get_image().save_png(output.path_join(str(spec[0])+".png"))
		last = Time.get_ticks_usec()
		await get_tree().process_frame
	var result := {"id":spec[0],"cpu_ms":stats(cpu),"frame_ms":stats(wall),"draw_calls":stats(calls),"peak_weapon_visuals":peaks}
	report.cases.append(result)
	print("BENCHMARK ",JSON.stringify(result))

func stats(samples: Array[float]) -> Dictionary:
	samples.sort()
	var sum := 0.0
	for value in samples: sum += value
	return {"mean":sum/samples.size(),"median":samples[samples.size()/2],"p95":samples[mini(samples.size()-1,ceili(samples.size()*0.95)-1)],"max":samples.back()}
