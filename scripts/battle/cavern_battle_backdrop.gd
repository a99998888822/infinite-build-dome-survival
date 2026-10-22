extends Node2D
class_name CavernBattleBackdrop
## Stable, sparse world decals. Cell generation never consumes gameplay RNG.
const CELL := Vector2(530,245)
const ART_SCALE := 2.15
const PATCH_SCALE := 1.0
const GROUND_SHADER = preload("res://shaders/battle/cavern_ground.gdshader")
const DECAL_SHADER = preload("res://shaders/battle/cavern_decoration.gdshader")
@export_file("*.json") var scenery_config_path := "res://data_config/cavern_meadow_battlefield.json"
var player: PlayerController
var horizon: CavernBattleHorizon
var initialized := false
var ground: ColorRect
var ground_material: ShaderMaterial
var decoration_material: ShaderMaterial
var roots: Node2D
var decals: Node2D
var proxy: Node2D
var enemy_sort_root: Node2D
var enemy_sort_parent: Node
var old_visual_position := Vector2.ZERO
var foot_offset := Vector2.ZERO
var foot_bounds_cache: Dictionary = {}
var cells: Dictionary = {}
var cell_rect := Rect2i()
var _pending_cells: Array[Vector2i] = []
const STREAM_BUDGET_USEC := 2500
const NEAR_VIEW_BUDGET_USEC := 5000
const LOADING_BUDGET_USEC := 4000
const MAX_RETIRE_NODES := 8
const MAX_RETIRE_BACKLOG := 1024
var _cell_jobs: Dictionary = {}
var _retiring_nodes: Array[Node] = []
var last_stream_usec := 0
var last_stream_steps := 0
var _stream_urgent := false
var ground_textures: Array = []
var prop_textures: Array[Texture2D] = []
var grass_textures: Array[Texture2D] = []
var detail_textures: Array[Texture2D] = []
var rubble_textures: Array[Texture2D] = []
var ground_image: Image
var config: Dictionary
var environment_time := 0.0
var world_to_ui := Transform2D.IDENTITY

func _ready() -> void:
	add_to_group("battle_cavern")
	process_priority = 40
	horizon = get_node("../../BattleSky/DistantRuins")
	set_process(false)

func set_world_context(subject: PlayerController, wave_manager: WaveManager) -> void:
	player = subject
	if is_instance_valid(wave_manager): enemy_sort_root = wave_manager.enemy_root as Node2D
	_setup.call_deferred()

func _setup() -> void:
	if initialized or not is_instance_valid(player) or not is_inside_tree(): return
	config = JSON.parse_string(FileAccess.get_file_as_string(scenery_config_path))
	for row: Dictionary in config.ground:
		var variants: Array[Texture2D] = []
		for path: String in row.textures: variants.append(load(path))
		ground_textures.append(variants)
	for row: Dictionary in config.props: prop_textures.append(load(row.texture))
	for row: Dictionary in config.grass: grass_textures.append(load(row.texture))
	for row: Dictionary in config.details: detail_textures.append(load(row.texture))
	for row: Dictionary in config.rubble: rubble_textures.append(load(row.texture))
	if not ground_textures.is_empty():
		ground_image = (ground_textures[0][0] as Texture2D).get_image()
		if ground_image.is_compressed(): ground_image.decompress()
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = CombatRenderWorld.GROUND_Z
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	var base: Array = config.floor_color
	ground_material.set_shader_parameter("floor_color",Color(base[0],base[1],base[2],base[3]))
	ground.material = ground_material
	add_child(ground)
	decoration_material = ShaderMaterial.new()
	decoration_material.shader = DECAL_SHADER
	decals = Node2D.new()
	decals.name = "GroundFragments"
	decals.z_index = CombatRenderWorld.GROUND_DECALS_Z
	decals.y_sort_enabled = true
	add_child(decals)
	roots = Node2D.new()
	roots.name = "RootDepthSort"
	roots.y_sort_enabled = true
	add_child(roots)
	# Keep the manager's enemy container intact; sort its children with scenery.
	if is_instance_valid(enemy_sort_root):
		enemy_sort_parent = enemy_sort_root.get_parent()
		enemy_sort_root.y_sort_enabled = true
		enemy_sort_root.reparent(roots, true)
	proxy = Node2D.new()
	proxy.name = "PlayerFeetSortAnchor"
	roots.add_child(proxy)
	old_visual_position = player.visual_anchor.position
	player.visual_anchor.reparent(proxy,false)
	_refresh_player_foot()
	initialized = true
	# Subclasses finish their materials and surface data before the first stream.
	set_process(true)

