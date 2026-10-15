extends CavernBattleHorizon
class_name CavernPitHorizon
## Sparse ruins in the walls between distant cave openings.
var ruin_sprites: Array[Sprite2D] = []
var ruin_material: ShaderMaterial
const FAR_SCALE_RATIO := .8
const FAR_BRIGHTNESS := 1.118
const REVEAL_DISTANCE := 38.0
const TOP_ARC_HEIGHT := 104.0
var pit_light: ColorRect

func _ready() -> void:
	super._ready()
	var cave_material := ShaderMaterial.new()
	cave_material.shader = preload("res://shaders/battle/cavern_pit_panorama.gdshader")
	material = cave_material
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
	ruin_material = lighting
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
	return fposmod(camera_x*camera_scale*FAR_SPEED+115.0*art_scale*FAR_SCALE_RATIO,far_period())

func cave_openings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var period := far_period()
	var far_scale := art_scale*FAR_SCALE_RATIO
	var offset := far_offset()
	for repeat in range(-1,ceili(view_size.x/period)+2):
		var cursor := 0.0
		for row: Dictionary in config.panorama_modules:
			var rect := Rect2(Vector2(repeat*period-offset+(cursor+floorf(row.wall_gap*.5))*far_scale,row.opening_top*far_scale),
				Vector2(row.width*far_scale,(row.opening_bottom-row.opening_top)*far_scale))
			if rect.end.x>0 and rect.position.x<view_size.x: result.append({"source":row.source,"rect":rect})
			cursor += row.width+row.wall_gap
	return result

func far_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for opening: Dictionary in cave_openings():
		var rect: Rect2 = opening.rect
		result.append({"source":opening.source,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	return result

func _cave_gap_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var far_scale := art_scale*FAR_SCALE_RATIO
	var period := far_period()
	# Unwrapped repeats keep each ruin attached to the same cave even when
	# the panorama's wrapped drawing offset crosses zero in either direction.
	var shift := camera_x*camera_scale*FAR_SPEED+115.0*far_scale
	var count: int = config.panorama_modules.size()
	for repeat in range(floori(shift/period)-1,ceili((view_size.x+shift)/period)+1):
		var cursor := 0.0
		for index in count:
			var row: Dictionary = config.panorama_modules[index]
			var next: Dictionary = config.panorama_modules[(index+1)%count]
			var left := cursor+floorf(row.wall_gap*.5)+float(row.width)
			var right := cursor+float(row.width)+float(row.wall_gap)+floorf(next.wall_gap*.5)
			var top := maxf(row.opening_top,next.opening_top)*far_scale
			var bottom := minf(row.opening_bottom,next.opening_bottom)*far_scale
			var rect := Rect2(Vector2(repeat*period-shift+left*far_scale,top),Vector2((right-left)*far_scale,bottom-top))
			if rect.end.x>0 and rect.position.x<view_size.x:
				result.append({"slot":repeat*count+index,"rect":rect})
			cursor += float(row.width)+float(row.wall_gap)
	return result

func configure_view(size: Vector2, x: float, zoom_scale: float) -> void:
	super.configure_view(size,x,zoom_scale)
	darkness_material.set_shader_parameter("art_scale",art_scale)
	darkness_material.set_shader_parameter("top_arc_height",TOP_ARC_HEIGHT)
	if is_instance_valid(pit_light): pit_light.size = size

func far_height() -> float:
	return super.far_height()*FAR_SCALE_RATIO

func far_period() -> float:
	return super.far_period()*FAR_SCALE_RATIO

func darkness_end() -> float:
	# The cave openings end before the panorama texture's empty bottom padding.
	var lower_edge := 0.0
	for module: Dictionary in config.panorama_modules:
		lower_edge = maxf(lower_edge, float(module.opening_bottom))
	return lower_edge*art_scale*FAR_SCALE_RATIO

func reveal_end() -> float:
	# Lift the clear edge; the full-dark edge now recedes to the cave artwork.
	return far_height()+REVEAL_DISTANCE*art_scale

func ground_fade_end() -> float:
	return reveal_end()+14.0*art_scale

func top_arc_offset(screen_x: float) -> float:
	var x := clampf((screen_x/view_size.x-.5)/.62,-1.0,1.0)
	return (1.0-sqrt(maxf(0.0,1.0-x*x)))*TOP_ARC_HEIGHT*art_scale

func reveal_at(screen_x: float) -> float:
	return reveal_end()+top_arc_offset(screen_x)

func _cave_side_rect(gap: Rect2, requested_size: Vector2, left_side: bool) -> Rect2:
	var inset := 10.0*art_scale*FAR_SCALE_RATIO
	var room := gap.size-Vector2(inset*2,inset)
	var size := requested_size*minf(1.0,minf(room.x/requested_size.x,room.y/requested_size.y))
	var x := gap.position.x+inset if left_side else gap.end.x-inset-size.x
	# The base belongs to the cave wall, well above the ground's light/dark arc.
	return Rect2(Vector2(roundf(x),floorf(gap.end.y-2.0*art_scale*FAR_SCALE_RATIO-size.y)),size)

func _update_entries() -> void:
	entries.clear()
	var gaps := _cave_gap_slots()
	for gap: Dictionary in gaps:
		var slot: int = gap.slot
		var index := posmod(slot,ruins.size())
		var factor := art_scale*FAR_SCALE_RATIO
		var size := ruin_display_size(index)*factor
		var rect := _cave_side_rect(gap.rect,size,posmod(slot,2)==1)
		size = rect.size
		factor = size.y/ruin_display_size(index).y
		if rect.end.x<=0 or rect.position.x>=view_size.x: continue
		var root := Vector2(rect.get_center().x,rect.end.y)
		entries.append({"slot":slot,"index":index,"root":root,"scale":factor,"position":rect.position,"alpha":1.0})
	if ruin_material == null: return
	while ruin_sprites.size()<entries.size():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.material = ruin_material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		ruin_sprites.append(sprite)
	for i in ruin_sprites.size():
		var sprite := ruin_sprites[i]
		sprite.visible = i<entries.size()
		if not sprite.visible: continue
		var entry: Dictionary = entries[i]
		sprite.texture = ruins[entry.index]
		var size := ruin_display_size(entry.index)*float(entry.scale)
		sprite.position = entry.position
		sprite.scale = size/sprite.texture.get_size()
		sprite.modulate.a = entry.alpha

func _draw() -> void:
	if panorama==null: return
	var period := far_period()
	var offset := far_offset()
	for i in range(-1,ceili(view_size.x/period)+2):
		draw_texture_rect(panorama,Rect2(Vector2(i*period-offset,0),Vector2(period,far_height())),false,Color(FAR_BRIGHTNESS,FAR_BRIGHTNESS,FAR_BRIGHTNESS,1))
