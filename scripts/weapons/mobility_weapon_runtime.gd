extends DirectedWeaponRuntime
class_name MobilityWeaponRuntime
## A cast owns motion, contacts and sprite lifetimes. No floating weapon body.
const SLASH_SECONDS := 10.0 / 48.0
const GROUND = preload("res://scripts/effects/ground_projection_r05.gd")
const CANNON_JET = preload("res://scripts/effects/cannon_jet_flame.gd")
var live_source: WeaponInstance
var return_ready := false
var anchor_position := Vector2.ZERO
var anchor: MobilityAtlasEffect
var phase := "takeoff"
var phase_age := 0.0
var replay_only := false
var hit_count := 0
var allow_return := true
var destination := Vector2.ZERO
var departure := Vector2.ZERO
var takeoff_seconds := 0.36
var landing_seconds := 0.36
var returning_cast := false
var _jump_active := false

func initialize(source: WeaponInstance, original: WeaponInstance, point: Vector2, automatic: bool = false) -> void:
	allow_return = not automatic
	bind_weapon(source, "mobility_weapon_runtimes")
	# Child clips use absolute layers inside the shared effect band.
	live_source = original
	original.mobility_runtime = weakref(self)
	var player := weapon.owner_player
	anchor_position = player.global_position
	heading = anchor_position.direction_to(point)
	if heading.is_zero_approx(): heading = player.last_move_direction
	destination = player.resolve_mobility_destination(anchor_position + weapon.get_mobility_landing(point - anchor_position))
	_begin_jump(heading)

func _begin_jump(attack_direction: Vector2 = Vector2.ZERO) -> void:
	var player := weapon.owner_player
	departure = player.global_position
	player.play_mobility_action(weapon.weapon_id, destination - departure, attack_direction)
	var animator := player.action_animator
	var clip: Dictionary = animator._clips.get(animator.action, {})
	var times: Array = clip.get("frame_durations", [])
	var count := maxi(2, int(clip.get("frames", 6)))
	takeoff_seconds = 0.0
	landing_seconds = 0.0
	for i in count:
		var seconds := maxf(0.001, float(times[i])) if times.size() == count else 1.0 / maxf(0.1, float(clip.get("fps", 1.0 / 0.12)))
		if i < count / 2: takeoff_seconds += seconds
		else: landing_seconds += seconds
	# Own the jump from takeoff through landing, including the airborne transit.
	if not player.begin_mobility_motion(self, departure, INF):
		cancel()
		return
	_jump_active = true
	animator.hold_action_at(takeoff_seconds)
	phase = "takeoff"
	phase_age = 0.0

func _travel_seconds() -> float:
	return 0.0 if weapon.is_star_tome() else float(weapon.weapon_data.get("movement_ms", 220)) / 1000.0

func owns_jump_animation() -> bool:
	return _jump_active

func _start_travel() -> void:
	var player := weapon.owner_player
	var landing := player.resolve_mobility_destination(destination)
	if returning_cast and landing.distance_squared_to(anchor_position) > 1.0:
		# Terrain may have appeared during takeoff. Land here and keep the mark.
		return_ready = allow_return
		_begin_landing()
		return
	if weapon.is_star_tome():
		if not player.blink_mobility_hold(self, landing):
			cancel()
			return
		MobilityAtlasEffect.spawn(self, weapon, "star_depart", departure)
		MobilityAtlasEffect.spawn(self, weapon, "star_return" if returning_cast else "star_arrive", landing)
		if returning_cast:
			if is_instance_valid(anchor): anchor.cancel()
		else:
			if allow_return:
				anchor = MobilityAtlasEffect.spawn(self, weapon, "star_anchor", anchor_position, 0, Vector2.ONE, true)
			return_ready = allow_return
			_impact(landing)
		_begin_landing()
	else:
		player.cancel_mobility_motion(self)
		player.begin_mobility_motion(self, landing, _travel_seconds())
		phase = "moving"
		phase_age = 0.0
		if weapon.is_hand_cannon():
			_fire_cannon(departure)
			MobilityAtlasEffect.spawn(self, weapon, "recoil_dust", departure, heading.angle())
		else:
			var trail := MobilityAtlasEffect.spawn(self, weapon, "dash_trail", departure, heading.angle())
			trail.follow = weakref(player)

func _begin_landing() -> void:
	var player := weapon.owner_player
	player.cancel_mobility_motion(self)
	player.begin_mobility_motion(self, player.global_position, landing_seconds)
	player.action_animator.resume_action()
	phase = "landing"
	phase_age = 0.0

