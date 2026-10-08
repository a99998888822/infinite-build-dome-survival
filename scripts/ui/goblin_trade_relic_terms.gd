extends RichTextLabel
class_name GoblinTradeRelicTerms
## The approved [icon] placeholder is an inline, hoverable item, not extra copy.

var relic: Dictionary = {}
var active_tooltip: PanelContainer


func _ready() -> void:
	name = "RelicTerms"
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	selection_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS


func configure(body: String, entry: Dictionary, reference: Label) -> void:
	relic = entry.duplicate(true)
	add_theme_font_override("normal_font", reference.get_theme_font("font"))
	add_theme_font_size_override("normal_font_size", reference.get_theme_font_size("font_size"))
	add_theme_color_override("default_color", reference.get_theme_color("font_color"))
	clear()
	var parts := body.split("[icon]", true, 1)
	add_text(parts[0])
	add_image(_glowing_icon(str(entry.get("icon", ""))), 40, 40, Color.WHITE,
		INLINE_ALIGNMENT_CENTER, Rect2(), null, false,
		L10n.source(relic.get("display_name", "")) + "\n" + L10n.source(relic.get("description", "")))
	if parts.size() > 1: add_text(parts[1])


func _make_custom_tooltip(for_text: String) -> Object:
	# Image tooltips use RichTextLabel's native hit testing and hover lifetime.
	active_tooltip = PanelContainer.new()
	active_tooltip.add_theme_stylebox_override("panel", FinanceFrameSkin.box("panel", 12))
	active_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = minf(286, get_viewport_rect().size.x - 48)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", FinanceUIStyle.TEXT)
	active_tooltip.add_child(label)
	return active_tooltip


static func _glowing_icon(path: String) -> Texture2D:
	var canvas := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var radius := Vector2(x - 23.5, y - 23.5).length() / 24.0
			var alpha := pow(maxf(0, 1.0 - radius), 0.8) * 0.85
			canvas.set_pixel(x, y, Color(0.66, 0.32, 0.95, alpha))
	var texture := FinanceUIStyle.item_icon(path)
	if texture != null:
		var source := texture.get_image()
		source.convert(Image.FORMAT_RGBA8)
		source.resize(32, 32, Image.INTERPOLATE_NEAREST)
		canvas.blend_rect(source, Rect2i(0, 0, 32, 32), Vector2i(8, 8))
	return ImageTexture.create_from_image(canvas)
