extends Texture2D
## Draw inside the owning Control's canvas item, retaining its clips and states.
## Art variants share one logical footprint, rounded only at the screen boundary.

var texture: Texture2D
var logical_size := Vector2.ZERO
var owner_ref: WeakRef
var last_local_rect := Rect2()
var last_modulate := Color.WHITE
var draw_count := 0


func configure(owner: Control, image: Texture2D, display_size: Vector2) -> void:
	owner_ref = weakref(owner)
	if texture == image and logical_size == display_size: return
	texture = image
	logical_size = display_size
	set_meta("item_icon_source", image.get_meta("item_icon_source", image.resource_path))
	set_meta("item_icon_pixels", image.get_meta("item_icon_pixels", image.get_width()))
	emit_changed()


func physical_size() -> Vector2:
	var owner := owner_ref.get_ref() as Control if owner_ref != null else null
	if texture == null or owner == null or not owner.is_inside_tree(): return Vector2.ZERO
	return (logical_size * screen_transform(owner).get_scale().abs()).round().max(Vector2.ONE)


static func screen_transform(owner: CanvasItem) -> Transform2D:
	var viewport := owner.get_viewport()
	if not viewport.snap_2d_transforms_to_pixel:
		return viewport.get_stretch_transform() * owner.get_global_transform_with_canvas()
	# The canvas renderer rounds each inherited transform, not just the leaf.
	# Reproduce that order before choosing an integer-pixel draw rectangle.
	var chain: Array[CanvasItem] = []
	var item: CanvasItem = owner
	while item != null:
		chain.push_front(item)
		if item.is_set_as_top_level(): break
		item = item.get_parent() as CanvasItem
	var result := viewport.get_stretch_transform() * owner.get_canvas_transform()
	for ancestor in chain:
		var local := ancestor.get_transform()
		if ancestor is Control and viewport.gui_snap_controls_to_pixels:
			local.origin = local.origin.round()
		result = result * local
		result.origin = result.origin.round()
	return result


func _get_width() -> int:
	return ceili(logical_size.x) if texture != null else 0


func _get_height() -> int:
	return ceili(logical_size.y) if texture != null else 0


func _has_alpha() -> bool: return true


func _get_rid() -> RID:
	return texture.get_rid() if texture != null else RID()


func _get_image() -> Image:
	return texture.get_image() if texture != null else null


func _is_pixel_opaque(x: int, y: int) -> bool:
	if texture == null: return false
	var point := Vector2(x, y) * texture.get_size() / get_size()
	return texture.is_pixel_opaque(int(point.x), int(point.y))


func _draw(item: RID, pos: Vector2, color: Color, transpose: bool) -> void:
	_draw_rect(item, Rect2(pos, get_size()), false, color, transpose)


func _draw_rect(item: RID, rect: Rect2, tile: bool, color: Color, transpose: bool) -> void:
	if texture == null: return
	last_local_rect = _fit_rect(rect, physical_size()) if not tile else rect
	last_modulate = color
	draw_count += 1
	texture.draw_rect(item, last_local_rect, tile, color, transpose)


func _draw_rect_region(item: RID, rect: Rect2, region: Rect2, color: Color, transpose: bool, clip_uv: bool) -> void:
	if texture == null: return
	var source_factor := texture.get_size() / get_size()
	var source_region := Rect2(region.position * source_factor, region.size * source_factor)
	last_local_rect = _fit_rect(rect, physical_size() * region.size.abs() / get_size())
	last_modulate = color
	draw_count += 1
	texture.draw_rect_region(item, last_local_rect, source_region, color, transpose, clip_uv)


func _fit_rect(rect: Rect2, pixels: Vector2) -> Rect2:
	var owner := owner_ref.get_ref() as Control if owner_ref != null else null
	if owner == null or not owner.is_inside_tree(): return rect
	var transform := screen_transform(owner)
	# Leave explicit rotation/flip effects to their original drawing behavior.
	if absf(transform.x.y) > 0.001 or absf(transform.y.x) > 0.001 or transform.determinant() <= 0.0:
		return rect
	var physical := transform * rect.abs()
	physical = Rect2((physical.get_center() - pixels * 0.5).round(), pixels)
	var local := transform.affine_inverse() * physical
	if rect.size.x < 0:
		local.position.x += local.size.x
		local.size.x = -local.size.x
	if rect.size.y < 0:
		local.position.y += local.size.y
		local.size.y = -local.size.y
	return local
