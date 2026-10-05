extends Node2D

## Short, render-only reaction cues. They never own damage or status timing.
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const SHAPES = preload("res://scripts/effects/reaction_pixel_shapes.gd")
const GROUP := "element_reaction_cues"
const MAX_CUES := 96
const STEAM_SCALE := 0.6
var kind := ""
var elapsed := 0.0
var duration := 0.6
var options: Dictionary = {}
var detail := 2
var _draw_frame := -1
var _conduct_cells := PackedVector2Array()


static func spawn(parent: Node, reaction: String, origin: Vector2, settings: Dictionary = {}) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if reaction in ["holy", "dark_flame", "cancel"]:
		return
	var peers := parent.get_tree().get_nodes_in_group(GROUP)
	# Merge simultaneous cues at the same location before reducing decoration.
	for peer in peers:
		if not peer.is_queued_for_deletion() and peer.kind == reaction and peer.elapsed < 0.08 and peer.global_position.distance_squared_to(origin) < 64.0 and reaction != "wet_spread":
			return
	if peers.size() >= MAX_CUES:
		return
	var effect := new()
	effect.kind = reaction
	effect.options = settings.duplicate()
	effect.duration = 1.1 if reaction in ["steam", "dark_flame", "holy"] else 0.72
	if reaction == "freeze": effect.duration = 0.62
	if reaction == "conduct": effect.duration = 1.1
	if reaction == "wet_spread": effect.duration = 0.50
	parent.add_child(effect)
	effect.global_position = origin
	effect.add_to_group(GROUP)
	effect.detail = PIXEL.register(effect, "reaction_" + reaction)
	effect.z_index = -5 if reaction in ["ice_expand", "thaw"] else 83


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed += delta
	if options.has("follow"):
		var target: Node2D = options.follow.get_ref()
		if is_instance_valid(target): global_position = target.global_position
		else: queue_free(); return
	if elapsed >= duration:
		queue_free()
	var frame := int(elapsed * 12.0)
	if kind != "conduct" or frame != _draw_frame:
		_draw_frame = frame
		queue_redraw()


func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var fade := (1.0 - smoothstep(0.5, 1.0, t)) * (0.7 if detail == 0 else 1.0)
	if kind == "conduct": fade = (1.0 - smoothstep(0.75, 1.0, t)) * (0.7 if detail == 0 else 1.0)
	match kind:
		"steam": _draw_steam(t, fade)
		"freeze": _draw_freeze(t, fade)
		"thaw": _draw_thaw(t, fade)
		"conduct": _draw_conduct(t, fade)
		"wet_spread": _draw_water_ribbon(t, fade)
		"ice_expand": _draw_frost_front(t, fade)


func _draw_steam(t: float, fade: float) -> void:
	# Faceted, uneven puffs retain the old smoke silhouette, without side streaks.
	# Scale positions and radii before pixel snapping to preserve crisp pixels.
	for index in range(3 if detail > 0 else 2):
		var age := clampf((t - index * 0.07) * 1.18, 0.0, 1.0)
		var x := (index - 1) * (14.0 + age * 14.0)
		var center := Vector2(x, -10.0 - age * (42.0 + index * 7.0)) * STEAM_SCALE
		var radius := lerpf(3.0, 19.0, age) * STEAM_SCALE
		var cloud := PackedVector2Array()
		for point in range(17):
			var angle := point * TAU / 16.0
			var lobe := 1.0 + 0.18 * sin(angle * 5.0 + index)
			cloud.append(center + Vector2(cos(angle), sin(angle) * 0.80) * radius * lobe)
		PIXEL.polygon(self, cloud, Color(0.45, 0.59, 0.59, fade * 0.48))
		PIXEL.path(self, cloud, Color(0.84, 0.91, 0.86, fade * 0.84), 2)


