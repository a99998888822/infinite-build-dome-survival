extends RefCounted
class_name AutoMobilityPlanner
## Bounded, conservative assistance. Input is intent; velocity is not intent.
const EVALUATION_SECONDS := 0.25
const STABLE_SECONDS := 0.35
const SHARED_SECONDS := 2.0
const MAX_TRAVEL := 240.0
const MAX_NEARBY := 128
const MAX_TARGETS := 6
const ALIGNMENT := 0.8660254 # Within 30 degrees of the current command.
const SAFETY_MARGIN := 14.0

var evaluation_wait := 0.0
var shared_wait := 0.0
var stable_time := 0.0
var previous_intent := Vector2.ZERO
var evaluations := 0
var candidates_checked := 0

func reset_intent() -> void:
	stable_time = 0.0
	previous_intent = Vector2.ZERO
	evaluation_wait = EVALUATION_SECONDS

func manual_priority() -> void:
	shared_wait = maxf(shared_wait, 0.8)
	reset_intent()

func tick(casting: ActiveWeaponCasting, delta: float) -> void:
	shared_wait = maxf(0.0, shared_wait - delta)
	evaluation_wait = maxf(0.0, evaluation_wait - delta)
	var player: PlayerController = casting.loadout.owner_player
	var intent := player.movement_intent()
	if casting.manual_aiming or player.is_mobility_moving() or intent.is_zero_approx():
		reset_intent()
		return
	if previous_intent.is_zero_approx() or intent.dot(previous_intent) < 0.96:
		stable_time = 0.0
	else:
		stable_time += minf(delta, EVALUATION_SECONDS)
	previous_intent = intent
	if shared_wait > 0.0 or evaluation_wait > 0.0 or stable_time < STABLE_SECONDS: return
	evaluation_wait = EVALUATION_SECONDS # Never catch up with multiple evaluations after a hitch.
	var ready: Array[WeaponInstance] = []
	for weapon: WeaponInstance in casting.loadout.weapon_instances:
		if weapon.is_mobility_weapon() and CombatSettings.is_weapon_automatic(weapon) and not weapon.is_return_ready() and casting.can_cast(weapon):
			ready.append(weapon)
	if ready.is_empty(): return
	evaluations += 1
	var context := snapshot(player)
	if context.is_empty(): return
	var crowd: Vector2 = context.crowd
	if crowd.is_zero_approx(): return
	var alignment := intent.dot(crowd.normalized())
	var retreat := alignment <= -0.65 and bool(context.pressure)
	if not retreat and alignment < 0.65: return
	# Advancing into an existing close-range emergency is never an automatic chase.
	if not retreat and bool(context.pressure): return
	var best: Dictionary = {}
	for weapon in ready:
		var proposal := propose(weapon, player, intent, retreat, context)
		if not proposal.is_empty() and (best.is_empty() or float(proposal.score) > float(best.score)):
			best = proposal
	if best.is_empty(): return
	if casting.cast(best.weapon, best.point, true):
		shared_wait = SHARED_SECONDS
		reset_intent()

