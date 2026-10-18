extends Sprite2D
## Pixel ground contact, independent of sprite hit offsets and animation poses.
## Textures are shared by footprint / air-height step, never rebuilt per frame.
const VISUAL_PROFILES = preload("res://scripts/effects/enemy_visual_profiles.gd")
const PROFILES = VISUAL_PROFILES.PROFILES
const INK := Color(0.035, 0.05, 0.055)
static var _textures: Dictionary = {}
var body: Node2D
var source: Sprite2D
var profile: Dictionary
var kind := ""
var footprint := Vector2i.ZERO
var _texture_key := Vector3i(-1, -1, -1)


func configure(enemy: Node2D) -> void:
	body = enemy
	source = body.get_node_or_null("Sprite2D") as Sprite2D
	kind = str(body.get("enemy_id"))
	profile = PROFILES.get(kind, PROFILES.enemy_mutated_grub)
	z_index = -2 # Below bodies and existing skill warnings, above the terrain.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_priority = 10
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(source):
		hide()
		return
	visible = source.visible and source.modulate.a * source.self_modulate.a > 0.001
	if not visible: return
	var factor := VISUAL_PROFILES.body_factor(body)
	var elevation := 0.0
	if kind == "enemy_underworld_wolf":
		elevation = clampf(float(body.get("air_height")) / 66.0, 0.0, 1.0)
	var air_step := roundi(elevation * 8.0)
	var spread := lerpf(1.0, 0.72, air_step / 8.0)
	var dimensions := Vector2(profile["size"]) * factor * spread
	# Whole world pixels, including challenge body scales and leap contraction.
	footprint = Vector2i(maxi(4, roundi(dimensions.x / 2.0) * 2), maxi(4, roundi(dimensions.y / 2.0) * 2))
	var key := Vector3i(footprint.x, footprint.y, air_step)
	if key != _texture_key:
		_texture_key = key
		var cache_key := "%s:%d:%d:%d" % [kind, key.x, key.y, key.z]
		if not _textures.has(cache_key): _textures[cache_key] = _make_texture(footprint, air_step)
		texture = _textures[cache_key]
	var anchor: Vector2 = profile.origin * factor
	if source.flip_h: anchor.x = -anchor.x
	position = anchor.round()
	# Only opacity follows the body fade. Hit flashes and status tints stay on art.
	modulate = Color(1, 1, 1, source.modulate.a * source.self_modulate.a * lerpf(1.0, 0.50, elevation))


func _make_texture(size: Vector2i, air_step: int) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var half := Vector2(size) * 0.5
	var cell := Vector2i(maxi(2, roundi(float(size.x) / float(profile["size"].x) * 4.0)), 2)
	var levels: Vector3 = profile.alpha
	for y in range(0, size.y, cell.y):
		for x in range(0, size.x, cell.x):
			var center := Vector2(x, y) + Vector2(cell) * 0.5 - half
			var distance := (center / half).length_squared()
			if distance > 0.96: continue
			var opacity := levels.x
			if distance < 0.64: opacity = levels.y
			if distance < 0.25: opacity = levels.z
			# Broad heel / paw contact patches; lift removes contact before the
			# detached shadow fades. No scattered pixels, rings or blur filters.
			if air_step < 2:
				var original_point := center * Vector2(profile["size"]) / Vector2(size)
				for pad: Rect2 in profile.pads:
					var normalized := (original_point - pad.get_center()) / (pad.size * 0.5)
					if normalized.length_squared() < 0.92:
						opacity = 0.54 if air_step == 0 else 0.43
			image.fill_rect(Rect2i(x, y, mini(cell.x, size.x - x), cell.y), Color(INK, opacity))
	return ImageTexture.create_from_image(image)
