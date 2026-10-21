extends Node2D
# Frozen pre-optimization visual formulas; draw calls replaced by capture only.
const DOMAIN := Vector2(220,145)
var domain_layer: Node2D
var elapsed := 0.0
var boundary_particles: Array[Dictionary] = []
var outer_particles: Array[Dictionary] = []
var captured_vertices := PackedVector2Array()
var captured_colors := PackedColorArray()

func _initialize_domain_particles() -> void:
	# Cache visual randomness independently of combat targeting; never reroll per frame.
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.seed = 250926
	boundary_particles.clear()
	outer_particles.clear()
	for index in 48:
		var angle := TAU * (index + 0.5) / 48.0
		var tangent_length := Vector2(-sin(angle) * DOMAIN.x, cos(angle) * DOMAIN.y).length()
		var group_offset := visual_rng.randf_range(-4.0, 4.0)
		for part in 3:
			boundary_particles.append({
				"angle": angle + ((part - 1) * 5.0 + group_offset + visual_rng.randf_range(-1.5, 1.5)) / tangent_length,
				"tangent_length": tangent_length,
				"radial_offset": visual_rng.randf_range(-0.6, 0.6),
				"phase": visual_rng.randf_range(0.0, TAU),
				"speed": visual_rng.randf_range(0.6, 0.95),
				"rotation": visual_rng.randf_range(-PI / 4.0, PI / 4.0)})
	for index in 24:
		outer_particles.append({"angle": TAU * index / 24.0 + visual_rng.randf_range(-0.03, 0.03),
			"phase": visual_rng.randf_range(0.0, TAU), "speed": visual_rng.randf_range(0.6, 0.95),
			"rotation": visual_rng.randf_range(-PI / 4.0, PI / 4.0)})


func _draw_domain_square(point: Vector2, size: float, color: Color, _rotation_angle: float) -> void:
	# The domain scales with range; rebuild each square in world pixels first.
	var world := domain_layer.global_transform
	var center := (world*point).round()
	var side := maxf(2.0,roundf(size*maxf(world.x.length(),world.y.length())))
	var top_left := (center-Vector2.ONE*side*0.5).round()
	var corners := PackedVector2Array()
	for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		corners.append(world.affine_inverse()*(top_left+offset*side))
	captured_vertices.append_array(corners)
	for i in 4: captured_colors.append(color)


func _draw_domain() -> void:
	# Preserve particle count while gaps visibly expand and contract along the ellipse.
	for particle in boundary_particles:
		var motion := elapsed * float(particle.speed) + float(particle.phase)
		var angle := float(particle.angle) + sin(motion) * 4.0 / float(particle.tangent_length)
		var radius_offset := float(particle.radial_offset) + sin(motion * 0.8) * 0.35
		var point := Vector2(cos(angle), sin(angle)) * (DOMAIN + Vector2.ONE * radius_offset)
		var pulse := 0.5 + 0.5 * sin(elapsed * 2.8 + float(particle.phase))
		var rotation_angle := float(particle.rotation) + sin(motion * 0.85) * deg_to_rad(8.0)
		_draw_domain_square(point, 2.0, Color(0.62, 0.85, 0.98, 0.50 + pulse * 0.28), rotation_angle)
	# Sparse companions retain their slow drift, each with its own phase and angle.
	for particle in outer_particles:
		var motion := elapsed * float(particle.speed) + float(particle.phase)
		var angle := float(particle.angle) + elapsed * 0.045 + sin(motion) * 0.022
		var pulse := 0.5 + 0.5 * sin(elapsed * 2.0 + float(particle.phase))
		var point := Vector2(cos(angle), sin(angle)) * (DOMAIN + Vector2.ONE * (4.0 + pulse * 3.0))
		var rotation_angle := float(particle.rotation) + sin(motion * 0.85) * deg_to_rad(8.0)
		_draw_domain_square(point, 1.0, Color(0.67, 0.86, 0.97, 0.20 + pulse * 0.30), rotation_angle)
	# One centered glyph slowly breathes from almost invisible to 20% opacity.
	# The PNG itself has max alpha 51/255; modulation remains within [0.08, 1].