func snapshot(player: PlayerController) -> Dictionary:
	var threats: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var crowd := Vector2.ZERO
	var close_count := 0
	var pressure := false
	var player_radius := body_radius(player, 14.0)
	var half_segment := 0.0
	var player_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_shape != null and player_shape.shape is CapsuleShape2D:
		var capsule := player_shape.shape as CapsuleShape2D
		var scale := maxf(absf(player_shape.global_scale.x), absf(player_shape.global_scale.y))
		player_radius = capsule.radius * scale
		half_segment = (capsule.height * 0.5 - capsule.radius) * scale
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_alive(): continue
		var offset := enemy.global_position - player.global_position
		if offset.length_squared() > 640.0 * 640.0: continue
		# Never silently discard nearby threats when the budget is exhausted.
		if threats.size() >= MAX_NEARBY: return {}
		var spawning: bool = (enemy is EliteRusher and enemy.skill_state == "spawn") or (enemy is UnderworldWolf and enemy.state == "spawn")
		var radius := body_radius(enemy, 18.0)
		var safety := radius + player_radius + SAFETY_MARGIN
		var distance := offset.length()
		var prediction := enemy.velocity.limit_length(120.0) * 0.2
		var collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var center := collision.global_position if collision != null else enemy.global_position
		threats.append({"enemy": enemy, "position": enemy.global_position, "predicted": enemy.global_position + prediction, "center": center, "future_center": center + prediction, "segment": half_segment, "safety": safety, "targetable": not spawning})
		if not spawning and distance <= 260.0:
			crowd += offset.normalized() * (1.0 - distance / 300.0)
			if distance <= 150.0: close_count += 1
			if distance < safety + 20.0: pressure = true
			if (enemy is EliteRusher or enemy is UnderworldWolf) and distance < safety + 55.0: pressure = true
		_append_hazards(enemy, hazards, player_radius + half_segment)
	for node in player.get_tree().get_nodes_in_group("echo_bat_projectiles"):
		var sonic := node as EchoBatSonic
		if sonic == null or sonic.impacted: continue
		if sonic.global_position.distance_squared_to(player.global_position) > 640.0 * 640.0: continue
		if hazards.size() >= MAX_NEARBY: return {}
		hazards.append({"start": sonic.global_position, "end": sonic.global_position + sonic.direction * minf(sonic.speed * 0.6, sonic.max_distance - sonic.travelled), "radius": 10.0 + player_radius + half_segment + SAFETY_MARGIN})
	threats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return player.global_position.distance_squared_to(a.position) < player.global_position.distance_squared_to(b.position))
	return {"threats": threats, "hazards": hazards, "crowd": crowd, "pressure": pressure or close_count >= 3}

static func body_radius(body: Node2D, fallback: float) -> float:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null: return fallback
	var rect := collision.shape.get_rect()
	return maxf(rect.size.x, rect.size.y) * 0.5 * maxf(absf(collision.global_scale.x), absf(collision.global_scale.y))

func propose(weapon: WeaponInstance, player: PlayerController, intent: Vector2, retreat: bool, context: Dictionary) -> Dictionary:
	var points: Array[Vector2] = []
	var origin := player.global_position
	if weapon.is_hand_cannon():
		# Firing and recoil directions are coupled: pursuit cannot fire backwards at the crowd.
		if not retreat: return {}
		for threat: Dictionary in context.threats.slice(0, MAX_TARGETS):
			if not bool(threat.targetable): continue
			var offset: Vector2 = threat.position - origin
			if offset.length() <= weapon.get_attack_range() and (-offset.normalized()).dot(intent) >= ALIGNMENT:
				points.append(threat.position)
	elif retreat:
		for angle in [0.0, -0.2, 0.2]:
			var direction := intent.rotated(angle)
			var full := weapon.get_mobility_landing(direction * MAX_TRAVEL)
			for fraction in [0.75, 1.0]:
				points.append(origin + full * fraction)
	else:
		for threat: Dictionary in context.threats.slice(0, MAX_TARGETS):
			if not bool(threat.targetable): continue
			var offset: Vector2 = threat.position - origin
			if offset.normalized().dot(intent) < ALIGNMENT: continue
			# Land on the near edge of the damage circle, outside contact distance.
			var stand_off := weapon.get_hit_radius() * 0.82
			if stand_off < float(threat.safety): continue
			points.append(Vector2(threat.position) - offset.normalized() * stand_off)
	var best: Dictionary = {}
	for point in points:
		candidates_checked += 1
		var desired := origin + weapon.get_mobility_landing(point - origin)
		var landing := player.resolve_mobility_destination(desired)
		var displacement := landing - origin
		if displacement.length() < 40.0 or displacement.length() > MAX_TRAVEL + 0.1: continue
		if displacement.normalized().dot(intent) < ALIGNMENT: continue
		if not player.keyboard_movement and player.has_move_destination:
			# Do not overshoot the click target and then force a walk back.
			if displacement.dot(intent) > origin.distance_to(player.move_destination): continue
		if landing.distance_squared_to(desired) > 4.0: continue
		if not safe_path(origin, landing, retreat, weapon.is_star_tome(), context): continue
		var hits := 0
		if weapon.is_hand_cannon():
			var target_path := player.resolve_mobility_destination(point)
			if target_path.distance_squared_to(point) > 4.0: continue
			hits = 1
		else:
			for threat: Dictionary in context.threats:
				if bool(threat.targetable) and landing.distance_to(threat.predicted) <= weapon.get_hit_radius():
					var sight := PhysicsRayQueryParameters2D.create(landing, threat.position, 4)
					if player.get_world_2d().direct_space_state.intersect_ray(sight).is_empty(): hits += 1
		if not retreat and hits == 0: continue
		var before := nearest_clearance(origin, context.threats)
		var after := nearest_clearance(landing, context.threats)
		if retreat and after < before + 30.0: continue
		var score := after - before + mini(hits, 3) * 8.0 if retreat else hits * 12.0 - displacement.length() * 0.04
		if best.is_empty() or score > float(best.score):
			best = {"weapon": weapon, "point": point, "landing": landing, "score": score}
	return best

