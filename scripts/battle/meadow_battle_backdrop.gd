extends Node2D
class_name MeadowBattleBackdrop
## Approved streamed meadow: no per-grass scripts, physics, texture reads or manual sort per frame.
const CELL := 256.0
const GRASS_FILL_MULTIPLIER := 2.6
const GRASS_FILL_LIMIT := 210
const GROUND_SHADER = preload("res://shaders/battle/meadow/continuous_ground.gdshader")
const GRASS_SHADER = preload("res://shaders/battle/meadow/continuous_grass.gdshader")
var config: Dictionary
var context: Image
var textures: Dictionary = {}
var roots := Node2D.new()
var ground := ColorRect.new()
var ground_material := ShaderMaterial.new()
var grass_material := ShaderMaterial.new()
var shadow_texture: Texture2D
var cells: Dictionary = {}
var plans: Dictionary = {}
var stone_footprints: Dictionary = {}
var stone_cap_clearances: Dictionary = {}
var cell_rect := Rect2i()
var player: PlayerController
var proxy: Node2D
var old_visual_position: Vector2
var foot_offset := Vector2.ZERO
var generation_times: Array[float] = []
var update_times: Array[float] = []
var _preference_samples := 0
var _placed_green := 0
var _placed_total := 0
var _horizon: Node2D
var enabled := true



const FOREGROUND = preload("res://shaders/battle/meadow/foreground_decoration.gdshader")
const SURFACE = preload("res://assets/sprites/background/meadow/meadow-ground.png")
const CONTEXT = preload("res://assets/sprites/background/meadow/ground-context.png")
const SHADOW = preload("res://assets/sprites/background/meadow/root-shadow.png")
const GRASS_ATLAS = preload("res://assets/sprites/background/meadow/grass-atlas.png")
var grass_atlas: Texture2D
var grass_regions: Dictionary
var decoration_material := ShaderMaterial.new()
var _foot_texture: Texture2D
var _time := 0.0
var initialized := false
var grass_batch: Node


func _ready() -> void:
	add_to_group("battle_meadow")
	process_priority = 40
	_horizon = get_node("../../BattleSky/DistantRuins")
	set_process(false)


func set_world_context(subject: PlayerController, _wave_manager: WaveManager) -> void:
	player = subject
	# Character selection finishes after BattleRoot binds its world context.
	_setup.call_deferred()


func _process(delta: float) -> void:
	if not initialized or not enabled or not is_instance_valid(player): return
	_update_area()
	if player.alive and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)):
		_time += delta


func _refresh_player_foot() -> void:
	if _foot_texture == player._idle_texture: return
	_foot_texture = player._idle_texture
	var image := _foot_texture.get_image()
	if image.is_compressed(): image.decompress()
	var bounds := image.get_used_rect()
	foot_offset = Vector2(0,(bounds.end.y-_foot_texture.get_height()*.5+player.sprite.position.y)*absf(player.visual_anchor.scale.y)+old_visual_position.y)
	player.visual_anchor.position = old_visual_position-foot_offset


func detach_player() -> void:
	# Called before BattleRoot reparents or frees its world nodes.
	set_process(false)
	if is_instance_valid(grass_batch): grass_batch.set_process(false)
	if is_instance_valid(player) and is_instance_valid(player.visual_anchor) and player.visual_anchor.get_parent() == proxy:
		player.visual_anchor.reparent(player,false)
		player.visual_anchor.position = old_visual_position


func get_environment_time() -> float:
	return _time


