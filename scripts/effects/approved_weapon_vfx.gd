extends RefCounted
## Shared offline frames; one texture-region submission per visual, no raster loops.
const FRAMES=preload("res://scripts/effects/approved_weapon_frames.gd")

static func draw(canvas: CanvasItem, key: String, frame: int, pose:=Transform2D.IDENTITY, scale:=Vector2.ONE, tint:=Color.WHITE, crop_left: float=-INF) -> void:
	var d: Dictionary=FRAMES.DEFINITIONS[key]
	if frame<0 or frame>=int(d.count): return
	var extent:=Vector2(d.size[0],d.size[1])
	var origin:=Vector2(d.origin[0],d.origin[1])
	var clip:=clampf(crop_left-origin.x,0,extent.x)
	if clip>=extent.x: return
	var src:=Vector2(frame%int(d.columns),frame/int(d.columns))*extent
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_set_transform_matrix(pose)
	canvas.draw_texture_rect_region(FRAMES.TEXTURES[key],Rect2((origin+Vector2(clip,0))*scale,(extent-Vector2(clip,0))*scale),Rect2(src+Vector2(clip,0),extent-Vector2(clip,0)),tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func rock(canvas: CanvasItem, point: Vector2, direction: Vector2, elapsed: float, length: float, child: bool, size: float, clearance: float) -> void:
	if elapsed<0 or elapsed>=1.25: return
	var variant:=posmod(floori(point.dot(direction)/maxf(length,1)),5)
	var key: String=("branch" if child else "rock")+str(variant)
	var scale:=Vector2(length/107.0,1.0)*size
	var cut: float=(clearance-point.dot(direction))/maxf(scale.x,0.001)
	draw(canvas,key,mini(22,floori(elapsed*18)),Transform2D(direction.angle(),point),scale,Color.WHITE,cut)

static func spear(canvas: CanvasItem, direction: Vector2, tip: float, half_width: float, elapsed: float, duration: float, tint:=Color.WHITE) -> void:
	if elapsed<0 or elapsed>=duration+0.08: return
	var frame:=mini(12,floori(elapsed/(duration+0.08)*13))
	draw(canvas,"spear",frame,Transform2D(direction.angle(),Vector2.ZERO),Vector2(tip/220.0,maxf(0.25,half_width/23.0)),tint)
