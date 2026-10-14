extends Node2D
class_name CavernBattleHorizon
## Screen-space ruins retain their size and height regardless of world Y.
const FAR_SPEED := .08
const RUIN_SPEED := .26
const SLOT := 158.0
var config: Dictionary
var panorama: Texture2D
var ruins: Array[Texture2D] = []
var view_size := Vector2(1152,768)
var camera_x := 0.0
var camera_scale := 1.0
var art_scale := 1.5
var entries: Array[Dictionary] = []
var foreground_layer: CanvasLayer
var foreground_root: Node2D
var darkness: ColorRect
var darkness_material: ShaderMaterial

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/cavern_battlefield.json"))
	panorama = load(config.panorama)
	for row: Dictionary in config.ruins: ruins.append(load(row.texture))
	darkness = ColorRect.new()
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.show_behind_parent = true
	darkness_material = ShaderMaterial.new()
	darkness_material.shader = preload("res://shaders/battle/cavern_darkness.gdshader")
	darkness.material = darkness_material
	add_child(darkness)
	foreground_layer = CanvasLayer.new()
	foreground_layer.layer = -1
	add_child(foreground_layer)
	foreground_root = Node2D.new()
	foreground_layer.add_child(foreground_root)
	for row: Dictionary in config.foreground:
		var sprite := Sprite2D.new()
		sprite.texture = load(row.texture)
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foreground_root.add_child(sprite)
	get_node("../Sky").hide()
	configure_view(view_size,0.0,1.0)

func configure_view(size: Vector2, x: float, zoom_scale: float) -> void:
	view_size = size
	camera_x = x
	camera_scale = zoom_scale
	art_scale = minf(size.x/768.0,size.y/432.0)
	darkness.size = size
	darkness_material.set_shader_parameter("darkness_end",darkness_end())
	darkness_material.set_shader_parameter("reveal_end",reveal_end())
	darkness_material.set_shader_parameter("view_height",size.y)
	_update_entries()
	for i in config.foreground.size():
		var row: Dictionary = config.foreground[i]
		var sprite: Sprite2D = foreground_root.get_child(i)
		sprite.position = (Vector2(row.corner[0],row.corner[1])*size+Vector2(row.offset[0],row.offset[1])*art_scale).round()
		var logical: Array = row.get("display_size",[sprite.texture.get_width(),sprite.texture.get_height()])
		sprite.scale = Vector2(logical[0],logical[1])/sprite.texture.get_size()*art_scale
	queue_redraw()

func ruin_display_size(index: int) -> Vector2:
	var logical: Array = config.ruins[index].get("display_size",[ruins[index].get_width(),ruins[index].get_height()])
	return Vector2(logical[0],logical[1])

func far_height() -> float:
	return 103.0*art_scale

func darkness_end() -> float:
	return far_height()+4.0*art_scale

func reveal_end() -> float:
	return far_height()+39.0*art_scale

func _update_entries() -> void:
	entries.clear()
	var shift := camera_x*camera_scale*RUIN_SPEED
	var spacing := SLOT*art_scale
	var first := floori((shift-120*art_scale)/spacing)
	var last := ceili((shift+view_size.x+120*art_scale)/spacing)
	for slot in range(first,last+1):
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(slot*73856093 ^ 11092026)
		# Adjacent slots use different silhouettes; seeded jitter avoids a grid.
		var index := posmod(slot,ruins.size())
		var factor := rng.randf_range(.83,1.1)*art_scale
		var anchor := Vector2(slot*spacing+rng.randf_range(24,100)*art_scale-shift,
			far_height()+rng.randf_range(6,25)*art_scale)
		entries.append({"slot":slot,"index":index,"root":anchor,"scale":factor})

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in entries:
		result[str(entry.slot)] = {"root":[entry.root.x,entry.root.y],"scale":entry.scale,"index":entry.index}
	return result

func _draw() -> void:
	if panorama == null: return
	# The full-width opaque upper band and its lower fade are drawn by darkness.
	var scale_factor := art_scale*.5
	var period := panorama.get_width()*scale_factor
	var offset := fposmod(camera_x*camera_scale*FAR_SPEED+45*art_scale,period)
	for i in range(-1,ceili(view_size.x/period)+2):
		draw_texture_rect(panorama,Rect2(Vector2(i*period-offset,0),Vector2(period,far_height())),false,Color(.67,.67,.67,1))
	for entry: Dictionary in entries:
		var texture := ruins[entry.index]
		var size := ruin_display_size(entry.index)*float(entry.scale)
		draw_texture_rect(texture,Rect2((entry.root-Vector2(size.x*.5,size.y)).round(),size),false)