static func nearest_clearance(point: Vector2, threats: Array) -> float:
	var nearest := INF
	for threat: Dictionary in threats:
		var spine := Vector2(0, float(threat.segment))
		nearest = minf(nearest, Geometry2D.get_closest_point_to_segment(point, Vector2(threat.future_center) - spine, Vector2(threat.future_center) + spine).distance_to(point) - float(threat.safety))
	return nearest

static func safe_path(origin: Vector2, landing: Vector2, retreat: bool, blink: bool, context: Dictionary) -> bool:
	for threat: Dictionary in context.threats:
		for center: Vector2 in [threat.center, threat.future_center]:
			var safe := float(threat.safety)
			var spine := Vector2(0, float(threat.segment))
			var top := center - spine
			var bottom := center + spine
			if Geometry2D.get_closest_point_to_segment(landing, top, bottom).distance_to(landing) < safe: return false
			if blink: continue
			# Escaping an existing overlap is allowed only while moving away.
			var start_distance := Geometry2D.get_closest_point_to_segment(origin, top, bottom).distance_to(origin)
			if retreat and start_distance < safe:
				if (landing - origin).dot(origin - center) < 0.0: return false
				safe = maxf(0.0, start_distance - 0.5)
			if segment_distance(origin, landing, top, bottom) < safe: return false
	for hazard: Dictionary in context.hazards:
		# Sample only non-instant movement; reject entering a visible attack region.
		for i in range(1, 7):
			if blink and i != 6: continue
			var point := origin.lerp(landing, i / 6.0)
			if Geometry2D.get_closest_point_to_segment(point, hazard.start, hazard.end).distance_to(point) < float(hazard.radius): return false
	return true

static func segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null: return 0.0
	return minf(minf(Geometry2D.get_closest_point_to_segment(a, c, d).distance_to(a), Geometry2D.get_closest_point_to_segment(b, c, d).distance_to(b)), minf(Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c), Geometry2D.get_closest_point_to_segment(d, a, b).distance_to(d)))

static func _append_hazards(enemy: EnemyController, hazards: Array[Dictionary], radius: float) -> void:
	if enemy is EliteRusher and enemy.skill_state in ["windup", "dash"]:
		hazards.append({"start": enemy._origin, "end": enemy._origin + enemy._direction * float(enemy._profile.get("dash_distance", 240)), "radius": float(enemy._profile.get("dash_half_width", 35.84)) + radius + SAFETY_MARGIN})
	elif enemy is EchoBat and enemy.skill_state == "warning":
		hazards.append({"start": enemy.shot_origin, "end": enemy.shot_origin + enemy.aim_direction * enemy.attack_range(), "radius": float(enemy.profile.get("path_width", 20)) * 0.5 + radius + SAFETY_MARGIN})
	elif enemy is UnderworldWolf:
		if enemy.state in ["leap_charge", "leap", "land"]:
			hazards.append({"start": enemy.locked_point, "end": enemy.locked_point, "radius": float(enemy.profile.leap_radius) + radius + SAFETY_MARGIN})
		elif enemy.state in ["breath_charge", "breath"]:
			# Conservative capsule enclosing the complete cone.
			var reach := float(enemy.profile.breath_range)
			var width := reach * sin(deg_to_rad(float(enemy.profile.breath_cone_degrees)) * 0.5)
			hazards.append({"start": enemy.breath_origin, "end": enemy.breath_origin + enemy.breath_direction * reach, "radius": width + radius + SAFETY_MARGIN})
