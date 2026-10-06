extends Node2D
class_name MeadowBattleHorizon
const SKYLINE = preload("res://shaders/battle/meadow/continuous_skyline.gdshader")
const RUIN = preload("res://shaders/battle/meadow/distant_ruin.gdshader")
var land := ColorRect.new()
var ruins := Node2D.new()
var surface: Texture2D
var config: Dictionary
var view_size := Vector2(1152,768)
var center := Vector2.ZERO
var materials: Array[ShaderMaterial] = []
var entries: Dictionary = {}
var coverage_debug := false



const SPACING := Vector2(360,150)
var screen_to_world := Transform2D.IDENTITY
var horizon_y := 72.0
var surface_parameters: Dictionary = {}


func setup(texture: Texture2D) -> void:
	surface = texture
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/green_battlefield.json"))
	land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SKYLINE
	material.set_shader_parameter("ground_texture",surface)
	land.material = material
	materials.append(material)
	add_child(land)
	ruins.y_sort_enabled = true
	add_child(ruins)


func configure_view(size: Vector2, _world_x: float) -> void:
	view_size = size
	# Only fill the sky-side silhouette. Everything below shares the native ground.
	land.size = Vector2(size.x,BattleEnvironment.get_sky_height(size.x)+(86.0 if coverage_debug else 1.0))


func set_surface_transform(parameters: Dictionary, point: Vector2) -> void:
	center = point
	if parameters != surface_parameters:
		surface_parameters = parameters.duplicate()
		screen_to_world = Transform2D(parameters.world_screen_x,parameters.world_screen_y,parameters.world_screen_origin)
		horizon_y = float(parameters.horizon_y)
		_update_ruins()
	for material: ShaderMaterial in materials:
		for key: String in parameters: material.set_shader_parameter(key,parameters[key])


func terrain_at_screen(point: Vector2) -> Vector2:
	var remaining := 1.0-clampf((point.y-horizon_y)/120.0,0.0,1.0)
	return screen_to_world*Vector2(point.x,point.y-43.333333*remaining*remaining*remaining)


func project_terrain(point: Vector2) -> Vector2:
	var flat := screen_to_world.affine_inverse()*point
	# Invert the monotone vertical compression in continuous_land.gdshaderinc.
	# This is a terrain projection, not a second, independently moving parallax.
	var low := flat.y
	var high := flat.y+43.333333
	for i in 18:
		var middle := (low+high)*.5
		var remaining := 1.0-clampf((middle-horizon_y)/120.0,0.0,1.0)
		if middle-43.333333*remaining*remaining*remaining<flat.y: low = middle
		else: high = middle
	return Vector2(flat.x,(low+high)*.5)


func _update_ruins() -> void:
	var far_y := horizon_y+10.0
	var near_y := far_y+64.0
	var bounds := Rect2(terrain_at_screen(Vector2(-160,far_y)),Vector2.ZERO)
	for corner in [Vector2(view_size.x+160,far_y),Vector2(-160,near_y),Vector2(view_size.x+160,near_y)]:
		bounds = bounds.expand(terrain_at_screen(corner))
	var first := Vector2i((bounds.position/SPACING).floor())-Vector2i.ONE
	var last := Vector2i((bounds.end/SPACING).floor())+Vector2i.ONE
	var wanted: Dictionary = {}
	var ids: Array = config.groups.ruins
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key := Vector2i(x,y)
			# Retain four of every five world cells without moving the survivors.
			if posmod(x*269+y*73+1,5)==0: continue
			# Approved sparser skyline: retain two thirds of the remaining cells.
			if posmod(x*137+y*83+2,3)==0: continue
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(x*73856093 ^ y*19349663 ^ 113907)
			var anchor := (Vector2(key)*SPACING+Vector2(rng.randf_range(65,295),rng.randf_range(25,125))).round()
			var projected := project_terrain(anchor)
			if projected.y<far_y or projected.y>near_y or projected.x< -160 or projected.x>view_size.x+160: continue
			wanted[key] = true
			var q := (projected.y-far_y)/64.0
			if not entries.has(key):
				var id := str(ids[rng.randi_range(0,ids.size()-1)])
				var asset: Dictionary = config.assets[id]
				var sprite := Sprite2D.new()
				sprite.texture = load(str(asset.texture))
				sprite.centered = false
				sprite.offset = -Vector2(asset.anchor[0],asset.anchor[1])
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var material := ShaderMaterial.new()
				material.shader = RUIN
				material.set_shader_parameter("ground_texture",surface)
				material.set_shader_parameter("root_uv",float(asset.anchor[1])/sprite.texture.get_height())
				sprite.material = material
				materials.append(material)
				ruins.add_child(sprite)
				entries[key] = {"sprite":sprite,"id":id,"anchor":anchor,"base_scale":float(asset.scale)}
			var entry: Dictionary = entries[key]
			var sprite: Sprite2D = entry.sprite
			# Restore each asset's authored scale, then apply a modest distance factor.
			# Offset is relative to the root: changes of size never move the foot.
			sprite.position = projected.round()
			sprite.scale = Vector2.ONE*entry.base_scale*lerpf(.70,1.15,q)
			sprite.material.set_shader_parameter("distance_fraction",q)
			sprite.material.set_shader_parameter("edge_fade",smoothstep(0,.12,q)*(1-smoothstep(.84,1,q)))
			entry.depth = q
			entry.brightness = lerpf(.55,.88,q)
	for key in entries.keys():
		if not wanted.has(key):
			var sprite: Sprite2D = entries[key].sprite
			materials.erase(sprite.material)
			sprite.queue_free()
			entries.erase(key)


func _base_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key in entries:
		var entry: Dictionary = entries[key]
		var sprite: Sprite2D = entry.sprite
		result[str(key)] = {"id":entry.id,"depth":entry.depth,"scale":sprite.scale.x,"brightness":entry.brightness,
			"root":[sprite.position.x,sprite.position.y]}
	return result


func snapshot() -> Dictionary:
	var result := _base_snapshot()
	for key in entries:
		var entry: Dictionary = entries[key]
		var sprite: Sprite2D = entry.sprite
		var anchor: Vector2 = entry.anchor
		var projected := project_terrain(anchor)
		result[str(key)].terrain_anchor = [anchor.x,anchor.y]
		result[str(key)].root_snap_error_px = sprite.position.distance_to(projected)
	return result
