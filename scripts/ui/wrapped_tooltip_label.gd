extends Label
class_name WrappedTooltipLabel
## Keep economic explanations readable and inside small game windows.


func _make_custom_tooltip(for_text: String) -> Object:
	var content := Label.new()
	content.text = for_text
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.custom_minimum_size.x = minf(320.0, get_viewport_rect().size.x - 48.0)
	content.size.x = content.custom_minimum_size.x
	var face := get_theme_font("font")
	content.add_theme_font_override("font", face)
	content.add_theme_font_size_override("font_size", 14)
	var paragraph := TextParagraph.new()
	paragraph.width = content.custom_minimum_size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(for_text, face, 14)
	# Popup placement happens before its first layout pass: provide height upfront.
	content.custom_minimum_size.y = paragraph.get_size().y + maxf(0, paragraph.get_line_count() - 1) * content.get_theme_constant("line_spacing")
	content.add_theme_color_override("font_color", Color("f1e6d2"))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14201dfc")
	style.border_color = Color("8c9274")
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel
