extends Node2D
class_name CavernBattleBackdrop
## Stable, sparse world decals. Cell generation never consumes gameplay RNG.
const CELL := Vector2(530,245)
const ART_SCALE := 2.15
const PATCH_SCALE := 1.0
const GROUND_SHADER = preload("res://shaders/battle/cavern_ground.gdshader")
const DECAL_SHADER = preload("res://shaders/battle/cavern_decoration.gdshader")
@export_file("*.json") var scenery_config_path := "res://data_config/cavern_battlefield.json"
var player: PlayerController
var horizon: CavernBattleHorizon
var initialized := false
var ground: ColorRect
var ground_material: ShaderMaterial
var decoration_material: ShaderMaterial
var roots: Node2D
var decals: Node2D
var proxy: Node2D
var old_visual_position := Vector2.ZERO
var foot_offset := Vector2.ZERO
var foot_texture: Texture2D
var cells: Dictionary = {}
var cell_rect := Rect2i()
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

func set_world_context(subject: PlayerController, _wave_manager: WaveManager) -> void:
	player = subject
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
	ground.z_index = -110
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
	decals.z_index = -100
	decals.y_sort_enabled = true
	add_child(decals)
	roots = Node2D.new()
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
	_update_area()
	set_process(true)

func _refresh_player_foot() -> void:
	if foot_texture == player._idle_texture: return
	foot_texture = player._idle_texture
	var image := foot_texture.get_image()
	if image.is_compressed(): image.decompress()
	var bounds := image.get_used_rect()
	foot_offset = Vector2(0,(bounds.end.y-foot_texture.get_height()*.5+player.sprite.position.y)*absf(player.visual_anchor.scale.y)+old_visual_position.y)
	player.visual_anchor.position = old_visual_position-foot_offset

func detach_player() -> void:
	set_process(false)
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
	var area: Rect2 = (inverse*get_viewport_rect()).grow(_stream_margin())
	ground.position = area.position.floor()
	ground.size = area.end.ceil()-ground.position
	var ui_size := get_tree().root.get_visible_rect().size
	var ratio := get_viewport_rect().size/ui_size
	world_to_ui = Transform2D(inverse.x*ratio.x,inverse.y*ratio.y,inverse.origin).affine_inverse()
	horizon.configure_view(ui_size,player.camera_2d.get_screen_center_position().x,1.0/(inverse.x.length()*ratio.x))
	var fade_start := horizon.far_height()*.62
	var fade_end := horizon.far_height()+68.0*horizon.art_scale
	for material: ShaderMaterial in [ground_material,decoration_material]:
		material.set_shader_parameter("view_size",ui_size)
		material.set_shader_parameter("fade_start",fade_start)
		material.set_shader_parameter("fade_end",fade_end)
	var first := Vector2i((area.position/CELL).floor())
	var last := Vector2i((area.end/CELL).floor())+Vector2i.ONE
	var wanted := Rect2i(first,last-first)
	if wanted == cell_rect: return
	cell_rect = wanted
	for key in cells.keys():
		if not wanted.has_point(key):
			for node: Node in cells[key]: node.queue_free()
			cells.erase(key)
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var key := Vector2i(x,y)
			if not cells.has(key): _make_cell(key)

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
