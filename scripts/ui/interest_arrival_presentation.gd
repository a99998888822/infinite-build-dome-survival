extends Control
class_name InterestArrivalPresentation
## Receipt animation holds its final state until dismissed; balances are already settled.

signal finished
signal arrived(amount: int)

const FRAME := preload("res://assets/ui/finance/trade_panel.png")
const TICK := preload("res://assets/audio/sfx/finance/interest_tick.wav")
const BONUS := preload("res://assets/audio/sfx/finance/interest_bonus.wav")
const ARRIVE := preload("res://assets/audio/sfx/finance/interest_arrive.wav")
const GOLD := Color("f2d58a")
const LOSS := Color("de9380")
const ROW_ICON_SIZE := Vector2(20, 20)
const ROW_PADDING := 6
const ROW_COLUMN_GAP := 8
const FOOTER_HEIGHT := 56.0
var report: Dictionary = {}
var sound_enabled := true
var duration := 1.5
var final_time := 0.8
var _active := false
var _elapsed := 0.0
var _step_span := 0.2
var _last_step := -1
var _arrived := false
var _card: Control
var _shade: ColorRect
var _heading: Label
var _amount: Label
var _caption: Label
var _comparison: Label
var _skip_hint: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _row_nodes: Array[Control] = []
var _tick_audio: AudioStreamPlayer
var _event_audio: AudioStreamPlayer
var _effects: Control
var _wallet_target := Vector2(90, 54)
var _compact := false
var _receipt_bounds := Rect2()


func _ready() -> void:
	L10n.locale_changed.connect(_refresh_language)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 35
	_shade = ColorRect.new()
	_shade.color = Color("0b100bb3")
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(_gui_input)
	add_child(_card)
	var frame := NinePatchRect.new()
	frame.texture = FRAME
	frame.patch_margin_left = 12
	frame.patch_margin_right = 12
	frame.patch_margin_top = 12
	frame.patch_margin_bottom = 12
	FinanceFrameSkin.nine_patch(frame)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heading = _label(_card, 20, GOLD)
	_amount = _label(_card, 40, GOLD)
	_caption = _label(_card, 12, FinanceUIStyle.TEXT)
	_caption.text = "ui.interest.actual_received"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_amount, _caption]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_comparison = _label(_card, 12, FinanceUIStyle.GREEN)
	_skip_hint = _label(_card, 11, FinanceUIStyle.MUTED)
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scroll = ScrollContainer.new()
	FinanceUIStyle.bank_scroll(_scroll)
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 0)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_rows)
	_tick_audio = AudioStreamPlayer.new()
	_tick_audio.bus = "SFX"
	_tick_audio.stream = TICK
	_tick_audio.volume_db = -15
	add_child(_tick_audio)
	_event_audio = AudioStreamPlayer.new()
	_event_audio.bus = "SFX"
	_event_audio.volume_db = -10
	add_child(_event_audio)
	_effects = Control.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.draw.connect(_draw_effects)
	add_child(_effects)
	hide()


