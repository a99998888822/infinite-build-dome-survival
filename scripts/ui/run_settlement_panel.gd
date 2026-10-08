extends Control
class_name RunSettlementPanel
## Read-only animation. A skip or repeated presentation never awards currency.

signal back_requested
const ICONS := preload("res://assets/ui/settlement/settlement_icons.png")
const GOBLIN := preload("res://assets/ui/settlement/goblin_reactions.png")
const GLINT := preload("res://assets/ui/settlement/payout_glint.png")
const DESK := preload("res://assets/ui/finance/bank_counter_desk_picxel.png")
const TEXT := Color("e4d9bd")
const GOLD := Color("d6b476")
const MUTED := Color("999e89")
var report: Dictionary = {}
var sound_enabled := true
var _config := RunSettlement.configuration()
var _elapsed := 0.0
var _last_stage := -1
var _voice_started := false
var _skipped := false
var _speech_text := ""
var _voice_path := ""
var _reaction_row := 0
var _card: Panel
var _title: Label
var _subtitle: Label
var _heading: Label
var _scroll: ScrollContainer
var _content: Control
var _left: Control
var _right: Control
var _monster_heading: Label
var _monster_scroll: ScrollContainer
var _monster_list: Control
var _monster_nodes: Array[Dictionary] = []
var _speech: Panel
var _speech_label: Label
var _portrait: TextureRect
var _desk: TextureRect
var _rows: Array[Dictionary] = []
var _conversion: Label
var _total: Panel
var _total_title: Label
var _total_value: Label
var _total_icon: TextureRect
var _status: Label
var back_button: Button
var _skip_hint: Label
var _cue: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _effects: Control


