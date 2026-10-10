extends Node2D
## Dynamic aim geometry only; attack animation uses imported PNG atlases.
const STYLE = preload("res://scripts/battle/pixel_indicator_style.gd")
var _style := STYLE.new()
var _shape_transform := Transform2D.IDENTITY
const FOOTPRINT = preload("res://scripts/battle/attack_footprint.gd")
enum Kind { DASH_BLADE, RECOIL_GUN, STAR_TOME }

var kind := Kind.DASH_BLADE
var aim_offset := Vector2(140, 0)
var movement_distance := 140.0
var impact_radius := 64.0
var attack_range_bonus := 0.0
var damage_area_bonus := 0.0
var shot_range := 150.0
var shot_angle := 56.0
var return_ready := false
var anchor_offset := Vector2(-180, 0)
var available := true
var clearance := 25.0
var resolved_landing: Variant = null
var _configuration: Array = []
var _rings: Dictionary = {}
var _ring_fills: Dictionary = {}
var _fan_key: Array = []
var _fan_points := PackedVector2Array()
var _fan_fill := PackedVector2Array()

func configure_weapon(source: WeaponInstance, offset: Vector2, can_cast: bool) -> void:
	var anchor := Vector2.ZERO
	if source.is_return_ready(): anchor = source.mobility_runtime.get_ref().anchor_position - source.owner_player.global_position
	var next := [source.instance_id, offset, can_cast, source.get_stat("area_size"), source.get_stat("damage_area_size"), source.is_return_ready(), anchor, source.owner_player.global_position]
	if next == _configuration: return
	_configuration = next
	kind = Kind.STAR_TOME if source.is_star_tome() else Kind.RECOIL_GUN if source.is_hand_cannon() else Kind.DASH_BLADE
	aim_offset = offset
	movement_distance = float(source.weapon_data.get("retreat_distance", 96)) if source.is_hand_cannon() else source.get_base_attack_range()
	impact_radius = float(source.weapon_data.hit_radius)
	attack_range_bonus = source.get_stat("area_size")
	damage_area_bonus = source.get_stat("damage_area_size")
	shot_range = source.get_attack_range()
	shot_angle = source.get_spread_angle()
	return_ready = source.is_return_ready()
	anchor_offset = anchor
	available = can_cast
	clearance = FOOTPRINT.player_clearance(source)
	resolved_landing = source.owner_player.resolve_mobility_destination(source.owner_player.global_position + source.get_mobility_landing(offset)) - source.owner_player.global_position
	STYLE.sync_material(self, clearance, available)
	queue_redraw()


func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = STYLE.make_material()
	queue_redraw()


func outline(points: PackedVector2Array, strength: float = 1.0) -> void:
	_style.outline(self, _shape_transform * points, available, false, strength)


func ring(at: Vector2, radius: float, filled: bool, strength: float = 1.0) -> void:
	ellipse(at, Vector2.ONE * radius, filled, strength)


func ellipse(at: Vector2, axes: Vector2, filled: bool, strength: float = 1.0) -> void:
	if axes.x <= 0.0 or axes.y <= 0.0: return
	if not _rings.has(axes):
		var border := PackedVector2Array()
		for i in 96: border.append(Vector2.from_angle(TAU * i / 96.0) * axes)
		if _rings.size() >= 8:
			_rings.clear()
			_ring_fills.clear()
		# Polygon triangulation expects unique vertices; only the outline closes.
		_ring_fills[axes] = border.duplicate()
		border.append(border[0])
		_rings[axes] = border
	var points: PackedVector2Array = _rings[axes]
	_shape_transform = Transform2D(0, at)
	if filled:
		draw_colored_polygon(_shape_transform * _ring_fills[axes], STYLE.fill_color(available))
	outline(points, strength)
	_shape_transform = Transform2D.IDENTITY


func get_movement_axes() -> Vector2:
	var reach := movement_distance if kind == Kind.RECOIL_GUN else StatDefinitions.calculate_attack_radius(movement_distance, attack_range_bonus)
	return Vector2(reach, reach * FOOTPRINT.ELLIPSE_RATIO)