func _refresh_player_foot() -> void:
	var sprite := player.sprite
	if sprite.texture == null: return
	var grid := Vector2i(sprite.hframes,sprite.vframes)
	cache_player_frame_bounds(sprite.texture, grid)
	var layouts: Dictionary = foot_bounds_cache[sprite.texture]
	var bounds: Rect2i = layouts[grid][sprite.frame]
	var rect := sprite.get_rect()
	var bottom := rect.position.y + (rect.size.y-bounds.position.y if sprite.flip_v else float(bounds.end.y))
	# Use the current animation frame and both visual transforms. Moving the
	# sort anchor must not move the rendered player, camera or collision body.
	var visual_transform := player.visual_anchor.transform
	visual_transform.origin = old_visual_position
	foot_offset = Vector2(0,(visual_transform*sprite.transform*Vector2(0,bottom)).y)
	player.visual_anchor.position = old_visual_position-foot_offset

func cache_player_frame_bounds(texture: Texture2D, grid: Vector2i) -> void:
	if not foot_bounds_cache.has(texture): foot_bounds_cache[texture] = {}
	var layouts: Dictionary = foot_bounds_cache[texture]
	if layouts.has(grid): return
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	var frame_size := image.get_size()/grid
	var frames: Array[Rect2i] = []
	for y in grid.y:
		for x in grid.x:
			frames.append(image.get_region(Rect2i(Vector2i(x,y)*frame_size,frame_size)).get_used_rect())
	layouts[grid] = frames

func is_initial_stream_ready() -> bool:
	return initialized and cell_rect.has_area() and _pending_cells.is_empty() and _stream_prewarm_ready()

func detach_player() -> void:
	set_process(false)
	_cell_jobs.clear()
	_pending_cells.clear()
	if is_instance_valid(enemy_sort_root) and is_instance_valid(enemy_sort_parent) and enemy_sort_root.get_parent() == roots:
		enemy_sort_root.reparent(enemy_sort_parent, true)
	if is_instance_valid(player) and is_instance_valid(player.visual_anchor) and player.visual_anchor.get_parent() == proxy:
		player.visual_anchor.reparent(player,false)
		player.visual_anchor.position = old_visual_position

func get_environment_time() -> float:
	return environment_time

func _process(delta: float) -> void:
	if not initialized or not is_instance_valid(player): return
	_update_area()
	if player.alive and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)):
		environment_time += delta

func _stream_margin() -> float:
	return 850.0

