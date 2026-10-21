extends "res://scripts/tests/weapon_trio_test.gd"

const FLAIL := "weapon_meteor_flail"
const PLASMA := "weapon_plasma_cannon"
const BOW := "weapon_void_blade"
const GRENADE := "weapon_iron_grenade_cannon"
const TOME := "weapon_kunyu_ritual_tome"
const COIN := "weapon_rentier_purse"
const CANNON := "weapon_hand_cannon"
const SPEAR := "weapon_nightwatch_spear"
const DAGGER := "weapon_camp_dagger"
const DASH := "weapon_dash_blade"
const STAR := "weapon_star_tome"
var records: Array[Dictionary] = []

func total(stat: String, value: float) -> void:
	weapon.runtime_stats[stat] = float(weapon.runtime_stats.get(stat, 0.0)) + value - weapon.get_stat(stat)

func prepare(id: String, positions: Array, area: float = 0.0) -> void:
	await setup(positions)
	player = load("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	loadout = WeaponLoadout.new()
	host.add_child(loadout)
	loadout.initialize(player)
	check(loadout.equip_weapon(id), "equip " + id)
	weapon = loadout.get_weapon_instance(id)
	loadout.set_active_combat_enabled(true)
	for stat in ["area_size", "damage_area_size", "crit_chance", "attack_speed"]:
		total(stat, area if stat == "damage_area_size" else 0.0)
	total("projectile_count", 1.0)
	await frames()

func start_cast(point := Vector2(1000, 0)) -> Node2D:
	check(loadout.cast_weapon(weapon, point), "production active cast " + weapon.weapon_id)
	var state := loadout.active_casting.state_for(weapon)
	var runtime: Node2D = state.body.get_ref() if state.body is WeakRef else null
	for node in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if not host.is_ancestor_of(node): continue
		node.set_physics_process(false)
		if runtime == null and (node is ProjectileInstance or node is CoinProjectile or node is GrenadeProjectile):
			runtime = node
	return runtime

func tick(runtime: Node2D, duration: float, step := 1.0 / 120.0) -> void:
	var left := duration
	while left > 0.000001 and is_instance_valid(runtime) and not runtime.is_queued_for_deletion():
		var dt := minf(step, left)
		runtime._physics_process(dt)
		left -= dt

func record(label: String, extra: Dictionary = {}) -> void:
	var row := {"case": label, "weapon": weapon.weapon_id, "hp": enemies.map(func(e): return e.current_hp)}
	row.merge(extra)
	records.append(row)
	print("AUDIT_CASE ", JSON.stringify(row))

func bitmap(path: String) -> Image:
	var result := Image.new()
	result.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	return result

func opaque_overlap(path: String, region: Rect2i, transform: Transform2D, enemy: EnemyController) -> int:
	var source := bitmap(path)
	var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var point := CircleShape2D.new()
	point.radius = 0.1
	var count := 0
	for y in region.size.y:
		for x in region.size.x:
			if source.get_pixel(region.position.x + x, region.position.y + y).a < 0.9: continue
			var world := transform * Vector2(x + 0.5, y + 0.5)
			if point.collide(Transform2D(0, world), body.shape, body.global_transform): count += 1
	return count

func overlaps_shape(shape: Shape2D, at: Vector2, enemy: EnemyController) -> bool:
	var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
	return shape.collide(Transform2D(0, at), body.shape, body.global_transform)

func _run() -> void:
	CampProgression.begin_transient_session()
	await _controls()
	await _flail_edge()
	await _point_based_edges()
	await _plasma_growth()
	await _tentacle_timing()
	await _surface_controls()
	await _projectile_step_probe()
	await _growth_and_walls()
	await _hammer_regressions()
	await _negative_edges()
	await _projectile_lifecycle()
	FileAccess.open("res://artifacts/reports/weapon_contact_fix_results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "records": records}, "\t"))
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("WEAPON_CONTACT_REGRESSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _controls() -> void:
	for id in [BOW, PLASMA, GRENADE, TOME, COIN, LAMP, TENTACLE, HAMMER, DAGGER, SPEAR, FLAIL, DASH, CANNON, STAR]:
		await prepare(id, [Vector2(80, 0)])
		var point := Vector2.ZERO if id == GRENADE else Vector2(100, 0) if id in [DASH, STAR] else Vector2(1000, 0)
		var runtime := start_cast(point)
		check(runtime != null, "runtime exists " + id)
		if runtime == null: continue
		if id in [BOW, PLASMA]:
			for i in 60:
				if not is_instance_valid(runtime) or runtime.is_queued_for_deletion() or enemies[0].current_hp < 10000: break
				runtime._physics_process(1.0 / 60.0)
				await frames()
		elif id == CANNON:
			for child in runtime.get_children():
				if child is CannonPellet: tick(child, 0.25)
		elif id == DASH:
			player.cancel_mobility_motion(runtime)
			player.position = point
			runtime._physics_process(0.23)
		elif id != STAR:
			tick(runtime, 1.05 if id == HAMMER else 0.55 if id in [FLAIL, GRENADE] else 0.32)
		check(enemies[0].current_hp < 10000, "in-range stationary control damages " + id)
		record("stationary_control")

func _flail_edge() -> void:
	await prepare(FLAIL, [Vector2(265, 0)])
	var flail := start_cast() as MeteorFlail
	tick(flail, 0.315)
	var swing := flail.swings[0]
	var head := flail.head_position(swing, flail.age)
	var grip := AttackFootprint.project(AttackFootprint.ground_direction(flail.heading) * 14.0)
	var rotation := (head - grip).angle() + flail.age * float(swing.sign) * 5.0
	var radius := flail.head_radius(swing)
	var pose := Transform2D(rotation, Vector2.ONE * radius / 20.0, 0, head.round())
	pose.origin -= pose.basis_xform(Vector2(20, 20))
	var pixels := opaque_overlap("res://assets/sprites/weapons/meteor_flail/meteor_flail_head.png", Rect2i(0, 0, 40, 40), pose, enemies[0])
	check(pixels > 0, "flail iron head opaque pixels intersect real enemy body outside center range")
	tick(flail, 0.24)
	check(enemies[0].current_hp < 10000, "flail damages contacted body beyond enemy root range")
	record("flail_head_edge_contact", {"opaque_pixels_inside_body": pixels, "reach": weapon.get_attack_range(), "head_radius": radius})

func _point_based_edges() -> void:
	await prepare(LAMP, [Vector2(80, 0), AttackFootprint.project(Vector2(16, 0) + Vector2.from_angle(deg_to_rad(34)) * 110)])
	var lamp := start_cast() as CopperLamp
	var reach := weapon.get_attack_range()
	var points := PackedVector2Array([AttackFootprint.project(Vector2(16, 0))])
	for i in 33:
		var ray := Vector2.from_angle(lerpf(-PI / 6, PI / 6, i / 32.0))
		var projection := Vector2(16, 0).dot(ray)
		points.append(AttackFootprint.project(Vector2(16, 0) + ray * (-projection + sqrt(projection * projection + reach * reach - 16 * 16))))
	var cone := ConvexPolygonShape2D.new()
	cone.points = points
	check(overlaps_shape(cone, Vector2.ZERO, enemies[1]), "lamp edge body overlaps the same cone clipped by flame shader")
	tick(lamp, 0.30)
	check(enemies[0].current_hp < 10000 and enemies[1].current_hp < 10000, "lamp includes real body at cone edge")
	record("lamp_body_edge_contact", {"body_overlaps_cone": true})

	for id in [GRENADE, TOME]:
		await prepare(id, [])
		var edge := weapon.get_grenade_blast_radius() if id == GRENADE else weapon.get_domain_axes().x
		# Ritual marks choose one random target per hit. Isolate the edge body
		# so this contact check does not require a particular random sequence.
		# The central target is already covered by _controls().
		var positions := [Vector2(edge + 10, 0)]
		if id == GRENADE: positions.push_front(Vector2(50, 0))
		await prepare(id, positions)
		var runtime := start_cast(Vector2.ZERO)
		var shape := AttackFootprint.projected_disk(edge) if id == GRENADE else _ellipse(weapon.get_domain_axes())
		check(overlaps_shape(shape, Vector2.ZERO, enemies.back()), "body overlaps drawn area " + id)
		tick(runtime, 0.5 if id == GRENADE else 1.1)
		check(enemies.all(func(enemy): return enemy.current_hp < 10000), "area includes actual body edge " + id)
		record("area_root_only_edge", {"body_overlaps_area": true, "radius_x": edge})

func _ellipse(axes: Vector2) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for i in 96: points.append(Vector2.from_angle(TAU * i / 96.0) * axes)
	shape.points = points
	return shape

func _plasma_growth() -> void:
	await prepare(PLASMA, [Vector2(80, 40)], 100.0)
	var orb := start_cast() as ProjectileInstance
	orb.global_position = Vector2(80, 0)
	await frames()
	var visible_core := CircleShape2D.new()
	visible_core.radius = orb._plasma_visual.core_radius
	check(overlaps_shape(visible_core, orb.global_position, enemies[0]), "enlarged plasma solid core overlaps real body")
	check(orb._query_plasma_enemies().has(enemies[0]), "plasma collision includes visible core contact")
	tick(orb, 1.5)
	check(enemies[0].current_hp < 10000, "enlarged plasma damages visible core contact")
	record("plasma_growth_contact", {"core_radius": visible_core.radius, "hit_radius": weapon.get_hit_radius()})

func _tentacle_timing() -> void:
	await prepare(TENTACLE, [Vector2(80, 90)])
	var limb := start_cast() as MutantTentacle
	tick(limb, limb.hit_time + 0.001)
	enemies[0].position = Vector2(80, 0)
	await frames()
	check(limb.rectangle_contacts(Vector2.ZERO, Vector2.RIGHT, weapon.get_attack_range(), weapon.get_hit_radius()).has(enemies[0]), "tentacle late entrant body overlaps damage rectangle")
	tick(limb, 0.05)
	check(limb.attacking and limb.visible and enemies[0].current_hp == 10000, "tentacle visible recovery does not deal additional damage")
	record("tentacle_single_impact_timing", {"hit_time": limb.hit_time, "motion_duration": limb.motion_duration})

func _surface_controls() -> void:
	for id in [SPEAR, DAGGER, COIN, CANNON, DASH, STAR]:
		await prepare(id, [])
		var point := Vector2(100, 0)
		if id == SPEAR: point = Vector2(weapon.get_attack_range() + 12, 0)
		elif id == DAGGER: point = Vector2(weapon.get_dagger_outer_radius() + 12, 0)
		elif id in [COIN, CANNON]: point = Vector2(80, weapon.get_hit_radius() + 7)
		elif id in [DASH, STAR]: point = Vector2(100 + weapon.get_hit_radius() + 12, 0)
		await prepare(id, [point])
		var runtime := start_cast(Vector2(100, 0) if id in [DASH, STAR] else Vector2(1000, 0))
		if id == CANNON:
			for child in runtime.get_children():
				if child is CannonPellet: tick(child, 0.25)
		elif id == DASH:
			player.cancel_mobility_motion(runtime)
			player.position = Vector2(100, 0)
			runtime._physics_process(0.23)
		elif id != STAR: tick(runtime, 0.5)
		check(enemies[0].current_hp < 10000, "actual body edge is included " + id)
		record("body_edge_positive_control")

func _projectile_step_probe() -> void:
	# Deliberately enlarged physics step; not a claim about ordinary render FPS.
	for id in [BOW, PLASMA, COIN, CANNON]:
		await prepare(id, [Vector2(80, 0)])
		var runtime := start_cast()
		var projectile: Node2D = runtime
		if id == CANNON:
			for child in runtime.get_children():
				if child is CannonPellet: projectile = child
		await frames()
		projectile._physics_process(160.0 / float(projectile.speed))
		await frames()
		if id in [BOW, PLASMA]:
			check(enemies[0].current_hp < 10000, "swept arrow/plasma includes long-step contact " + id)
		else:
			check(enemies[0].current_hp < 10000, "swept projectile preserves long-step contact " + id)
		record("deliberate_160px_step", {"ordinary_physics_step": false})

func _growth_and_walls() -> void:
	for id in [BOW, PLASMA, COIN, HAMMER, CANNON]:
		for bonus: float in [0.0, 100.0, 300.0]:
			await prepare(id, [], bonus)
			var base := float(weapon.weapon_data.hit_radius)
			var factor := 1.0 + bonus / 200.0
			check(is_equal_approx(weapon.get_hit_radius(), base * factor), "contact size follows visual bonus " + id + str(bonus))
			var runtime := start_cast()
			if runtime is ProjectileInstance:
				check(is_equal_approx(runtime._hit_shape.radius, base * factor), "actual projectile shape grows once")
				if id == PLASMA:
					check(is_equal_approx(runtime._plasma_visual.core_radius, runtime._hit_shape.radius), "plasma core and collider identical without squared bonus")
			var snapshot: WeaponInstance = runtime.weapon
			total("damage_area_size", bonus + 100)
			check(is_equal_approx(snapshot.get_hit_radius(), base * factor), "in-flight contact keeps cast snapshot")
	for id in [BOW, PLASMA, COIN, CANNON]:
		await prepare(id, [Vector2(180, 0)], 100.0)
		wall(Vector2(90, 0))
		await frames()
		var runtime := start_cast()
		var projectile: Node2D = runtime
		if id == CANNON:
			for child in runtime.get_children():
				if child is CannonPellet: projectile = child
		await frames()
		projectile._physics_process(240.0 / float(projectile.speed))
		check(enemies[0].current_hp == 10000 and projectile.cancelled, "grown projectile cannot tunnel through wall " + id)
	for id in [LAMP, FLAIL, TOME]:
		await prepare(id, [])
		var reach := weapon.get_attack_range()
		await prepare(id, [Vector2(reach + 12, 0)])
		check(loadout.active_casting._auto_target(weapon) == enemies[0], "automatic acquisition includes body edge " + id)

func _hammer_regressions() -> void:
	for pair in [[Vector2(65, 52), 0.0], [Vector2(95, 65), 100.0]]:
		await prepare(HAMMER, [pair[0]], pair[1])
		var quake := start_cast() as EarthHammer
		tick(quake, 1.05)
		check(enemies[0].current_hp == 9970, "hammer opaque contact pose damages exactly once " + str(pair))
	await prepare(HAMMER, [Vector2(80, 90)])
	var quake := start_cast() as EarthHammer
	tick(quake, 0.621)
	enemies[0].position = Vector2(80, 0)
	await frames()
	tick(quake, 0.4)
	check(enemies[0].current_hp == 9970, "hammer contact window catches late body without duplicate hit")
	await prepare(HAMMER, [])
	var bat := load("res://scenes/enemy/echo_bat.tscn").instantiate() as EnemyController
	host.add_child(bat)
	bat.position = Vector2(140, 0)
	bat.current_hp = 10000
	bat.set_physics_process(false)
	wall(Vector2(160, 0))
	await frames()
	quake = start_cast() as EarthHammer
	tick(quake, 1.05)
	check(quake.blocked and bat.current_hp == 9970, "blocked node keeps native damage before wall")
	await prepare(HAMMER, [Vector2(210, 0)])
	wall(Vector2(160, 0))
	await frames()
	quake = start_cast() as EarthHammer
	tick(quake, 1.05)
	check(enemies[0].current_hp == 10000, "hammer clipped cell never damages beyond wall")
	await prepare(HAMMER, [Vector2(80, 0)])
	quake = start_cast() as EarthHammer
	tick(quake, 0.5)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	tick(quake, 2.0)
	check(enemies[0].current_hp == 10000 and is_equal_approx(quake.age, 0.5), "pause freezes hammer contact window")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	tick(quake, 0.2)
	check(enemies[0].current_hp == 9970, "hammer resumes contact once after pause")

func _negative_edges() -> void:
	for id in [FLAIL, LAMP, GRENADE, TOME]:
		await prepare(id, [])
		var reach := weapon.get_grenade_blast_radius() if id == GRENADE else weapon.get_attack_range()
		await prepare(id, [Vector2(80, 0), Vector2(reach + 100, 0)])
		var runtime := start_cast(Vector2.ZERO if id in [GRENADE, TOME] else Vector2(1000, 0))
		tick(runtime, 0.55 if id != TOME else 1.1)
		check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000, "outside actual shape remains safe " + id)
		await prepare(id, [Vector2(80, 0), Vector2(100, 0)])
		var body := enemies[1].get_node("CollisionShape2D") as CollisionShape2D
		body.position = Vector2(0, 1000)
		await frames()
		runtime = start_cast(Vector2.ZERO if id in [GRENADE, TOME] else Vector2(1000, 0))
		tick(runtime, 0.55 if id != TOME else 1.1)
		check(enemies[1].current_hp == 10000, "in-range root cannot hit remote collision body " + id)
	for id in [FLAIL, LAMP]:
		await prepare(id, [Vector2(80, 0), Vector2(160, 0)])
		wall(Vector2(120, 0))
		await frames()
		var runtime := start_cast()
		tick(runtime, 0.55)
		check(enemies[0].current_hp < 10000 and enemies[1].current_hp == 10000, "body-aware melee keeps wall occlusion " + id)

func _projectile_lifecycle() -> void:
	await prepare(PLASMA, [Vector2(30, 0)])
	var orb := start_cast() as ProjectileInstance
	orb._physics_process(0.0)
	check(enemies[0].current_hp == 9988 and orb._plasma_tick_count == 1, "plasma initial overlap ticks once")
	check(is_equal_approx(orb.speed, float(weapon.weapon_data.plasma_contact_speed)), "plasma contact uses configured slow speed")
	orb._physics_process(0.04)
	check(enemies[0].current_hp == 9988, "plasma sweep never adds ticks between intervals")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	orb._physics_process(1.0)
	check(enemies[0].current_hp == 9988 and orb._plasma_tick_count == 1, "paused plasma cannot tick")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for i in 4: orb._physics_process(0.101)
	check(enemies[0].current_hp == 9940 and orb._plasma_tick_count == 5 and orb.cancelled, "plasma keeps five-tick damage budget")
	orb._physics_process(1.0)
	check(enemies[0].current_hp == 9940, "expired plasma never hits again")
	await prepare(PLASMA, [Vector2(30, 0)])
	orb = start_cast() as ProjectileInstance
	orb._physics_process(0.0)
	enemies[0].position = Vector2(1000, 0)
	await frames()
	orb._physics_process(0.10)
	check(orb.speed < weapon.get_projectile_speed(), "plasma retains brief contact slowdown after separation")
	orb._physics_process(0.3)
	check(is_equal_approx(orb.speed, weapon.get_projectile_speed()), "plasma restores configured flight speed after separation")
	await prepare(BOW, [Vector2(80, 0), Vector2(160, 0)])
	var arrow := start_cast() as ProjectileInstance
	arrow.remaining_target_hits = 2
	arrow._physics_process(220.0 / arrow.speed)
	check(enemies[0].current_hp == 9988 and enemies[1].current_hp == 9988 and arrow.cancelled, "swept arrow pierces two ordered bodies once each")
	await prepare(BOW, [Vector2(80, 0), Vector2(180, 0)])
	wall(Vector2(120, 0))
	await frames()
	arrow = start_cast() as ProjectileInstance
	arrow.remaining_target_hits = 2
	arrow._physics_process(220.0 / arrow.speed)
	check(enemies[0].current_hp == 9988 and enemies[1].current_hp == 10000, "piercing arrow processes nearer body before wall and excludes farther body")
	for id in [COIN, CANNON]:
		await prepare(id, [], 100.0)
		var child: CoinProjectile = CannonPellet.new() if id == CANNON else CoinProjectile.new()
		host.add_child(child)
		child.initialize(weapon.make_cast_copy(), weapon.calculate_damage_events()[0], Vector2.ZERO, Vector2.RIGHT, {}, 1)
		child.set_physics_process(false)
		var shrink := 0.65 if id == CANNON else 0.75
		check(is_equal_approx(child.get_contact_radius(), weapon.get_hit_radius() * shrink), "split projectile collider follows smaller visual " + id)
