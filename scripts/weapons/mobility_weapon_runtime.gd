extends DirectedWeaponRuntime
class_name MobilityWeaponRuntime
## A cast owns motion, contacts and sprite lifetimes. No floating weapon body.
const SLASH_SECONDS := 10.0 / 48.0
const SHOCK_SECONDS := 10.0 / 24.0
var live_source: WeaponInstance
var return_ready := false
var anchor_position := Vector2.ZERO
var anchor: MobilityAtlasEffect
var phase := "moving"
var phase_age := 0.0
var replay_only := false
var hit_count := 0
var allow_return := true

func initialize(source: WeaponInstance, original: WeaponInstance, point: Vector2, automatic: bool = false) -> void:
	allow_return = not automatic
	bind_weapon(source, "mobility_weapon_runtimes")
	z_index = 0 # Child clips own their authored ground/foreground layers.
	live_source = original
	original.mobility_runtime = weakref(self)
	var player := weapon.owner_player
	anchor_position = player.global_position
	heading = anchor_position.direction_to(point)
	if heading.is_zero_approx(): heading = player.last_move_direction
	var landing := player.resolve_mobility_destination(anchor_position + weapon.get_mobility_landing(point - anchor_position))
	if weapon.is_star_tome():
		player.reset_stationary_relic_state()
		MobilityAtlasEffect.spawn(self, weapon, "star_depart", anchor_position)
		if allow_return:
			anchor = MobilityAtlasEffect.spawn(self, weapon, "star_anchor", anchor_position, 0, Vector2.ONE, true)
		player.global_position = landing
		MobilityAtlasEffect.spawn(self, weapon, "star_arrive", landing)
		_impact(landing)
		phase = "arriving"
		return_ready = allow_return
	else:
		player.begin_mobility_motion(self, landing, float(weapon.weapon_data.get("movement_ms", 220)) / 1000.0)
		if weapon.is_hand_cannon():
			_fire_cannon(anchor_position)
			MobilityAtlasEffect.spawn(self, weapon, "recoil_dust", anchor_position, heading.angle())
		else:
			var trail := MobilityAtlasEffect.spawn(self, weapon, "dash_trail", anchor_position, heading.angle())
			trail.follow = weakref(player)

func initialize_replay(source: WeaponInstance, point: Vector2, direction: Vector2, contact: EnemyController = null) -> void:
	bind_weapon(source, "mobility_weapon_runtimes")
	z_index = 0
	replay_only = true
	heading = direction
	phase = "impact"
	if weapon.is_hand_cannon():
		_fire_cannon(point, contact)
	else:
		_impact(point)

func _fire_cannon(point: Vector2, contact: EnemyController = null) -> void:
	MobilityAtlasEffect.spawn(self, weapon, "muzzle", point + heading * 20, heading.angle())
	for angle in weapon.get_projectile_angles():
		var pellet := CannonPellet.new()
		add_child(pellet)
		pellet.initialize(weapon, weapon.calculate_damage_events()[0], point, heading.rotated(deg_to_rad(angle)), {})
		if is_instance_valid(contact) and contact.is_alive(): pellet._hit_enemy(contact)
	AudioManager.play_sfx_path(str(weapon.weapon_data.get("launch_sfx", "")), 100, "hand_cannon_launch")

func _impact(point: Vector2) -> void:
	var shock := weapon.is_star_tome()
	MobilityAtlasEffect.spawn(self, weapon, "star_shockwave" if shock else "dash_circle", point, 0, Vector2.ONE * weapon.get_hit_radius() / 64.0)
	# Copy only matching contacts before native damage/reactions mutate the registry.
	var victims: Array[EnemyController] = []
	var radius_squared := weapon.get_hit_radius() * weapon.get_hit_radius()
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if is_instance_valid(enemy) and enemy.is_inside_tree() and enemy.is_alive() and point.distance_squared_to(enemy.global_position) <= radius_squared and clear_path(self, point, enemy.global_position):
			victims.append(enemy)
	AudioManager.begin_combat_audio()
	for segment in maxi(1, int(weapon.get_stat("projectile_count"))):
		var event := weapon.calculate_damage_events()[0]
		for enemy in victims:
			if not is_instance_valid(enemy) or not enemy.is_alive(): continue
			var direction := point.direction_to(enemy.global_position)
			if direction.is_zero_approx(): direction = heading
			deal_hit(enemy, event, direction)
			hit_count += 1
			if shock and segment == 0 and is_instance_valid(enemy) and enemy.is_alive():
				enemy.apply_knockback(direction, float(weapon.weapon_data.get("shock_speed", 360)), 0.24)
	AudioManager.end_combat_audio()

func request_return() -> bool:
	if not return_ready or cancelled or not ready_to_tick() or weapon.owner_player.is_mobility_moving(): return false
	var player := weapon.owner_player
	var landing := player.resolve_mobility_destination(anchor_position)
	# A blocked return keeps the mark available, instead of consuming it halfway.
	if landing.distance_squared_to(anchor_position) > 1.0: return false
	var departure := player.global_position
	player.reset_stationary_relic_state()
	player.global_position = landing
	MobilityAtlasEffect.spawn(self, weapon, "star_depart", departure)
	MobilityAtlasEffect.spawn(self, weapon, "star_return", landing)
	if is_instance_valid(anchor): anchor.cancel()
	return_ready = false
	phase = "returning"
	phase_age = 0.0
	return true

func expire_return() -> void:
	if not weapon.is_star_tome() or replay_only: return
	return_ready = false
	if is_instance_valid(anchor) and not anchor.cancelled: anchor.cancel()
	# End availability without moving the player; remaining PNGs finish normally.
	phase = "done"

func _physics_process(delta: float) -> void:
	if not ready_to_tick(): return
	age += delta
	phase_age += delta
	if phase == "moving" and not weapon.owner_player.is_mobility_moving():
		phase = "impact"
		phase_age = age if weapon.is_hand_cannon() else 0.0
		if not weapon.is_hand_cannon(): _impact(weapon.owner_player.global_position)
	elif phase == "arriving" and phase_age >= SHOCK_SECONDS:
		phase = "anchored" if allow_return else "done"
	elif phase == "returning" and phase_age >= 8.0 / 24.0:
		phase = "done"
	elif phase == "impact" and phase_age >= (0.28 if weapon.is_hand_cannon() else SLASH_SECONDS):
		var flying := false
		for child in get_children():
			if child is CannonPellet and not child.cancelled: flying = true
		if not flying: phase = "done"
	if phase == "done" and get_child_count() == 0: cancel()

func is_attacking() -> bool:
	return not cancelled and phase != "done"

func cancel() -> void:
	return_ready = false
	if is_instance_valid(weapon.owner_player): weapon.owner_player.cancel_mobility_motion(self)
	if live_source != null and live_source.mobility_runtime != null and live_source.mobility_runtime.get_ref() == self:
		live_source.mobility_runtime = null
	for child in get_children():
		if child.has_method("cancel"): child.cancel()
	super.cancel()

func _exit_tree() -> void:
	if weapon != null and is_instance_valid(weapon.owner_player): weapon.owner_player.cancel_mobility_motion(self)
	if live_source != null and live_source.mobility_runtime != null and live_source.mobility_runtime.get_ref() == self:
		live_source.mobility_runtime = null
