extends Control
class_name EconomyLogPanel

const PANEL_HEIGHT := 160.0
const COMPACT_PANEL_HEIGHT := 128.0

var toggle_button: Button
var panel: PanelContainer
var log_text: RichTextLabel
var _journal: EconomyJournal
var _last_sequence := 0
var _open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toggle_button = Button.new()
	toggle_button.name = "EconomyLogToggle"
	toggle_button.text = "日志"
	toggle_button.tooltip_text = "展开 / 收起本局经济日志；查看战斗收入、结息与存取款"
	toggle_button.focus_mode = Control.FOCUS_NONE
	FinanceUIStyle.button(toggle_button)
	toggle_button.pressed.connect(func(): set_open(not _open))
	add_child(toggle_button)
	panel = PanelContainer.new()
	panel.name = "EconomyLogBody"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111d1bb3")
	style.border_color = Color("99845799")
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var heading := Label.new()
	heading.name = "LogTitle"
	heading.text = "日志"
	heading.tooltip_text = "保留本局最近 300 条记录"
	heading.add_theme_color_override("font_color", Color("e0c68a"))
	heading.add_theme_font_size_override("font_size", 13)
	column.add_child(heading)
	log_text = RichTextLabel.new()
	log_text.name = "EconomyLogText"
	log_text.bbcode_enabled = false
	log_text.selection_enabled = true
	log_text.scroll_active = true
	log_text.fit_content = false
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.add_theme_color_override("default_color", Color("dddac7"))
	log_text.add_theme_font_size_override("normal_font_size", 13)
	log_text.add_theme_constant_override("line_separation", 2)
	column.add_child(log_text)
	panel.hide()
	apply_layout()


func bind_journal(journal: EconomyJournal) -> void:
	if _journal == journal:
		return
	if _journal != null and _journal.changed.is_connected(_refresh_entries):
		_journal.changed.disconnect(_refresh_entries)
	_journal = journal
	if _journal != null:
		_journal.changed.connect(_refresh_entries)
	_last_sequence = 0
	set_open(false)
	_refresh_entries()


func set_open(open: bool) -> void:
	_open = open
	panel.visible = open
	toggle_button.button_pressed = open
	FinanceUIStyle.button(toggle_button, open)
	if open:
		_scroll_to_end.call_deferred()


func apply_layout() -> void:
	if toggle_button == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := OS.has_feature("mobile")
	var button_y := maxf(50, viewport_size.y - (200 if mobile else 82))
	toggle_button.position = Vector2(10, button_y)
	toggle_button.size = Vector2(52, 32)
	var height := minf(_panel_height_limit(), maxf(0, button_y - 60))
	panel.position = Vector2(10, button_y - height - 6)
	panel.size = Vector2(minf(400, viewport_size.x - 24), height)


func apply_finance_layout(content_rect: Rect2, button_rect: Rect2) -> void:
	toggle_button.position = button_rect.position
	toggle_button.size = button_rect.size
	var height := minf(_panel_height_limit(), maxf(0, button_rect.position.y - content_rect.position.y - 6))
	panel.position = Vector2(content_rect.position.x, button_rect.position.y - height - 6)
	panel.size = Vector2(minf(400, content_rect.size.x), height)


func _panel_height_limit() -> float:
	return COMPACT_PANEL_HEIGHT if get_viewport().get_visible_rect().size.y < 480 else PANEL_HEIGHT


func _refresh_entries() -> void:
	if _journal == null or log_text == null:
		return
	var bar := log_text.get_v_scroll_bar()
	var follow := bar.value >= bar.max_value - bar.page - 4
	var latest := int(_journal.entries[-1].sequence) if not _journal.entries.is_empty() else 0
	if latest < _last_sequence:
		set_open(false)
	_last_sequence = latest
	var lines: PackedStringArray = []
	for entry in _journal.entries:
		lines.append("第 %d 波 · %s" % [int(entry.get("wave", 1)), str(entry.text)])
	log_text.text = "\n".join(lines) if not lines.is_empty() else "本局暂无经济记录。"
	if follow and _open:
		_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	if is_instance_valid(log_text):
		log_text.scroll_to_line(maxi(0, log_text.get_line_count() - 1))
