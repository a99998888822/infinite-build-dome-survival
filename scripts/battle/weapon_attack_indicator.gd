extends Node2D
class_name WeaponAttackIndicator
## Pixel range silhouettes shared by live previews and transparent exports.

const FOOTPRINT = preload("res://scripts/battle/attack_footprint.gd")
const STYLE = preload("res://scripts/battle/pixel_indicator_style.gd")
const MOBILITY = preload("res://scripts/battle/mobility_weapon_indicator.gd")
var mobility_indicator: Node2D
var _style := STYLE.new()
var _shape_transform := Transform2D.IDENTITY
var weapon: WeaponInstance
var target_offset := Vector2(180, 0)
var available := true
var clearance := 34.0
var pattern: AttackPatternPlan
var pattern_units: Array[WeaponInstance] = []
var _preview_key: Array = []


func configure(source: WeaponInstance, offset: Vector2, can_cast: bool = true) -> void:
	weapon = source
	target_offset = offset
	available = can_cast
	clearance = FOOTPRINT.player_clearance(source)
	_update_pattern(source)
	if source.is_mobility_weapon():
		if mobility_indicator == null:
			mobility_indicator = MOBILITY.new()
			add_child(mobility_indicator)
		mobility_indicator.show()
		mobility_indicator.configure_weapon(source, offset, can_cast, pattern, pattern_units)
	elif mobility_indicator != null:
		mobility_indicator.hide()
	STYLE.sync_material(self, clearance, available)
	queue_redraw()

func _update_pattern(source: WeaponInstance) -> void:
	var key := [source.instance_id, source.level, source.get_enchantment_sequence(),
		source.get_stat("projectile_count"), source.get_hit_radius(), source.get_attack_range(),
		source.get_grenade_blast_radius(), source.get_active_cooldown_seconds(),
		source.get_stat("area_size"), source.get_stat("damage_area_size"), source.use_active_range_rules]
	if key == _preview_key: return
	_preview_key = key
	pattern = AttackPatternPlan.build(source)
	pattern_units.clear()
	if not pattern.changes_shape(): return
	# Geometry snapshots are cached. Previewing never rolls damage or starts a cast.
	for i in pattern.units.size():
		var unit := source.make_cast_copy()
		pattern.apply_unit(unit, i)
		pattern_units.append(unit)


func _ready() -> void:
	CombatRenderWorld.set_world_layer(self, CombatRenderWorld.TELEGRAPH_Z)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = STYLE.make_material()


func _draw() -> void:
	STYLE.sync_material(self, clearance, available)
	_shape_transform = Transform2D.IDENTITY
	if weapon == null:
		return
	if pattern != null and pattern.changes_shape():
		if not weapon.is_mobility_weapon() or weapon.is_hand_cannon(): _draw_pattern()
		return
	if weapon.is_mobility_weapon(): return
	var reach := weapon.get_attack_range()
	var aim := target_offset.normalized() if target_offset.length_squared() > 0.01 else Vector2.RIGHT
	if weapon.is_ritual_tome():
		_range_ellipse(Vector2.ZERO, weapon.get_domain_axes(), true)
	elif weapon.is_grenade():
		_range_ellipse(Vector2.ZERO, FOOTPRINT.grenade_range_axes(weapon), false)
		for point in grenade_landings(weapon, target_offset):
			_range_ellipse(point, FOOTPRINT.grenade_blast_axes(weapon), true)
	else:
		_shape_transform = Transform2D(aim.angle(), Vector2.ZERO)
		if weapon.is_camp_dagger() or weapon.is_copper_lamp() or weapon.is_meteor_flail():
			_shape_transform = FOOTPRINT.ground_transform(aim)
		if weapon.is_camp_dagger():
			_fan(clearance, maxf(clearance + 8, weapon.get_dagger_outer_radius()), deg_to_rad(float(weapon.weapon_data.get("dagger_arc_degrees", 130))))
		elif weapon.is_copper_lamp():
			_lamp_fan(reach, deg_to_rad(weapon.get_lamp_cone_degrees()))
		elif weapon.is_meteor_flail():
			_fan(clearance, reach, deg_to_rad(FOOTPRINT.FLAIL_ARC))
		else:
			for angle in weapon.get_projectile_angles():
				_shape_transform = Transform2D(aim.angle() + deg_to_rad(angle), Vector2.ZERO)
				_arrow(reach, get_arrow_width_parameter())
	_shape_transform = Transform2D.IDENTITY


static func grenade_landings(source: WeaponInstance, landing: Vector2) -> Array[Vector2]:
	return FOOTPRINT.grenade_landings(source, landing)


