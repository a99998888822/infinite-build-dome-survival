extends Node2D
## Reused render-only surfaces. No change to authored size, direction or hitboxes.
const SHADER = preload("res://shaders/effects/aligned_atlas.gdshader")
var bounds := Rect2()

static func begin(canvas: CanvasItem) -> void:
	if not canvas.has_meta("aligned_atlas_surfaces"): return
	for surface: Node2D in canvas.get_meta("aligned_atlas_surfaces"): surface.hide()
	canvas.set_meta("aligned_atlas_cursor",0)

static func draw(canvas: CanvasItem, texture: Texture2D, rect: Rect2, source: Rect2,
		tint := Color.WHITE, pose := Transform2D.IDENTITY, grid := 3.0, behind := true) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0 or source.size.x <= 0 or source.size.y <= 0: return
	if not canvas.has_meta("aligned_atlas_surfaces"):
		canvas.set_meta("aligned_atlas_surfaces",[])
	var surfaces: Array = canvas.get_meta("aligned_atlas_surfaces")
	var index := int(canvas.get_meta("aligned_atlas_cursor",0))
	var surface: Node2D
	if index == surfaces.size():
		surface = new()
		surface.name = "AlignedEffect%d" % index
		surface.show_behind_parent = true
		surface.material = ShaderMaterial.new()
		surface.material.shader = SHADER
		canvas.add_child(surface)
		surfaces.append(surface)
	else: surface = surfaces[index]
	canvas.set_meta("aligned_atlas_cursor",index+1)
	surface.show_behind_parent = behind
	surface.transform = pose
	surface.modulate = tint
	surface.material.set_shader_parameter("atlas",texture)
	surface.material.set_shader_parameter("atlas_size",texture.get_size())
	surface.material.set_shader_parameter("source_rect",Vector4(source.position.x,source.position.y,source.size.x,source.size.y))
	surface.material.set_shader_parameter("destination",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
	surface.material.set_shader_parameter("grid",grid)
	surface.bounds = rect.grow(8.0/maxf(0.1,minf(pose.x.length(),pose.y.length())))
	surface.show()
	surface.queue_redraw()

func _draw() -> void:
	draw_rect(bounds,Color.WHITE)

static func configure_sprite(sprite: Sprite2D, grid := 2.0) -> void:
	if sprite.texture == null: return
	if not sprite.has_meta("aligned_sprite_material"):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		sprite.material = mat
		sprite.set_meta("aligned_sprite_material",mat)
	var mat: ShaderMaterial = sprite.get_meta("aligned_sprite_material")
	var extent := sprite.texture.get_size()/Vector2(sprite.hframes,sprite.vframes)
	var rect := sprite.get_rect()
	var frame_origin := Vector2(sprite.frame_coords)*extent
	mat.set_shader_parameter("atlas",sprite.texture)
	mat.set_shader_parameter("atlas_size",sprite.texture.get_size())
	mat.set_shader_parameter("source_rect",Vector4(frame_origin.x,frame_origin.y,extent.x,extent.y))
	mat.set_shader_parameter("destination",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
	mat.set_shader_parameter("grid",grid)
