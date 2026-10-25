extends DirectedWeaponRuntime
class_name SaberRuntime
const ART = preload("res://scripts/effects/candidate_weapon_art.gd")
const CUT_GAP := 4.0 / 60.0
var live_source: WeaponInstance
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var half_jump := 0.36
var jump_duration := 0.72
var blinked := false
var return_ready := false
var replay_only := false
var hit_count := 0
var cuts_fired := 0
var duration := 0.72
var visuals: Array[Dictionary] = []
var cut_centers: Array[Vector2] = []
var cut_angles: Array[float] = []
var _shapes: Array[ConvexPolygonShape2D] = []
var _query := PhysicsShapeQueryParameters2D.new()

func initialize(source: WeaponInstance, original: WeaponInstance, point: Vector2) -> bool:
	bind_weapon(source, "saber_runtimes")
	var player := source.owner_player
	origin = player.global_position
	var offset := point - origin
	if offset.is_zero_approx(): offset = player.last_move_direction * source.get_attack_range()
	destination = player.resolve_mobility_destination(origin + source.get_mobility_landing(offset))
	if origin.distance_to(destination) < 4.0: return false
	# Read the actual animation timing; both halves keep the source frame durations.
	var clip: Dictionary = player.action_animator._clips.get("jump_forward", {})
	var times: Array = clip.get("frame_durations", [0.12, 0.12, 0.12, 0.12, 0.12, 0.12])
	half_jump = 0.0
	jump_duration = 0.0
	for i in times.size():
		jump_duration += float(times[i])
		if i < times.size() / 2: half_jump += float(times[i])
	if not player.begin_mobility_motion(self, origin, jump_duration): return false
	live_source = original
	original.mobility_runtime = weakref(self)
	player.play_mobility_action(source.weapon_id, destination - origin)
	duration = maxf(jump_duration, half_jump + (maxi(1, int(source.get_stat("projectile_count"))) - 1) * CUT_GAP + 0.30)
	return true

func initialize_replay(source: WeaponInstance, point: Vector2, direction: Vector2) -> void:
	bind_weapon(source, "saber_runtimes")
	replay_only = true
	blinked = true
	half_jump = 0.0
	origin = point - direction * source.get_attack_range() * 0.5
	destination = point + direction * source.get_attack_range() * 0.5
	_build_shape()
	duration = (maxi(1, int(source.get_stat("projectile_count"))) - 1) * CUT_GAP + 0.30

func owns_jump_animation() -> bool:
	return not cancelled and not replay_only

func _physics_process(delta: float) -> void:
	if not ready_to_tick(): return
	age += delta
	if not blinked and age + 0.000001 >= half_jump:
		var player := weapon.owner_player
		# Recheck terrain at the actual blink, including obstacles appearing mid-jump.
		destination = player.resolve_mobility_destination(destination)
		if not player.blink_mobility_hold(self, destination):
			cancel()
			return
		blinked = true
		_build_shape()
	if blinked:
		while cuts_fired < maxi(1, int(weapon.get_stat("projectile_count"))) and age + 0.000001 >= half_jump + cuts_fired * CUT_GAP:
			_cut(cuts_fired)
			cuts_fired += 1
	for i in range(visuals.size() - 1, -1, -1):
		var visual := visuals[i]
		if not is_instance_valid(visual.node):
			visuals.remove_at(i)
		elif age - float(visual.start) >= 0.30:
			visual.node.queue_free()
			visuals.remove_at(i)
		else:
			visual.node.sample(age - float(visual.start))
	if age >= duration: cancel()

func _build_shape() -> void:
	var length := origin.distance_to(destination)
	_shapes.clear()
	if length < 4.0: return
	var points := PackedVector2Array()
	for side in [1.0, -1.0]:
		for i in 25:
			if side < 0 and (i == 0 or i == 24): continue
			var x := lerpf(-1.0, 1.0, float(i if side > 0 else 24 - i) / 24.0)
			points.append(Vector2(x * length * 0.5, side * weapon.get_hit_radius() * pow(maxf(1.0 - x * x, 0.0), 1.4)))
	# The sharp tips have a shallow concavity. Preserve it with convex pieces,
	# instead of letting the physics engine replace the blade with its hull.
	for polygon in Geometry2D.decompose_polygon_in_convex(points):
		var shape := ConvexPolygonShape2D.new()
		shape.points = polygon
		_shapes.append(shape)
	_query.collision_mask = 2
	_query.collide_with_areas = false

func _cut(index: int) -> void:
	if origin.distance_to(destination) < 4.0: return
	var step := (index + 1) / 2
	var degrees := minf(float(step) * 3.0, 15.0) * (1.0 if index % 2 == 1 else -1.0)
	var center := (origin + destination) * 0.5
	var angle := origin.angle_to_point(destination) + deg_to_rad(degrees)
	cut_centers.append(center)
	cut_angles.append(degrees)
	var start := half_jump + index * CUT_GAP
	var visual := ART.cut(self, origin, destination, degrees, weapon.get_hit_radius() / 8.0)
	visual.manual_clock = true
	visuals.append({"node": visual, "start": start})
	_query.transform = Transform2D(angle, center)
	var event := weapon.calculate_damage_events()[0]
	var hit := {}
	AudioManager.begin_combat_audio()
	for shape in _shapes:
		_query.shape = shape
		for contact in get_world_2d().direct_space_state.intersect_shape(_query, maxi(32, EnemyRegistry.get_registered_enemies().size() * 2)):
			var enemy := contact.collider as EnemyController
			if not is_instance_valid(enemy) or not enemy.is_alive() or hit.has(enemy.get_instance_id()): continue
			if not clear_path(self, origin, enemy.global_position): continue
			hit[enemy.get_instance_id()] = true
			deal_hit(enemy, event, Vector2.from_angle(angle))
			hit_count += 1
	AudioManager.end_combat_audio()

func is_attacking() -> bool:
	return not cancelled and age < duration

func cancel() -> void:
	if is_instance_valid(weapon.owner_player): weapon.owner_player.cancel_mobility_motion(self)
	if live_source != null and live_source.mobility_runtime != null and live_source.mobility_runtime.get_ref() == self:
		live_source.mobility_runtime = null
	super.cancel()

func _exit_tree() -> void:
	if weapon != null and is_instance_valid(weapon.owner_player): weapon.owner_player.cancel_mobility_motion(self)
	if live_source != null and live_source.mobility_runtime != null and live_source.mobility_runtime.get_ref() == self:
		live_source.mobility_runtime = null
