extends Node2D
class_name BattleBackdrop

## World-space arena dressing. The node lives under CombatRenderWorld so every
## structure shares the same camera transform as the floor and actors.

const AMBIENT_RECT := Rect2(-720.0, -420.0, 1440.0, 840.0)
const DUST_COUNT: int = 26
const FOG_COUNT: int = 8
const STRUCTURE_COLORS := [
	Color(0.025, 0.039, 0.032, 0.88),
	Color(0.038, 0.055, 0.042, 0.72),
	Color(0.058, 0.071, 0.051, 0.54),
]
const RUNE_COLOR := Color(0.38, 0.67, 0.30, 1.0)
const RUNE_GOLD := Color(0.68, 0.52, 0.22, 1.0)

var wave_manager: Node = null
var elapsed_seconds: float = 0.0
var wave_number: float = 1.0
var dust: Array[Dictionary] = []
var fog: Array[Dictionary] = []


func _ready() -> void:
	z_index = -30
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed_ambient_particles()
	queue_redraw()


func set_world_context(_target_player: Node2D, target_wave_manager: Node) -> void:
	# Kept as a small compatibility hook; only the wave state is dynamic here.
	wave_manager = target_wave_manager


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed_seconds += delta
	_update_wave_number()
	_update_ambient_particles(delta)
	queue_redraw()


func _update_wave_number() -> void:
	if wave_manager == null or not is_instance_valid(wave_manager):
		return
	wave_number = maxf(1.0, float(int(wave_manager.get("current_wave_index")) + 1))


func _seed_ambient_particles() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 184731
	for index in range(DUST_COUNT):
		dust.append({
			"position": Vector2(
				random.randf_range(AMBIENT_RECT.position.x, AMBIENT_RECT.end.x),
				random.randf_range(AMBIENT_RECT.position.y, AMBIENT_RECT.end.y)
			),
			"speed": random.randf_range(1.5, 5.0),
			"phase": random.randf_range(0.0, TAU),
			"size": random.randi_range(1, 2),
			"alpha": random.randf_range(0.10, 0.28),
		})
	for index in range(FOG_COUNT):
		fog.append({
			"position": Vector2(
				random.randf_range(AMBIENT_RECT.position.x, AMBIENT_RECT.end.x),
				random.randf_range(-150.0, AMBIENT_RECT.end.y)
			),
			"speed": random.randf_range(2.0, 7.0),
			"width": random.randf_range(48.0, 110.0),
			"phase": random.randf_range(0.0, TAU),
			"alpha": random.randf_range(0.025, 0.070),
		})


func _update_ambient_particles(delta: float) -> void:
	for particle in dust:
		var position: Vector2 = particle["position"]
		position.x += float(particle["speed"]) * delta
		position.y += sin(elapsed_seconds * 0.35 + float(particle["phase"])) * delta * 0.18
		particle["position"] = _wrap_world_position(position, 16.0)
	for mist in fog:
		var position: Vector2 = mist["position"]
		position.x += float(mist["speed"]) * delta
		mist["position"] = _wrap_world_position(position, float(mist["width"]))


func _wrap_world_position(position: Vector2, margin: float) -> Vector2:
	var wrapped := position
	if wrapped.x > AMBIENT_RECT.end.x + margin:
		wrapped.x = AMBIENT_RECT.position.x - margin
	elif wrapped.x < AMBIENT_RECT.position.x - margin:
		wrapped.x = AMBIENT_RECT.end.x + margin
	if wrapped.y > AMBIENT_RECT.end.y + margin:
		wrapped.y = AMBIENT_RECT.position.y - margin
	elif wrapped.y < AMBIENT_RECT.position.y - margin:
		wrapped.y = AMBIENT_RECT.end.y + margin
	return wrapped


func _draw() -> void:
	# These coordinates are world coordinates around the initial arena origin.
	# Camera movement now reveals/hides them naturally instead of repositioning them.
	_draw_distant_structures()
	_draw_midground_pillars()
	_draw_runes()
	_draw_fog()
	_draw_dust()


func _draw_distant_structures() -> void:
	var base_y := 188.0
	var structures := [
		{"x": -520.0, "height": 118.0, "width": 58.0, "variant": 0},
		{"x": -330.0, "height": 76.0, "width": 42.0, "variant": 1},
		{"x": 330.0, "height": 92.0, "width": 50.0, "variant": 2},
		{"x": 520.0, "height": 132.0, "width": 64.0, "variant": 0},
	]
	for structure in structures:
		var width: float = structure["width"]
		var height: float = structure["height"]
		var variant: int = structure["variant"]
		var x := float(structure["x"]) - width * 0.5
		var y := base_y - height
		var color: Color = STRUCTURE_COLORS[variant]
		_draw_stepped_tower(Vector2(x, y), Vector2(width, height), color, variant)

	# Broken vault sections are fixed in the world and leave the center open.
	var frame_color := Color(0.035, 0.052, 0.041, 0.54)
	draw_rect(Rect2(-720.0, -112.0, 170.0, 6.0), frame_color)
	draw_rect(Rect2(540.0, -100.0, 220.0, 5.0), frame_color)
	draw_rect(Rect2(-590.0, -129.0, 8.0, 23.0), frame_color)
	draw_rect(Rect2(650.0, -115.0, 7.0, 17.0), frame_color)