func present(data: Dictionary) -> void:
	stop()
	report = data.duplicate(true)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_nodes.clear()
	for step: Dictionary in report.steps:
		var row := MarginContainer.new()
		row.add_theme_constant_override("margin_top", ROW_PADDING)
		row.add_theme_constant_override("margin_bottom", ROW_PADDING)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(row)
		var columns := HBoxContainer.new()
		columns.name = "Columns"
		columns.add_theme_constant_override("separation", ROW_COLUMN_GAP)
		columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(columns)
		var icon := TextureRect.new()
		icon.name = "IconSlot"
		# Empty rows reserve the same column as relic rows. Keep the explicit
		# drawing bounds instead of the shared native-relic display size.
		icon.custom_minimum_size = ROW_ICON_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = FinanceUIStyle.item_icon(str(step.icon))
		columns.add_child(icon)
		var color := LOSS if step.kind == "loss" else (FinanceUIStyle.GREEN if step.kind == "growth" else FinanceUIStyle.TEXT)
		var label := _label(columns, 12, color)
		label.name = "Description"
		label.text = str(step.label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value := _label(columns, 14, GOLD if step.kind == "bonus" else color)
		value.name = "Value"
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.text = str(step.amount)
		row.modulate.a = 0
		_row_nodes.append(row)
	_heading.text = L10n.text("ui.interest.wave_title") % int(report.wave)
	_caption.text = "ui.interest.transferred_to_principal" if bool(report.get("auto_deposit", false)) else "ui.interest.actual_received"
	_comparison.text = L10n.text("ui.interest.income_summary") % [int(report.combat), int(report.total)]
	_skip_hint.text = "ui.interest.close_hint"
	_step_span = clampf(0.85 / maxf(1, report.steps.size()), 0.10, 0.24)
	final_time = 0.16 + _step_span * report.steps.size()
	duration = final_time + (0.80 if bool(report.special) else 0.65)
	_elapsed = 0
	_last_step = -1
	_arrived = false
	_active = true
	_scroll.scroll_vertical = 0
	show()
	if is_visible_in_tree(): grab_focus()
	arrange(size, _wallet_target, _receipt_bounds)
	seek(0)


func _refresh_language() -> void:
	if report.is_empty() or not report.has("source_payload"):
		return
	var updated := InterestArrivalReport.build(report.source_payload)
	if updated.is_empty() or updated.steps.size() != _row_nodes.size():
		return
	report = updated
	for index in _row_nodes.size():
		var row := _row_nodes[index]
		row.get_node("Columns/Description").text = str(report.steps[index].label)
		row.get_node("Columns/Value").text = str(report.steps[index].amount)
	_heading.text = L10n.text("ui.interest.wave_title") % int(report.wave)
	_comparison.text = L10n.text("ui.interest.income_summary") % [int(report.combat), int(report.total)]
	# No seek/present call: keep elapsed time, sounds and the arrival signal intact.


func arrange(bounds: Vector2, wallet_target: Vector2, receipt_bounds := Rect2()) -> void:
	size = bounds
	_wallet_target = wallet_target
	_receipt_bounds = receipt_bounds if receipt_bounds.has_area() else Rect2(Vector2.ZERO, bounds)
	if _card == null: return
	_compact = bounds.y < 400
	var rows_height := maxf(0, _row_nodes.size() - 1) * _rows.get_theme_constant("separation")
	for row in _row_nodes:
		rows_height += row.get_combined_minimum_size().y
	var rows_top := 94.0 if _compact else 128.0
	var footer_height := 48.0 if _compact else FOOTER_HEIGHT
	var content_height := maxf(206, rows_top + rows_height + footer_height)
	_card.size = Vector2(minf(550, _receipt_bounds.size.x), minf(content_height, _receipt_bounds.size.y))
	_card.position = (_receipt_bounds.position + (_receipt_bounds.size - _card.size) * 0.5).floor()
	_shade.position = _card.position - Vector2(4, 4)
	_shade.size = _card.size + Vector2(8, 8)
	_card.pivot_offset = _card.size * 0.5
	var w := _card.size.x
	var h := _card.size.y
	_heading.position = Vector2(20, 10 if _compact else 14)
	_heading.size = Vector2(w - 40, 26)
	_amount.position = Vector2(20, 38 if _compact else 44)
	_amount.size = Vector2(w - 40, 34 if _compact else 50)
	FinanceUIStyle.label(_amount, 28 if _compact else 40, GOLD)
	_caption.position = Vector2(20, 74 if _compact else 96)
	_caption.size = Vector2(w - 40, 16 if _compact else 18)
	FinanceUIStyle.label(_caption, 11 if _compact else 12, FinanceUIStyle.TEXT)
	_scroll.position = Vector2(20, rows_top)
	_scroll.size = Vector2(w - 40, maxf(ROW_ICON_SIZE.y + ROW_PADDING * 2, h - rows_top - footer_height))
	_comparison.position = Vector2(20, h - (42 if _compact else 46))
	_comparison.size = Vector2(w - 40, 18)
	_skip_hint.position = Vector2(20, h - (24 if _compact else 26))
	_skip_hint.size = Vector2(w - 40, 16)
	_scroll_to_current.call_deferred()
	_effects.queue_redraw()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if _active and is_visible_in_tree() and _elapsed < duration:
		seek(minf(_elapsed + delta, duration))


func seek(seconds: float) -> void:
	if not _active: return
	_elapsed = maxf(0, seconds)
	var index := clampi(floori((_elapsed - 0.16) / _step_span), -1, report.steps.size() - 1)
	var current := 0.0
	if index >= 0:
		var previous := float(report.steps[index - 1].target) if index > 0 else 0.0
		var progress := clampf((_elapsed - 0.16 - index * _step_span) / _step_span, 0, 1)
		current = lerpf(previous, float(report.steps[index].target), ease(progress, 0.4))
	for row_index in _row_nodes.size():
		_row_nodes[row_index].modulate.a = clampf((_elapsed - 0.16 - row_index * _step_span) / 0.10, 0, 1)
	if index > _last_step:
		_last_step = index
		if index >= 0:
			_scroll_to_current.call_deferred()
			if sound_enabled:
				_tick_audio.pitch_scale = 1.0 + mini(index, 6) * 0.07
				_tick_audio.play()
				if report.steps[index].kind == "bonus":
					_event_audio.stream = BONUS
					_event_audio.play()
	var landed := _elapsed >= final_time
	_amount.text = "+%d" % (int(report.total) if landed else roundi(current))
	_caption.visible = landed and int(report.total) > 0
	_comparison.modulate.a = 1.0 if landed else 0.35
	_shade.modulate.a = 1.0 - clampf((_elapsed - final_time - 0.20) / 0.30, 0, 1) * 0.75
	_amount.pivot_offset = _amount.size * 0.5
	_amount.scale = Vector2.ONE * (1.0 + sin(clampf((_elapsed - final_time) / 0.25, 0, 1) * PI) * (0.12 if bool(report.special) else 0.06))
	_card.scale = Vector2.ONE * lerpf(0.97, 1.0, clampf(_elapsed / 0.15, 0, 1))
	if landed and not _arrived:
		_arrived = true
		if sound_enabled and int(report.total) > 0:
			_event_audio.stream = ARRIVE
			_event_audio.play()
		arrived.emit(int(report.total))
	_effects.queue_redraw()


func _scroll_to_current() -> void:
	if _active and _last_step >= 0 and _last_step < _row_nodes.size():
		_scroll.scroll_vertical = maxi(0, int(_row_nodes[_last_step].get_rect().end.y - _scroll.size.y))


func _gui_input(event: InputEvent) -> void:
	if not _active: return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]):
		accept_event()
		skip()