func _setup() -> void:
	if initialized or not is_instance_valid(player) or not is_inside_tree(): return
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/green_battlefield.json"))
	context = CONTEXT.get_image()
	shadow_texture = SHADOW
	for id: String in config.assets: textures[id] = load(str(config.assets[id].texture))
	if context.is_compressed(): context.decompress()
	_cache_stone_footprints()
	grass_atlas = GRASS_ATLAS
	grass_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/background/meadow/grass-atlas.json"))
	decoration_material.shader = FOREGROUND
	_horizon.setup(SURFACE)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = -110
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("ground_texture",SURFACE)
	ground_material.set_shader_parameter("sample_offset",Vector2(config.sample_offset[0],config.sample_offset[1]))
	ground.material = ground_material
	add_child(ground)
	grass_material.shader = GRASS_SHADER
	roots.name = "RootDepthSort"
	roots.y_sort_enabled = true
	add_child(roots)
	proxy = Node2D.new()
	proxy.name = "PlayerFeetSortAnchor"
	roots.add_child(proxy)
	old_visual_position = player.visual_anchor.position
	player.visual_anchor.reparent(proxy,false)
	_refresh_player_foot()
	initialized = true
	set_process(true)
	_update_area()
	# Own the approved V2 renderer so it shares this battle's pause and lifetime.
	grass_batch = load("res://scripts/battle/meadow_grass_batch.gd").new()
	grass_batch.name = "GrassBatch"
	add_child(grass_batch)
	grass_batch.bind(self)
	grass_batch.set_mode("batch")


func sample_ground(point: Vector2) -> Color:
	var pixel := point+Vector2(config.sample_offset[0],config.sample_offset[1])
	return context.get_pixel(posmod(floori(pixel.x/8),context.get_width()),posmod(floori(pixel.y/8),context.get_height()))


func _cache_stone_footprints() -> void:
	for group: String in ["ruins","rubble"]:
		for id: String in config.groups[group]:
			var entry: Dictionary = config.assets[id]
			var image: Image = textures[id].get_image()
			var used := image.get_used_rect()
			# Ruins stand on their lower base; flat rubble occupies its whole surface.
			var top := maxi(used.position.y,used.end.y-10) if group == "ruins" else used.position.y
			var left := used.end.x
			var right := used.position.x
			for y in range(top,used.end.y):
				for x in range(used.position.x,used.end.x):
					if image.get_pixel(x,y).a>=.5:
						left = mini(left,x)
						right = maxi(right,x+1)
			var anchor := Vector2(entry.anchor[0],entry.anchor[1])
			var factor := float(entry.scale)
			stone_footprints[id] = Rect2((Vector2(left,top)-anchor)*factor,Vector2(right-left,used.end.y-top)*factor).grow(4)
			# Leave a readable gap at tall silhouettes: grass immediately behind a cap
			# otherwise looks planted on top, even when depth sorting is correct.
			var cap := Rect2()
			if group == "ruins" and used.size.y*factor>=64:
				var cap_left := used.end.x
				var cap_right := used.position.x
				for y in range(used.position.y,mini(used.end.y,used.position.y+8)):
					for x in range(used.position.x,used.end.x):
						if image.get_pixel(x,y).a>=.5:
							cap_left = mini(cap_left,x)
							cap_right = maxi(cap_right,x+1)
				cap = Rect2((Vector2(cap_left,used.position.y)-anchor)*factor-Vector2(18,6),Vector2((cap_right-cap_left)*factor+36,34))
			stone_cap_clearances[id] = cap


func root_hits_stone(point: Vector2, key: Vector2i) -> bool:
	# Nine small cached plans cover bases crossing a 256px cell boundary.
	for y in range(key.y-1,key.y+2):
		for x in range(key.x-1,key.x+2):
			var stone: Dictionary = _plan_cell(Vector2i(x,y)).stone
			if not stone.is_empty() and ((stone.footprint as Rect2).has_point(point) or (stone.cap_clearance as Rect2).has_point(point)): return true
	return false


func layout_signature() -> Array[String]:
	var result: Array[String] = []
	for child in roots.get_children():
		if child is Sprite2D and child.has_meta("grass_id"): result.append("%s:%s" % [child.get_meta("grass_id"),child.position])
	result.sort()
	return result


