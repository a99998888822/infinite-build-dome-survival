extends CavernMeadowBackdrop
class_name CavernPopulationBackdrop
## Approved cavern population, terrain-matched grass and base-sorted props.
const LANDMARK_STEP := Vector2(1850,1100)
# Large, changing grass draws can crash Godot's ANGLE/D3D11 renderer.
# Keep each draw bounded while preserving the complete logical depth band.
const MAX_GRASS_BATCH_INSTANCES := 128
const GRASS_SHADER = preload("res://shaders/battle/cavern_grass_batch.gdshader")
const OCCLUSION_SHADER = preload("res://shaders/battle/cavern_player_occlusion.gdshader")
const ENEMY_OCCLUSION = preload("res://scripts/battle/cavern_enemy_occlusion.gd")
# Zero requests a fresh per-battle seed; explicit seeds reproduce review layouts.
@export var population_seed: int = 0
var grass_atlas: ImageTexture
var grass_bottoms: Array[float] = []
var grass_material: ShaderMaterial
var grass_cells: Dictionary = {}
var peak_cells := 0
var profile_enabled := false
var update_profile: Array[Dictionary] = []
var occluding_rocks: Array[Sprite2D] = []
var shadow_enabled := true
var shadow_active_count := 0
var enemy_shadow_active_count := 0
var scenery_bounds: Dictionary = {}
var _bounds_to_warm: Array[String] = []

func _init() -> void:
	scenery_config_path = "res://data_config/cavern_meadow_battlefield.json"

func _stream_margin() -> float:
	# Cover a 320 px dash while the next grass strip is being built.
	return 400.0

func _setup() -> void:
	if initialized or not is_instance_valid(player) or not is_inside_tree(): return
	if population_seed == 0:
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		population_seed = maxi(1, seed_rng.randi())
	# Build a tiny runtime atlas from the accepted, unmodified grass sprites.
	var sheet := Image.create(128,32,false,Image.FORMAT_RGBA8)
	var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scenery_config_path))
	for index in rows.grass.size():
		var texture: Texture2D = load(rows.grass[index].texture)
		var source := texture.get_image()
		if source.is_compressed(): source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		grass_bottoms.append(float(source.get_used_rect().end.y))
		sheet.blit_rect(source,Rect2i(0,0,32,32),Vector2i(index*32,0))
	grass_atlas = ImageTexture.create_from_image(sheet)
	grass_material = ShaderMaterial.new()
	grass_material.shader = GRASS_SHADER
	super._setup()
	for group in [config.props, config.rubble, config.grass]:
		for row: Dictionary in group: _bounds_to_warm.append(row.texture)

func _stream_prewarm_ready() -> bool:
	return _bounds_to_warm.is_empty()

func _step_stream_prewarm() -> void:
	_scenery_bounds(_bounds_to_warm.pop_back())

func landmark(key: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*83492791 ^ key.y*297121507 ^ population_seed ^ 20261013)
	# One obstacle per broad region, with enough margin between adjacent regions.
	var point := Vector2(key)*LANDMARK_STEP+Vector2(rng.randf_range(-660,660),rng.randf_range(-380,380))
	if point.length()<260.0:
		point = (point.normalized() if not point.is_zero_approx() else Vector2.RIGHT)*260.0
	return _placement("prop",rng.randi_range(0,config.props.size()-1),point,2.0,rng.randf()<.5)