func skip() -> void:
	if not _active: return
	if not _arrived:
		_arrived = true
		arrived.emit(int(report.total))
	stop()
	finished.emit()


func stop() -> void:
	_active = false
	if _tick_audio != null: _tick_audio.stop()
	if _event_audio != null: _event_audio.stop()
	hide()
	if _effects != null: _effects.queue_redraw()


func _draw_effects() -> void:
	if not _active: return
	var divider_y := _card.position.y + _scroll.position.y
	_effects.draw_line(Vector2(_card.position.x + 20, divider_y), Vector2(_card.get_rect().end.x - 20, divider_y), Color("74603e"))
	if _elapsed < final_time or int(report.total) <= 0: return
	var t := _elapsed - final_time
	var origin := _card.position + _amount.position + _amount.size * 0.5
	var count := 18 if bool(report.special) else 9
	for index in count:
		var progress := clampf((t - index * 0.012) / 0.42, 0, 1)
		if progress <= 0 or progress >= 1: continue
		var destination := _wallet_target
		if bool(report.get("auto_deposit", false)):
			destination = _card.position + _caption.position + _caption.size * 0.5
		var p := origin.lerp(destination, progress)
		p += Vector2(sin(index * 2.4) * 45 * sin(progress * PI), -sin(progress * PI) * (45 + index * 2))
		_effects.draw_rect(Rect2(p.round(), Vector2(6, 7)), Color("8f6229"))
		_effects.draw_rect(Rect2(p.round() + Vector2(1, 1), Vector2(4, 5)), GOLD)
	if t < 0.32:
		_effects.draw_arc(origin, 20 + t * 150, 0, TAU, 32, Color(1, 0.83, 0.38, (1 - t / 0.32) * 0.65), 2)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	FinanceUIStyle.label(label, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
