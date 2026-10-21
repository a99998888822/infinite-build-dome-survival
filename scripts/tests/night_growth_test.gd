extends "res://scripts/tests/night_evacuation_test.gd"
## Production battle regression for dusk, spawn snapshots, speed caps and flanks.
var timeline: Array[Dictionary] = []

func _ready() -> void:
	output = "res://artifacts/previews/night_growth"
	super._ready()

func run() -> void:
	CampProgression.begin_transient_session()
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	await boot()
	# Use the real countdown and renderer, including the frame before nightfall.
	for sample in [[11.0,0.0],[10.0,0.0],[5.0,0.15625],[0.0,0.5]]:
		manager.wave_time_left = sample[0]
		evacuation.visual.refresh()
		check(is_equal_approx(evacuation.night_progress(),sample[1]),"countdown fade at "+str(sample[0]))
		check(not evacuation.visual.night_material.get_shader_parameter("bunker_light_enabled"),"no phantom bunker light before night")
		if review: await capture("countdown_%02d" % int(sample[0]))
	manager.wave_time_left = 5.0
	flow.request_esc_overlay()
	manager._process(20.0)
	check(is_equal_approx(manager.wave_time_left,5.0),"pause freezes dusk countdown")
	flow.close_esc_overlay()
	manager.wave_time_left = 0.0
	manager._process(0.0)
	for sample in [[0.0,0.5],[5.0,0.84375],[10.0,1.0],[80.0,1.0]]:
		evacuation.elapsed = sample[0]
		evacuation.visual.refresh()
		check(is_equal_approx(evacuation.night_progress(),sample[1]),"continuous night fade at "+str(sample[0]))
		check(is_equal_approx(float(evacuation.visual.night_material.get_shader_parameter("darkness")),sample[1]*0.88),"renderer receives night strength")
		if review: await capture("night_%02d" % int(sample[0]))
	# Every sample is a fresh instance with same-wave/difficulty stats underneath.
	var first: EnemyController
	var first_hp := 0
	var first_damage := 0.0
	var first_speed := 0.0
	for sample in [[0.0,1.0,1.0],[10.0,1.5,1.0],[20.0,2.0,1.0],[30.0,2.25,1.5],[40.0,2.5,2.0],[50.0,2.75,2.25],[60.0,3.0,2.5],[100.0,4.0,3.5]]:
		var result := spawn_probe(float(sample[0]))
		var enemy := result.enemy as EnemyController
		check(enemy != null,"new enemy at night "+str(sample[0]))
		if enemy == null: continue
		check(absf(enemy.get_stat("max_hp")-float(result.hp)*float(sample[1]))<=1.0,"spawn HP factor at "+str(sample[0]))
		check(is_equal_approx(enemy.get_stat("melee_damage"),float(result.damage)*float(sample[2])),"spawn attack factor at "+str(sample[0]))
		check(enemy.current_hp==int(enemy.get_stat("max_hp")),"fresh enemy starts at its grown max HP")
		if sample[0]<=40.0:
			check(is_equal_approx(enemy.get_chase_speed(),result.speed),"no speed growth through night 40")
		elif sample[0]==50.0:
			check(enemy.get_chase_speed()>float(result.speed) and enemy.get_chase_speed()<player.get_stat("move_speed")*0.95,"speed rises gradually at night 50")
		elif sample[0]>=60.0:
			check(is_equal_approx(enemy.get_chase_speed(),player.get_stat("move_speed")*0.95),"speed reaches 95 percent at night 60 and stays capped")
		timeline.append({"night_seconds":sample[0],"hp":enemy.current_hp,"attack":enemy.get_stat("melee_damage"),"speed":enemy.get_chase_speed()})
		if first == null:
			first = enemy
			first_hp = maxi(1,enemy.current_hp-3)
			first.current_hp = first_hp
			first_damage = enemy.get_stat("melee_damage")
			first_speed = enemy.get_chase_speed()
	check(first.current_hp==first_hp and is_equal_approx(first.get_stat("melee_damage"),first_damage) and is_equal_approx(first.get_chase_speed(),first_speed),"older damaged enemies retain their birth stats and health")
	await verify_speed_cap()
	await verify_flanks()
	await boot()
	check(not evacuation.visual.night_rect.visible and not evacuation.visual.lit and is_zero_approx(evacuation.elapsed),"new battle resets dusk and growth")
	check(is_equal_approx(evacuation.next_flank_at,12.0) and not evacuation.flank_spawn_authorized,"new battle resets rare flank schedule and authorization")
	flow.enter_start_page()
	await frames(8)
	CampProgression.end_transient_session()
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"timeline":timeline},"\t"))
	print("NIGHT_GROWTH checks=",checks," failures=",failures.size())
	game.queue_free()
	await frames(8)
	get_tree().quit(0 if failures.is_empty() else 1)

func spawn_probe(seconds: float, id := "enemy_mutated_grub") -> Dictionary:
	evacuation.elapsed = seconds
	var point := evacuation.choose_spawn_position()
	evacuation.spawn_authorized = true
	var enemy := manager.spawn_enemy(id,point)
	evacuation.spawn_authorized = false
	if enemy == null: return {"enemy":null}
	enemy.set_physics_process(false)
	var result := {"enemy":enemy,"hp":enemy.get_stat("max_hp"),"damage":enemy.get_stat("melee_damage"),"speed":enemy.get_chase_speed()}
	enemy.set_meta("evacuation_enemy",true)
	evacuation.apply_pressure(enemy)
	return result