func _nearby_landmarks(point: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var block := Vector2i((point/LANDMARK_STEP).floor())
	for y in range(block.y-1,block.y+2):
		for x in range(block.x-1,block.x+2): result.append(landmark(Vector2i(x,y)))
	return result

func _clear_of_large(point: Vector2, nearby: Array[Dictionary], margin: float) -> bool:
	for entry: Dictionary in nearby:
		var d: Vector2 = point-entry.point
		if absf(d.x)<76+margin and d.y>-120-margin and d.y<20+margin: return false
	return true

func _solid_plan(key: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*73856093 ^ key.y*19349663 ^ population_seed ^ 14102026)
	var origin := Vector2(key)*CELL
	var plan: Array[Dictionary] = []
	var nearby := _nearby_landmarks(origin+CELL*.5)
	for entry: Dictionary in nearby:
		if Vector2i((entry.point/CELL).floor())==key: plan.append(entry)
	# At most two small objects per cell. Choose distinct jitter slots so gaps
	# also hold across streamed cell borders, independent of loading order.
	var slots: Array[int] = [0,1,2,3,4,5,6,7]
	var previous_index := -1
	for attempt in rng.randi_range(0,2):
		var slot: int = slots.pop_at(rng.randi_range(0,slots.size()-1))
		var point := origin+Vector2((slot%4+.5)*CELL.x/4,((slot/4)+.5)*CELL.y/2)
		point += Vector2(rng.randf_range(-38,38),rng.randf_range(-34,34))
		if not _clear_of_large(point,nearby,12): continue
		var index := rng.randi_range(0,config.rubble.size()-1)
		if index==previous_index: index = (index+rng.randi_range(1,config.rubble.size()-1))%config.rubble.size()
		previous_index = index
		var factor := 1.45 if index<2 else rng.randf_range(.85,1.16)
		plan.append(_placement("rubble",index,point,factor,rng.randf()<.5))
	return {"entries":plan,"rng":rng,"nearby":nearby}

func _plan_cell(key: Vector2i) -> Array[Dictionary]:
	# Synchronous callers and streamed cells share the same RNG sequence.
	var state := _begin_plan(key)
	while not _step_plan(state): pass
	return state.plan

func _begin_plan(key: Vector2i) -> Dictionary:
	var solids := _solid_plan(key)
	return {"key":key,"plan":solids.entries.duplicate(),"solids":solids.entries,
		"rng":solids.rng,"nearby":solids.nearby,"points":[],"patch":0,"companion":0}

func _step_plan(state: Dictionary) -> bool:
	if state.patch < 50:
		_plan_grass_patch(state, int(state.patch)/10, int(state.patch)%10)
		state.patch += 1
		return false
	if state.companion < state.solids.size():
		_plan_companion(state, state.solids[state.companion])
		state.companion += 1
		return false
	return true

func _plan_grass_patch(state: Dictionary, row: int, col: int) -> void:
	var origin := Vector2(state.key)*CELL
	var rng: RandomNumberGenerator = state.rng
	var plan: Array[Dictionary] = state.plan
	var nearby: Array[Dictionary] = state.nearby
	var grass_points: Array = state.points
	var center := origin+Vector2((col+.5)*53,(row+.5)*49)
	var best := -1.0
	for attempt in 4:
		var candidate := origin+Vector2((col+.5)*53,(row+.5)*49)+Vector2(rng.randf_range(-19,19),rng.randf_range(-16,16))
		var score := sample_surface(candidate).a
		if score>best:
			best = score
			center = candidate
	if best<.36: return
	for blade in rng.randi_range(3,6):
		var point := center+Vector2(rng.randf_range(-22,22),rng.randf_range(-13,13))
		point = point.clamp(origin+Vector2(8,8),origin+CELL-Vector2(8,8)).round()
		var surface := sample_surface(point)
		if surface.a<.30: continue
		var on_base := false
		for other: Dictionary in nearby:
			var d: Vector2 = point-other.point
			if absf(d.x)<68 and d.y>-24 and d.y<5: on_base = true
		if on_base: continue
		var clear := true
		for previous: Vector2 in grass_points:
			if point.distance_squared_to(previous)<100: clear = false; break
		if not clear: continue
		for entry: Dictionary in plan:
			if entry.kind=="rubble" and point.distance_to(entry.point)<28: clear = false; break
		if not clear: continue
		grass_points.append(point)
		var index := rng.randi_range(0,2) if surface.a>.52 else (3 if rng.randf()<.25 else 0)
		var entry := _placement("grass",index,point,rng.randf_range(.95,1.25),rng.randf()<.5)
		entry.tint = Color(.74,.80,.77) if index!=3 else Color(.76,.79,.73)
		entry.suitability = surface.a
		plan.append(entry)

func _plan_companion(state: Dictionary, solid: Dictionary) -> void:
	var rng: RandomNumberGenerator = state.rng
	var plan: Array[Dictionary] = state.plan
	var row: Dictionary = config.props[solid.index] if solid.kind=="prop" else config.rubble[solid.index]
	var bounds := _scenery_bounds(row.texture)
	var factor := float(solid.scale)/float(row.get("texture_density",1.0))
	var anchor: Vector2 = solid.anchor
	var width := bounds.size.x*factor
	var center_x := (bounds.get_center().x-anchor.x)*factor
	if solid.flip: center_x = -center_x
	var bottom := (bounds.end.y-anchor.y)*factor
	var count := clampi(ceili(width/24.0),2,6)
	var tuft_height := clampf(bounds.size.y*factor*.42,10.0,22.0)
	for i in count:
		var across := (float(i)+rng.randf_range(.15,.85))/float(count)-.5
		# Stay just in front of the host's depth boundary, even for padded art.
		var offset_y := maxf(1.0,bottom+rng.randf_range(1,3))
		var point: Vector2 = solid.point+Vector2(center_x+across*width*.94,offset_y)
		var surface := sample_surface(point)
		var index := rng.randi_range(0,1) if surface.a>=.30 else 3
		var grass_height := _scenery_bounds(config.grass[index].texture).size.y
		var scale := tuft_height/grass_height*rng.randf_range(.9,1.1)
		var entry := _placement("grass",index,point,scale,rng.randf()<.5)
		entry.tint = Color(.74,.80,.77) if index!=3 else Color(.76,.79,.73)
		entry.suitability = surface.a
		entry.companion = true
		entry.host_point = solid.point
		plan.append(entry)

func _scenery_bounds(path: String) -> Rect2:
	# Read alpha bounds once per texture, never during per-frame updates.
	if not scenery_bounds.has(path):
		var source := (load(path) as Texture2D).get_image()
		if source.is_compressed(): source.decompress()
		scenery_bounds[path] = Rect2(source.get_used_rect())
	return scenery_bounds[path]

func _grass_depth_bands(blades: Array[Dictionary], key: Vector2i) -> Array:
	var cuts: Array[float] = []
	var origin := Vector2(key)*CELL
	for y in range(key.y-1,key.y+2):
		for x in range(key.x-1,key.x+2):
			for solid: Dictionary in _solid_plan(Vector2i(x,y)).entries:
				if solid.point.x<origin.x-100 or solid.point.x>origin.x+CELL.x+100: continue
				if solid.point.y>blades[0].sort_y and solid.point.y<blades.back().sort_y:
					cuts.append(solid.point.y)
	cuts.sort()
	var groups: Array = []
	var band: Array[Dictionary] = []
	var cut := 0
	for blade: Dictionary in blades:
		while cut<cuts.size() and blade.sort_y>=cuts[cut]:
			if not band.is_empty(): groups.append(band); band = []
			cut += 1
		band.append(blade)
	if not band.is_empty(): groups.append(band)
	return groups

func _make_cell(key: Vector2i) -> void:
	var job := _begin_cell_job(key)
	while not _step_cell_job(job): pass

func _allows_solid(_entry: Dictionary) -> bool:
	return true

func _begin_cell_job(key: Vector2i) -> Dictionary:
	var nodes: Array[Node] = []
	cells[key] = nodes
	var state := _begin_plan(key)
	# Publish collision and its complete visual before a player can enter.
	for entry: Dictionary in state.solids:
		if _allows_solid(entry): _make_solid(entry, nodes)
	peak_cells = maxi(peak_cells,cells.size())
	return {"key":key,"state":state,"phase":0,"groups":[],"group":0,"offset":0}

func _step_cell_job(job: Dictionary) -> bool:
	var key: Vector2i = job.key
	if job.phase == 0:
		if not _step_plan(job.state): return false
		job.phase = 1
		return false
	if job.phase == 1:
		var blades: Array[Dictionary] = []
		for entry: Dictionary in job.state.plan:
			if entry.kind != "grass": continue
			entry.sort_y = entry.point.y+(grass_bottoms[entry.index]-entry.anchor.y)*float(entry.scale)
			blades.append(entry)
		if blades.is_empty(): return true
		blades.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.sort_y<b.sort_y)
		job.groups = _grass_depth_bands(blades,key)
		grass_cells[key] = {"blades":blades,"bands":[]}
		job.erase("state")
		job.phase = 2
		return false
	# One bounded draw pair is the largest indivisible grass construction step.
	var band: Array[Dictionary] = job.groups[job.group]
	var offset := int(job.offset)
	var end := mini(offset+MAX_GRASS_BATCH_INSTANCES,band.size())
	var back := _grass_batch(band.slice(offset,end),key,false)
	var front := _grass_batch(band.slice(band.size()-end,band.size()-offset),key,true)
	cells[key].append_array([back.get_parent(),front.get_parent()])
	grass_cells[key].bands.append({"blades":band,"offset":offset,"back":back,"front":front,"origin":Vector2(key)*CELL})
	job.offset = end
	if end == band.size():
		job.group += 1
		job.offset = 0
	return job.group == job.groups.size()