func _draw_stepped_tower(origin: Vector2, size: Vector2, color: Color, variant: int) -> void:
	var x: float = floorf(origin.x)
	var y: float = floorf(origin.y)
	var width: float = floorf(size.x)
	var height: float = floorf(size.y)
	draw_rect(Rect2(x, y + 12.0, width, height - 12.0), color)
	draw_rect(Rect2(x - 5.0, y + 21.0, width + 10.0, 5.0), color.lightened(0.06))
	draw_rect(Rect2(x + 7.0, y + 5.0, width - 14.0, 8.0), color)
	if variant == 0:
		draw_rect(Rect2(x + width * 0.5 - 3.0, y - 9.0, 6.0, 14.0), color)
		draw_rect(Rect2(x + width * 0.5 - 11.0, y - 2.0, 22.0, 4.0), color)
	elif variant == 1:
		draw_rect(Rect2(x + 4.0, y - 4.0, 14.0, 6.0), color)
		draw_rect(Rect2(x + width - 18.0, y + 1.0, 16.0, 5.0), color)
	else:
		draw_rect(Rect2(x + width * 0.5 - 2.0, y - 14.0, 4.0, 19.0), color)
	var slot_color := Color(0.012, 0.018, 0.015, color.a * 0.80)
	for row in range(3):
		var slot_y: float = y + 33.0 + float(row) * 18.0
		draw_rect(Rect2(x + 9.0, slot_y, 4.0, 7.0), slot_color)
		if width > 42.0:
			draw_rect(Rect2(x + width - 13.0, slot_y + 4.0, 4.0, 6.0), slot_color)


func _draw_midground_pillars() -> void:
	var pillar_color := Color(0.070, 0.084, 0.061, 0.34)
	var positions := [
		Vector2(-590.0, 112.0),
		Vector2(-245.0, 150.0),
		Vector2(245.0, 126.0),
		Vector2(590.0, 104.0),
	]
	for index in range(positions.size()):
		var position: Vector2 = positions[index]
		var height := 38.0 + float(index % 2) * 22.0
		draw_rect(Rect2(floorf(position.x), floorf(position.y), 9.0, height), pillar_color)
		draw_rect(Rect2(floorf(position.x - 4.0), floorf(position.y), 17.0, 5.0), pillar_color.lightened(0.10))
		if index % 2 == 0:
			draw_rect(Rect2(floorf(position.x + 3.0), floorf(position.y - 8.0), 3.0, 8.0), pillar_color)


func _draw_runes() -> void:
	var pulse := 0.5 + 0.5 * sin(elapsed_seconds * (1.25 + wave_number * 0.035))
	var danger := clampf((wave_number - 1.0) / 8.0, 0.0, 1.0)
	var anchors := [
		Vector2(-260.0, -110.0),
		Vector2(260.0, -88.0),
		Vector2(-300.0, 126.0),
		Vector2(290.0, 142.0),
	]
	for index in range(anchors.size()):
		var base_color := RUNE_GOLD if index == 1 else RUNE_COLOR
		var alpha := 0.16 + pulse * 0.12 + danger * 0.08
		_draw_rune(anchors[index], Color(base_color.r, base_color.g, base_color.b, alpha), index % 2 == 0)


func _draw_rune(position: Vector2, color: Color, cross_shape: bool) -> void:
	var x: float = floorf(position.x)
	var y: float = floorf(position.y)
	var glow := Color(color.r, color.g, color.b, color.a * 0.20)
	draw_rect(Rect2(x - 14.0, y - 2.0, 28.0, 4.0), glow)
	draw_rect(Rect2(x - 2.0, y - 14.0, 4.0, 28.0), glow)
	if cross_shape:
		draw_rect(Rect2(x - 9.0, y - 1.0, 18.0, 2.0), color)
		draw_rect(Rect2(x - 1.0, y - 9.0, 2.0, 18.0), color)
		draw_rect(Rect2(x - 5.0, y + 7.0, 10.0, 2.0), color)
	else:
		draw_rect(Rect2(x - 11.0, y - 1.0, 22.0, 2.0), color)
		draw_rect(Rect2(x - 1.0, y - 8.0, 2.0, 16.0), color)
		draw_rect(Rect2(x - 7.0, y - 7.0, 4.0, 4.0), color)
		draw_rect(Rect2(x + 3.0, y + 3.0, 4.0, 4.0), color)


func _draw_fog() -> void:
	for mist in fog:
		var position: Vector2 = mist["position"]
		var width: float = mist["width"]
		var alpha: float = float(mist["alpha"]) * (0.82 + 0.18 * sin(elapsed_seconds * 0.7 + float(mist["phase"])))
		var color := Color(0.30, 0.42, 0.31, alpha)
		for row in range(3):
			var row_width: float = width * (1.0 - float(row) * 0.18)
			draw_rect(Rect2(floorf(position.x - row_width * 0.5), floorf(position.y + float(row) * 3.0), row_width, 2.0), color)


func _draw_dust() -> void:
	for particle in dust:
		var position: Vector2 = particle["position"]
		var pulse := 0.65 + 0.35 * sin(elapsed_seconds * 1.8 + float(particle["phase"]))
		var alpha := float(particle["alpha"]) * pulse
		var size := float(particle["size"])
		draw_rect(Rect2(floorf(position.x), floorf(position.y), size, size), Color(0.55, 0.68, 0.40, alpha))
