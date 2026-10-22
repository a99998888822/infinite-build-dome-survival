extends DirectedWeaponRuntime
class_name EarthHammer

signal node_created(index: int, point: Vector2)
const HAMMER := preload("res://assets/sprites/weapons/earth_hammer/earth_hammer.png")
const BLOCK_VFX = preload("res://scripts/effects/weapon_block_vfx.gd")
const CRACKS := preload("res://assets/sprites/weapons/effects/block_vfx/hammer_crack.png")
const HAMMER_VISUAL_SCALE := 2.2
# Convex outline of the opaque contact pose in the 64px atlas (frame 8).
const CONTACT_OUTLINE := [Vector2(27,44), Vector2(29,40), Vector2(54,39), Vector2(55,39), Vector2(61,43), Vector2(61,45), Vector2(59,50), Vector2(56,57), Vector2(54,61), Vector2(49,63), Vector2(48,63), Vector2(42,60), Vector2(27,45)]
const IMPACT_R02 = preload("res://scripts/effects/combat_impact_r02.gd")
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
var contact_cells: Array[Dictionary] = []


func initialize(source: WeaponInstance, direction: Vector2) -> void:
	bind_weapon(source, "earth_hammers")
	crack_texture = CRACKS
	crack_clearance = maxf(42.0, AttackFootprint.player_clearance(source) + 8.0)
	crack_layer = Node2D.new()
	CombatRenderWorld.set_effect_layer(crack_layer, -1)
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
		var resolve_head := not impacted or age <= hit_at + contact
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
		if resolve_head:
			_damage_hammer_heads()
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
		for cell in contact_cells:
			if age <= float(cell.until):
				_native_damage(cell.origin, cell.direction, cell.length, cell.power, cell.hits)
		contact_cells = contact_cells.filter(func(cell): return age <= float(cell.until))
	if age > hit_at + (node_count - 1) * interval + 1.25:
		cancel()
	queue_redraw()
	crack_layer.queue_redraw()


func _emit_node(index: int, ray: Dictionary) -> void:
	var direction: Vector2 = ray.direction
	var offset := first_offset + index * spacing
	var point := global_position + direction * offset
	var when := appear + slam + index * interval
	var extent := spacing * weapon.get_projectile_visual_scale() * 0.5
	var start_offset := 0.0 if index == 0 else maxf(0.0, offset - extent)
	var start := global_position + direction * start_offset
	# A blocked node center must not discard the hittable interval before it.
	var end_distance := _clear_distance(global_position, direction, offset + extent)
	if not clear_path(self, global_position, point):
		_queue_contact_cell(start, direction, maxf(0, end_distance - start_offset), 1.0, ray.hits, when)
		ray.blocked = true
		return
	nodes.append({"point": point - global_position, "at": when, "child": false, "direction": direction, "length": spacing})
	if index == 0:
		IMPACT_R02.spawn(get_parent(), point, &"ground", direction, minf(2.5, 1.8 * weapon.get_projectile_visual_scale()))
	# Resolve the node once; real enemies below do not fire this dispatcher again.
	EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, event.duplicate_event(), point, direction, "", "electric_spark" if lightning_count > 0 else "")
	_queue_contact_cell(start, direction, maxf(0, end_distance - start_offset), 1.0, ray.hits, when)
	for profile in weapon.get_split_profiles():
		for child_index in int(profile.child_count):
			var sign_value := -1.0 if child_index % 2 == 0 else 1.0
			var angle := maxf(float(profile.spread_angle), 25.0) * sign_value
			var branch_direction := direction.rotated(deg_to_rad(angle))
			var branch_length := float(weapon.weapon_data.ground_branch_length)
			var endpoint := point + branch_direction * branch_length
			var contact_length := _clear_distance(point, branch_direction, branch_length * weapon.get_projectile_visual_scale())
			if not clear_path(self, point, endpoint):
				_queue_contact_cell(point, branch_direction, contact_length, float(profile.damage_multiplier), ray.hits, when)
				continue
			nodes.append({"point": point - global_position, "at": when, "child": true, "direction": branch_direction, "length": branch_length})
			var branch_event := event.continue_after_split(profile)
			branch_event.damage = maxi(1, roundi(branch_event.damage * float(profile.damage_multiplier)))
			branch_event.elemental_damage_scale *= float(profile.damage_multiplier)
			EFFECTS.trigger_ground_weapon_impact(get_parent(), weapon, branch_event, endpoint, branch_direction, "", "electric_spark" if lightning_count > 0 else "")
			_queue_contact_cell(point, branch_direction, contact_length, float(profile.damage_multiplier), ray.hits, when)
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


