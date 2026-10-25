extends "res://scripts/effects/lightning_pixel_bolt.gd"
## Ground-only accents share the bolt clock and own no damage or timers.

const PIXEL_PATH = preload("res://scripts/effects/lightning_pixel_bolt.gd")
var echo := false
var forks: Array[Node2D] = []
var impact: Node2D


func build(instanced := false) -> void:
	super.build(instanced)
	if points.size() < 3:
		return
	var length := points[0].distance_to(points[-1])
	var forward := points[0].direction_to(points[-1])
	var side := forward.orthogonal()
	# Derive accents from the existing path, without consuming gameplay RNG.
	for index in (1 if echo else 2):
		var root_index := clampi(roundi((points.size() - 1) * (0.36 if index == 0 else 0.62)), 1, points.size() - 2)
		var start := points[root_index]
		var sign_side := -1.0 if index == 0 else 1.0
		var reach := minf(length * (0.22 if index == 0 else 0.16), 40.0)
		var fork := PIXEL_PATH.new()
		fork.points = PackedVector2Array([
			start,
			(start + forward * reach * 0.34 + side * sign_side * reach * 0.35).round(),
			(start + forward * reach * 0.60 + side * sign_side * reach * 0.22).round(),
			(start + forward * reach + side * sign_side * reach * 0.70).round(),
		])
		fork.cell_size = 1
		fork.grid_origin = grid_origin
		fork.rim_enabled = false
		fork.base_alpha = base_alpha * 0.85
		fork.modulate = Color(0.46, 0.80, 1.0)
		fork.show_behind_parent = true
		fork.build(true)
		add_child(fork)
		forks.append(fork)
	if not echo:
		impact = Node2D.new()
		impact.name = "GroundLightningCore"
		impact.position = points[-1]
		CombatRenderWorld.set_world_layer(impact, CombatRenderWorld.IMPACT_Z)
		add_child(impact)
		impact.draw.connect(_draw_impact)


func advance_flash(age: float) -> void:
	for fork in forks:
		fork.modulate.a = 1.0 - smoothstep(0.035, 0.11, age)
	if is_instance_valid(impact):
		impact.modulate.a = 1.0 - smoothstep(0.025, 0.10, age)


func _draw_impact() -> void:
	var edge := Color(0.60, 0.84, 1.0, 0.72 * base_alpha)
	impact.draw_rect(Rect2(-7, -2, 14, 4), edge)
	impact.draw_rect(Rect2(-2, -7, 4, 14), edge)
	impact.draw_rect(Rect2(-3, -3, 6, 6), Color(1.0, 1.0, 1.0, base_alpha))
