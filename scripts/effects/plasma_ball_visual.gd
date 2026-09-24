extends Node2D

# Render-only pixel orb and grounded discharge. The parent owns all hit processing.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const ARC_PERIOD := 0.32
const DISCHARGE_RADIUS_MULTIPLIER := 2.0
const CORE_TEXTURE_SIZE := 24
const CORE_FRAME_COUNT := 16
static var _core_frames: Array[ImageTexture] = []

var weapon: WeaponInstance
var elapsed := 0.0
var radius := 24.0
var core_radius := 12.0
var phase := 0.0
var _ground: Node2D
var _arcs: Array[Dictionary] = []


func initialize(source: WeaponInstance, identity: String) -> void:
	weapon = source
	phase = float(absi(identity.hash()) % 1000) * 0.01
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prepare_core_frames()
	_ground = PIXEL.layer(self, 5, _draw_ground)
	advance(0.0)


func advance(delta: float) -> void:
	elapsed += delta
	core_radius = weapon.get_hit_radius()
	radius = core_radius * DISCHARGE_RADIUS_MULTIPLIER
	var count := clampi(int(weapon.weapon_data.get("plasma_arc_count", 3)), 1, 6)
	_arcs.resize(count)
	for index in count:
		var clock := elapsed + index * ARC_PERIOD / float(count)
		var cycle := int(floor(clock / ARC_PERIOD))
		if _arcs[index].is_empty() or int(_arcs[index].cycle) != cycle:
			var angle := phase + index * 2.4 + cycle * 1.73
			# Save the floor endpoint in world space for the entire double flash.
			var foot := Vector2(cos(angle) * radius * 1.65, radius * (1.4 + sin(angle) * 0.40))
			var socket_angle := 0.20 + absf(sin(angle * 1.31)) * 0.75
			if foot.x < 0.0:
				socket_angle = PI - socket_angle
			_arcs[index] = {"cycle": cycle, "foot": global_position + foot,
				"socket": Vector2.from_angle(socket_angle) * core_radius,
				"age": 0.0}
		_arcs[index].age = fmod(clock, ARC_PERIOD)
	queue_redraw()
	_ground.queue_redraw()


func _draw_ground() -> void:
	var floor_center := Vector2(0, radius * 1.4)
	_ground.draw_set_transform(floor_center)
	PIXEL.ellipse(_ground, Vector2(radius * 1.05, radius * 0.30), Color(0.015, 0.04, 0.08, 0.32))
	PIXEL.ellipse(_ground, Vector2(radius * 1.55, radius * 0.48), Color(0.18, 0.62, 1.0, 0.08))
	_ground.draw_set_transform(Vector2.ZERO)
	for arc in _arcs:
		var alpha := _arc_alpha(float(arc.age))
		if alpha <= 0.0:
			continue
		var foot := to_local(arc.foot)
		_ground.draw_set_transform(foot)
		PIXEL.ellipse(_ground, Vector2(7, 3), Color(0.25, 0.72, 1.0, alpha * 0.20))
		_ground.draw_set_transform(Vector2.ZERO)
		PIXEL.block(_ground, foot, Vector2(4, 2), Color(0.78, 0.95, 1.0, alpha))


func _draw() -> void:
	if weapon == null:
		return
	for index in _arcs.size():
		var arc := _arcs[index]
		var alpha := _arc_alpha(float(arc.age))
		if alpha <= 0.0:
			continue
		var start: Vector2 = arc.socket
		var foot := to_local(arc.foot)
		var segments := clampi(int(weapon.weapon_data.get("plasma_arc_segments", 16)) / 2, 4, 12)
		var jitter := maxf(float(weapon.weapon_data.get("plasma_arc_jitter", 4.5)), 0.0) * radius / 24.0
		var tick := floorf(elapsed * 24.0)
		var points := PackedVector2Array()
		for step in range(segments + 1):
			var t := float(step) / segments
			var point := start.lerp(foot, t)
			var seed_value := phase + index * 13.1 + step * 7.3 + tick * 2.7
			point += Vector2(sin(seed_value), cos(seed_value * 1.73)) * jitter * sin(PI * t)
			points.append(point)
		PIXEL.path(self, points, Color(0.22, 0.61, 1.0, alpha * 0.23), 2)
		_draw_thin_bolt(points, Color(0.88, 0.98, 1.0, alpha))
		if index % 2 == 0 and float(arc.age) >= 0.095:
			var fork: Vector2 = points[segments / 2]
			var side := -1.0 if index % 3 == 0 else 1.0
			_draw_thin_bolt(PackedVector2Array([fork, fork + Vector2(5 * side, 2),
				fork + Vector2(8 * side, 5)]) , Color(0.68, 0.88, 1.0, alpha * 0.65))
		PIXEL.block(self, start, Vector2(2, 2), Color(0.94, 1.0, 1.0, alpha))
	# Cover any discharge segment that passes behind the body during flight.
	_draw_core()


