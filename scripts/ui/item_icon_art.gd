extends RefCounted
class_name ItemIconArt
## Approved icon reductions, selected on layout changes and shared through atlases.

const CATALOG = preload("res://assets/ui/icons/clarity/catalog.gd")
const PIXEL_TEXTURE = preload("res://scripts/ui/weapon_pixel_texture.gd")
const BINDING_NAME := "ItemIconArtBinding"
const SOURCE_META := "item_icon_source"
const SIZE_META := "item_icon_pixels"
static var _atlases: Dictionary = {}
static var _textures: Dictionary = {}


static func source_path(texture: Texture2D) -> String:
	if texture == null: return ""
	if texture.has_meta(SOURCE_META): return str(texture.get_meta(SOURCE_META))
	if texture is AtlasTexture: return source_path(texture.atlas)
	return texture.resource_path


static func supports(texture: Texture2D) -> bool:
	return CATALOG.ITEMS.has(source_path(texture))


static func is_weapon(texture: Texture2D) -> bool:
	return supports(texture) and source_path(texture).begins_with("res://assets/ui/icons/weapons/")


static func physical_extent(control: Control, logical_extent: float, respect_parent_scale := false) -> float:
	if not control.is_inside_tree(): return logical_extent
	var factor := control.get_viewport().get_stretch_transform().get_scale().abs().x
	if respect_parent_scale:
		# Character selection has a separate, stable composition scale.
		factor *= control.get_global_transform_with_canvas().get_scale().abs().x / maxf(absf(control.scale.x), 0.001)
	return logical_extent * factor


static func texture_for(source: Texture2D, physical_pixels: float) -> Texture2D:
	var path := source_path(source)
	if not CATALOG.ITEMS.has(path): return source
	var item: Dictionary = CATALOG.ITEMS[path]
	var native := int(item.native_size)
	var cropped := source is AtlasTexture and not source.has_meta(SOURCE_META)
	var requested := roundi(physical_pixels * (native / maxf(source.get_width(), source.get_height()) if cropped else 1.0))
	var selected := native
	for size: int in item.variants:
		if absi(size - requested) < absi(selected - requested) or (absi(size - requested) == absi(selected - requested) and size < selected):
			selected = size
	return _texture_at(source, selected)


static func _texture_at(source: Texture2D, selected: int) -> Texture2D:
	var path := source_path(source)
	var item: Dictionary = CATALOG.ITEMS[path]
	var native := int(item.native_size)
	var cropped := source is AtlasTexture and not source.has_meta(SOURCE_META)
	if selected == native: return source
	var key := "%s:%d:%s" % [path, selected, str(cropped)]
	if _textures.has(key): return _textures[key]
	if not _atlases.has(selected):
		_atlases[selected] = load(CATALOG.ATLASES[selected]) as Texture2D
	var region: Array = item.variants[selected]
	var result := AtlasTexture.new()
	result.atlas = _atlases[selected]
	result.region = Rect2(region[0], region[1], region[2], region[3])
	if cropped:
		# Character-selection icons crop to their visible bounds. Retain the
		# repaired silhouette, including the newly continuous exterior pixels.
		result.region = Rect2(region[0] + region[4], region[1] + region[5], region[6], region[7])
	result.filter_clip = true
	result.set_meta(SOURCE_META, path)
	result.set_meta(SIZE_META, selected)
	_textures[key] = result
	return result


static func weapon_pixel_art(source: Texture2D, desired: float, minimum: float) -> Dictionary:
	var item: Dictionary = CATALOG.ITEMS[source_path(source)]
	var cropped := source is AtlasTexture and not source.has_meta(SOURCE_META)
	var target := maxf(desired, minimum)
	var native_extent := maxf(source.get_width(), source.get_height())
	var multiple := maxi(1, maxi(roundi(target / native_extent), ceili(minimum / native_extent)))
	var selected := int(item.native_size)
	var error := absf(native_extent * multiple - target)
	for size: int in item.variants:
		var region: Array = item.variants[size]
		var extent := maxf(region[6], region[7]) if cropped else float(size)
		if extent < minimum: continue
		var difference := absf(extent - target)
		if difference < error or (is_equal_approx(difference, error) and size < selected):
			error = difference
			selected = size
			multiple = 1
	return {"texture": _texture_at(source, selected), "multiple": multiple}


static func bind_texture(control: TextureRect, source: Texture2D, respect_parent_scale := false, minimum_pixels := 0.0, layout_owner: Control = null, logical_extent := 0.0) -> void:
	_bind(control, source, respect_parent_scale, minimum_pixels, layout_owner, logical_extent)


static func bind_button(control: Button, source: Texture2D, minimum_pixels := 0.0) -> void:
	_bind(control, source, false, minimum_pixels, null, 0.0)


static func _bind(control: Control, source: Texture2D, respect_parent_scale: bool, minimum_pixels: float, layout_owner: Control, logical_extent: float) -> void:
	var binding := control.get_node_or_null(BINDING_NAME) as IconBinding
	if binding == null and not supports(source):
		if control is TextureRect: control.texture = source
		else: (control as Button).icon = source
		return
	if binding == null:
		binding = IconBinding.new()
		binding.name = BINDING_NAME
		control.add_child(binding)
	binding.configure(source, respect_parent_scale, minimum_pixels, layout_owner, logical_extent)


static func refresh_branch(node: Node) -> void:
	var binding := node.get_node_or_null(BINDING_NAME) as IconBinding
	if binding != null: binding.request_refresh()
	for child in node.get_children():
		if not child is IconBinding: refresh_branch(child)


