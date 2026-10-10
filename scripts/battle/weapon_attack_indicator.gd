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


func configure(source: WeaponInstance, offset: Vector2, can_cast: bool = true) -> void:
	weapon = source
	target_offset = offset
	available = can_cast
	clearance = FOOTPRINT.player_clearance(source)
	if source.is_mobility_weapon():
		if mobility_indicator == null:
			mobility_indicator = MOBILITY.new()
			add_child(mobility_indicator)
		mobility_indicator.show()
		mobility_indicator.configure_weapon(source, offset, can_cast)
	elif mobility_indicator != null:
		mobility_indicator.hide()
	STYLE.sync_material(self, clearance, available)
	queue_redraw()


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = STYLE.make_material()


func _draw() -> void:
	STYLE.sync_material(self, clearance, available)
	_shape_transform = Transform2D.IDENTITY
	if weapon == null or weapon.is_mobility_weapon():
		return
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


func get_arrow_width_parameter() -> float:
	if weapon.use_active_range_rules:
		var base := minf(maxf(20, float(weapon.weapon_data.get("hit_radius", 0))), maxf(12, weapon.get_base_attack_range() - clearance - 2) * 0.23)
		return StatDefinitions.calculate_damage_area_radius(base, weapon.get_stat("damage_area_size")) if weapon.has_combat_tag(L10n.text("combat.tag.area")) else base
	return minf(maxf(20, weapon.get_hit_radius()), maxf(12, weapon.get_attack_range() - clearance - 2) * 0.23)


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