func _update_area() -> void:
	_refresh_player_foot()
	proxy.global_position = player.global_position+foot_offset
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	# Broad authored patches may extend well beyond their generating cell.
	var visible_area: Rect2 = inverse*get_viewport_rect()
	var area := visible_area.grow(_stream_margin())
	ground.position = area.position.floor()
	ground.size = area.end.ceil()-ground.position
	var ui_size := get_tree().root.get_visible_rect().size
	var ratio := get_viewport_rect().size/ui_size
	world_to_ui = Transform2D(inverse.x*ratio.x,inverse.y*ratio.y,inverse.origin).affine_inverse()
	horizon.configure_view(ui_size,player.camera_2d.get_screen_center_position().x,1.0/(inverse.x.length()*ratio.x))
	var fade_start := horizon.far_height()*.62
	var fade_end := horizon.ground_fade_end()
	for material: ShaderMaterial in [ground_material,decoration_material]:
		material.set_shader_parameter("view_size",ui_size)
		material.set_shader_parameter("fade_start",fade_start)
		material.set_shader_parameter("fade_end",fade_end)
	var first := Vector2i((area.position/CELL).floor())
	var last := Vector2i((area.end/CELL).floor())+Vector2i.ONE
	var wanted := Rect2i(first,last-first)
	if wanted != cell_rect:
		cell_rect = wanted
		_pending_cells.clear()
		for key in cells.keys():
			if not wanted.has_point(key):
				_retire_cell(key)
				cells.erase(key)
				_cell_jobs.erase(key)
		for key in _cell_jobs.keys():
			if not wanted.has_point(key): _cell_jobs.erase(key)
		for y in range(first.y,last.y):
			for x in range(first.x,last.x):
				var key := Vector2i(x,y)
				if not cells.has(key) or _cell_jobs.has(key): _pending_cells.append(key)
		# Establish cheap prop/collision skeletons before spending time on grass.
		# A dash must never enter an unblocked rock while its grass is pending.
		for key in _pending_cells:
			if not _cell_jobs.has(key): _cell_jobs[key] = _begin_cell_job(key)
	_prioritize_cells(visible_area)
	_advance_stream()

func _prioritize_cells(view: Rect2) -> void:
	_stream_urgent = false
	if _pending_cells.is_empty(): return
	var priorities: Dictionary = {}
	for key: Vector2i in _pending_cells:
		# Measure distance to the view rectangle, not its center: a corner
		# entering the picture must beat a distant cell along the centerline.
		var bounds := Rect2(Vector2(key)*CELL,CELL).grow(32.0)
		var gap := (bounds.position-view.end).max(Vector2.ZERO)+(view.position-bounds.end).max(Vector2.ZERO)
		priorities[key] = Vector2(gap.length_squared(), bounds.get_center().distance_squared_to(view.get_center()))
		if gap.length_squared()<160.0*160.0: _stream_urgent = true
	# Refresh even without a cell-rectangle change, since the view keeps moving.
	_pending_cells.sort_custom(func(a: Vector2i, b: Vector2i):
		var first: Vector2 = priorities[a]
		var second: Vector2 = priorities[b]
		return first.x<second.x if first.x!=second.x else first.y<second.y)

func _retire_cell(key: Vector2i) -> void:
	for node: Node in cells[key]:
		if not is_instance_valid(node): continue
		if node is CanvasItem: node.hide()
		for child in node.get_children():
			if child is BattleTerrainObstacle:
				child.collision_layer = 0
				BattleTerrainObstacle.active.erase(child)
		_retiring_nodes.append(node)

func _advance_stream() -> void:
	var started := Time.get_ticks_usec()
	last_stream_steps = 0
	# Queueing every old mesh at once only moves the spike to end-of-frame.
	# Bound retained memory even under repeated multi-screen teleports. That
	# exceptional overflow can exceed the normal per-frame retirement allowance.
	var retire_count := maxi(MAX_RETIRE_NODES, _retiring_nodes.size()-MAX_RETIRE_BACKLOG)
	for i in mini(retire_count, _retiring_nodes.size()):
		var node: Node = _retiring_nodes.pop_back()
		if is_instance_valid(node): node.queue_free()
	# A dash can consume most of the lookahead in one frame. Temporarily give
	# approaching cells more time, while keeping distant work at the low budget.
	var budget := NEAR_VIEW_BUDGET_USEC if _stream_urgent else STREAM_BUDGET_USEC
	if bool(GameGlobal.get_runtime_flag("battle_loading", false)): budget = LOADING_BUDGET_USEC
	while not _stream_prewarm_ready():
		_step_stream_prewarm()
		if Time.get_ticks_usec() - started >= budget:
			last_stream_usec = Time.get_ticks_usec() - started
			return
	while not _pending_cells.is_empty():
		var key: Vector2i = _pending_cells[0]
		if _step_cell_job(_cell_jobs[key]):
			_cell_jobs.erase(key)
			_pending_cells.pop_front()
		last_stream_steps += 1
		if Time.get_ticks_usec() - started >= budget: break
	last_stream_usec = Time.get_ticks_usec() - started

