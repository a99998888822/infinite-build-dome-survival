extends Node
class_name RecordingStudio
## Run this scene with F6. F8 returns here without recording camp progress.

const SAVE_PATH := "user://recording_studio/presets.json"
const SESSION_SCRIPT = preload("res://scripts/debug/recording_session.gd")
const GOLD := Color("ddbd78")
const INK := Color("111916")
var session: RecordingSession
var screen: Control
var columns: GridContainer
var form: GridContainer
var fields: Dictionary = {}
var weapon_box: VBoxContainer
var relic_box: VBoxContainer
var weapon_rows: Array[Dictionary] = []
var relic_rows: Array[Dictionary] = []
var preset_picker: OptionButton
var preset_name: LineEdit
var user_presets: Dictionary = {}
var storage_path := SAVE_PATH
var status: Label
var summary: Label
var start_button: Button
var countdown_label: Label
var overlay: Control
var busy := false
var _last_config: Dictionary = {}
var _restore_transient := false


func _ready() -> void:
	_restore_transient = not CampProgression._transient_session_active
	CampProgression.begin_transient_session()
	session = SESSION_SCRIPT.new()
	add_child(session)
	_build_ui()
	_load_saved_presets()
	_refresh_presets()
	set_config(RecordingSession.default_config())
	get_viewport().size_changed.connect(_arrange)
	_arrange()


func _exit_tree() -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	if _restore_transient: CampProgression.end_transient_session()


func _style(background: Color, border: Color = Color("3d4b40")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(text: String, parent: Node, size := 16, color := Color("e3e8dc")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent == form:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 144
	elif text == "Lv":
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(label)
	return label


func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _card(title: String, parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("1c2822")))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	if not title.is_empty(): _label(title, box, 18, GOLD)
	return box


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	screen = Control.new()
	var ui_theme := Theme.new()
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "sans-serif"])
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 15
	screen.theme = ui_theme
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(screen)
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	screen.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	_label("战斗录制台", layout, 28, GOLD)
	_label("选好一套构筑，直接进入镜头。临时会话 · 不计入正式存档", layout, 14, Color("9bb39f"))
	var preset_row := HBoxContainer.new()
	layout.add_child(preset_row)
	preset_picker = OptionButton.new()
	preset_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_picker.fit_to_longest_item = false
	preset_row.add_child(preset_picker)
	_button("载入预设", preset_row, _apply_preset)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	columns = GridContainer.new()
	columns.columns = 2
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("h_separation", 14)
	columns.add_theme_constant_override("v_separation", 14)
	scroll.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	var setup := _card("01 / 开场设置", left)
	form = GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	setup.add_child(form)
	_number("wave", "起始波次", 1, DataRegistry.get_table("waves").size())
	_option("difficulty", "难度", [["1", "难度 1"], ["2", "难度 2"], ["3", "难度 3"]])
	_label("角色", form)
	fields.character = _record_picker("characters", form)
	fields.character.item_selected.connect(func(_index): _update_summary())
	_number("level", "角色等级", 1, 200)
	_number("gold", "随身金币", 0, 10000000)
	_number("principal", "银行本金", 0, 10000000)
	_number("sanity_delta", "额外理智", -10000, 10000)
	_number("erosion_delta", "额外侵蚀", -10000, 10000)
	_option("entry", "开场位置", [["combat", "直接战斗"], ["bank", "先到银行备战"]])
	_number("countdown", "开场倒计时 / 秒", 0, 10)
	_label("战斗界面", form)
	var hud := CheckButton.new()
	hud.text = "显示 HUD"
	form.add_child(hud)
	fields.hud = hud
	_label("金币、本金为开波前余额；波初遗物仍正常生效。额外理智和侵蚀叠加在角色、遗物之上。", setup, 13, Color("9bb39f"))
	var build := _card("02 / 武器与附魔", right)
	_label("每把武器独立选择等级和附魔；空槽表示不装。", build, 13, Color("9bb39f"))
	weapon_box = VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 10)
	build.add_child(weapon_box)
	_button("＋ 添加武器", build, func():
		if weapon_rows.size() < 12: _add_weapon({"id": "weapon_void_blade", "level": 1, "attachments": []}))
	var relics := _card("03 / 遗物", right)
	_label("额外遗物；角色自带遗物会保留，数量遵循真实上限。", relics, 13, Color("9bb39f"))
	relic_box = VBoxContainer.new()
	relics.add_child(relic_box)
	_button("＋ 添加遗物", relics, func():
		if relic_rows.size() < 200: _add_relic({"id": "relic_steel_vault", "count": 1}))
	var review := _card("04 / 保存与操作", right)
	summary = _label("", review, 15)
	_label("F6 重拍同一配置　F7 暂停/继续\nF8 返回录制台　F9 显示/隐藏 HUD\nWASD / 方向键移动，战斗规则与正常游戏相同。", review, 14, Color("b8c9ba"))
	_label("重拍恢复起始配置，随机掉落与怪物位置可能不同。此页面负责开场配置，视频由你的录屏工具录制。", review, 13, Color("9bb39f"))
	preset_name = LineEdit.new()
	preset_name.placeholder_text = "方案名称，例如：第8波_火焰长枪"
	review.add_child(preset_name)
	_button("保存为我的方案", review, _save_preset)
	status = _label("", layout, 14, Color("e8b48d"))
	status.custom_minimum_size.y = 22
	start_button = _button("进入场景", layout, start_recording)
	start_button.add_theme_stylebox_override("normal", _style(Color("b18a4b"), GOLD))
	start_button.add_theme_color_override("font_color", Color("101710"))
	start_button.custom_minimum_size.y = 44
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	countdown_label = _label("", center, 48, GOLD)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.hide()


