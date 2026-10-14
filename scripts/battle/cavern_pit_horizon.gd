extends CavernBattleHorizon
class_name CavernPitHorizon
## Sparse, continuous parallax slots only become visible in the dark corners.
var ruin_sprites: Array[Sprite2D] = []
const PIT_RUIN_SPEED := .18
var pit_light: ColorRect

func _ready() -> void:
	super._ready()
	darkness_material.shader = preload("res://shaders/battle/cavern_pit_darkness.gdshader")
	pit_light = ColorRect.new()
	pit_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pit_light.show_behind_parent = true
	var floor_light := ShaderMaterial.new()
	floor_light.shader = preload("res://shaders/battle/cavern_pit_light.gdshader")
	pit_light.material = floor_light
	add_child(pit_light)
	# Light the world first, then mask it with the pit wall shadows.
	move_child(pit_light,0)
	var lighting := ShaderMaterial.new()
	lighting.shader = preload("res://shaders/battle/cavern_ruin_light.gdshader")
	for i in 2:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.material = lighting
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		ruin_sprites.append(sprite)
	configure_view(view_size,camera_x,camera_scale)

func far_offset() -> float:
	# Horizontal camera displacement is the only source of panorama motion.
	return fposmod(camera_x*camera_scale*FAR_SPEED+115.0*art_scale,panorama.get_width()*art_scale*.5)

func cave_openings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var period := panorama.get_width()*art_scale*.5
	var offset := far_offset()
	for repeat in range(-1,ceili(view_size.x/period)+2):
		var cursor := 0.0
		for row: Dictionary in config.panorama_modules:
			var rect := Rect2(Vector2(repeat*period-offset+(cursor+floorf(row.wall_gap*.5))*art_scale,row.opening_top*art_scale),
				Vector2(row.width*art_scale,(row.opening_bottom-row.opening_top)*art_scale))
			if rect.end.x>0 and rect.position.x<view_size.x: result.append({"source":row.source,"rect":rect})
			cursor += row.width+row.wall_gap
	return result

func far_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for opening: Dictionary in cave_openings():
		var rect: Rect2 = opening.rect
		result.append({"source":opening.source,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	return result

func _ruin_clearance(rect: Rect2, openings: Array[Dictionary]) -> float:
	var amount := 1.0
	for opening: Dictionary in openings:
		var cave: Rect2 = opening.rect
		if rect.position.y>=cave.end.y or rect.end.y<=cave.position.y: continue
		var gap := maxf(cave.position.x-rect.end.x,rect.position.x-cave.end.x)
		amount = minf(amount,smoothstep(0.0,28.0*art_scale,gap))
	return amount

func configure_view(size: Vector2, x: float, zoom_scale: float) -> void:
	super.configure_view(size,x,zoom_scale)
	darkness_material.set_shader_parameter("art_scale",art_scale)
	if is_instance_valid(pit_light): pit_light.size = size

func darkness_end() -> float:
	return far_height()+1.0*art_scale

func reveal_end() -> float:
	return far_height()+30.0*art_scale

func top_arc_offset(screen_x: float) -> float:
	var x := clampf((screen_x/view_size.x-.5)/.62,-1.0,1.0)
	return (1.0-sqrt(maxf(0.0,1.0-x*x)))*120.0*art_scale

func reveal_at(screen_x: float) -> float:
	return reveal_end()+top_arc_offset(screen_x)

func _update_entries() -> void:
	entries.clear()
	var openings := cave_openings()
	var shift := camera_x*camera_scale*PIT_RUIN_SPEED
	var spacing := 384.0*art_scale
	var first := floori((shift-180.0*art_scale)/spacing)
	var last := ceili((shift+view_size.x)/spacing)
	for side in 2:
		var candidate: Dictionary = {}
		var best := 0.0
		for slot in range(first,last+1):
			var x := slot*spacing+215.0*art_scale-shift
			var edge_x := x if side==0 else view_size.x-x
			var alpha := smoothstep(-25*art_scale,70*art_scale,edge_x)*(1.0-smoothstep(view_size.x*.28,view_size.x*.32,edge_x))
			var index := posmod(slot,ruins.size())
			var factor := art_scale*1.28*(1.0 if index==0 else 1.12)
			var size := ruin_display_size(index)*factor
			var root := Vector2(x,far_height()+12*art_scale)
			alpha *= _ruin_clearance(Rect2(root-Vector2(size.x*.5,size.y),size),openings)
			if alpha<=best: continue
			best = alpha
			candidate = {"slot":slot,"index":index,"root":root,"scale":factor,"alpha":alpha}
		if not candidate.is_empty(): entries.append(candidate)
	for i in ruin_sprites.size():
		var sprite := ruin_sprites[i]
		sprite.visible = i<entries.size()
		if not sprite.visible: continue
		var entry: Dictionary = entries[i]
		sprite.texture = ruins[entry.index]
		var size := ruin_display_size(entry.index)*float(entry.scale)
		sprite.position = (entry.root-Vector2(size.x*.5,size.y)).round()
		sprite.scale = size/sprite.texture.get_size()
		sprite.modulate.a = entry.alpha

func _draw() -> void:
	if panorama==null: return
	var factor := art_scale*.5
	var period := panorama.get_width()*factor
	var offset := far_offset()
	for i in range(-1,ceili(view_size.x/period)+2):
		draw_texture_rect(panorama,Rect2(Vector2(i*period-offset,0),Vector2(period,far_height())),false,Color(.67,.67,.67,1))
