extends "res://scripts/tests/weapon_trio_test.gd"
## Fixed-step production runtimes and real contacts; graphical wall times separate.
var results: Array = []
var spells := ["scroll_multishot","scroll_water","scroll_electric_spark"]
var ids := ["weapon_void_blade","weapon_earth_hammer","weapon_nightwatch_spear","weapon_furnace"]

# No automatic loadout attacks or wall-clock dependent effect ticks during setup.
func fixture(id: String, positions: Array, _attachments: Array = []) -> void:
	await setup(positions)
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	loadout = WeaponLoadout.new()
	host.add_child(loadout)
	loadout.initialize(player)
	loadout.set_process(false)
	loadout.set_physics_process(false)
	check(loadout.equip_weapon(id), "equip " + id)
	weapon = loadout.get_weapon_instance(id)
	await frames()

func freeze_tree(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze_tree(child)

func spawn_volley(w: WeaponInstance) -> void:
	var copy := w.make_cast_copy()
	copy.begin_attack()
	if copy.is_earth_hammer():
		var runtime := EarthHammer.new()
		host.add_child(runtime)
		runtime.initialize(copy,Vector2.RIGHT)
	elif copy.is_nightwatch_spear():
		var runtime := NightwatchSpear.new()
		host.add_child(runtime)
		runtime.initialize(copy,Vector2.RIGHT)
	elif copy.is_furnace():
		var runtime := FurnaceRuntime.new()
		host.add_child(runtime)
		runtime.initialize(copy)
	else:
		for angle in copy.get_projectile_angles():
			var ball := ProjectileInstance.new()
			host.add_child(ball)
			ball.initialize(copy,copy.calculate_damage_events()[0],"vfx_benchmark",copy.get_attack_origin(),Vector2.RIGHT.rotated(deg_to_rad(angle)),copy.get_attack_range(),load(copy.weapon_data.projectile_texture),1.0)

func _run() -> void:
	var graphical := DisplayServer.get_name()!="headless"
	if graphical and not "--background-capture" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	var output := "res://artifacts/reports/approved_weapon_vfx_after.json"
	var count := 150
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--enemies="): count=int(arg.trim_prefix("--enemies="))
	if graphical:
		get_window().size=Vector2i(1152,648)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	CampProgression.begin_transient_session()
	Engine.max_fps=0
	if "--live" in OS.get_cmdline_user_args():
		await run_live(output, count, graphical)
		return
	EffectScheduler.set_process(false)
	for scenario in ids+["mixed"]:
		var positions: Array=[]
		for i in count: positions.append(Vector2(40+(i%25)*18,(i/25-count/50.0)*12))
		await fixture(ids[0] if scenario=="mixed" else scenario,positions)
		player.add_runtime_modifier({"id":"benchmark_capacity","source_id":"benchmark","source_type":"test","stat":"load_capacity","operation":"override","value":1000,"duration":-1,"stack_rule":"unique","target_scope":"player"})
		if scenario=="mixed":
			for id in ids.slice(1): check(loadout.equip_weapon(id),"mixed equips "+id)
		for w: WeaponInstance in loadout.weapon_instances:
			while w.level<5: loadout.upgrade_weapon(w.weapon_id)
			w.use_active_range_rules=true
			for item_id in spells:
				var item:=player.item_inventory.add_item_from_base(item_id,"vfx_benchmark")
				check(loadout.attach_item_to_weapon(w.weapon_id,item.item_instance_id),"attach "+item_id)
			w.runtime_stats.crit_chance=0
		loadout.set_process(false)
		loadout.set_physics_process(false)
		for enemy in enemies: enemy.current_hp=10000000
		seed(741)
		var cpu: Array[float]=[]
		var wall: Array[float]=[]
		var peak_nodes:=0
		var categories: Dictionary = {}
		for frame in 150:
			var start:=Time.get_ticks_usec()
			if frame%50==0:
				for w: WeaponInstance in loadout.weapon_instances: spawn_volley(w)
			for child in host.get_children():
				if child is EnemyController or child==player or child==loadout: continue
				child.set_process(false)
				child.set_physics_process(false)
				if child.is_queued_for_deletion(): continue
				var tick_start := Time.get_ticks_usec()
				if child.has_method("_physics_process"): child._physics_process(1.0/60.0)
				if child.has_method("_process"): child._process(1.0/60.0)
				var category: String = child.get_script().resource_path if child.get_script() != null else child.get_class()
				categories[category] = float(categories.get(category, 0.0)) + (Time.get_ticks_usec()-tick_start)/1000.0
			var scheduled_start := Time.get_ticks_usec()
			EffectScheduler._process(1.0/60.0)
			categories["scheduler"] = float(categories.get("scheduler", 0.0)) + (Time.get_ticks_usec()-scheduled_start)/1000.0
			cpu.append((Time.get_ticks_usec()-start)/1000.0)
			freeze_tree(host)
			peak_nodes=maxi(peak_nodes,host.get_child_count())
			if graphical: await RenderingServer.frame_post_draw
			await get_tree().process_frame
			wall.append((Time.get_ticks_usec()-start)/1000.0)
		var damage:=0
		var hp: Array[int] = []
		for enemy in enemies:
			damage+=10000000-enemy.current_hp
			hp.append(enemy.current_hp)
		var row: Dictionary={"scenario":scenario,"enemies":count,"damage":damage,"hp":hp,"cpu":stats(cpu),"wall":stats(wall),"peak_host_children":peak_nodes,"category_total_ms":categories}
		results.append(row)
		print("APPROVED_VFX_BENCH ",JSON.stringify(row))
	if is_instance_valid(host): host.queue_free()
	await frames()
	EffectScheduler.set_process(true)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"graphical":graphical,"adapter":RenderingServer.get_video_adapter_name() if graphical else "headless","fixed_step":true,"fps_claim":false,"failures":failures,"results":results},"  "))
	print("APPROVED_VFX_BENCH_COMPLETE failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func stats(values: Array[float]) -> Dictionary:
	var total:=0.0
	for value in values: total+=value
	values.sort()
	return {"mean_ms":total/values.size(),"p95_ms":values[int(values.size()*0.95)],"max_ms":values.back()}

func run_live(output: String, count: int, graphical: bool) -> void:
	Engine.max_fps = 60
	var positions: Array = []
	for i in count: positions.append(Vector2(40 + (i % 25) * 18, (i / 25 - count / 50.0) * 12))
	await fixture(ids[0], positions)
	host.position = Vector2(180, 324)
	player._invincibility_timer = 10000
	player.add_runtime_modifier({"id":"benchmark_capacity","source_id":"benchmark","source_type":"test","stat":"load_capacity","operation":"override","value":1000,"duration":-1,"stack_rule":"unique","target_scope":"player"})
	for id in ids.slice(1): check(loadout.equip_weapon(id), "live mixed equips " + id)
	for w: WeaponInstance in loadout.weapon_instances:
		while w.level < 5: loadout.upgrade_weapon(w.weapon_id)
		w.use_active_range_rules = true
		for item_id in spells:
			var item := player.item_inventory.add_item_from_base(item_id, "vfx_benchmark")
			check(loadout.attach_item_to_weapon(w.weapon_id, item.item_instance_id), "live attach " + item_id)
		w.runtime_stats.crit_chance = 0
	for enemy in enemies:
		enemy.current_hp = 10000000
		if "--moving" in OS.get_cmdline_user_args():
			enemy.set_target_player(player)
			enemy.set_physics_process(true)
	# Prepare shared GPU paths before measuring combat. No damage or RNG involved.
	var warm := Node2D.new()
	add_child(warm)
	var warmer = preload("res://scripts/effects/weapon_render_warmup.gd")
	for kind in warmer.KINDS: warmer.prepare(warm, kind)
	for i in 30: await get_tree().process_frame
	warm.queue_free()
	await get_tree().process_frame
	var wall: Array[float] = []
	var process_times: Array[float] = []
	var physics_times: Array[float] = []
	var peak_nodes := 0
	var peak_draws := 0
	var start := Time.get_ticks_usec()
	var previous := start
	var volleys := 0
	seed(741)
	while Time.get_ticks_usec() - start < 6000000:
		if volleys < 3 and Time.get_ticks_usec() - start >= volleys * 833333:
			for w: WeaponInstance in loadout.weapon_instances: spawn_volley(w)
			volleys += 1
		if graphical: await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		wall.append((now - previous) / 1000.0)
		previous = now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		peak_nodes = maxi(peak_nodes, host.get_child_count())
		peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var over := 0
	for value in wall:
		if value > 16.667: over += 1
	var damage := 0
	for enemy in enemies: damage += 10000000 - enemy.current_hp
	var report := {"live":true,"target_fps":60,"samples":wall.size(),"elapsed_seconds":(Time.get_ticks_usec()-start)/1000000.0,"moving": "--moving" in OS.get_cmdline_user_args(),"enemies":count,"volleys":volleys,"wall":stats(wall),"engine_process":stats(process_times),"engine_physics":stats(physics_times),"over_16_67_ms_percent":100.0*over/wall.size(),"peak_host_children":peak_nodes,"peak_draw_calls":peak_draws,"damage":damage,"adapter":RenderingServer.get_video_adapter_name(),"failures":failures}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("APPROVED_VFX_LIVE ", JSON.stringify(report))
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures == 0 else 1)