func verify_speed_cap() -> void:
	var enemy := spawn_probe(600.0).enemy as EnemyController
	var hunter := spawn_probe(600.0,"enemy_elite_rusher").enemy as EliteRusher
	check(enemy != null and hunter != null,"ordinary and hunter samples exist for speed checks")
	if enemy == null or hunter == null: return
	var cap := player.get_stat("move_speed")*0.95
	check(is_equal_approx(enemy.get_chase_speed(),cap) and is_equal_approx(hunter.get_chase_speed(),cap),"long-night ordinary and hunter speed share player cap")
	player.modifier_stack.add_modifier_from_dictionary({"id":"night_test_slow","source_type":"test","source_id":"night_test","target_scope":"player","stat":"move_speed","operation":"multiply","value":0.4,"duration":-1,"stack_rule":"unique"})
	cap = player.get_stat("move_speed")*0.95
	enemy.velocity = Vector2.RIGHT*1000.0
	enemy._process_chase()
	check(enemy.get_stat("move_speed")<=cap and enemy.velocity.length()<=cap+0.001,"player slow immediately caps stat and existing chase momentum")
	hunter.skill_state = "chase"
	hunter._cooldown = 0.0
	hunter.global_position = player.global_position+Vector2(100,0)
	hunter._cavern_scenery = null
	check(hunter.start_dash(),"night hunter still enters its telegraphed skill")
	hunter.skill_state = "dash"
	hunter._state_time = 0.0
	var before := hunter.global_position
	hunter._process_special_behavior(0.05)
	check(hunter.global_position.distance_to(before)<=cap*0.05+0.01,"night hunter dash also respects player speed cap")
	player.modifier_stack.remove_by_source("test","night_test")
	clear_probe_enemies()
	await frames()

func verify_flanks() -> void:
	# Validate all approach directions, including an approach from above the art.
	var sample_count := 0
	var sectors_valid := true
	var original := evacuation.foot_position()
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		await move_foot(evacuation.ring_center+direction*900.0)
		for i in 32:
			var point := evacuation.choose_flank_spawn_position()
			if not point.is_finite(): continue
			sample_count += 1
			sectors_valid = sectors_valid and evacuation.spawn_position_valid(point,true) and not evacuation.spawn_position_valid(point)
	check(sectors_valid,"all far-bunker samples use a separate sector")
	check(sample_count==128,"all approach directions produce clear flank positions")
	await move_foot(original)
	evacuation.elapsed = 12.0
	evacuation.next_flank_at = 12.0
	evacuation._process_flank_spawn()
	var flankers := EnemyRegistry.get_registered_enemies().filter(func(e): return bool(e.get_meta("evacuation_flanker",false)))
	check(flankers.size()==1,"first flank is exactly one ordinary enemy")
	if not flankers.is_empty():
		flankers[0].set_physics_process(false)
		var point: Vector2 = flankers[0].global_position
		evacuation.spawn_authorized = true
		check(not evacuation.allows_spawn(point),"ordinary spawn authorization cannot use flank sector")
		evacuation.spawn_authorized = false
	check(evacuation.next_flank_at>=30.0 and evacuation.next_flank_at<=38.0,"flank cooldown is 18 to 26 seconds")
	for i in 5:
		evacuation.elapsed = evacuation.next_flank_at
		evacuation._process_flank_spawn()
		for e in EnemyRegistry.get_registered_enemies(): e.set_physics_process(false)
	flankers = EnemyRegistry.get_registered_enemies().filter(func(e): return bool(e.get_meta("evacuation_flanker",false)))
	check(flankers.size()==2,"at most two flankers survive even after repeated intervals")
	clear_probe_enemies()
	await frames()
	# Exercise the actual scheduled night spawns; keep space available without drops.
	evacuation.elapsed = 0.0
	evacuation.next_flank_at = 12.0
	evacuation.next_hunter_at = 10000.0
	evacuation.spawn_timers.fill(3.0)
	var total := 0
	var rare := 0
	for i in 120:
		manager._process(0.5)
		for e in EnemyRegistry.get_registered_enemies():
			if not e.is_alive(): continue
			total += 1
			if bool(e.get_meta("evacuation_flanker",false)): rare += 1
		clear_probe_enemies()
		await frames(1)
	check(rare>=2 and rare<=3 and total>rare*10,"actual night schedule keeps flankers sparse: %d of %d" % [rare,total])
	var old_limit: int = manager._difficulty.enemy_limit
	manager._difficulty.enemy_limit = 0
	evacuation.next_flank_at = evacuation.elapsed
	manager._process(0.5)
	check(manager.get_living_enemy_count()==0,"flank and ordinary spawns obey the shared population cap")
	manager._difficulty.enemy_limit = old_limit

func clear_probe_enemies() -> void:
	# Production cleanup fades for 0.2 seconds; these samples need an empty registry now.
	for enemy in EnemyRegistry.get_registered_enemies().duplicate(): enemy.free()