func _outline(points: PackedVector2Array, closed: bool = false, opacity: float = 1.0) -> void:
	_style.outline(self, _shape_transform * points, available, closed, opacity)


func _polygon(points: PackedVector2Array) -> void:
	draw_colored_polygon(_shape_transform * points, STYLE.fill_color(available))
	_outline(points, true)


func get_arrow_width_parameter(source: WeaponInstance = null) -> float:
	if source == null: source = weapon
	if source.use_active_range_rules:
		var base := minf(maxf(20, float(source.weapon_data.get("hit_radius", 0))), maxf(12, source.get_base_attack_range() - clearance - 2) * 0.23)
		var width := StatDefinitions.calculate_damage_area_radius(base, source.get_stat("damage_area_size")) if source.has_combat_tag(L10n.text("combat.tag.area")) or source.has_combat_tag(L10n.text("stat.category.projectiles")) else base
		return width * source.pattern_size_scale
	return minf(maxf(20, source.get_hit_radius()), maxf(12, source.get_attack_range() - clearance - 2) * 0.23)

func _draw_pattern() -> void:
	var aim := target_offset.normalized() if not target_offset.is_zero_approx() else Vector2.RIGHT
	if pattern.orbit:
		_draw_orbit()
	elif weapon.is_grenade():
		_draw_pattern_grenades()
	elif pattern.satellite:
		_draw_satellites(aim)
	else:
		var angles := pattern.angles(weapon)
		for i in pattern_units.size():
			_draw_pattern_unit(pattern_units[i], aim.rotated(deg_to_rad(angles[i])))
	_shape_transform = Transform2D.IDENTITY

func _draw_pattern_unit(unit: WeaponInstance, aim: Vector2) -> void:
	var reach := unit.get_attack_range()
	_shape_transform = Transform2D.IDENTITY
	if unit.is_ritual_tome():
		# The merged mark does not enlarge the domain in which targets are chosen.
		_range_ellipse(Vector2.ZERO, unit.get_domain_axes(), true)
	elif unit.is_furnace():
		_range_ellipse(Vector2.ZERO, Vector2(1.0, FOOTPRINT.ELLIPSE_RATIO) * unit.get_hit_radius(), true)
	else:
		_shape_transform = Transform2D(aim.angle(), Vector2.ZERO)
		if unit.is_camp_dagger() or unit.is_copper_lamp() or unit.is_meteor_flail():
			_shape_transform = FOOTPRINT.ground_transform(aim)
		if unit.is_camp_dagger():
			_fan(clearance, maxf(clearance + 8, unit.get_dagger_outer_radius()), deg_to_rad(float(unit.weapon_data.get("dagger_arc_degrees", 130))))
		elif unit.is_copper_lamp():
			_lamp_fan(reach, deg_to_rad(unit.get_lamp_cone_degrees()))
		elif unit.is_meteor_flail():
			_fan(clearance, reach + unit.get_hit_radius(), deg_to_rad(FOOTPRINT.FLAIL_ARC))
		else:
			_arrow(reach, get_arrow_width_parameter(unit))
	_shape_transform = Transform2D.IDENTITY

func _orbit_band(at: Vector2, radius: float, half_width: float) -> void:
	_shape_transform = Transform2D.IDENTITY
	draw_arc(at, radius, 0, TAU, 128, STYLE.fill_color(available), maxf(2, half_width * 2))
	_outline(_arc_points(at, Vector2.ONE * (radius + half_width)), true, 0.7)
	if radius > half_width:
		_outline(_arc_points(at, Vector2.ONE * (radius - half_width)), true, 0.7)

func _body_marker(at: Vector2, radius: float) -> void:
	_shape_transform = Transform2D.IDENTITY
	_range_ellipse(at, Vector2.ONE * maxf(5.0, radius), true)

func _draw_orbit() -> void:
	var main := pattern_units[0]
	var extent := main.get_hit_radius()
	for i in range(1, pattern_units.size()):
		extent = maxf(extent, pattern_units[i].get_hit_radius() + (pattern.get_satellite_radius(weapon) if pattern.satellite else 0.0))
	_orbit_band(Vector2.ZERO, weapon.get_attack_range(), extent)
	if pattern.satellite:
		var center := pattern.orbit_position(0, 0, weapon)
		_body_marker(center, main.get_hit_radius())
		_outline(_arc_points(center, Vector2.ONE * pattern.get_satellite_radius(weapon)), true)
		for i in range(1, pattern_units.size()):
			_body_marker(center + pattern.satellite_position(i, 0, weapon), pattern_units[i].get_hit_radius())
	else:
		for i in pattern_units.size():
			_body_marker(pattern.orbit_position(i, 0, weapon), pattern_units[i].get_hit_radius())

