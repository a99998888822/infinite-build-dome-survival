extends "res://scripts/debug/greed_promo.gd"
## One manually released domain, live AI and actual native/attachment contacts.
const BUILD = preload("res://scripts/debug/fixtures/kunyu_promo_build.gd")
var points: Array[Vector2] = []
var observed := {}
var contacts: Array[Dictionary] = []
var volleys: Dictionary = {}
var ground_strikes := 0
var cast_count := 0
var domains := 0
var move_heading := Vector2.DOWN
var advancing := false


func _ready() -> void:
	WindowSettings._startup_applied = true
	take = "kunyu_split_combat"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--advance": advancing = true
	if advancing:
		take = "kunyu_double_split_advance"
		move_heading = Vector2.RIGHT
	if output_dir.is_empty() or not "--transient-session" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not "--background-capture" in OS.get_cmdline_user_args():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	total = 300
	_run.call_deferred()


func _run() -> void:
	seed(10272026)
	get_tree().node_added.connect(func(node: Node):
		if node is CavernPopulationBackdrop: node.population_seed = 20261024)
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	CombatSettings.set_option("show_hints", false, false)
	CombatSettings.set_weapon_auto_cast(BUILD.TOME, false, false)
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
	var config := BUILD.advance_config() if advancing else BUILD.split_config()
	report.config = config
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		await _finish()
		return
	check(session.begin(), "Combat must start")
	battle = session.battle
	player = battle.player
	controller = battle.active_controller
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	controller.set_process(false)
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	origin = Vector2(-350, -200) if advancing else Vector2(0, -200)
	player.global_position = origin
	player._clear_move_input()
	_camera(origin + Vector2(140 if advancing else 0, -18), 1.15 if advancing else 1.0)
	var weapon := battle.loadout.get_weapon_instance(BUILD.TOME)
	report.projectiles = int(weapon.get_stat("projectile_count"))
	report.player_projectiles = int(player.get_stat("projectile_count"))
	report.attachments = weapon.get_attached_item_instances().map(func(item): return item.base_item_id)
	report.expected_rounds = 3 + report.projectiles - 1
	report.domain_axes = [weapon.get_domain_axes().x, weapon.get_domain_axes().y]
	report.damage_area_bonus = weapon.get_stat("damage_area_size")
	report.attack_distance_bonus = weapon.get_stat("area_size")
	report.projectile_bonus = report.player_projectiles - 1
	check(report.player_projectiles == (6 if advancing else 3), "Player projectile attribute must match the requested build")
	check(report.projectiles == (8 if advancing else 6), "Weapon projectile count must match the requested build")
	if advancing:
		check(is_equal_approx(weapon.get_domain_axes().x, 420), "Advance take must use the smaller native targeting domain")
	else:
		check(weapon.get_domain_axes().x > 540 and weapon.get_domain_axes().y > 430, "Build must create an oversized real targeting domain")
	var rng := RandomNumberGenerator.new()
	rng.seed = 73254
	var enemy_count := 48 if advancing else 60
	for attempt in 10000:
		if points.size() >= enemy_count: break
		var local := Vector2(rng.randf_range(205, 790), rng.randf_range(-245, 245)) if advancing else Vector2(rng.randf_range(-510, 580), rng.randf_range(-380, 380))
		if advancing:
			if ((local - Vector2(490, 0)) / Vector2(320, 275)).length_squared() > 1: continue
			# Stagger the forward groups around a loose gap; live AI closes it.
			if local.x < 470 and absf(local.y) < 135: continue
		else:
			if ((local - Vector2(50, 0)) / Vector2(550, 410)).length_squared() > 1 or local.length() < 235: continue
			# A natural gap between scattered groups gives the player a retreat route.
			if local.x < -130 and local.y > 70: continue
		var spaced := true
		for point in points:
			if point.distance_to(origin + local) < (56 if advancing else 64):
				spaced = false
				break
		if not spaced: continue
		points.append(origin + local)
		_spawn(origin + local)
		var enemy: EnemyController = enemies.back()
		enemy.set_meta("promo_index", enemies.size() - 1)
	check(enemies.size() == enemy_count, "Scatter the configured native enemies across the combat area")
	report.initial_enemies = enemies.size()
	report.spawn_points = points.map(func(point): return [point.x, point.y])
	await frames(18)
	_clean_hud()
	battle.hud.battle_top_bar.hide()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for voice in AudioManager._sfx_players: voice.stop()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	CombatHitFeedback.feedback_started.connect(_on_hitstop)
	aim = origin + Vector2(320, 80)
	report.gold_start = battle.wave_manager.current_gold
	report.hp_start = player.current_hp
	report.start_frame = Engine.get_frames_drawn()
	for i in total:
		frame = i
		if hitstop_end >= 0 and frame >= hitstop_end:
			CombatHitFeedback.hitstop_until_usec = 0
			hitstop_end = -1
		if frame == 0: _move(origin + (Vector2(100, 0) if advancing else Vector2(-25, 20)))
		if frame == 4: _key(KEY_1)
		if frame == (8 if advancing else 18):
			_cast()
			cast_count += 1
		if frame >= (30 if advancing else 54) and frame % 30 == 0: _steer()
		camera.global_position = camera.global_position.lerp(player.global_position + Vector2(140 if advancing else 0, -18), 0.05)
		_observe_effects()
		_point(aim)
		controller._update_indicator()
		controller._update_cursor_icon()
		_update_bar()
		if frame % 10 == 0:
			report.samples.append({"frame": frame, "hp": player.current_hp, "kills": kills,
				"player": [player.global_position.x, player.global_position.y], "contacts": contacts.size(), "ground_strikes": ground_strikes})
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if frame % 15 == 0 or frame == total - 1:
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	report.contacts = contacts
	report.volleys = volleys
	report.volley_count = volleys.size()
	report.ground_strikes = ground_strikes
	report.cast_count = cast_count
	report.domains = domains
	report.forward_distance = player.global_position.x - origin.x
	check(player.is_alive(), "Player must remain alive")
	check(cast_count == 1 and domains == 1, "Show one domain opened by a real manual cast")
	check(ground_strikes > 0 and kills > 0, "Native attacks must trigger real lightning and kills")
	check(volleys.size() >= (8 if advancing else int(report.expected_rounds)), "Show the native continuous-mark sequence")
	var targets_per_round := 5 if advancing else 3
	for volley: Array in volleys.values():
		var unique := {}
		for target in volley: unique[target] = true
		check(volley.size() <= targets_per_round and unique.size() == volley.size(), "Every round must hit distinct primary and split targets")
	var children := contacts.filter(func(contact): return contact.child).size()
	check(ground_strikes == children, "Each split contact must trigger the following lightning attachment")
	if advancing:
		check(player.current_hp == report.hp_start, "Advance smoothly without taking damage")
		check(report.forward_distance > 300, "Advance into the crowd instead of retreating")
		check(kills >= 36, "Clear most of the scattered crowd")
	await _finish()


