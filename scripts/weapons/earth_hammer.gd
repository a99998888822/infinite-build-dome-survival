extends DirectedWeaponRuntime
class_name EarthHammer

signal node_created(index: int, point: Vector2)
const HAMMER := preload("res://assets/sprites/weapons/earth_hammer/earth_hammer.png")
const CRACKS := preload("res://assets/sprites/weapons/ground_cracks/ground_cracks.png")
const REVIEW_CRACKS := preload("res://assets/sprites/weapons/ground_cracks/review_r04/ground_cracks_r04.png")
const IMPACT_R02 = preload("res://scripts/effects/combat_impact_r02.gd")
const FEEDBACK_SETTINGS = preload("res://scripts/effects/combat_feedback_settings.gd")
var crack_texture: Texture2D = CRACKS
var crack_layer: Node2D
var crack_clearance := 42.0
var next_node := 0
var node_count := 5
var impacted := false
var blocked := false
var hits: Dictionary = {}
var rays: Array[Dictionary] = []
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
var lightning_count := 0
var next_lightning := 0
var lightning_first := 40.0
var lightning_spacing := 64.0
var lightning_duration := 0.4


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	bind_weapon(source, "earth_hammers")
	crack_texture = REVIEW_CRACKS if source.use_active_range_rules else CRACKS
	crack_clearance = maxf(42.0, AttackFootprint.player_clearance(source) + 8.0)
	crack_layer = Node2D.new()
	crack_layer.z_as_relative = false
	crack_layer.z_index = -1
	add_child(crack_layer)
	crack_layer.draw.connect(_draw_ground_cracks)
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
	if weapon.has_effect("electric_spark"):
		# Sample the full ray independently of the five native damage cells.
		# Keep the first point near the caster and include the exact far endpoint.
		var reach := weapon.get_attack_range()
		lightning_first = minf(float(weapon.weapon_data.ground_first_offset), reach)
		var span := maxf(0.0, reach - lightning_first)
		var max_spacing := maxf(1.0, float(weapon.weapon_data.ground_node_spacing))
		lightning_count = ceili(span / max_spacing) + 1
		lightning_spacing = span / (lightning_count - 1) if lightning_count > 1 else 0.0
		lightning_duration = (node_count - 1) * interval
	for angle in weapon.get_projectile_angles():
		rays.append({"direction": heading.rotated(deg_to_rad(angle)), "hits": {}, "blocked": false, "lightning_blocked": false})
	# Origin and heading stay locked even if the player moves during the windup.
	queue_redraw()


func is_attacking() -> bool:
	return not cancelled and (age < appear + slam + contact + fade or (not blocked and next_node < node_count) or _has_pending_lightning())


func _has_pending_lightning() -> bool:
	return next_lightning < lightning_count and rays.any(func(ray: Dictionary): return not ray.lightning_blocked)


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
			blocked = true
			for ray in rays:
				if not ray.blocked:
					_emit_node(next_node, ray)
				blocked = blocked and bool(ray.blocked)
			next_node += 1
		# This queue has its own wall state: a blocked distant native node must
		# not discard nearer lightning samples that still lie before the wall.
		while _has_pending_lightning():
			var when := lightning_duration * next_lightning / maxf(lightning_count - 1, 1)
			if impact_age + 0.000001 < when:
				break
			for ray in rays:
				if not ray.lightning_blocked:
					_emit_lightning_sample(next_lightning, ray)
			next_lightning += 1
	if age > hit_at + (node_count - 1) * interval + 1.25:
		cancel()
	queue_redraw()
	crack_layer.queue_redraw()


func _emit_node(index: int, ray: Dictionary) -> void:
	var direction: Vector2 = ray.direction
	var offset := first_offset + index * spacing
	var point := global_position + direction * offset
	if not clear_path(self, global_position, point):
		ray.blocked = true
		return
	var when := appear + slam + index * interval
	nodes.append({"point": point - global_position, "at": when, "child": false, "direction": direction, "length": spacing})
	if index == 0:
		IMPACT_R02.spawn(get_parent(), point, &"ground", direction, minf(1.5, weapon.get_projectile_visual_scale()))
	# Resolve the node once; real enemies below do not fire this dispatcher again.
	EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, event.duplicate_event(), point, direction, "", "electric_spark" if lightning_count > 0 else "")
	var start := global_position if index == 0 else point - direction * spacing * 0.5
	var length := offset + spacing * 0.5 if index == 0 else spacing
	if weapon.use_active_range_rules:
		length = minf(length, maxf(0.0, weapon.get_attack_range() - (start - global_position).dot(direction)))
	_native_damage(start, direction, length, 1.0, ray.hits)
	for profile in weapon.get_split_profiles():
		for child_index in int(profile.child_count):
			var sign_value := -1.0 if child_index % 2 == 0 else 1.0
			var angle := maxf(float(profile.spread_angle), 25.0) * sign_value
			var branch_direction := direction.rotated(deg_to_rad(angle))
			var branch_length := float(weapon.weapon_data.ground_branch_length)
			var endpoint := point + branch_direction * branch_length
			if not clear_path(self, point, endpoint):
				continue
			nodes.append({"point": point - global_position, "at": when, "child": true, "direction": branch_direction, "length": branch_length})
			var branch_event := event.continue_after_split(profile)
			branch_event.damage = maxi(1, roundi(branch_event.damage * float(profile.damage_multiplier)))
			branch_event.elemental_damage_scale *= float(profile.damage_multiplier)
			EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, branch_event, endpoint, branch_direction, "", "electric_spark" if lightning_count > 0 else "")
			_native_damage(point, branch_direction, branch_length, float(profile.damage_multiplier), ray.hits)
	node_created.emit(index, point)