func _decorate_solid(_sprite: Sprite2D, _nodes: Array[Node]) -> void:
	pass

func _retire_cell(key: Vector2i) -> void:
	for node: Node in cells[key]:
		if node is Sprite2D: occluding_rocks.erase(node)
	grass_cells.erase(key)
	super._retire_cell(key)

func _make_solid(entry: Dictionary, nodes: Array[Node]) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = prop_textures[entry.index] if entry.kind=="prop" else rubble_textures[entry.index]
	sprite.position = entry.point
	sprite.scale = Vector2.ONE*float(entry.scale)
	if entry.kind=="rubble": sprite.scale /= float(config.rubble[entry.index].get("texture_density",1.0))
	sprite.flip_h = entry.flip
	var anchor: Vector2 = entry.anchor
	if sprite.flip_h: anchor.x = sprite.texture.get_width()-anchor.x
	sprite.offset = sprite.texture.get_size()*.5-anchor
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = decoration_material
	sprite.set_meta("scenery",entry)
	roots.add_child(sprite)
	nodes.append(sprite)
	if entry.kind=="prop":
		# Obstacles block movement at their ground footprint.
		var body := BattleTerrainObstacle.new()
		body.collision_layer = 6
		body.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		var polygon := PackedVector2Array()
		var radius := Vector2(31,12) if entry.index==0 else Vector2(28,5)
		for i in 12:
			polygon.append(Vector2(cos(i*TAU/12),sin(i*TAU/12))*radius+Vector2(0,-6))
		shape.polygon = polygon
		body.add_child(shape)
		sprite.add_child(body)
		if entry.index==0:
			var occlusion_material := ShaderMaterial.new()
			occlusion_material.shader = OCCLUSION_SHADER
			sprite.material = occlusion_material
			occluding_rocks.append(sprite)
	_decorate_solid(sprite, nodes)