func _ready() -> void:
	L10n.locale_changed.connect(_refresh_language)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade := ColorRect.new()
	shade.color = Color("080f0d")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = _panel(self, "151e19", "8d7953")
	_title = _label(_card, "", 36, GOLD)
	_subtitle = _label(_card, "", 14, MUTED)
	_heading = _label(_card, "ui.settlement.camp_title", 20, GOLD)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scroll = ScrollContainer.new()
	FinanceUIStyle.scroll(_scroll)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_card.add_child(_scroll)
	_scroll.gui_input.connect(_gui_input)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_content)
	_left = Control.new()
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_left)
	_right = Control.new()
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_right)
	_monster_heading = _label(_left, "ui.settlement.kill_records", 20)
	_monster_scroll = ScrollContainer.new()
	_monster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_monster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_monster_scroll)
	_monster_list = Control.new()
	_monster_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monster_scroll.add_child(_monster_list)
	_speech = _panel(_left, "2a3023", "998252")
	_speech_label = _label(_speech, "", 18)
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portrait = _texture(_left, null)
	_desk = _texture(_left, DESK)
	var names := ["ui.settlement.total_kills", "ui.settlement.gold_earned", "ui.settlement.waves_survived", "ui.settlement.interest_earned"]
	for i in 4:
		var row := _panel(_right, "1b261f", "3f4b3b")
		var icon := _texture(row, _atlas(ICONS, Rect2(i * 32, 0, 32, 32)))
		var label := _label(row, names[i], 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		var value := _label(row, "0", 24)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var points := _label(row, "+0", 20, GOLD)
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rows.append({"panel": row, "icon": icon, "label": label, "value": value, "points": points})
	_conversion = _label(_right, "ui.settlement.conversion_hint", 12, MUTED)
	_conversion.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total = _panel(_right, "292c20", "9c834e")
	_total_icon = _texture(_total, _atlas(ICONS, Rect2(128, 0, 32, 32)))
	_total_title = _label(_total, "ui.settlement.camp_coins_earned", 18, GOLD)
	_total_value = _label(_total, "+ 0", 48, Color("ffe6a2"))
	_status = _label(_total, "", 12, Color("96bda3"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	back_button = Button.new()
	back_button.name = "ResultBackButton"
	back_button.text = "ui.common.return_to_main_menu"
	FinanceUIStyle.button(back_button)
	back_button.pressed.connect(func(): stop_audio(); back_requested.emit())
	_card.add_child(back_button)
	_skip_hint = _label(_card, "ui.settlement.skip_hint", 12, MUTED)
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cue = AudioStreamPlayer.new()
	_cue.bus = "SFX"
	_cue.volume_db = float(_config.presentation.cue_volume_db)
	add_child(_cue)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX"
	_voice.volume_db = float(_config.presentation.voice_volume_db)
	add_child(_voice)
	_effects = Control.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.draw.connect(_draw_effects)
	_content.add_child(_effects)
	resized.connect(_arrange)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): stop_audio())
	_arrange()


func present(data: Dictionary) -> void:
	if not report.is_empty() and str(report.get("run_id", "")) == str(data.get("run_id", "")):
		report["paid"] = bool(data.get("paid", false))
		seek(_elapsed)
		return
	stop_audio()
	_voice.stream = null
	report = data.duplicate(true)
	_elapsed = 0
	_last_stage = -1
	_voice_started = false
	_skipped = false
	_title.text = "ui.settlement.defeat"
	_subtitle.text = L10n.text("ui.settlement.victory") if bool(report.victory) else L10n.text("ui.settlement.death_wave") % int(report.get("end_wave", int(report.get("waves", 0)) + 1))
	_subtitle.text += L10n.text("ui.settlement.difficulty_suffix") % str(report.get("difficulty_id", BattleDifficulty.DEFAULT_ID))
	_heading.text = L10n.text("ui.settlement.multiplier") % roundi(float(report.get("difficulty_multiplier", 1.0)) * 100.0)
	_title.add_theme_color_override("font_color", GOLD if bool(report.victory) else Color("c78f79"))
	var reaction: Dictionary = _config.reactions.get(str(report.reaction), {})
	_speech_text = L10n.source(str(reaction.get("speech", "")))
	_voice_path = str(reaction.get("voice_path", "")).strip_edges()
	_reaction_row = int(reaction.get("row", 3))
	_speech_label.text = _speech_text
	for child in _monster_list.get_children():
		_monster_list.remove_child(child)
		child.queue_free()
	_monster_nodes.clear()
	var counts: Dictionary = report.get("monsters", {})
	var ids := counts.keys()
	ids.sort_custom(func(a: String, b: String): return int(counts[a]) > int(counts[b]) if counts[a] != counts[b] else a < b)
	for id: String in ids:
		var tile := _panel(_monster_list, "1e2821", "756748")
		var path := str(_config.monster_portraits.get(id, ""))
		var icon := _texture(tile, load(path) as Texture2D if ResourceLoader.exists(path) else _atlas(ICONS, Rect2(0, 0, 32, 32)))
		var label := _label(tile, L10n.source(str(DataRegistry.get_record("enemies", id).get("display_name", id))), 16)
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var count := _label(tile, "× 0", 18, GOLD)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_monster_nodes.append({"id": id, "tile": tile, "icon": icon, "label": label, "count": count, "amount": int(counts[id])})
	if ids.is_empty():
		_label(_monster_list, "ui.settlement.no_kills", 14, MUTED)
	var rates: Dictionary = _config.formula
	var tips := [L10n.text("ui.settlement.kills_tooltip") % int(rates.kills_per_coin),
		L10n.text("ui.settlement.gold_tooltip") % int(rates.gold_per_coin),
		L10n.text("ui.settlement.waves_tooltip") % int(rates.coins_per_wave),
		L10n.text("ui.settlement.interest_tooltip") % [int(rates.interest_per_coin), int(rates.interest_cap_per_wave)]]
	for i in 4:
		_rows[i].panel.tooltip_text = tips[i]
		_rows[i].panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.scroll_vertical = 0
	_arrange()
	seek(0)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or report.is_empty() or _skipped: return
	var next := _elapsed + delta
	var stage := -1
	for i in 5:
		if next >= float(_config.presentation.stage_times[i]): stage = i
	if stage > _last_stage:
		_last_stage = stage
		if sound_enabled and next < float(_config.presentation.voice_time):
			_cue.stream = load("res://assets/audio/sfx/settlement/stage_%d.wav" % (stage + 1))
			_cue.play()
	if not _voice_started and next >= float(_config.presentation.voice_time):
		_voice_started = true
		if sound_enabled and not _voice_path.is_empty() and ResourceLoader.exists(_voice_path, "AudioStream"):
			_voice.stream = load(_voice_path) as AudioStream
			if _voice.stream != null: _voice.play()
	seek(next)


func _refresh_language() -> void:
	if report.is_empty():
		return
	_subtitle.text = L10n.text("ui.settlement.victory") if bool(report.victory) else L10n.text("ui.settlement.death_wave") % int(report.get("end_wave", int(report.get("waves", 0)) + 1))
	_subtitle.text += L10n.text("ui.settlement.difficulty_suffix") % str(report.get("difficulty_id", BattleDifficulty.DEFAULT_ID))
	_heading.text = L10n.text("ui.settlement.multiplier") % roundi(float(report.get("difficulty_multiplier", 1.0)) * 100.0)
	var reaction: Dictionary = _config.reactions.get(str(report.reaction), {})
	_speech_text = L10n.source(reaction.get("speech", ""))
	for monster in _monster_nodes:
		monster.label.text = L10n.source(DataRegistry.get_record("enemies", str(monster.id)).get("display_name", monster.id))
	var rates: Dictionary = _config.formula
	var tips := [L10n.text("ui.settlement.kills_tooltip") % int(rates.kills_per_coin),
		L10n.text("ui.settlement.gold_tooltip") % int(rates.gold_per_coin),
		L10n.text("ui.settlement.waves_tooltip") % int(rates.coins_per_wave),
		L10n.text("ui.settlement.interest_tooltip") % [int(rates.interest_per_coin), int(rates.interest_cap_per_wave)]]
	for index in 4:
		_rows[index].panel.tooltip_text = tips[index]
	# Retain progress, payout state, and audio playback.
	seek(_elapsed)


func seek(seconds: float) -> void:
	_elapsed = seconds
	if report.is_empty(): return
	for i in 4:
		var progress := _progress(i)
		_rows[i].value.text = _number(roundi(int(report.values[i]) * progress))
		_rows[i].points.text = "+" + _number(roundi(int(report.contributions[i]) * progress))
		_rows[i].panel.modulate = Color.WHITE * (0.55 + progress * 0.45)
	for monster in _monster_nodes: monster.count.text = "× " + _number(roundi(int(monster.amount) * _progress(0)))
	_total_value.text = "+ " + _number(roundi(int(report.camp_currency) * _progress(4)))
	var pulse := maxf(0, 1 - absf(seconds - float(_config.presentation.stage_times[4]) - 0.3) / 0.3)
	_total_value.scale = Vector2.ONE * (1 + pulse * 0.07)
	_status.text = ("ui.settlement.saved" if bool(report.get("paid", false)) else "ui.settlement.save_failed") if _progress(4) >= 1 else "ui.settlement.counting"
	_conversion.text = "ui.settlement.base_conversion_hint"
	if _progress(4) >= 1:
		_conversion.text = L10n.text("ui.settlement.conversion") % [_number(int(report.get("base_camp_currency", report.camp_currency))), roundi(float(report.get("difficulty_multiplier", 1.0)) * 100.0), _number(int(report.camp_currency))]
	if bool(report.interest_capped) and _progress(3) >= 1:
		_conversion.text += L10n.text("ui.settlement.interest_cap_suffix")
	var voice_time := float(_config.presentation.voice_time)
	_speech.visible = seconds >= voice_time and not _speech_text.is_empty()
	_speech_label.visible_characters = -1 if _skipped else maxi(0, int((seconds - voice_time) * 18))
	var frame := int(seconds * 5) % 4 if not _skipped else 0
	var frame_size := GOBLIN.get_width() / 4.0
	_portrait.texture = _atlas(GOBLIN, Rect2(frame * frame_size, _reaction_row * frame_size, frame_size, frame_size))
	_effects.queue_redraw()


func skip() -> void:
	_skipped = true
	stop_audio()
	seek(20)


func stop_audio() -> void:
	if _cue != null: _cue.stop()
	if _voice != null: _voice.stop()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		skip()
		accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		skip()
		get_viewport().set_input_as_handled()


func _arrange() -> void:
	if _card == null: return
	var compact := size.x < 900 or size.y < 600
	var stacked := size.x < 540
	var short_window := size.y < 400 and not stacked
	var margin := 12.0 if compact else 24.0
	_card.size = Vector2(minf(960, size.x - margin * 2), minf(640 if stacked else 600, size.y - margin * 2))
	_card.position = (size - _card.size) * 0.5
	var padding := 12.0 if compact else 24.0
	var width := _card.size.x - padding * 2
	var header := 52.0 if compact else 72.0
	_place(_title, Vector2(padding, 4 if compact else 12), Vector2(width * 0.65, 26 if compact else 34), 24 if compact else 28)
	_place(_subtitle, Vector2(padding, 32 if compact else 46), Vector2(width * 0.65, 16 if compact else 18), 12 if compact else 14)
	_place(_heading, Vector2(padding + width * 0.65, 14 if compact else 20), Vector2(width * 0.35, 30), 14 if compact else 18)
	_scroll.position = Vector2(padding, header)
	_scroll.size = Vector2(width, _card.size.y - header - (52 if compact else 60))
	# Only scroll when the actual compact content cannot fit, rather than forcing
	# a desktop-sized minimum into shorter windows or both stacked columns.
	var stacked_offset := 252.0 if stacked else 0.0
	var body_height := maxf(228 if short_window else (252 if compact else 348), _scroll.size.y - stacked_offset)
	var left_width := width if stacked else (minf(196, width * 0.33) if compact else 300.0)
	var gap := 14.0 if compact else 24.0
	_left.position = Vector2.ZERO
	_left.size = Vector2(left_width, 238 if stacked else body_height)
	_right.position = Vector2(0, stacked_offset) if stacked else Vector2(left_width + gap, 0)
	_right.size = Vector2(width if stacked else width - left_width - gap, body_height)
	_content.custom_minimum_size = Vector2(width - 2, stacked_offset + body_height)
	_content.size = _content.custom_minimum_size
	_place(_monster_heading, Vector2.ZERO, Vector2(left_width, 25), 14 if compact else 18)
	_monster_scroll.position = Vector2(0, 23 if short_window else (28 if compact else 34))
	var columns := mini(2, maxi(1, _monster_nodes.size()))
	var rows := maxi(1, ceili(float(_monster_nodes.size()) / columns))
	var tile_gap := 6.0
	var tw := floorf((left_width - tile_gap * (columns - 1)) / columns)
	var th := 44.0 if short_window else (50.0 if stacked else (64.0 if compact else 92.0))
	var grid_height := rows * th + (rows - 1) * tile_gap
	_monster_scroll.size = Vector2(left_width, grid_height)
	_monster_list.custom_minimum_size = _monster_scroll.size
	for index in _monster_nodes.size():
		var monster: Dictionary = _monster_nodes[index]
		var tile: Control = monster.tile
		var name_font_size := 10 if compact else 12
		var line_height := 12.0 if compact else 18.0
		tile.position = Vector2((index % columns) * (tw + tile_gap), floorf(float(index) / columns) * (th + tile_gap))
		tile.size = Vector2(tw, th)
		monster.icon.position = Vector2(4, 3)
		monster.icon.size = Vector2(tw - 8, th - 2 * line_height - 6)
		_place(monster.label, Vector2(2, th - 2 * line_height - 2), Vector2(tw - 4, line_height), name_font_size)
		_place(monster.count, Vector2(2, th - line_height - 2), Vector2(tw - 4, line_height), 10 if compact else 14)
	var speech_y := _monster_scroll.position.y + grid_height + 8
	var speech_height := 44.0 if short_window or stacked else (52.0 if compact else 60.0)
	_speech.position = Vector2(0, speech_y)
	_speech.size = Vector2(left_width, speech_height)
	_place(_speech_label, Vector2(8, 7), _speech.size - Vector2(16, 14), 12 if compact else 16)
	var portrait_y := speech_y + speech_height + 2
	var portrait_height := maxf(52, _left.size.y - portrait_y)
	_portrait.position = Vector2(0, portrait_y)
	_portrait.size = Vector2(left_width, portrait_height * 0.84)
	_desk.position = Vector2(0, portrait_y + portrait_height * 0.57)
	_desk.size = Vector2(left_width, portrait_height * 0.43)
	var rw := _right.size.x
	var row_height := 31.0 if short_window else (34.0 if compact else 46.0)
	var row_gap := 4.0 if short_window else (5.0 if compact else 7.0)
	for i in 4:
		var row: Dictionary = _rows[i]
		row.panel.position = Vector2(0, i * (row_height + row_gap))
		row.panel.size = Vector2(rw, row_height)
		row.icon.position = Vector2(8, 5 if compact else 9)
		row.icon.size = Vector2.ONE * (24 if compact else 28)
		var value_x := rw * (0.40 if compact else 0.42)
		var label_x := 38.0 if compact else 48.0
		_place(row.label, Vector2(label_x, 0), Vector2(maxf(1, value_x - label_x - 6), row_height), 12 if compact else 16)
		_place(row.value, Vector2(value_x, 0), Vector2(rw * 0.35, row_height), 16 if compact else 22)
		_place(row.points, Vector2(rw * 0.76, 0), Vector2(rw * 0.24 - 10, row_height), 14 if compact else 18)
	var rows_end := 4 * (row_height + row_gap)
	_place(_conversion, Vector2(0, rows_end), Vector2(rw, 18), 10 if compact else 12)
	_total.position = Vector2(0, rows_end + (18 if short_window else 23))
	_total.size = Vector2(rw, 70 if short_window else (72 if compact else 104))
	var icon_size := 42.0 if compact else 56.0
	_total_icon.position = Vector2(12, 16 if compact else 24)
	_total_icon.size = Vector2.ONE * icon_size
	_place(_total_title, Vector2(icon_size + 24, 5 if compact else 8), Vector2(rw - icon_size - 36, 24), 12 if compact else 16)
	_place(_total_value, Vector2(icon_size + 24, 22 if compact else 28), Vector2(rw - icon_size - 36, 36 if compact else 52), 28 if compact else 40)
	_place(_status, Vector2(8, _total.size.y - 18), Vector2(rw - 16, 18), 10 if compact else 12)
	var button_width := minf(218, width * 0.45)
	back_button.position = Vector2(padding + (width - button_width) * 0.5, _card.size.y - (42 if compact else 48))
	back_button.size = Vector2(button_width, 30 if compact else 36)
	back_button.add_theme_font_size_override("font_size", 12 if compact else 16)
	_place(_skip_hint, Vector2(padding + width * 0.73, back_button.position.y), Vector2(width * 0.27, back_button.size.y), 10 if compact else 12)
	_skip_hint.visible = width >= 520
	_effects.size = _content.size


func _draw_effects() -> void:
	if report.is_empty() or _skipped: return
	for i in 5:
		var since := _elapsed - float(_config.presentation.stage_times[i])
		if since < 0 or since > 0.85: continue
		var target: Control = _total if i == 4 else _rows[i].panel
		var rect := Rect2(_right.position + target.position, target.size)
		var strength := (1 - since / 0.85) * (0.45 + i * 0.13)
		_effects.draw_rect(rect.grow(1), Color(GOLD, strength), false, 1 + i * 0.3)
		for k in (6 + i * 4):
			var p := Vector2(rect.end.x - 16 - fmod(since * 120 + k * 19, maxf(1, rect.size.x * 0.4)), rect.position.y + rect.size.y * 0.5 + sin(k * 2.3 + since * 9) * 12)
			_effects.draw_rect(Rect2(p, Vector2.ONE * (2 if i < 4 else 4)), Color(GOLD, strength))
		if i == 4:
			var center := rect.position + _total_icon.position + _total_icon.size * 0.5
			_effects.draw_texture_rect_region(GLINT, Rect2(center - Vector2(64, 64), Vector2(128, 128)), Rect2(mini(7, int(since * 10)) * 64, 0, 64, 64), Color(1, 1, 1, strength))


func _progress(stage: int) -> float:
	var t := clampf((_elapsed - float(_config.presentation.stage_times[stage])) / float(_config.presentation.count_seconds), 0, 1)
	return 1 - pow(1 - t, 3)


static func _number(value: int) -> String:
	var digits := str(value)
	var result := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0: result += ","
		result += digits[i]
	return result


static func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _panel(parent: Node, fill: String, edge: String) -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.add_theme_stylebox_override("panel", FinanceUIStyle.box(fill, edge, 0))
	parent.add_child(node)
	return node


func _label(parent: Node, value: String, font_size: int, color := TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FinanceUIStyle.label(label, font_size, color)
	parent.add_child(label)
	return label


func _texture(parent: Node, texture: Texture2D) -> TextureRect:
	var node := TextureRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(node)
	return node


func _place(node: Label, origin: Vector2, bounds: Vector2, font_size: int) -> void:
	node.position = origin
	node.size = bounds
	node.add_theme_font_size_override("font_size", font_size)