func _stream_prewarm_ready() -> bool:
	return true

func _step_stream_prewarm() -> void:
	pass

func _begin_cell_job(key: Vector2i) -> Dictionary:
	return {"key":key}

func _step_cell_job(job: Dictionary) -> bool:
	_make_cell(job.key)
	return true

func get_darkness_entry_direction(world_point: Vector2) -> Vector2:
	if not initialized: return Vector2.ZERO
	var point := world_to_ui*world_point
	var threshold := horizon.reveal_end()+16.0
	if point.y>=threshold: return Vector2.ZERO
	var target := world_to_ui.affine_inverse()*Vector2(point.x,threshold+8.0)
	return world_point.direction_to(target)

func _plan_cell(key: Vector2i) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*73856093 ^ key.y*19349663 ^ 13102026)
	var plan: Array[Dictionary] = []
	var origin := Vector2(key)*CELL
	# One complete 01 image per broad area; original moss and stone contours
	# sit on a matching solid. Small source-derived details fill open areas below.
	if posmod(key.x,3)==0 and posmod(key.y,2)==0:
		var center := origin+Vector2(rng.randf_range(-10,170),rng.randf_range(105,175))
		var flip := rng.randf()<.5
		plan.append({"kind":"ground","material":0,"variant":0,
			"point":center,"scale":PATCH_SCALE,"flip":flip,"alpha":1.0})
		# Anchors were sampled from actual green regions of 01. Grass stands
		# upright at those roots and uses its original, unfiltered pixel artwork.
		for anchor: Array in config.grass_anchors:
			if rng.randf()>.72: continue
			var offset := Vector2(float(anchor[0]),float(anchor[1]))
			if flip: offset.x = -offset.x
			plan.append({"kind":"grass","index":rng.randi_range(0,grass_textures.size()-1),
				"point":center+offset*PATCH_SCALE,"scale":2.0,"flip":rng.randf()<.5})
	# Small, infrequent groups leave generous open fighting space. The starting
	# clearing is a world-space feature, not scenery that dodges the camera.
	if rng.randf()<.22:
		var point := origin+Vector2(rng.randf_range(130,400),rng.randf_range(65,185))
		if point.length()>230.0:
			var index := posmod(key.x+key.y*3,prop_textures.size())
			plan.append({"kind":"prop","index":index,"point":point,
				"scale":rng.randf_range(.90,1.06)*ART_SCALE})
	_add_surface_details(key,plan)
	return plan

func _surface_is_clear(point: Vector2) -> bool:
	# Consult the full 01 silhouette before adding detail, so existing cracks
	# do not receive another dark patch. Recreate only nearby patch transforms.
	var block := Vector2i(floori(point.x/(CELL.x*3.0))*3,floori(point.y/(CELL.y*2.0))*2)
	for dy in [-2,0,2]:
		for dx in [-3,0,3]:
			var key := block+Vector2i(dx,dy)
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(key.x*73856093 ^ key.y*19349663 ^ 13102026)
			var center := Vector2(key)*CELL+Vector2(rng.randf_range(-10,170),rng.randf_range(105,175))
			var flip := rng.randf()<.5
			for offset: Vector2 in [Vector2.ZERO,Vector2(-35,-12),Vector2(35,-12),Vector2(-35,12),Vector2(35,12)]:
				var local := (point+offset-center)/PATCH_SCALE
				if flip: local.x = -local.x
				var pixel := Vector2i((local+Vector2(ground_image.get_size())*.5).floor())
				if not Rect2i(Vector2i.ZERO,ground_image.get_size()).has_point(pixel): continue
				var color := ground_image.get_pixelv(pixel)
				if color.a>.5 and color.r<.26: return false
	return true