func _update_cells() -> void:
	proxy.global_position = player.global_position+foot_offset
	var area: Rect2 = (get_viewport().get_canvas_transform().affine_inverse()*get_viewport_rect()).grow(32)
	ground.position = area.position.floor()
	ground.size = area.end.ceil()-ground.position
	ground_material.set_shader_parameter("world_origin",ground.position)
	ground_material.set_shader_parameter("surface_size",ground.size)
	var ui_size := get_tree().root.get_visible_rect().size
	ground_material.set_shader_parameter("view_size",ui_size)
	ground_material.set_shader_parameter("horizon_y",BattleEnvironment.get_sky_height(ui_size.x))
	_horizon.configure_view(ui_size,player.camera_2d.get_screen_center_position().x)
	var first := Vector2i((area.position/CELL).floor())-Vector2i.ONE
	var last := Vector2i((area.end/CELL).floor())+Vector2i(2,2)
	var wanted := Rect2i(first,last-first)
	if wanted == cell_rect: return
	cell_rect = wanted
	for key in cells.keys():
		if not wanted.has_point(key):
			for node: Node in cells[key].nodes: node.queue_free()
			cells.erase(key)
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var key := Vector2i(x,y)
			if not cells.has(key): _make_cell(key)
	# Neighbour plans make placement independent of chunk load order.
	var planned_area := wanted.grow(1)
	for key in plans.keys():
		if not planned_area.has_point(key): plans.erase(key)


func _base_plan_cell(key: Vector2i) -> Dictionary:
	if plans.has(key): return plans[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*73856093 ^ key.y*19349663 ^ 622091)
	var origin := Vector2(key)*CELL
	var mean_green := 0.0
	for y in range(4):
		for x in range(4): mean_green += sample_ground(origin+Vector2(x*64+32,y*64+32)).a/16.0
	var target := clampi(roundi(4+18*mean_green),4,22)
	var points: Array[Vector2] = []
	var placements: Array[Dictionary] = []
	var anchor := Vector2.ZERO
	for attempt in range(160):
		if points.size()>=target: break
		if attempt%5 == 0:
			anchor = origin+Vector2(rng.randf_range(32,224),rng.randf_range(32,224))
		var point := (anchor+Vector2(rng.randf_range(-35,35),rng.randf_range(-23,23))).round()
		point = point.clamp(origin+Vector2(12,12),origin+Vector2(244,244))
		var local := sample_ground(point)
		_preference_samples += 1
		if rng.randf()>0.03+0.94*local.a*local.a: continue
		var close := false
		for p: Vector2 in points:
			if p.distance_squared_to(point)<170: close = true; break
		if close: continue
		var names: Array = config.groups.grass
		var id := str(names[3] if rng.randf()<(1-local.a)*0.60 else names[rng.randi_range(0,2)])
		placements.append({"id":id,"point":point,"local":local})
		points.append(point)
		_placed_total += 1
		if local.a>.5: _placed_green += 1
	var stone: Dictionary = {}
	if rng.randf()<.44:
		var group := "ruins" if rng.randf()<.13 else "rubble"
		var options: Array = config.groups[group]
		var id := str(options[rng.randi_range(0,options.size()-1)])
		var point := origin+Vector2(rng.randf_range(40,216),rng.randf_range(64,224))
		var footprint: Rect2 = stone_footprints[id]
		footprint.position += point
		var cap: Rect2 = stone_cap_clearances[id]
		cap.position += point
		stone = {"id":id,"point":point,"footprint":footprint,"cap_clearance":cap}
	plans[key] = {"grass":placements,"stone":stone}
	return plans[key]


func _dense_plan_cell(key: Vector2i) -> Dictionary:
	var plan := _base_plan_cell(key)
	if plan.get("meadow",false): return plan
	plan.meadow = true
	var original: Array = plan.grass.duplicate()
	if original.is_empty(): return plan
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*73856093 ^ key.y*19349663 ^ 388463)
	var origin := Vector2(key)*CELL
	var target := mini(80,roundi(original.size()*3.6))
	var center := Vector2.ZERO
	for attempt in range(900):
		if plan.grass.size()>=target: break
		if attempt%7 == 0:
			center = original[rng.randi_range(0,original.size()-1)].point if rng.randf()<.85 else origin+Vector2(rng.randf_range(24,232),rng.randf_range(24,232))
		var point := (center+Vector2(rng.randf_range(-35,35),rng.randf_range(-24,24))).round().clamp(origin+Vector2(6,6),origin+Vector2(250,250))
		var local := sample_ground(point)
		if rng.randf()>.02+.98*local.a*local.a: continue
		var close := false
		for entry: Dictionary in plan.grass:
			if point.distance_squared_to(entry.point)<64: close = true; break
		if close: continue
		var names: Array = config.groups.grass
		var id := str(names[3] if rng.randf()<(1-local.a)*.25 else names[rng.randi_range(0,2)])
		plan.grass.append({"id":id,"point":point,"local":local})
	return plan