func _clear_distance(origin: Vector2, direction: Vector2, length: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(origin, origin + direction * length, 4)
	query.hit_from_inside = true
	var wall := get_world_2d().direct_space_state.intersect_ray(query)
	return length if wall.is_empty() else maxf(0, origin.distance_to(wall.position) - 0.1)


func _queue_contact_cell(origin: Vector2, direction: Vector2, length: float, power: float, ray_hits: Dictionary, when: float) -> void:
	if length <= 0.001: return
	_native_damage(origin, direction, length, power, ray_hits)
	contact_cells.append({"origin": origin, "direction": direction, "length": length, "power": power, "hits": ray_hits, "until": when + contact})


func _damage_hammer_heads() -> void:
	var shape := ConvexPolygonShape2D.new()
	var size_scale := weapon.get_projectile_visual_scale() * HAMMER_VISUAL_SCALE
	for ray in rays:
		var direction: Vector2 = ray.direction
		var grip := (direction * 10 + Vector2(0, 2)).round()
		var points := PackedVector2Array()
		for point: Vector2 in CONTACT_OUTLINE:
			points.append(grip + ((point - Vector2(30, 43)) * size_scale).rotated(direction.angle()))
		shape.points = points
		for enemy in EnemyRegistry.get_registered_enemies():
			if AttackFootprint.body_overlaps(shape, Transform2D(0, global_position), enemy) and clear_path(self, global_position, enemy.global_position):
				_native_hit(enemy, direction, 1.0, ray.hits)


func _native_damage(origin: Vector2, direction: Vector2, length: float, power: float, ray_hits: Dictionary) -> void:
	for enemy in rectangle_contacts(origin, direction, length, weapon.get_hit_radius()):
		_native_hit(enemy, direction, power, ray_hits)


func _native_hit(enemy: EnemyController, direction: Vector2, power: float, ray_hits: Dictionary) -> void:
	if ray_hits.has(enemy.get_instance_id()): return
	ray_hits[enemy.get_instance_id()] = true
	hits[enemy.get_instance_id()] = true
	var hit := event.duplicate_event()
	hit.damage = maxi(1, roundi(hit.damage * power))
	deal_hit(enemy, hit, direction, power != 1.0, false)


func _draw() -> void:
	BLOCK_VFX.begin(self)
	if cancelled:
		return
	var opacity := hammer_opacity()
	if opacity > 0:
		var frame := mini(4, int(age / maxf(appear, 0.001) * 5))
		if age >= appear:
			frame = 5 + mini(3, int((age - appear) / maxf(slam, 0.001) * 3))
		for ray in rays:
			var direction: Vector2 = ray.direction
			var visual_scale := weapon.get_projectile_visual_scale() * HAMMER_VISUAL_SCALE
			var grip := direction * 10 + Vector2(0, 2)
			if age >= appear * 0.9:
				var visual_frame := maxi(0, frame - 4)
				if age >= appear + slam:
					visual_frame = mini(7, 4 + int((age - appear - slam) / maxf(contact + fade, 0.001) * 4.0))
				# Grow the head and wind together around the authored grip.
				var pose := Transform2D(direction.angle(),Vector2.ONE*visual_scale,0,grip-direction*10*visual_scale)
				BLOCK_VFX.draw(self,"hammer",visual_frame/8.0,Rect2(-32,-100,128,128),Color.WHITE,pose)
			draw_atlas(HAMMER, 64, frame, Vector2(30, 43), grip, direction.angle(), Vector2.ONE * visual_scale, opacity)


func _draw_ground_cracks() -> void:
	BLOCK_VFX.ALIGNED.begin(crack_layer)
	if cancelled:
		return
	for node in nodes:
		var elapsed := age - float(node.at)
		if elapsed < 0 or elapsed > 1.25:
			continue
		var frame := 0 if elapsed < 0.065 else 1 if elapsed < 0.12 else 2 if elapsed < 0.22 else 3 if elapsed < 0.45 else 4 if elapsed < 0.85 else 5
		var direction: Vector2 = node.direction
		var point: Vector2 = node.point
		var child := bool(node.child)
		var pivot := Vector2(0 if child else 48, 48)
		var dimensions := Vector2(float(node.length) / 96.0, 0.90) if child else Vector2(spacing / 96.0, 1.30)
		dimensions *= weapon.get_projectile_visual_scale()
		# Clip the artwork, not the node positions or damage cells. This also
		# prevents enlarged strips from growing backwards through the caster.
		var crop := clampf(pivot.x + (crack_clearance - point.dot(direction)) / maxf(dimensions.x, 0.001), 0, 96)
		if crop >= 96:
			continue
		var rect := Rect2(Vector2(crop, 0) - pivot, Vector2(96 - crop, 96))
		var region := Rect2(frame * 96 + crop, 0, 96 - crop, 96)
		BLOCK_VFX.ALIGNED.draw(crack_layer,crack_texture,rect,region,Color(1,1,1,minf(1,(1.25-elapsed)*3)),Transform2D(direction.angle(),dimensions,0,point))
	crack_layer.draw_set_transform(Vector2.ZERO)