func _observe_effects() -> void:
	for domain: RitualDomain in get_tree().get_nodes_in_group("ritual_domains"):
		var id := domain.get_instance_id()
		if observed.has(id): continue
		observed[id] = true
		domains += 1
		domain.target_rng.seed = 452019
		domain.target_hit.connect(func(target_id: int, damage: int, child: bool):
			var enemy := instance_from_id(target_id) as EnemyController
			var index := int(enemy.get_meta("promo_index", -1)) if enemy != null else -1
			contacts.append({"frame": frame, "physics_frame": Engine.get_physics_frames(), "target": index, "damage": damage, "child": child})
			var key := str(Engine.get_physics_frames())
			if not volleys.has(key): volleys[key] = []
			volleys[key].append(index))
	for effect in get_tree().get_nodes_in_group("combat_particle_counters"):
		if not is_instance_valid(effect) or effect.get_script() == null: continue
		var id: int = effect.get_instance_id()
		if observed.has(id): continue
		observed[id] = true
		if effect is LightningParticleEffect and effect._is_ground_strike: ground_strikes += 1


func _steer() -> void:
	# Evaluate short walks through actual moving enemies, then send native RMB.
	var waypoint := origin + Vector2(-180, 120) if frame < 180 else origin + Vector2(-170, 10)
	if advancing: waypoint = origin + Vector2(720, 0)
	var desired := player.global_position.direction_to(waypoint)
	var best := -INF
	var chosen := move_heading
	for i in 24:
		var direction := Vector2.RIGHT.rotated(TAU * i / 24.0)
		if advancing and direction.x < 0.5: continue
		var clearance := 180.0
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy.is_alive(): continue
			for seconds: float in [0.2, 0.4, 0.6]:
				var enemy_at := enemy.global_position + enemy.global_position.direction_to(player.global_position) * enemy.get_chase_speed() * seconds
				var player_at := player.global_position + direction * player.get_stat("move_speed") * seconds
				clearance = minf(clearance, enemy_at.distance_to(player_at))
		var distance := (player.global_position + direction * 75).distance_to(origin)
		var score := minf(clearance, 110) * 2 + direction.dot(desired) * 28 + direction.dot(move_heading) * 18 - maxf(0, distance - 190) * 0.45
		if advancing:
			score = minf(clearance, 90) * 4 + direction.dot(desired) * 80 + direction.dot(move_heading) * 30 - absf(player.global_position.y + direction.y * 72 - origin.y) * 0.1
		if score > best:
			best = score
			chosen = direction
	move_heading = chosen
	_move(player.global_position + chosen * 72)


func _finish() -> void:
	AudioManager.stop_bgm()
	AudioManager._bgm_player.stream = null
	await super._finish()