func _plan_cell(key: Vector2i) -> Dictionary:
	var plan := _dense_plan_cell(key)
	if not plan.stone.is_empty() and config.groups.ruins.has(plan.stone.id):
		plan.stone = {}
	if plan.get("colour_fill", false): return plan
	plan.colour_fill = true
	var original: Array = plan.grass.duplicate()
	if original.is_empty(): return plan
	var target := mini(GRASS_FILL_LIMIT, roundi(original.size() * GRASS_FILL_MULTIPLIER))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x * 73856093 ^ key.y * 19349663 ^ 4100426)
	var origin := Vector2(key) * CELL
	# Preserve existing clusters, then fill matching patches. Spatial bins keep
	# generation bounded; all work happens once per streamed cell, not per frame.
	var bins: Dictionary = {}
	for entry: Dictionary in original:
		var bin_key := Vector2i((entry.point / 8.0).floor())
		if not bins.has(bin_key): bins[bin_key] = []
		bins[bin_key].append(entry.point)
	var center := Vector2.ZERO
	for attempt in 4200:
		if plan.grass.size() >= target: break
		if attempt % 6 == 0:
			center = original[rng.randi_range(0, original.size() - 1)].point if rng.randf() < .65 else origin + Vector2(rng.randf_range(12, 244), rng.randf_range(12, 244))
		var point := (center + Vector2(rng.randf_range(-48, 48), rng.randf_range(-34, 34))).round().clamp(origin + Vector2(6, 6), origin + Vector2(250, 250))
		var local := sample_ground(point)
		# Stronger matching for additions leaves brown/dull islands readable.
		if local.a < .40 or rng.randf() > .98 * local.a * local.a: continue
		var bin_key := Vector2i((point / 8.0).floor())
		var close := false
		for y in range(bin_key.y - 1, bin_key.y + 2):
			for x in range(bin_key.x - 1, bin_key.x + 2):
				for other: Vector2 in bins.get(Vector2i(x, y), []):
					if other.distance_squared_to(point) < 64.0: close = true; break
		if close: continue
		var names: Array = config.groups.grass
		var id := str(names[3] if rng.randf() < (1.0 - local.a) * .25 else names[rng.randi_range(0, 2)])
		plan.grass.append({"id": id, "point": point, "local": local})
		if not bins.has(bin_key): bins[bin_key] = []
		bins[bin_key].append(point)
	return plan


func _base_make_cell(key: Vector2i) -> void:
	var started := Time.get_ticks_usec()
	var plan := _plan_cell(key)
	var nodes: Array[Node] = []
	var points: Array[Vector2] = []
	for entry: Dictionary in plan.grass:
		if root_hits_stone(entry.point,key): continue
		var grass := add_grass(entry.id,entry.point,entry.local)
		nodes.append(grass)
		points.append(entry.point)
	var shadows := MultiMeshInstance2D.new()
	shadows.name = "GrassContactShadows"
	shadows.z_index = -60
	shadows.texture = shadow_texture
	var mesh := QuadMesh.new()
	mesh.size = Vector2(22,7)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_2D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = points.size()
	for i in points.size():
		multi.set_instance_transform_2d(i,Transform2D(0,points[i]+Vector2(0,-1)))
		multi.set_instance_color(i,Color(0.13,0.19,0.12,1))
	shadows.multimesh = multi
	add_child(shadows)
	nodes.append(shadows)
	if not plan.stone.is_empty():
		var id := str(plan.stone.id)
		var entry: Dictionary = config.assets[id]
		var prop := Sprite2D.new()
		prop.texture = textures[id]
		prop.centered = false
		prop.offset = -Vector2(entry.anchor[0],entry.anchor[1])
		prop.position = plan.stone.point
		prop.scale = Vector2.ONE*float(entry.scale)
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop.set_meta("meadow_stone",true)
		prop.set_meta("stone_id",id)
		# Stones share root sorting so grass behind a column cannot paint its shaft.
		roots.add_child(prop)
		nodes.append(prop)
	cells[key] = {"nodes":nodes,"grass":points.size(),"points":points}
	generation_times.append(float(Time.get_ticks_usec()-started)/1000.0)
	if generation_times.size()>256: generation_times.pop_front()