func _emit_lightning_sample(index: int, ray: Dictionary) -> void:
	var direction: Vector2 = ray.direction
	var point := global_position + direction * (lightning_first + index * lightning_spacing)
	if not clear_path(self, global_position, point):
		ray.lightning_blocked = true
		return
	EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, event.duplicate_event(), point, direction, "electric_spark")
	# Split-before-lightning samples the same translated branch endpoints;
	# only the enchantment is repeated, not native damage or other effects.
	for profile in weapon.get_split_profiles():
		for child_index in int(profile.child_count):
			var sign_value := -1.0 if child_index % 2 == 0 else 1.0
			var branch_direction := direction.rotated(deg_to_rad(maxf(float(profile.spread_angle), 25.0) * sign_value))
			var endpoint := point + branch_direction * float(weapon.weapon_data.ground_branch_length)
			if not clear_path(self, point, endpoint):
				continue
			var branch_event := event.continue_after_split(profile)
			branch_event.damage = maxi(1, roundi(branch_event.damage * float(profile.damage_multiplier)))
			branch_event.elemental_damage_scale *= float(profile.damage_multiplier)
			EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, branch_event, endpoint, branch_direction, "electric_spark")


func _native_damage(origin: Vector2, direction: Vector2, length: float, power: float, ray_hits: Dictionary) -> void:
	for enemy in rectangle_contacts(origin, direction, length, weapon.get_hit_radius()):
		if ray_hits.has(enemy.get_instance_id()):
			continue
		ray_hits[enemy.get_instance_id()] = true
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
		for ray in rays:
			var direction: Vector2 = ray.direction
			draw_atlas(HAMMER, 64, frame, Vector2(30, 43), direction * 10 + Vector2(0, 2), direction.angle(), Vector2.ONE * weapon.get_projectile_visual_scale(), opacity)


func _draw_ground_cracks() -> void:
	if cancelled:
		return
	for node in nodes:
		var elapsed := age - float(node.at)
		if elapsed < 0 or elapsed > 1.25:
			continue
		var frame := 0 if elapsed < 0.12 else 1 if elapsed < 0.35 else 2
		var direction: Vector2 = node.direction
		var point: Vector2 = node.point
		var child := bool(node.child)
		var pivot := Vector2(3 if child else 32, 32)
		var dimensions := Vector2(float(node.length) / 57.0, 0.65) if child else Vector2(spacing / 64.0, 1)
		dimensions *= weapon.get_projectile_visual_scale()
		# Clip the artwork, not the node positions or damage cells. This also
		# prevents enlarged strips from growing backwards through the caster.
		var crop := clampf(pivot.x + (crack_clearance - point.dot(direction)) / maxf(dimensions.x, 0.001), 0, 64)
		if crop >= 64:
			continue
		var rect := Rect2(Vector2(crop, 0) - pivot, Vector2(64 - crop, 64))
		var region := Rect2(frame * 64 + crop, 0, 64 - crop, 64)
		crack_layer.draw_set_transform(point, direction.angle(), dimensions)
		crack_layer.draw_texture_rect_region(crack_texture, rect, region, Color(1, 1, 1, minf(1, (1.25 - elapsed) * 3)))
		# Briefly brighten the existing pixels, preserving the crack shape and crop.
		if FEEDBACK_SETTINGS.enabled() and not child and elapsed < 0.075:
			var emphasis := 0.65 if point.length() < first_offset + spacing * 0.5 else 0.25
			crack_layer.draw_texture_rect_region(crack_texture, rect, region, Color(2.4, 2.1, 1.65, emphasis * (1.0 - elapsed / 0.075)))
	crack_layer.draw_set_transform(Vector2.ZERO)
