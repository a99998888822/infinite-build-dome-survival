extends CavernBattleBackdrop
class_name CavernMeadowBackdrop
## Configured grassland surface inside the approved cavern depth layers.
const SURFACE_SHADER = preload("res://shaders/battle/meadow/pit_ground.gdshader")
var surface_context: Image
var sample_offset := Vector2(1320,1120)

func _stream_margin() -> float:
	# A continuous surface needs only the maximum prop/grass overhang loaded.
	return 180.0

func _setup() -> void:
	if initialized or not is_instance_valid(player) or not is_inside_tree(): return
	var surface_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scenery_config_path))
	var surface := load(str(surface_config.surface_texture)) as Texture2D
	surface_context = (load(str(surface_config.surface_context)) as Texture2D).get_image()
	if surface_context.is_compressed(): surface_context.decompress()
	super._setup()
	ground_material.shader = SURFACE_SHADER
	ground_material.set_shader_parameter("surface_texture",surface)
	ground_material.set_shader_parameter("sample_offset",sample_offset)
	ground_material.set_shader_parameter("projection_y",AttackFootprint.ELLIPSE_RATIO)

func sample_surface(point: Vector2) -> Color:
	var pixel := Vector2(point.x,point.y/AttackFootprint.ELLIPSE_RATIO)+sample_offset
	return surface_context.get_pixel(posmod(floori(pixel.x/8.0),surface_context.get_width()),
		posmod(floori(pixel.y/8.0),surface_context.get_height()))

func _placement(kind: String, index: int, point: Vector2, factor: float, flip := false) -> Dictionary:
	var group: Array = config.grass if kind=="grass" else (config.rubble if kind=="rubble" else config.props)
	var row: Dictionary = group[index]
	return {"kind":kind,"index":index,"point":point.round(),"scale":factor,"flip":flip,
		"anchor":Vector2(row.anchor[0],row.anchor[1]),"source_id":row.id}

func _plan_cell(key: Vector2i) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*73856093 ^ key.y*19349663 ^ 15102026)
	var origin := Vector2(key)*CELL
	var plan: Array[Dictionary] = []
	var solid_roots: Array[Vector2] = []
	# Two permanent world landmarks frame the starting clearing, rather than
	# following the camera. Their anchors also reserve space in adjacent cells.
	for group: Dictionary in config.initial_groups:
		var point := Vector2(group.point[0],group.point[1])
		solid_roots.append(point)
		if Vector2i((point/CELL).floor())==key:
			plan.append(_placement("prop",group.prop_index,point,2.0))
			plan.append(_placement("rubble",group.rubble_index,point+Vector2(48,17),1.0))
	# A few readable stone silhouettes, with the starting clearing left open.
	if rng.randf()<.22 and not prop_textures.is_empty():
		var point := origin+Vector2(rng.randf_range(95,435),rng.randf_range(85,200))
		var clear := point.length()>230
		for other: Vector2 in solid_roots:
			if point.distance_to(other)<170: clear = false
		if clear:
			var index := rng.randi_range(0,prop_textures.size()-1)
			plan.append(_placement("prop",index,point,2.0))
			solid_roots.append(point)
	for attempt in 2:
		if rng.randf()>.46: continue
		var point := origin+Vector2(rng.randf_range(40,490),rng.randf_range(35,220))
		var clear := true
		for other: Vector2 in solid_roots:
			if point.distance_to(other)<105: clear = false
		if not clear: continue
		var index := posmod(key.x*3+key.y*5+attempt*2,rubble_textures.size())
		plan.append(_placement("rubble",index,point,
			2.0 if rng.randf()<.28 else 1.0,rng.randf()<.5))
		solid_roots.append(point)
	# Grass follows the original meadow's green regions, gathered into groups
	# with clear soil between them. All sampling is performed when a cell loads.
	var groups: Array[Vector2] = []
	for cluster in 7:
		var center := origin+CELL*.5
		var best := -1.0
		for attempt in 5:
			var candidate := origin+Vector2(rng.randf_range(35,495),rng.randf_range(28,217))
			var score := sample_surface(candidate).a
			for previous: Vector2 in groups:
				if candidate.distance_to(previous)<65: score -= 1.0
			if score>best:
				best = score
				center = candidate
		if best<.15: continue
		groups.append(center)
		var points: Array[Vector2] = []
		for blade in rng.randi_range(4,8):
			var point := (center+Vector2(rng.randf_range(-42,42),rng.randf_range(-21,21))).round()
			var local := sample_surface(point)
			if local.a<.22 and rng.randf()>.18: continue
			var clear := true
			for other: Vector2 in solid_roots:
				if absf(point.x-other.x)<57 and point.y>other.y-95 and point.y<other.y+12: clear = false
			for other: Vector2 in points:
				if point.distance_to(other)<13: clear = false
			if not clear: continue
			points.append(point)
			var index := 3 if rng.randf()<maxf(0.0,.7-local.a)*.40 else rng.randi_range(0,2)
			var entry := _placement("grass",index,point,2.0 if rng.randf()<.10 else 1.0,rng.randf()<.5)
			entry.tint = Color(.82,.91,.90,1.0)
			plan.append(entry)
	return plan