func _dense_make_cell(key: Vector2i) -> void:
	_base_make_cell(key)
	var cell: Dictionary = cells[key]
	for node: Node in cell.nodes:
		if not node is MultiMeshInstance2D: continue
		var multi: MultiMesh = node.multimesh
		for i in cell.points.size():
			var point: Vector2 = cell.points[i]
			var factor := variant_size(point)/32.0
			multi.set_instance_transform_2d(i,Transform2D(Vector2(factor,0),Vector2(0,factor),point+Vector2(0,-1)))


func _make_cell(key: Vector2i) -> void:
	_dense_make_cell(key)
	for node: Node in cells[key].nodes:
		if node is MultiMeshInstance2D or node.has_meta("meadow_stone"):
			node.material = decoration_material


func variant_size(point: Vector2) -> int:
	return 26 if posmod(roundi(point.x)*31+roundi(point.y)*17,100)<8 else 20


func add_grass(id: String, point: Vector2, local: Color) -> Sprite2D:
	var size := variant_size(point)
	var entry: Dictionary = grass_regions[id+"@"+str(size)]
	var grass := Sprite2D.new()
	grass.texture = grass_atlas
	grass.region_enabled = true
	grass.region_rect = Rect2(entry.region[0],entry.region[1],size,size)
	grass.centered = false
	grass.offset = -Vector2(entry.anchor[0],entry.anchor[1])
	grass.position = point
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.material = grass_material
	# A encodes root V in the shared 32px-high atlas; source alpha is restored.
	grass.modulate = Color(local.r,local.g,local.b,(entry.anchor[1]+2.0)/32.0)
	grass.set_meta("green_score",local.a)
	grass.set_meta("grass_id",id)
	grass.set_meta("pixel_size",size)
	roots.add_child(grass)
	return grass


func _base_visible_counts() -> Dictionary:
	var area: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport_rect()
	var grass := 0
	var green := 0
	var stone := 0
	for child in roots.get_children():
		if child is Sprite2D and child.has_meta("grass_id") and area.has_point(child.global_position):
			grass += 1
			if float(child.get_meta("green_score",0))>.5: green += 1
	for cell: Dictionary in cells.values():
		for child: Node in cell.nodes:
			if child.has_meta("meadow_stone") and area.has_point((child as Node2D).global_position): stone += 1
	return {"grass":grass,"green_roots":green,"other_props":stone,"loaded_cells":cells.size(),"loaded_sort_nodes":roots.get_child_count()}


func _grass_visible_counts() -> Dictionary:
	var result := _base_visible_counts()
	var small := 0
	var area: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport_rect()
	for child in roots.get_children():
		if child is Sprite2D and area.has_point(child.global_position) and int(child.get_meta("pixel_size",0)) == 20: small += 1
	result.small_grass = small
	return result


func visible_counts() -> Dictionary:
	var result := _grass_visible_counts()
	result.tall_props = 0
	for child in roots.get_children():
		if child.has_meta("stone_id") and config.groups.ruins.has(child.get_meta("stone_id")):
			result.tall_props += 1
	return result


func _update_area() -> void:
	_refresh_player_foot()
	_update_cells()
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_tree().root.get_visible_rect().size
	var ratio := get_viewport_rect().size/size
	var horizon := BattleEnvironment.get_sky_height(size.x)
	var parameters := {
		"view_size":size,"horizon_y":horizon,"world_screen_origin":inverse.origin,
		"world_screen_x":inverse.x*ratio.x,"world_screen_y":inverse.y*ratio.y,
		"sample_offset":Vector2(config.sample_offset[0],config.sample_offset[1])}
	for key: String in parameters: ground_material.set_shader_parameter(key,parameters[key])
	for material: ShaderMaterial in [grass_material,decoration_material]:
		material.set_shader_parameter("view_size",size)
		material.set_shader_parameter("transition_bottom",horizon+74.0)
	_horizon.set_surface_transform(parameters,player.camera_2d.get_screen_center_position())
