extends Node2D
## Offline R01 lightning source, with no gameplay hooks.
## The inward-mote trajectory is adapted from pixelfx shadow/black-hole,
## MIT, Patch; Sprite Fusion black-hole, MIT, Copyright (c) 2026 Hugo Duprez.
## Ballistic spark head/tail/cooling adapts pixelfx lightning/lightning-strike
## and Sprite Fusion lightning (MIT, Copyright (c) 2026 Hugo Duprez).
const BASE := "res://scripts/tools/spell_vfx_sources/"
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const GROUND_BOLT = preload("res://scripts/effects/ground_lightning_bolt.gd")
const PIXEL_BOLT = preload("res://scripts/effects/lightning_pixel_bolt.gd")
const PROJECTION := 145.0 / 220.0
const WATER_AXES := Vector2(75.3984, 49.762944)
var kind := "electric_spark"
var elapsed := 0.0
var radius := 90.0
var variant := "balanced"
var surface: Node2D
var back: Node2D
var front: Node2D
var primary: Node2D
var echo: Node2D
var extra_forks: Array[Node2D] = []
var second_forks: Array[Node2D] = []

func configure(effect_kind: String, style := "balanced") -> void:
	kind = effect_kind
	variant = style
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back = Node2D.new()
	surface = Node2D.new()
	front = Node2D.new()
	for node in [back, surface, front]: add_child(node)
	back.draw.connect(_draw_back)
	front.draw.connect(_draw_front)

func set_time(t: float) -> void:
	elapsed = maxf(0.0, t)
	if surface.material is ShaderMaterial:
		surface.material.set_shader_parameter("effect_time", elapsed)
	if kind == "electric_spark": _sync_bolts()
	back.queue_redraw()
	front.queue_redraw()
	surface.queue_redraw()

func project(p: Vector2, elevation := 0.0) -> Vector2:
	return Vector2(p.x, p.y * PROJECTION - elevation)

func _draw_back() -> void:
	_draw_ground_arcs(back)

func _draw_front() -> void:
	_draw_sparks(front)

func set_paths(points: PackedVector2Array, echo_points: PackedVector2Array) -> void:
	for pass_index in 2:
		var bolt := GROUND_BOLT.new()
		bolt.points = points if pass_index == 0 else echo_points
		bolt.echo = pass_index == 1
		bolt.cell_size = 2 if pass_index == 0 else 1
		bolt.rim_enabled = false
		bolt.grid_origin = Vector2.ZERO
		bolt.build(true)
		add_child(bolt)
		var forks: Array[Node2D] = []
		for index in 4:
			var fraction := 0.18 + float(index) * 0.19
			var path_index := clampi(roundi((bolt.points.size() - 1) * fraction), 1, bolt.points.size() - 2)
			var start: Vector2 = bolt.points[path_index]
			var sign_side := -1.0 if index % 2 == 0 else 1.0
			var reach := 23.0 + float((index * 11) % 20)
			var fork := PIXEL_BOLT.new()
			fork.points = PackedVector2Array([start, start + Vector2(sign_side * reach * 0.30, 8), start + Vector2(sign_side * reach * 0.73, 12), start + Vector2(sign_side * reach * 0.52, 19), start + Vector2(sign_side * reach, 26)])
			fork.cell_size = 2
			fork.rim_enabled = false
			fork.modulate = Color(0.54, 0.78, 0.92, 0.85)
			fork.build(true)
			bolt.add_child(fork)
			forks.append(fork)
		if pass_index == 0:
			primary = bolt
			extra_forks = forks
		else:
			echo = bolt
			second_forks = forks
	_sync_bolts()

func _sync_bolts() -> void:
	if primary == null: return
	var age := elapsed - 0.5
	primary.visible = age >= 0.0 and age < 0.16
	echo.visible = age >= 0.20 and age < 0.36
	var alpha := LightningParticleEffect.ground_alpha_at(maxf(0.0, age))
	primary.modulate.a = alpha
	echo.modulate.a = alpha
	primary.advance_flash(maxf(0.0, age))
	echo.advance_flash(maxf(0.0, age - 0.2))
	for fork in extra_forks: fork.modulate.a = 0.85 * (1.0 - smoothstep(0.06, 0.15, age))
	for fork in second_forks: fork.modulate.a = 0.65 * (1.0 - smoothstep(0.04, 0.14, age - 0.2))

func _draw_ground_arcs(canvas: Node2D) -> void:
	var age := floorf((elapsed - 0.5) * 18.0) / 18.0
	if age < 0.0 or age > 0.42: return
	var fade := 1.0 - smoothstep(0.06, 0.42, age)
	for i in 5:
		var angle := float(i) * TAU / 5.0 + 0.1
		var r := 13.0 + age * 42.0
		var a := project(Vector2.from_angle(angle) * 4.0)
		var b := project(Vector2.from_angle(angle + 0.15) * r * 0.65)
		var c := project(Vector2.from_angle(angle - 0.13) * r)
		PIXEL.path(canvas, PackedVector2Array([a, b, c]), Color(0.48, 0.73, 0.86, fade * 0.75), 2)

func _draw_sparks(canvas: Node2D) -> void:
	var age := floorf((elapsed - 0.5) * 18.0) / 18.0
	if age < 0.0 or age > 0.55: return
	# Sparse ballistic 3D spray: ground X/Y is projected; height stays vertical.
	# Pixel particles step at 18fps and use 2--4px blocks instead of 1px hot haze.
	for i in 14:
		var life := 0.28 + float(i % 5) * 0.055
		if age > life: continue
		var angle := float(i) * 2.399963 + 0.4
		var speed := 45.0 + float(posmod(i * 23, 70))
		var lift := 65.0 + float(posmod(i * 13, 70))
		var h := maxf(0.0, lift * age - 230.0 * age * age)
		var ground := Vector2.from_angle(angle) * speed * age
		var point := project(ground, h)
		var older := maxf(0.0, age - 0.045)
		var tail := project(Vector2.from_angle(angle) * speed * older, maxf(0.0, lift * older - 230.0 * older * older))
		var k := age / life
		var color := Color(0.91, 0.94, 0.76) if k < 0.3 else Color(0.94, 0.70, 0.29) if k < 0.67 else Color(0.58, 0.31, 0.15)
		color.a = 1.0 - smoothstep(0.65, 1.0, k)
		PIXEL.line(canvas, tail, point, Color(0.54, 0.36, 0.19, color.a * 0.7), 2)
		PIXEL.block(canvas, point, Vector2(4, 2) if i % 3 == 0 else Vector2(2, 2), color)