func _add_surface_details(key: Vector2i, plan: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.x*83492791 ^ key.y*297121507 ^ 13102027)
	var companions: Array[Dictionary] = []
	for entry: Dictionary in plan:
		if entry.kind=="grass" and rng.randf()<.38:
			companions.append({"kind":"grass","index":rng.randi_range(0,grass_textures.size()-1),
				"point":entry.point+Vector2(rng.randf_range(16,30),rng.randf_range(3,8)),
				"scale":1.0,"flip":rng.randf()<.5})
	plan.append_array(companions)
	var placed: Array[Vector2] = []
	for attempt in 5:
		if placed.size()>=2: break
		var point := Vector2(key)*CELL+Vector2(rng.randf_range(75,455),rng.randf_range(40,205))
		if not _surface_is_clear(point): continue
		var clear := true
		for entry: Dictionary in plan:
			if entry.kind=="prop" and point.distance_to(entry.point)<110: clear = false
		for previous: Vector2 in placed:
			if point.distance_to(previous)<135: clear = false
		if not clear: continue
		placed.append(point)
		plan.append({"kind":"detail","index":rng.randi_range(0,detail_textures.size()-1),
			"point":point,"scale":1.0,"flip":rng.randf()<.5})
		if rng.randf()<.65:
			plan.append({"kind":"rubble","index":rng.randi_range(0,rubble_textures.size()-1),
				"point":point+Vector2(rng.randf_range(-26,26),rng.randf_range(6,17)),
				"scale":2.0 if rng.randf()<.35 else 1.0,"flip":rng.randf()<.5})
		if rng.randf()<.58:
			plan.append({"kind":"grass","index":rng.randi_range(0,grass_textures.size()-1),
				"point":point+Vector2(rng.randf_range(25,46),rng.randf_range(1,12)),
				"scale":1.0 if rng.randf()<.5 else 2.0,"flip":rng.randf()<.5})

func _make_cell(key: Vector2i) -> void:
	var nodes: Array[Node] = []
	for entry: Dictionary in _plan_cell(key):
		var sprite := Sprite2D.new()
		sprite.position = entry.point
		sprite.scale = Vector2.ONE*float(entry.scale)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = decoration_material
		if entry.kind == "ground":
			sprite.scale /= float(config.get("ground_texture_density",1.0))
			sprite.texture = ground_textures[entry.material][entry.variant]
			sprite.flip_h = entry.flip
			sprite.modulate.a = entry.alpha
			decals.add_child(sprite)
		elif entry.kind == "detail":
			sprite.texture = detail_textures[entry.index]
			sprite.flip_h = entry.flip
			sprite.z_index = 1
			decals.add_child(sprite)
		elif entry.kind == "rubble":
			sprite.texture = rubble_textures[entry.index]
			sprite.scale /= float(config.rubble[entry.index].get("texture_density",1.0))
			sprite.flip_h = entry.flip
			sprite.offset.y = -sprite.texture.get_height()*.5
			roots.add_child(sprite)
		elif entry.kind == "grass":
			sprite.texture = grass_textures[entry.index]
			sprite.z_as_relative = false
			sprite.z_index = CombatRenderWorld.GRASS_Z
			sprite.flip_h = entry.flip
			sprite.offset.y = -sprite.texture.get_height()*.5
			roots.add_child(sprite)
		else:
			sprite.texture = prop_textures[entry.index]
			sprite.offset.y = -sprite.texture.get_height()*.5
			roots.add_child(sprite)
		# Production sprites retain their authored root, including transparent
		# atlas margins. Cropped cavern sprites continue to use the bottom edge.
		if entry.has("anchor"):
			var anchor: Vector2 = entry.anchor
			if sprite.flip_h: anchor.x = sprite.texture.get_width()-anchor.x
			sprite.offset = sprite.texture.get_size()*.5-anchor
		if entry.has("tint"): sprite.modulate = entry.tint
		sprite.set_meta("scenery",entry)
		nodes.append(sprite)
	cells[key] = nodes

func layout_signature() -> Array[String]:
	var result: Array[String] = []
	for key in cells:
		for node: Node in cells[key]: result.append(str(key)+str(node.get_meta("scenery")))
	result.sort()
	return result