func _grass_batch(blades: Array[Dictionary], key: Vector2i, reverse: bool) -> MultiMeshInstance2D:
	var node := MultiMeshInstance2D.new()
	node.position = Vector2(key)*CELL
	node.texture = grass_atlas
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.material = grass_material
	# Each band lies between prop bases. Its two prefixes also sort correctly
	# around the moving player, without placing all grass above every object.
	var anchor := Node2D.new()
	anchor.set_meta("scenery",{"kind":"grass_batch","count":blades.size(),"reverse":reverse})
	roots.add_child(anchor)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(32,32)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_2D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = blades.size()
	# Prefix visibility can leave the renderer's cached bounds empty/stale.
	# Geometry is static: bound all instances once, including shader wind sway.
	var quad_bounds := Rect2(-mesh.size*.5,mesh.size).grow(2.0)
	var bounds := Rect2()
	for i in blades.size():
		var entry := blades[blades.size()-1-i if reverse else i]
		var factor := float(entry.scale)
		var scale_xy := Vector2(-factor if entry.flip else factor,factor)
		var center: Vector2 = entry.point-node.position+(Vector2(16,16)-entry.anchor)*scale_xy
		var transform := Transform2D(0.0,scale_xy,0.0,center)
		multi.set_instance_transform_2d(i,transform)
		var instance_bounds := transform*quad_bounds
		bounds = instance_bounds if i==0 else bounds.merge(instance_bounds)
		multi.set_instance_color(i,entry.tint)
		multi.set_instance_custom_data(i,Color(float(entry.index),0,0,0))
	multi.custom_aabb = AABB(Vector3(bounds.position.x,bounds.position.y,-1),Vector3(bounds.size.x,bounds.size.y,2))
	node.multimesh = multi
	node.set_meta("scenery",{"kind":"grass_batch","count":blades.size(),"reverse":reverse})
	anchor.add_child(node)
	return node