func _draw_core() -> void:
	var pulse := 0.5 + sin(elapsed * TAU * 2.0 + phase) * 0.5
	PIXEL.ellipse(self, Vector2.ONE * core_radius * 1.20, Color(0.25, 0.69, 1.0, 0.07 + pulse * 0.05))
	var frame := int(floor((elapsed + phase) * CORE_FRAME_COUNT)) % CORE_FRAME_COUNT
	draw_texture_rect(_core_frames[frame], Rect2(-Vector2.ONE * core_radius, Vector2.ONE * core_radius * 2.0), false)
	# Detached, short-lived square sparks suggest an ionized edge, not surface arcs.
	for index in 6:
		var clock := elapsed / 0.24 + phase + index / 6.0
		var life := fposmod(clock, 1.0)
		if life > 0.32:
			continue
		var angle := index * 2.399 + floorf(clock) * 1.73 + phase
		var point := (Vector2.from_angle(angle) * (core_radius + 2.0 + life * 7.0)).round()
		var alpha := (1.0 - life / 0.32) * 0.90
		draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), Color(0.22, 0.65, 1.0, alpha * 0.15))
		draw_rect(Rect2(point, Vector2.ONE), Color(0.84, 0.97, 1.0, alpha))


static func _prepare_core_frames() -> void:
	if not _core_frames.is_empty():
		return
	var palette: Array[Color] = [Color(0.18, 0.53, 0.77), Color(0.26, 0.73, 0.94),
		Color(0.53, 0.87, 1.0), Color(0.88, 0.98, 1.0)]
	# Pixel-center circle coverage is symmetric on both axes at this small size.
	# Every frame shares one circular mask; only emissive clouds move inside it.
	for frame in CORE_FRAME_COUNT:
		var bitmap := Image.create(CORE_TEXTURE_SIZE, CORE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		var clock := TAU * float(frame) / CORE_FRAME_COUNT
		for y in CORE_TEXTURE_SIZE:
			for x in CORE_TEXTURE_SIZE:
				var uv := (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * CORE_TEXTURE_SIZE * 0.5) / (CORE_TEXTURE_SIZE * 0.5)
				var distance_sq := uv.length_squared()
				if distance_sq >= 1.0:
					continue
				var turbulence := sin(uv.x * 8.0 + clock) * sin(uv.y * 7.0 - clock) * 0.40
				var heat := (1.0 - distance_sq) * 3.3 + turbulence + sin(clock * 2.0) * 0.18
				bitmap.set_pixel(x, y, palette[clampi(int(floor(heat)), 0, palette.size() - 1)])
		_core_frames.append(ImageTexture.create_from_image(bitmap))


func _draw_thin_bolt(points: PackedVector2Array, color: Color) -> void:
	# One-pixel cores keep the short discharges sharp rather than solid struts.
	for index in range(1, points.size()):
		var a := points[index - 1].round()
		var b := points[index].round()
		var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
		for step in range(steps + 1):
			draw_rect(Rect2(a.lerp(b, float(step) / steps).round(), Vector2.ONE), color)


static func _arc_alpha(age: float) -> float:
	if age < 0.065:
		return 0.85
	if age >= 0.095 and age < 0.155:
		return 1.0
	if age >= 0.155 and age < 0.19:
		return (0.19 - age) / 0.035 * 0.35
	return 0.0
