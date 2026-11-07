extends Node2D
## Review only. Ground motes adapt pixelfx shadow/black-hole (MIT).
const BASE := "res://scripts/tools/spell_vfx_sources/"
const R01 = preload("res://scripts/tools/spell_vfx_sources/selected_lightning.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const BLOCK_VFX = preload("res://scripts/effects/enchantment_block_vfx.gd")
const PROJECTION := 145.0 / 220.0
var kind := "water"
var elapsed := 0.0
var back: Node2D
var surface: Node2D
var front: Node2D
var lightning: Node2D
var steady := false

func configure(effect_kind: String) -> void:
	kind = effect_kind
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back = Node2D.new()
	surface = Node2D.new()
	front = Node2D.new()
	for node in [back, surface, front]: add_child(node)
	back.draw.connect(_draw_motes.bind(back, false))
	front.draw.connect(_draw_motes.bind(front, true))
	surface.draw.connect(_draw_surface)
	if kind == "water":
		var shader_material := ShaderMaterial.new()
		shader_material.shader = load(BASE + "water_r02.gdshader")
		surface.material = shader_material
	if kind == "electric_spark":
		lightning = R01.new()
		add_child(lightning)
		lightning.configure("electric_spark")

func set_paths(points: PackedVector2Array, echo_points: PackedVector2Array) -> void:
	lightning.set_paths(points, echo_points)

func set_time(t: float) -> void:
	elapsed = maxf(t, 0.0)
	if kind == "water": surface.material.set_shader_parameter("effect_time", elapsed)
	if lightning != null: lightning.set_time(elapsed)
	for node in [back, surface, front]: node.queue_redraw()

func _draw_surface() -> void:
	if kind == "water": surface.draw_rect(Rect2(-100, -75, 200, 150), Color.WHITE)
	elif kind == "black_hole":
		# Production palette and shader. Only the sphere radius changes to 80%.
		BLOCK_VFX.paint(surface, 2, Rect2(-90, -90, 180, 180), 90, elapsed * PI if steady else elapsed, 0.4 if steady else elapsed / 0.85, 2)
		surface.material.set_shader_parameter("sphere_radius", 31.5 * 0.8)

func _mote_at(age: float, life: float, angle0: float, distance0: float, crosses: bool) -> Vector2:
	var q := pow(clampf(age / life, 0.0, 1.0), 1.6)
	var terminal := 2.0 if crosses else 26.2
	var distance := terminal + (distance0 - terminal) * (1.0 - q)
	var angle := angle0 + 0.9 * q
	return Vector2(cos(angle) * distance, sin(angle) * distance * PROJECTION - 19.8)

func _draw_motes(canvas: Node2D, is_front: bool) -> void:
	if kind != "black_hole": return
	var t := floorf(elapsed * 18.0) / 18.0
	var u := 0.4 if steady else elapsed / 0.85
	var fade := minf(1.0, u * 9.0) * (1.0 - smoothstep(0.78, 1.0, u))
	for i in 22:
		var life := 0.48 + float(posmod(i * 13, 9)) * 0.035
		# Only the extended-duration hold uses periods that divide the 2s loop.
		if steady: life = 2.0 / (3.0 if i % 2 == 0 else 4.0)
		var age := fposmod(t + float(i) * 0.117, life)
		# A minority takes the foreground lane and crosses the visible sphere.
		var crosses := i % 5 == 1
		var angle0 := float(i) * 2.399963 + 0.4
		var start_radius := 86.0 + float(posmod(i * 17, 21))
		var head := _mote_at(age, life, angle0, start_radius, crosses)
		var foreground := crosses or head.y > -19.8
		if foreground != is_front: continue
		var body_distance := (head - Vector2(0, -19.8)).length()
		if body_distance < 26.2 and not crosses: continue
		var tail := _mote_at(maxf(0.0, age - 0.085), life, angle0, start_radius, crosses)
		var middle := tail.lerp(head, 0.62)
		var alpha := fade * minf(1.0, age * 9.0)
		if crosses: alpha *= 1.0 - smoothstep(0.91, 1.0, age / life)
		PIXEL.line(canvas, tail, middle, Color(0.25, 0.19, 0.35, alpha * 0.75), 2)
		PIXEL.line(canvas, middle, head, Color(0.54, 0.45, 0.67, alpha), 2)
		if i % 3 == 0 or crosses: PIXEL.block(canvas, head, Vector2(2, 2), Color(0.77, 0.71, 0.85, alpha))