class IconBinding extends Node2D:
	var source: Texture2D
	var respect_parent_scale := false
	var refresh_count := 0
	var _pending := false
	var _original_filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE
	var minimum_pixels := 0.0
	var _layout_owner: Control
	var _logical_extent := 0.0
	var _base_minimum := Vector2.ZERO
	var _base_icon_width := 0
	var _had_icon_width := false
	var _reserved := false
	var _factor := Vector2.ZERO
	var pixel_texture: Texture2D
	@onready var control := get_parent() as Control


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_original_filter = control.texture_filter
		control.resized.connect(request_refresh)
		control.visibility_changed.connect(request_refresh)
		control.theme_changed.connect(request_refresh)
		get_viewport().size_changed.connect(request_refresh)
		request_refresh()


	func configure(texture: Texture2D, parent_scale: bool, minimum: float, layout_owner: Control, logical_extent: float) -> void:
		if _reserved and (not ItemIconArt.is_weapon(texture) or minimum <= 0.0):
			_restore_layout()
		source = texture
		respect_parent_scale = parent_scale
		minimum_pixels = minimum
		if not _reserved:
			_layout_owner = layout_owner
			_logical_extent = logical_extent
		request_refresh()


	func _notification(what: int) -> void:
		if what != NOTIFICATION_TRANSFORM_CHANGED or not _reserved or not is_instance_valid(control): return
		# Consume our inherited transform so future ancestor changes notify again.
		get_global_transform()
		# Scroll and ancestor movement change pixel alignment without resizing.
		control.queue_redraw()
		if is_inside_tree() and not _screen_factor().is_equal_approx(_factor): request_refresh()


	func _screen_factor() -> Vector2:
		return (control.get_viewport().get_stretch_transform() * control.get_global_transform_with_canvas()).get_scale().abs().max(Vector2(0.001, 0.001))


	func _reserve_layout() -> void:
		if _reserved: return
		if _layout_owner == null: _layout_owner = control
		_base_minimum = _layout_owner.custom_minimum_size
		if control is Button:
			_base_icon_width = control.get_theme_constant("icon_max_width")
			_had_icon_width = control.has_theme_constant_override("icon_max_width")
			_logical_extent = float(_base_icon_width) if _base_icon_width > 0 else minf(control.size.x, control.size.y)
		elif _logical_extent <= 0.0:
			_logical_extent = minf(control.size.x, control.size.y)
			if _logical_extent <= 0.0: _logical_extent = minf(_base_minimum.x, _base_minimum.y)
		_reserved = true
		set_notify_transform(true)
		get_global_transform()


	func _restore_layout() -> void:
		if is_instance_valid(_layout_owner): _layout_owner.custom_minimum_size = _base_minimum
		if is_instance_valid(control) and control is Button:
			if _had_icon_width: control.add_theme_constant_override("icon_max_width", _base_icon_width)
			else: control.remove_theme_constant_override("icon_max_width")
		_reserved = false
		set_notify_transform(false)
		pixel_texture = null


	func _fit_weapon() -> Texture2D:
		_reserve_layout()
		_factor = _screen_factor()
		var art := ItemIconArt.weapon_pixel_art(source, _logical_extent * minf(_factor.x, _factor.y), minimum_pixels)
		var pixels: Vector2 = art.texture.get_size() * art.multiple
		# One physical pixel on each side accommodates destination rounding.
		var minimum := _base_minimum.max((pixels + Vector2(2, 2)) / _factor)
		if control is Button:
			var padding := Vector2.ZERO
			for state in ["normal", "hover", "pressed", "disabled"]:
				padding = padding.max(control.get_theme_stylebox(state).get_minimum_size())
			minimum = _base_minimum.max((pixels + Vector2(2, 2)) / _factor + padding)
			var icon_width := ceili((pixels.x + 2.0) / _factor.x)
			if control.get_theme_constant("icon_max_width") != icon_width:
				control.add_theme_constant_override("icon_max_width", icon_width)
		if not _layout_owner.custom_minimum_size.is_equal_approx(minimum):
			_layout_owner.custom_minimum_size = minimum
		if pixel_texture == null: pixel_texture = ItemIconArt.PIXEL_TEXTURE.new()
		pixel_texture.configure(control, art.texture, art.multiple)
		pixel_texture.set_meta(ItemIconArt.SOURCE_META, ItemIconArt.source_path(source))
		control.queue_redraw()
		return pixel_texture


	func request_refresh() -> void:
		if _pending or not is_inside_tree(): return
		_pending = true
		_refresh.call_deferred()


	func _refresh() -> void:
		_pending = false
		if not is_inside_tree(): return
		refresh_count += 1
		var result := source
		if minimum_pixels > 0.0 and ItemIconArt.is_weapon(source):
			result = _fit_weapon()
			control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		elif ItemIconArt.supports(source):
			var extent := minf(control.size.x, control.size.y)
			if control is TextureRect and control.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED:
				extent = maxf(source.get_width(), source.get_height())
			elif control is Button:
				var maximum := control.get_theme_constant("icon_max_width")
				if maximum > 0: extent = minf(extent, maximum)
			result = ItemIconArt.texture_for(source, ItemIconArt.physical_extent(control, extent, respect_parent_scale))
			control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			control.texture_filter = _original_filter
		if control is TextureRect: control.texture = result
		else: (control as Button).icon = result
