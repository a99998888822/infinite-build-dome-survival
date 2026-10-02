extends WetlandBackdrop
class_name GreenBattleBackdrop
## Approved green floor with bounded, coordinate-stable decoration streaming.
const GREEN_SHADER = preload("res://shaders/battle/green_ground.gdshader")
const CONFIG_PATH := "res://data_config/green_battlefield.json"
const GREEN_CELL_SIZE := 384.0
var config: Dictionary = {}
var _green_textures: Dictionary = {}
var _central_props: Node2D
var _central_bounds: Rect2


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var bounds: Array = config.central_bounds
	_central_bounds = Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
	for id: String in config.assets:
		_green_textures[id] = load(str(config.assets[id].texture))
	# Keep the old backdrop interface for scene coordination and historical reviews.
	# Water nodes remain dormant; no wet effects are advanced on this surface.
	super._ready()
	if is_instance_valid(_floor): _floor.hide()
	_ground.name = "ContinuousGreenGround"
	_material.shader = GREEN_SHADER
	_material.set_shader_parameter("ground_texture",load(str(config.ground_texture)))
	_material.set_shader_parameter("sample_offset",Vector2(float(config.sample_offset[0]),float(config.sample_offset[1])))
	_central_props = Node2D.new()
	_central_props.name = "ApprovedCentralScenery"
	add_child(_central_props)
	for entry: Dictionary in config.central_placements:
		_add_green_prop(_central_props,str(entry.id),Vector2(float(entry.root[0]),float(entry.root[1])),float(entry.scale))
	_update_ground()


func _process(delta: float) -> void:
	_update_ground()
	if is_instance_valid(_player) and _player.alive and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)):
		_time += delta


func _update_ground() -> void:
	var camera := get_viewport().get_camera_2d()
	camera_position = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var area: Rect2 = (inverse * get_viewport_rect()).grow(8.0)
	var origin := area.position.floor()
	_ground.position = origin
	_ground.size = area.end.ceil()-origin
	_material.set_shader_parameter("world_origin",origin)
	_material.set_shader_parameter("surface_size",_ground.size)
	var first := Vector2i((origin/GREEN_CELL_SIZE).floor())-Vector2i.ONE
	var last := Vector2i((area.end/GREEN_CELL_SIZE).floor())+Vector2i(2,2)
	var next_rect := Rect2i(first,last-first)
	if next_rect != _cell_rect:
		_cell_rect = next_rect
		_refresh_decals()
	if is_instance_valid(_central_props):
		_central_props.visible = area.intersects(_central_bounds.grow(128.0))


func _refresh_decals() -> void:
	for key in _cells.keys():
		if not _cell_rect.has_point(key):
			(_cells[key] as Node2D).queue_free()
			_cells.erase(key)
	for cy in range(_cell_rect.position.y,_cell_rect.end.y):
		for cx in range(_cell_rect.position.x,_cell_rect.end.x):
			var key := Vector2i(cx,cy)
			if _cells.has(key): continue
			var cell := Node2D.new()
			cell.name = "GreenScenery_%d_%d" % [cx,cy]
			add_child(cell)
			_cells[key] = cell
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(cx*73856093 ^ cy*19349663 ^ 94103)
			var types: Array[String] = ["grass","grass","grass","grass","grass","grass","rubble","moss"]
			if rng.randf()<0.5: types.append("ruins")
			for type: String in types:
				var choices: Array = config.groups[type]
				var id := str(choices[rng.randi_range(0,choices.size()-1)])
				var point := Vector2(cx,cy)*GREEN_CELL_SIZE+Vector2(rng.randf_range(30,354),rng.randf_range(38,354)).round()
				# Do not disturb the approved central composition, including tall silhouettes.
				var definition: Dictionary = config.assets[id]
				var scale_factor := float(definition.scale)
				var size: Vector2 = (_green_textures[id] as Texture2D).get_size()*scale_factor
				var prop_rect := Rect2(point-Vector2(size.x*0.5,size.y),size)
				if prop_rect.intersects(_central_bounds.grow(16.0)): continue
				_add_green_prop(cell,id,point,scale_factor)


func _add_green_prop(parent: Node2D, id: String, foot: Vector2, scale_factor: float) -> void:
	var definition: Dictionary = config.assets[id]
	var sprite := Sprite2D.new()
	sprite.texture = _green_textures[id] as Texture2D
	sprite.centered = false
	sprite.offset = -Vector2(float(definition.anchor[0]),float(definition.anchor[1]))
	sprite.position = foot
	sprite.scale = Vector2.ONE*scale_factor
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 20
	sprite.set_meta("asset_id",id)
	parent.add_child(sprite)


func set_horizon_view(_horizon: float, _height: float, _ui_size: Vector2, _units_per_pixel: Vector2, _sky_texture: Texture2D) -> void:
	pass


func is_wet_at(_world_position: Vector2) -> bool:
	return false


func spawn_ripple(_world_position: Vector2, _strength: float = 1.0) -> void:
	pass
