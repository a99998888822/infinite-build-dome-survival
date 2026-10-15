extends RichTextLabel
class_name GoblinTradeRelicTerms
## The approved [icon] placeholder is an inline, hoverable item, not extra copy.

var relic: Dictionary = {}
var active_tooltip: PanelContainer
var _tooltip_label: Label
var _pointer_position := Vector2.ZERO
var _icon_hitbox: Control
var _body_parts := PackedStringArray()
var _tooltip_layout_frames := 0


func _ready() -> void:
	name = "RelicTerms"
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	selection_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	_icon_hitbox = Control.new()
	_icon_hitbox.name = "RelicHover"
	_icon_hitbox.mouse_filter = Control.MOUSE_FILTER_STOP
	_icon_hitbox.hide()
	_icon_hitbox.mouse_entered.connect(_show_relic_tooltip)
	_icon_hitbox.mouse_exited.connect(_hide_relic_tooltip)
	add_child(_icon_hitbox)
	resized.connect(func(): _layout_relic_hitbox.call_deferred())
	visibility_changed.connect(_hide_relic_tooltip)
	item_rect_changed.connect(_hide_relic_tooltip)


func configure(body: String, entry: Dictionary, reference: Label) -> void:
	_hide_relic_tooltip()
	relic = entry.duplicate(true)
	add_theme_font_override("normal_font", reference.get_theme_font("font"))
	add_theme_font_size_override("normal_font_size", reference.get_theme_font_size("font_size"))
	add_theme_color_override("default_color", reference.get_theme_color("font_color"))
	clear()
	_body_parts = body.split("[icon]", true, 1)
	add_text(_body_parts[0])
	add_image(_glowing_icon(str(entry.get("icon", ""))), 40, 40, Color.WHITE,
		INLINE_ALIGNMENT_CENTER)
	if _body_parts.size() > 1: add_text(_body_parts[1])
	_layout_relic_hitbox.call_deferred()


func _layout_relic_hitbox() -> void:
	if _body_parts.is_empty() or not is_instance_valid(_icon_hitbox): return
	# Images do not emit RichTextLabel's metadata hover signals. Shape the same
	# inline object to place a real hit target, including after text wraps.
	var paragraph := TextParagraph.new()
	var style := get_theme_stylebox("normal")
	paragraph.width = maxf(1, size.x - style.get_minimum_size().x)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | autowrap_trim_flags
	var font := get_theme_font("normal_font")
	var font_size := get_theme_font_size("normal_font_size")
	paragraph.add_string(_body_parts[0], font, font_size)
	paragraph.add_object("relic", Vector2(40, 40), INLINE_ALIGNMENT_CENTER)
	if _body_parts.size() > 1: paragraph.add_string(_body_parts[1], font, font_size)
	get_content_height()
	for line in paragraph.get_line_count():
		if not paragraph.get_line_objects(line).has("relic"): continue
		var rect := paragraph.get_line_object_rect(line, "relic")
		_icon_hitbox.position = rect.position + style.get_offset() + Vector2(0, get_line_offset(line))
		_icon_hitbox.size = rect.size
		_icon_hitbox.show()
		return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Pointer events use viewport coordinates, as does GameTooltipLayer.
		_pointer_position = event.position
		if is_instance_valid(active_tooltip) and active_tooltip.visible:
			_fit_relic_tooltip()


func _process(_delta: float) -> void:
	if _tooltip_layout_frames <= 0 or not is_instance_valid(active_tooltip) or not active_tooltip.visible: return
	# Label minimum heights settle after the container's first wrapping pass.
	active_tooltip.reset_size()
	_fit_relic_tooltip()
	_tooltip_layout_frames -= 1
	active_tooltip.modulate.a = 1.0 if _tooltip_layout_frames == 0 else 0.0


func _show_relic_tooltip() -> void:
	if relic.is_empty() or not is_visible_in_tree(): return
	if not is_instance_valid(active_tooltip):
		active_tooltip = PanelContainer.new()
		active_tooltip.add_theme_stylebox_override("panel", FinanceFrameSkin.box("panel", 12))
		active_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_tooltip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_tooltip_label = Label.new()
		_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tooltip_label.add_theme_font_size_override("font_size", 12)
		_tooltip_label.add_theme_color_override("font_color", FinanceUIStyle.TEXT)
		active_tooltip.add_child(_tooltip_label)
		GameTooltipLayer.for_owner(self).add_child(active_tooltip)
	_tooltip_label.text = L10n.record_text(relic, "display_name") + "\n" + L10n.record_text(relic, "description")
	var font := get_theme_font("normal_font")
	_tooltip_label.add_theme_font_override("font", font)
	var padding := active_tooltip.get_theme_stylebox("panel").get_minimum_size()
	var width := maxf(1, minf(286, get_viewport_rect().size.x - padding.x - 24))
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(_tooltip_label.text, font, 12)
	var height := ceilf(paragraph.get_size().y) + maxi(0, paragraph.get_line_count() - 1) * _tooltip_label.get_theme_constant("line_spacing")
	_tooltip_label.custom_minimum_size = Vector2(width, height)
	# Resolve wrapping at its real width before the panel asks for a minimum
	# height; the initial zero-width label otherwise expands the first popup.
	_tooltip_label.size = _tooltip_label.custom_minimum_size
	active_tooltip.reset_size()
	active_tooltip.size = _tooltip_label.custom_minimum_size + padding
	_fit_relic_tooltip()
	_tooltip_layout_frames = 2
	active_tooltip.modulate.a = 0.0
	active_tooltip.show()


func _fit_relic_tooltip() -> void:
	var bounds := get_viewport_rect()
	var point := _pointer_position + Vector2(14, 14)
	if point.x + active_tooltip.size.x > bounds.end.x - 12:
		point.x = _pointer_position.x - active_tooltip.size.x - 14
	point.x = clampf(point.x, 12, maxf(12, bounds.end.x - active_tooltip.size.x - 12))
	point.y = clampf(point.y, 12, maxf(12, bounds.end.y - active_tooltip.size.y - 12))
	active_tooltip.position = point.round()


func _hide_relic_tooltip() -> void:
	_tooltip_layout_frames = 0
	if is_instance_valid(active_tooltip): active_tooltip.hide()


static func _glowing_icon(path: String) -> Texture2D:
	var canvas := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var radius := Vector2(x - 23.5, y - 23.5).length() / 24.0
			var alpha := pow(maxf(0, 1.0 - radius), 0.8) * 0.85
			canvas.set_pixel(x, y, Color(0.66, 0.32, 0.95, alpha))
	var texture := FinanceUIStyle.item_icon(path)
	if texture != null:
		texture = ItemIconArt.texture_for(texture, 32)
		var source := texture.get_image()
		source.convert(Image.FORMAT_RGBA8)
		source.resize(32, 32, Image.INTERPOLATE_NEAREST)
		canvas.blend_rect(source, Rect2i(0, 0, 32, 32), Vector2i(8, 8))
	return ImageTexture.create_from_image(canvas)