func _draw_freeze(t: float, fade: float) -> void:
	var reach := 14.0 + ease(t, 0.4) * 25.0
	for index in range(6 if detail > 0 else 4):
		var angle := index * TAU / 6.0
		var direction := Vector2.from_angle(angle)
		var point := direction * reach
		point.y = point.y * 0.65 + 8.0 - sin(t * PI) * 7.0
		SHAPES.shard(self, point, direction, 15.0 * (1.0 - t * 0.5), 4.0, fade)
	if t < 0.4:
		for side in [-1.0, 1.0]:
			PIXEL.line(self, Vector2(side * 10, 14), Vector2(side * 17, -16 - t * 25), Color(0.77, 0.98, 1.0, fade), 3)


func _draw_thaw(t: float, fade: float) -> void:
	for index in range(6):
		var angle := index * TAU / 6.0
		var point := Vector2.from_angle(angle) * (15.0 + t * 21.0)
		point.y = point.y * 0.4 + 12.0 - sin(t * PI) * 12.0
		SHAPES.shard(self, point, Vector2.from_angle(angle), 9.0 * (1.0 - t), 2.0, fade)
	PIXEL.arc(self, 16 + t * 21, 0, TAU, Color(0.37, 0.75, 0.88, fade * 0.7), 2, Vector2(1, 0.4))


func _draw_conduct(t: float, fade: float) -> void:
	var frame := int(elapsed * 12.0)
	_conduct_cells = _build_conduct_cells(frame)
	for cell in _conduct_cells:
		draw_rect(Rect2(cell, Vector2(3, 3)), Color(0.25, 0.72, 1.0, fade))


func _build_conduct_cells(frame: int) -> PackedVector2Array:
	# This cue uses true 3px cells; the shared helper rounds widths to 2px units.
	# A step coprime to the modulus makes the geometry change on each tick.
	var points := PackedVector2Array()
	for index in range(5):
		var jitter := float(posmod(index * 7 + frame * 3, 5) - 2) * 3.0
		points.append((Vector2(-16 + index * 8, -10 + jitter) / 3.0).round())
	var cells := PackedVector2Array()
	var used := {}
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
		for step in range(steps + 1):
			var cell := a.lerp(b, float(step) / steps).round()
			if used.has(cell): continue
			used[cell] = true
			cells.append(cell * 3.0)
	return cells


func _draw_water_ribbon(t: float, fade: float) -> void:
	var target: Vector2 = options.get("target", global_position)
	var offset := target - global_position
	var head := minf(t * 1.7, 1.0)
	var tail := maxf(head - 0.20, 0.0)
	var path := PackedVector2Array()
	for index in range(6):
		var u := lerpf(tail, head, float(index) / 5.0)
		path.append(offset * u + Vector2(0, -sin(u * PI) * 7.0))
	PIXEL.path(self, path, Color(0.28, 0.59, 0.71, fade * 0.42), 2)
	if t > 0.55:
		PIXEL.block(self, offset, Vector2(2, 2), Color(0.41, 0.70, 0.78, fade * 0.35))


func _draw_frost_front(t: float, fade: float) -> void:
	var frost = preload("res://scripts/effects/frost_pattern.gd")
	var old_radius := float(options.get("from_radius", 51.2))
	var radius := lerpf(old_radius, float(options.get("radius", 69.12)), smoothstep(0, 0.65, t))
	fade *= frost.OPACITY
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, frost.GROUND_FLATTEN))
	for index in range(10 if detail > 0 else 6):
		var angle := index * TAU / 10.0
		var axis := Vector2.from_angle(angle)
		var side := axis.orthogonal()
		var a := axis * (old_radius - 8)
		var b := axis * radius
		PIXEL.line(self, a, b, Color(0.59, 0.78, 0.93, fade), 2)
		for branch in [-1.0, 1.0]:
			PIXEL.line(self, b - axis * 5, b - axis * 12 + side * branch * 7, Color(0.59, 0.78, 0.93, fade * 0.9), 2)
		SHAPES.shard(self, b, axis, 10, 3, fade)
		PIXEL.arc(self, radius, angle + 0.05, angle + 0.40, Color(0.35, 0.58, 0.78, fade * 0.65), 3)
	draw_set_transform(Vector2.ZERO)