func _draw_satellites(aim: Vector2) -> void:
	var main := pattern_units[0]
	var reach := weapon.get_attack_range()
	var radius := pattern.get_satellite_radius(weapon)
	var center := aim * reach * 0.58
	if weapon.is_meteor_flail():
		# This transformed flail swings in screen space, matching its flight runtime.
		_shape_transform = Transform2D(aim.angle(), Vector2.ZERO)
		_fan(maxf(clearance, reach - radius - main.get_hit_radius()), reach + radius + main.get_hit_radius(), 2.4)
		center = aim * reach
	else:
		_shape_transform = Transform2D(aim.angle(), Vector2.ZERO)
		_arrow(reach, get_arrow_width_parameter(main))
		var extent := radius + pattern_units[1].get_hit_radius()
		_outline(PackedVector2Array([Vector2(clearance, -extent), Vector2(reach, -extent)]), false, 0.5)
		_outline(PackedVector2Array([Vector2(clearance, extent), Vector2(reach, extent)]), false, 0.5)
	_shape_transform = Transform2D.IDENTITY
	_outline(_arc_points(center, Vector2.ONE * radius), true)
	_body_marker(center, main.get_hit_radius())
	for i in range(1, pattern_units.size()):
		_body_marker(center + pattern.satellite_position(i, 0, weapon), pattern_units[i].get_hit_radius())

func _draw_pattern_grenades() -> void:
	_shape_transform = Transform2D.IDENTITY
	_range_ellipse(Vector2.ZERO, FOOTPRINT.grenade_range_axes(weapon), false)
	var main_landing := pattern.grenade_landing(pattern_units[0], 0, target_offset)
	var flight_seconds := float(weapon.weapon_data.get("grenade_flight_seconds", 0.45))
	for i in pattern_units.size():
		var point := pattern.grenade_landing(pattern_units[i], i, target_offset)
		if pattern.satellite and i > 0:
			point = main_landing + pattern.satellite_position(i, flight_seconds, weapon)
		_range_ellipse(point, Vector2(1.0, FOOTPRINT.ELLIPSE_RATIO) * pattern_units[i].get_grenade_blast_radius(), true)
		_outline(PackedVector2Array([Vector2.ZERO, point]), false, 0.45)
	if pattern.satellite:
		_outline(_arc_points(main_landing, Vector2.ONE * pattern.get_satellite_radius(weapon)), true)


func arrow_points(reach: float, width: float) -> PackedVector2Array:
	var begin := clearance + 2.0
	var length := maxf(12, reach - begin)
	var shoulder := reach - minf(length * 0.32, maxf(22, width * 2.4))
	var shaft := width * 0.62 * 0.8
	# Sharp shoulders retain the original reach/width and read as a pixel arrow.
	return PackedVector2Array([Vector2(begin, -shaft), Vector2(shoulder, -shaft),
		Vector2(shoulder, -width * 1.2), Vector2(reach, 0), Vector2(shoulder, width * 1.2),
		Vector2(shoulder, shaft), Vector2(begin, shaft)])


func _arrow(reach: float, width: float) -> void:
	_polygon(arrow_points(reach, width))


func _arc_points(center: Vector2, axes: Vector2, start: float = 0.0, end: float = TAU, count: int = 96) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count + 1:
		points.append(center + Vector2.from_angle(lerpf(start, end, float(i) / count)) * axes)
	return points


func _range_ellipse(center: Vector2, axes: Vector2, filled: bool) -> void:
	var border := _arc_points(center, axes, 0, TAU, 160)
	border.remove_at(border.size() - 1)
	if filled:
		draw_colored_polygon(border, STYLE.fill_color(available))
	_outline(border, true, 1.0 if filled else 0.70)


func _fan(inner: float, outer: float, angle: float) -> void:
	var points := _arc_points(Vector2.ZERO, Vector2.ONE * outer, -angle * 0.5, angle * 0.5, 48)
	points.append_array(_arc_points(Vector2.ZERO, Vector2.ONE * inner, angle * 0.5, -angle * 0.5, 48))
	_polygon(points)


func _lamp_fan(reach: float, angle: float) -> void:
	var origin := Vector2(16, 0)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 49:
		var a := lerpf(-angle * 0.5, angle * 0.5, i / 48.0)
		var ray := Vector2.from_angle(a)
		var projection := origin.dot(ray)
		outer.append(origin + ray * (-projection + sqrt(maxf(0, projection * projection + reach * reach - origin.length_squared()))))
		inner.append(origin + ray * (-projection + sqrt(maxf(0, projection * projection + clearance * clearance - origin.length_squared()))))
	var points := outer.duplicate()
	inner.reverse()
	points.append_array(inner)
	_polygon(points)