func _update_area() -> void:
	var started := Time.get_ticks_usec()
	var previous_rect := cell_rect
	super._update_area()
	for key in grass_cells.keys():
		if not cells.has(key): grass_cells.erase(key); continue
		var group: Dictionary = grass_cells[key]
		for band: Dictionary in group.bands:
			# Most prefetched bands remain entirely in front of or behind the
			# player. Reuse their split until the foot crosses either neighbor.
			var previous_split := int(band.get("split",-1))
			if previous_split>=0 and (previous_split==0 or band.blades[previous_split-1].sort_y<=proxy.global_position.y) and (previous_split==band.blades.size() or band.blades[previous_split].sort_y>proxy.global_position.y):
				continue
			# Binary search changes visibility and sort anchors, never buffers.
			var low := 0
			var high: int = band.blades.size()
			while low<high:
				var mid := (low+high)/2
				if band.blades[mid].sort_y<=proxy.global_position.y: low = mid+1
				else: high = mid
			if low==band.get("split",-1): continue
			band.split = low
			var offset := int(band.get("offset",0))
			band.back.multimesh.visible_instance_count = clampi(low-offset,0,band.back.multimesh.instance_count)
			band.front.multimesh.visible_instance_count = clampi(band.blades.size()-low-offset,0,band.front.multimesh.instance_count)
			# Pixel-snapped transforms can erase a .001 separation. Whole-pixel
			# anchors preserve the ordering, including grass level with the feet.
			# All chunks retain their original band's anchor and painter order.
			var back_y := floorf(band.blades[maxi(0,low-1)].sort_y)-1.0
			var front_y := ceilf(band.blades[mini(low,band.blades.size()-1)].sort_y)+1.0
			for item: Array in [[band.back,back_y],[band.front,front_y]]:
				var batch: MultiMeshInstance2D = item[0]
				var anchor := batch.get_parent() as Node2D
				anchor.position.y = item[1]
				batch.position = band.origin-anchor.position
	if grass_material!=null:
		grass_material.set_shader_parameter("view_size",horizon.view_size)
		grass_material.set_shader_parameter("fade_start",horizon.far_height()*.62)
		grass_material.set_shader_parameter("fade_end",horizon.ground_fade_end())
	_update_player_shadow()
	if profile_enabled:
		update_profile.append({"microseconds":Time.get_ticks_usec()-started,"streamed":previous_rect!=cell_rect or last_stream_steps>0,"stream_usec":last_stream_usec,"pending":_pending_cells.size()})