func initialize_replay(source: WeaponInstance, point: Vector2, direction: Vector2, contact: EnemyController = null) -> void:
	bind_weapon(source, "mobility_weapon_runtimes")
	replay_only = true
	heading = direction
	phase = "impact"
	if weapon.is_hand_cannon():
		_fire_cannon(point, contact)
	else:
		_impact(point)

func _fire_cannon(point: Vector2, contact: EnemyController = null) -> void:
	CANNON_JET.spawn(self, weapon, point, heading)
	for angle in weapon.get_projectile_angles():
		var pellet := CannonPellet.new()
		add_child(pellet)
		pellet.initialize(weapon, weapon.calculate_damage_events()[0], point, AttackFootprint.spread_direction(heading, deg_to_rad(angle)), {})
		if is_instance_valid(contact) and contact.is_alive(): pellet._hit_enemy(contact)
	AudioManager.play_sfx_path(str(weapon.weapon_data.get("launch_sfx", "")), 100, "hand_cannon_launch")

func _impact(point: Vector2) -> void:
	var shock := weapon.is_star_tome()
	var visual_scale := weapon.get_hit_radius() / 64.0
	if not shock:
		# The atlas reaches 82 px including sparks: 1.1x stays inside the 96 px hit circle.
		visual_scale = weapon.get_hit_radius() / 96.0 * 1.1
	# Project slash and star shockwave frames onto the shared ground plane.
	# Star impact follows its projected warning. Dash keeps its approved body query.
	var visual_axes := GROUND.projected_axes()
	MobilityAtlasEffect.spawn(self, weapon, "star_shockwave" if shock else "dash_circle", point, 0, visual_axes * visual_scale)
	# Copy only matching contacts before native damage/reactions mutate the registry.
	var victims: Array[EnemyController] = []
	var shape: Shape2D
	if shock:
		shape = AttackFootprint.projected_disk(weapon.get_hit_radius())
	else:
		var circle := CircleShape2D.new()
		circle.radius = weapon.get_hit_radius()
		shape = circle
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 2
	query.collide_with_areas = false
	# Use body overlap, including collider offsets/scale, rather than enemy origins.
	for contact in get_world_2d().direct_space_state.intersect_shape(query, maxi(32, EnemyRegistry.get_registered_enemies().size())):
		var enemy := contact.collider as EnemyController
		if is_instance_valid(enemy) and enemy.is_inside_tree() and enemy.is_alive() and not victims.has(enemy) and clear_path(self, point, enemy.global_position):
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
				enemy.apply_knockback(direction, float(weapon.weapon_data.get("shock_speed", 360)), 0.24, weapon.get_stat("control_power"))
	AudioManager.end_combat_audio()

func request_return() -> bool:
	if not return_ready or cancelled or not ready_to_tick() or weapon.owner_player.is_mobility_moving(): return false
	var player := weapon.owner_player
	var landing := player.resolve_mobility_destination(anchor_position)
	# A blocked return keeps the mark available, instead of consuming it halfway.
	if landing.distance_squared_to(anchor_position) > 1.0: return false
	destination = landing
	returning_cast = true
	return_ready = false
	_begin_jump()
	return true

func expire_return() -> void:
	if not weapon.is_star_tome() or replay_only: return
	return_ready = false
	allow_return = false
	if is_instance_valid(anchor) and not anchor.cancelled: anchor.cancel()
	# End availability without moving the player; remaining PNGs finish normally.
	if not _jump_active: phase = "done"

func _physics_process(delta: float) -> void:
	if not ready_to_tick(): return
	age += delta
	phase_age += delta
	if phase == "takeoff" and phase_age + 0.000001 >= takeoff_seconds:
		_start_travel()
	elif phase == "moving" and not weapon.owner_player.is_mobility_moving():
		if not weapon.is_hand_cannon(): _impact(weapon.owner_player.global_position)
		_begin_landing()
	elif phase == "landing" and not weapon.owner_player.is_mobility_moving():
		_jump_active = false
		phase = "anchored" if return_ready else "impact"
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
	_release_jump()
	if live_source != null and live_source.mobility_runtime != null and live_source.mobility_runtime.get_ref() == self:
		live_source.mobility_runtime = null
	for child in get_children():
		if child.has_method("cancel"): child.cancel()
	super.cancel()

func _exit_tree() -> void:
	_release_jump()
	if live_source != null and live_source.mobility_runtime != null and live_source.mobility_runtime.get_ref() == self:
		live_source.mobility_runtime = null

func _release_jump() -> void:
	if weapon != null and is_instance_valid(weapon.owner_player):
		var player := weapon.owner_player
		player.cancel_mobility_motion(self)
		if _jump_active and player.action_animator.action in ["jump_forward", "jump_backward"]:
			player.action_animator.reset()
	_jump_active = false