func _number(key: String, title: String, minimum: int, maximum: int) -> void:
	_label(title, form)
	var spin := _spin(form, minimum, maximum)
	fields[key] = spin
	spin.value_changed.connect(func(_value): _update_summary())


func _spin(parent: Node, minimum: int, maximum: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.custom_minimum_size = Vector2(90, 32)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin


func _option(key: String, title: String, items: Array) -> void:
	_label(title, form)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = false
	for item in items:
		option.add_item(item[1])
		option.set_item_metadata(option.item_count - 1, item[0])
	form.add_child(option)
	fields[key] = option


func _record_picker(table: String, parent: Node, empty := false) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(110, 34)
	option.fit_to_longest_item = false
	if empty:
		option.add_item("无附魔")
		option.set_item_metadata(0, "")
	for record in DataRegistry.get_table(table):
		if table == "characters" and not bool(record.get("enabled", true)): continue
		if table == "augmentations" and str(record.get("category", "")) not in WeaponLoadout.ATTACHABLE_ITEM_CATEGORIES: continue
		option.add_item(str(record.get("display_name", record.id)))
		option.set_item_metadata(option.item_count - 1, str(record.id))
		option.get_popup().set_item_tooltip(option.item_count - 1, str(record.get("description", "")))
	parent.add_child(option)
	return option


func _select(option: OptionButton, id: String) -> void:
	for index in option.item_count:
		if str(option.get_item_metadata(index)) == id:
			option.select(index)
			return


func _selected(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""


func _add_weapon(data: Dictionary) -> void:
	var box := _card("", weapon_box)
	var line := HBoxContainer.new()
	box.add_child(line)
	var picker := _record_picker("weapons", line)
	_select(picker, str(data.id))
	_label("Lv", line)
	var level := _spin(line, 1, int(DataRegistry.get_record("weapons", str(data.id)).get("max_level", 5)))
	level.size_flags_horizontal = Control.SIZE_FILL
	level.value = int(data.get("level", 1))
	var second := HBoxContainer.new()
	box.add_child(second)
	var first := _record_picker("augmentations", second, true)
	var last := _record_picker("augmentations", second, true)
	first.tooltip_text = "附魔 1"
	last.tooltip_text = "附魔 2（随武器品质开放）"
	var attachments: Array = data.get("attachments", [])
	if not attachments.is_empty(): _select(first, str(attachments[0]))
	if attachments.size() > 1: _select(last, str(attachments[1]))
	var row := {"picker": picker, "level": level, "first": first, "last": last, "panel": box.get_parent()}
	weapon_rows.append(row)
	_button("移除", line, func():
		weapon_rows.erase(row)
		row.panel.queue_free()
		_update_summary())
	picker.item_selected.connect(func(_index):
		level.max_value = int(DataRegistry.get_record("weapons", _selected(picker)).get("max_level", 5))
		_update_summary())
	level.value_changed.connect(func(_value): _update_summary())
	_update_summary()


func _add_relic(data: Dictionary) -> void:
	var line := HBoxContainer.new()
	relic_box.add_child(line)
	var picker := _record_picker("relics", line)
	_select(picker, str(data.id))
	var count := _spin(line, 1, 100)
	count.size_flags_horizontal = Control.SIZE_FILL
	count.value = int(data.get("count", 1))
	var row := {"picker": picker, "count": count, "panel": line}
	relic_rows.append(row)
	_button("移除", line, func():
		relic_rows.erase(row)
		line.queue_free()
		_update_summary())
	_update_summary()


func set_config(data: Dictionary) -> void:
	for key in fields:
		if fields[key] is SpinBox: fields[key].value = int(data.get(key, 0))
		elif fields[key] is OptionButton: _select(fields[key], str(data.get(key, "")))
		elif fields[key] is CheckButton: fields[key].button_pressed = bool(data.get(key, true))
	for row in weapon_rows: row.panel.free()
	for row in relic_rows: row.panel.free()
	weapon_rows.clear()
	relic_rows.clear()
	for row in data.get("weapons", []): _add_weapon(row)
	for row in data.get("relics", []): _add_relic(row)
	_update_summary()


func get_config() -> Dictionary:
	var result := {"weapons": [], "relics": []}
	for key in fields:
		if fields[key] is SpinBox:
			if fields[key].get_line_edit().has_focus(): fields[key].apply()
			result[key] = int(fields[key].value)
		elif fields[key] is OptionButton: result[key] = _selected(fields[key])
		elif fields[key] is CheckButton: result[key] = fields[key].button_pressed
	for row in weapon_rows:
		if row.level.get_line_edit().has_focus(): row.level.apply()
		var attachments: Array[String] = []
		for picker in [row.first, row.last]:
			var id := _selected(picker)
			if not id.is_empty(): attachments.append(id)
		result.weapons.append({"id": _selected(row.picker), "level": int(row.level.value), "attachments": attachments})
	for row in relic_rows:
		if row.count.get_line_edit().has_focus(): row.count.apply()
		result.relics.append({"id": _selected(row.picker), "count": int(row.count.value)})
	return result


func _update_summary() -> void:
	if summary == null or not fields.has("principal"): return
	var character := DataRegistry.get_record("characters", _selected(fields.character))
	summary.text = "%s · 第%d波 · 等级%d\n%d 把武器，%d 项额外遗物\n金币 %d / 本金 %d\n附魔兼容性、槽位和负载会在开场前检查。" % [
		str(character.get("display_name", "")), fields.wave.value, fields.level.value,
		weapon_rows.size(), relic_rows.size(), fields.gold.value, fields.principal.value]


func _arrange() -> void:
	columns.columns = 2 if get_viewport().get_visible_rect().size.x >= 1000 else 1


func _refresh_presets() -> void:
	preset_picker.clear()
	for name in RecordingSession.presets():
		preset_picker.add_item(name)
		preset_picker.set_item_metadata(preset_picker.item_count - 1, {"kind": "builtin", "name": name})
	for name in user_presets:
		preset_picker.add_item("我的 / " + str(name))
		preset_picker.set_item_metadata(preset_picker.item_count - 1, {"kind": "user", "name": name})


func _apply_preset() -> void:
	var selection: Dictionary = preset_picker.get_selected_metadata()
	var data: Dictionary = (RecordingSession.presets() if selection.kind == "builtin" else user_presets)[selection.name]
	var error := RecordingSession.validate(data)
	if not error.is_empty():
		status.text = "方案不能载入：" + error
		return
	set_config(data)
	preset_name.text = str(selection.name)
	status.text = "已载入：" + str(selection.name)


func _load_saved_presets() -> void:
	if not FileAccess.file_exists(storage_path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
	if not parsed is Dictionary:
		status.text = "保存的方案文件无效，已使用内置预设。"
		return
	for name in parsed:
		if parsed[name] is Dictionary: user_presets[str(name)] = parsed[name]


func _save_preset() -> void:
	var name := preset_name.text.strip_edges()
	if name.is_empty():
		status.text = "请先填写方案名称。"
		return
	var data := get_config()
	var error := RecordingSession.validate(data)
	if not error.is_empty():
		status.text = error
		return
	var next := user_presets.duplicate(true)
	next[name] = data
	DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		status.text = "方案保存失败。"
		return
	file.store_string(JSON.stringify(next, "\t"))
	file.close()
	user_presets = next
	_refresh_presets()
	status.text = "已保存：" + name + "（同名方案会覆盖）"


func start_recording() -> void:
	if busy: return
	await _start(get_config())


func _start(data: Dictionary) -> void:
	busy = true
	start_button.disabled = true
	status.text = "正在配置场景…"
	var error := await session.prepare(data)
	if not error.is_empty():
		await session.dispose()
		screen.show()
		status.text = error
		busy = false
		start_button.disabled = false
		return
	_last_config = data.duplicate(true)
	screen.hide()
	overlay.show()
	for remaining in range(int(data.countdown), 0, -1):
		countdown_label.text = "准备开场\n%d" % remaining
		await get_tree().create_timer(1.0).timeout
	overlay.hide()
	if not session.begin():
		await session.dispose()
		screen.show()
		status.text = "无法开始指定波次。"
	busy = false
	start_button.disabled = false


func return_to_studio() -> void:
	if busy: return
	busy = true
	overlay.hide()
	await session.dispose()
	screen.show()
	status.text = "可调整配置后再次开场。"
	busy = false


func _input(event: InputEvent) -> void:
	if busy or screen.visible or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F6:
			get_viewport().set_input_as_handled()
			await _start(_last_config)
		KEY_F7:
			session.toggle_pause()
			countdown_label.text = "已暂停\nF7 继续 · F8 返回"
			overlay.visible = session.paused
			get_viewport().set_input_as_handled()
		KEY_F8:
			get_viewport().set_input_as_handled()
			await return_to_studio()
		KEY_F9:
			session.set_hud_visible(not session.hud_visible)
			get_viewport().set_input_as_handled()