func _update_player_shadow() -> void:
	shadow_active_count = 0
	var source := player.sprite
	var player_rect := source.get_rect()
	var inverse := source.global_transform.affine_inverse()
	var row_x := Vector3(inverse.x.x,inverse.y.x,inverse.origin.x-player_rect.position.x)/player_rect.size.x
	var row_y := Vector3(inverse.x.y,inverse.y.y,inverse.origin.y-player_rect.position.y)/player_rect.size.y
	if source.flip_h: row_x = -row_x+Vector3(0,0,1)
	if source.flip_v: row_y = -row_y+Vector3(0,0,1)
	var hero_area: Rect2 = source.global_transform*player_rect
	for i in range(occluding_rocks.size()-1,-1,-1):
		var rock := occluding_rocks[i]
		if not is_instance_valid(rock) or rock.is_queued_for_deletion():
			occluding_rocks.remove_at(i)
			continue
		var material := rock.material as ShaderMaterial
		var rock_area: Rect2 = rock.global_transform*rock.get_rect()
		var active := shadow_enabled and player.alive and source.is_visible_in_tree() and proxy.global_position.y<rock.global_position.y and hero_area.intersects(rock_area)
		material.set_shader_parameter("shadow_strength",1.0 if active else 0.0)
		material.set_shader_parameter("view_size",horizon.view_size)
		material.set_shader_parameter("fade_start",horizon.far_height()*.62)
		material.set_shader_parameter("fade_end",horizon.ground_fade_end())
		if not active: continue
		shadow_active_count += 1
		material.set_shader_parameter("player_texture",source.texture)
		material.set_shader_parameter("player_uv_x",row_x)
		material.set_shader_parameter("player_uv_y",row_y)
		material.set_shader_parameter("player_frame_origin",Vector2(source.frame_coords)/Vector2(source.hframes,source.vframes))
		material.set_shader_parameter("player_frame_size",Vector2.ONE/Vector2(source.hframes,source.vframes))
		material.set_shader_parameter("player_pixel",Vector2.ONE/player_rect.size)
	enemy_shadow_active_count = ENEMY_OCCLUSION.update(occluding_rocks, shadow_enabled, horizon)

func population_stats() -> Dictionary:
	var area: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport_rect()
	var stats := {"cells":cells.size(),"grass_loaded":0,"grass_visible":0,"small_visible":0,
		"large_visible":[],"grass_batch_nodes":0,"scenery_nodes":0,"minimum_suitability":1.0,"companion_grass":0}
	for group: Dictionary in grass_cells.values():
		stats.grass_batch_nodes += group.bands.size()*2
		stats.grass_loaded += group.blades.size()
		for entry: Dictionary in group.blades:
			if entry.index!=3: stats.minimum_suitability = minf(stats.minimum_suitability,entry.suitability)
			if entry.get("companion",false): stats.companion_grass += 1
			var screen: Vector2 = world_to_ui*entry.point
			if area.has_point(entry.point) and screen.y>horizon.reveal_at(screen.x): stats.grass_visible += 1
	for nodes: Array in cells.values():
		stats.scenery_nodes += nodes.size()
		for node: Node in nodes:
			var entry: Dictionary = node.get_meta("scenery")
			if entry.kind=="grass_batch": continue
			if not area.has_point(entry.point): continue
			if entry.kind=="prop": stats.large_visible.append(entry.index)
			else:
				var screen: Vector2 = world_to_ui*entry.point
				if screen.y>horizon.reveal_at(screen.x): stats.small_visible += 1
	return stats

func get_darkness_entry_direction(world_point: Vector2) -> Vector2:
	if not initialized: return Vector2.ZERO
	var point := world_to_ui*world_point
	# Enemies must approach the local curved edge, not the old horizontal band.
	var threshold: float = horizon.reveal_at(point.x)+16.0
	if point.y>=threshold: return Vector2.ZERO
	var target := world_to_ui.affine_inverse()*Vector2(point.x,threshold+8.0)
	return world_point.direction_to(target)
