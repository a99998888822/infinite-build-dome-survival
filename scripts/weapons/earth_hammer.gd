extends DirectedWeaponRuntime
class_name EarthHammer

signal node_created(index: int, point: Vector2)
const HAMMER := preload("res://assets/sprites/weapons/earth_hammer/earth_hammer.png")
const CRACKS := preload("res://assets/sprites/weapons/ground_cracks/ground_cracks.png")
var next_node := 0
var node_count := 5
var impacted := false
var blocked := false
var hits: Dictionary = {}
var nodes: Array[Dictionary] = []
var attack_scale := 1.0
var appear := 0.56
var slam := 0.06
var contact := 0.04
var fade := 0.06
var spacing := 64.0
var first_offset := 40.0
var interval := 0.1
var impact_age := -1.0
var event: DamageEvent


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	bind_weapon(source, "earth_hammers")
	heading = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	attack_scale = speed_scale()
	appear = float(weapon.weapon_data.hammer_appear_ms) / 1000.0 * attack_scale
	slam = float(weapon.weapon_data.hammer_slam_ms) / 1000.0 * attack_scale
	contact = float(weapon.weapon_data.hammer_contact_ms) / 1000.0 * attack_scale
	fade = float(weapon.weapon_data.hammer_fade_ms) / 1000.0 * attack_scale
	node_count = weapon.get_ground_node_count()
	var range_scale := weapon.get_attack_range() / (float(weapon.weapon_data.ground_first_offset) + (node_count - 1) * float(weapon.weapon_data.ground_node_spacing))
	spacing = float(weapon.weapon_data.ground_node_spacing) * range_scale
	first_offset = float(weapon.weapon_data.ground_first_offset) * range_scale
	interval = float(weapon.weapon_data.ground_node_interval_ms) / 1000.0
	event = weapon.calculate_damage_events()[0]
	# Origin and heading stay locked even if the player moves during the windup.
	queue_redraw()


func is_attacking() -> bool:
	return not cancelled and age < appear + slam + contact + fade


func hammer_opacity() -> float:
	if age < appear:
		return smoothstep(0, appear, age)
	if age < appear + slam + contact:
		return 1.0
	return 1.0 - clampf((age - appear - slam - contact) / maxf(fade, 0.001), 0, 1)


func _physics_process(delta: float) -> void:
	if not ready_to_tick():
		return
	age += delta
	var hit_at := appear + slam
	if age >= hit_at:
		impact_age = age - hit_at
		if not impacted:
			impacted = true
			weapon.play_attack_hit_sfx()
		while next_node < node_count and impact_age + 0.000001 >= next_node * interval and not blocked:
			_emit_node(next_node)
			next_node += 1
	if age > hit_at + (node_count - 1) * interval + 1.25:
		cancel()
	queue_redraw()


func _emit_node(index: int) -> void:
	var offset := first_offset + index * spacing
	var point := global_position + heading * offset
	if not clear_path(self, global_position, point):
		blocked = true
		return
	var when := appear + slam + index * interval
	nodes.append({"point": point - global_position, "at": when, "child": false, "direction": heading, "length": spacing})
	# Resolve the node once; real enemies below do not fire this dispatcher again.
	EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, event.duplicate_event(), point, heading)
	var start := global_position if index == 0 else point - heading * spacing * 0.5
	var length := offset + spacing * 0.5 if index == 0 else spacing
	_native_damage(start, heading, length, 1.0)
	for profile in weapon.get_split_profiles():
		for child_index in int(profile.child_count):
			var sign_value := -1.0 if child_index % 2 == 0 else 1.0
			var angle := maxf(float(profile.spread_angle), 25.0) * sign_value
			var branch_direction := heading.rotated(deg_to_rad(angle))
			var branch_length := float(weapon.weapon_data.ground_branch_length)
			var endpoint := point + branch_direction * branch_length
			if not clear_path(self, point, endpoint):
				continue
			nodes.append({"point": point - global_position, "at": when, "child": true, "direction": branch_direction, "length": branch_length})
			var branch_event := event.continue_after_split(profile)
			branch_event.damage = maxi(1, roundi(branch_event.damage * float(profile.damage_multiplier)))
			branch_event.elemental_damage_scale *= float(profile.damage_multiplier)
			EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, branch_event, endpoint, branch_direction)
			_native_damage(point, branch_direction, branch_length, float(profile.damage_multiplier))
	node_created.emit(index, point)


func _native_damage(origin: Vector2, direction: Vector2, length: float, power: float) -> void:
	for enemy in rectangle_contacts(origin, direction, length, weapon.get_hit_radius()):
		if hits.has(enemy.get_instance_id()):
			continue
		hits[enemy.get_instance_id()] = true
		var hit := event.duplicate_event()
		hit.damage = maxi(1, roundi(hit.damage * power))
		deal_hit(enemy, hit, direction, power != 1.0, false)


func _draw() -> void:
	if cancelled:
		return
	var opacity := hammer_opacity()
	if opacity > 0:
		var frame := mini(4, int(age / maxf(appear, 0.001) * 5))
		if age >= appear:
			frame = 5 + mini(3, int((age - appear) / maxf(slam, 0.001) * 3))
		draw_atlas(HAMMER, 64, frame, Vector2(30, 43), heading * 10 + Vector2(0, 2), heading.angle(), Vector2.ONE, opacity)
	for node in nodes:
		var elapsed := age - float(node.at)
		if elapsed < 0 or elapsed > 1.25:
			continue
		var frame := 0 if elapsed < 0.12 else 1 if elapsed < 0.35 else 2
		var direction: Vector2 = node.direction
		var point: Vector2 = node.point
		if bool(node.child):
			# Reuse the thin main strip along a short branch so its pivot joins exactly.
			draw_atlas(CRACKS, 64, frame, Vector2(3, 32), point, direction.angle(), Vector2(float(node.length) / 57.0, 0.65), minf(1, (1.25 - elapsed) * 3))
		else:
			draw_atlas(CRACKS, 64, frame, Vector2(32, 32), point, direction.angle(), Vector2(spacing / 64.0, 1), minf(1, (1.25 - elapsed) * 3))