func get_landing_offset() -> Vector2:
	if resolved_landing is Vector2: return resolved_landing
	var direction := aim_offset.normalized() if aim_offset.length_squared() > 0.01 else Vector2.RIGHT
	if kind == Kind.RECOIL_GUN:
		return -direction * movement_distance
	var axes := get_movement_axes()
	if axes.x <= 0 or axes.y <= 0:
		return Vector2.ZERO
	return (aim_offset / axes).limit_length(1.0) * axes


func get_impact_radius() -> float:
	return StatDefinitions.calculate_damage_area_radius(impact_radius, damage_area_bonus)


func dashed(from: Vector2, to: Vector2, strength: float = 0.8) -> void:
	var distance := from.distance_to(to)
	var heading := from.direction_to(to)
	var offset := 0.0
	var spacing := maxf(13, distance / 48.0)
	while offset < distance:
		outline(PackedVector2Array([from + heading * offset, from + heading * minf(offset + 7, distance)]), strength)
		offset += spacing


func arrowhead(point: Vector2, heading: Vector2) -> void:
	var normal := heading.orthogonal()
	outline(PackedVector2Array([point - heading * 9 + normal * 5, point, point - heading * 9 - normal * 5]))


func _draw() -> void:
	STYLE.sync_material(self, clearance, available)
	_shape_transform = Transform2D.IDENTITY
	var direction := aim_offset.normalized() if aim_offset.length_squared() > 0.01 else Vector2.RIGHT
	match kind:
		Kind.DASH_BLADE:
			var landing := get_landing_offset()
			ellipse(Vector2.ZERO, get_movement_axes(), false, 0.70)
			dashed(direction * minf(clearance, landing.length()), landing)
			arrowhead(landing, direction)
			ellipse(landing, Vector2(1.0, FOOTPRINT.ELLIPSE_RATIO) * get_impact_radius(), true)
		Kind.RECOIL_GUN:
			if _fan_key != [shot_range, shot_angle, clearance]:
				_fan_key = [shot_range, shot_angle, clearance]
				_fan_points.clear()
				for i in 49:
					_fan_points.append(Vector2.from_angle(deg_to_rad(lerpf(-shot_angle * 0.5, shot_angle * 0.5, i / 48.0))) * shot_range)
				for i in 49:
					_fan_points.append(Vector2.from_angle(deg_to_rad(lerpf(shot_angle * 0.5, -shot_angle * 0.5, i / 48.0))) * clearance)
				_fan_fill = _fan_points.duplicate()
				_fan_points.append(_fan_points[0])
			_shape_transform = Transform2D(direction.angle(), Vector2.ZERO)
			draw_colored_polygon(_shape_transform * _fan_fill, STYLE.fill_color(available))
			outline(_fan_points)
			_shape_transform = Transform2D.IDENTITY
			var retreat := get_landing_offset()
			dashed(-direction * clearance, retreat)
			arrowhead(retreat, -direction)
			ring(retreat, 12, false)
		Kind.STAR_TOME:
			if return_ready:
				var heading := anchor_offset.normalized()
				dashed(heading * clearance, anchor_offset)
				arrowhead(anchor_offset - heading * 20, heading)
				ring(anchor_offset, 24, false)
				var points := PackedVector2Array()
				for i in 9:
					points.append(anchor_offset + Vector2.from_angle(i * PI / 4) * (12 if i % 2 == 0 else 3))
				outline(points)
			else:
				var landing := get_landing_offset()
				ellipse(Vector2.ZERO, get_movement_axes(), false, 0.70)
				dashed(direction * minf(clearance, landing.length()), landing, 0.45)
				ring(landing, get_impact_radius(), true)
				outline(PackedVector2Array([landing + Vector2(-5, 0), landing + Vector2(5, 0)]))
				outline(PackedVector2Array([landing + Vector2(0, -5), landing + Vector2(0, 5)]))
