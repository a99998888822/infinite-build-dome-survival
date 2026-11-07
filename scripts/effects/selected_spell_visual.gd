extends RefCounted
## Playback only: all authored water/hole/ground-strike artwork is offline baked.
const FRAMES = preload("res://scripts/effects/selected_spell_frames.gd")
const FPS := 18.0

static func frame_at(key: String, time: float) -> int:
	return clampi(int(floor(time * FPS + 0.00001)), 0, int(FRAMES.DEFINITIONS[key].count)-1)

static func draw(canvas: CanvasItem, key: String, time: float, size := Vector2.ONE, tint := Color.WHITE) -> void:
	var d: Dictionary = FRAMES.DEFINITIONS[key]
	var extent := Vector2(d.size[0],d.size[1])
	var origin := Vector2(d.origin[0],d.origin[1])
	var frame := frame_at(key,time)
	canvas.draw_texture_rect_region(FRAMES.TEXTURES[key],Rect2(origin*size,extent*size),
		Rect2(Vector2(frame % int(d.columns),frame / int(d.columns))*extent,extent),tint)

static func hole_time(elapsed: float, duration: float) -> float:
	# Default duration remains the exact reviewed clip. Extra control duration
	# holds the middle; it never slows the attraction particles or damage clock.
	if duration <= 0.85001: return elapsed * 0.85 / maxf(duration,0.001)
	if elapsed < 0.56: return elapsed
	var remaining := duration-elapsed
	if remaining < 0.29: return 0.85-remaining
	return -1.0

static func warmup(parent: Node2D) -> void:
	for key in FRAMES.TEXTURES:
		var sprite := Sprite2D.new()
		sprite.texture = FRAMES.TEXTURES[key]
		sprite.region_enabled = true
		var d: Dictionary = FRAMES.DEFINITIONS[key]
		var extent := Vector2(d.size[0],d.size[1])
		var frame := mini(1,int(d.count)-1)
		sprite.region_rect = Rect2(Vector2(frame % int(d.columns),frame / int(d.columns))*extent,extent)
		sprite.set_meta("selected_spell_clip",key)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		parent.add_child(sprite)
