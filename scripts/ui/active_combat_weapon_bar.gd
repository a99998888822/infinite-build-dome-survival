extends Control
class_name ActiveCombatWeaponBar
signal slot_pressed(index: int)
## Battle-only display; the existing Esc WeaponStrip remains independent.

const COOLDOWN_SHADER := preload("res://shaders/ui/weapon_cooldown.gdshader")
const CAST_MODE_ICON_SCRIPT := preload("res://scripts/ui/weapon_cast_mode_icon.gd")
const PULSE_R02 := preload("res://scripts/ui/weapon_pulse_r02.gd")
const COOLDOWN_FEEDBACK := preload("res://scripts/ui/weapon_cooldown_feedback.gd")
const ICON_ART_PIXELS := 36.0
const LARGE_ICON_SIZE := 72.0
const SMALL_ICON_SIZE := 36.0
const LARGE_SLOT_SIZE := 108.0
const SMALL_SLOT_SIZE := 72.0
const LARGE_GAP := 10.0
const SMALL_GAP := 8.0
const ROW_GAP := 20.0
class PointerInput extends Node:
	func _input(event: InputEvent) -> void:
		get_parent()._input(event)

class WeaponHeader extends Control:
	var number_source: Label
	var status_source: Label
	var compact := false
	func _draw() -> void:
		var font := number_source.get_theme_font("font")
		for side in 2:
			var text := number_source.text if side == 0 else status_source.text
			var align := HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			var pixels := 14 if compact else 20
			var inset := 6 if compact else 10
			draw_string_outline(font, Vector2(inset, 21), text, align, size.x - inset * 2, pixels, 2, Color("101c20"))
			draw_string(font, Vector2(inset, 21), text, align, size.x - inset * 2, pixels, Color("e1f4ff"))

var headers: Array[WeaponHeader] = []
var feedbacks: Array[Control] = []
var weapons: Array[WeaponInstance] = []
var cards: Array[Panel] = []
var icons: Array[TextureRect] = []
var cooldown_masks: Array[ColorRect] = []
var numbers: Array[Label] = []
var timers: Array[Label] = []
var cast_mode_icons: Array[WeaponCastModeIcon] = []
var selected_index := -1
const CAST_MODE_SIZE := 23.333333
var slot_size := LARGE_SLOT_SIZE
var icon_size := LARGE_ICON_SIZE
var slot_gap := LARGE_GAP
var columns := 1
var preview_page := 0
var _normal_style: CombatHudFrame
var _aim_style: CombatHudFrame
var _pointer_position := Vector2.ZERO
var _has_pointer_position := false


func _ready() -> void:
	# Track movement during hitstop without advancing the bar's paused effects.
	var pointer_input := PointerInput.new()
	pointer_input.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pointer_input)
	set_process_input(false)


func setup(sources: Array[WeaponInstance]) -> void:
	weapons = sources.duplicate()
	mouse_filter = Control.MOUSE_FILTER_STOP
	for feedback in feedbacks: feedback.detach()
	feedbacks.clear()
	for child in get_children():
		if not child is PointerInput:
			child.queue_free()
	cards.clear()
	icons.clear()
	cooldown_masks.clear()
	numbers.clear()
	timers.clear()
	cast_mode_icons.clear()
	headers.clear()
	for i in weapons.size():
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _style(false))
		add_child(card)
		cards.append(card)
		var icon := TextureRect.new()
		icon.texture = combat_icon(load(str(weapons[i].weapon_data.icon)))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		icons.append(icon)
		# A separate disk also covers transparent pixels around narrow weapon art.
		var mask := ColorRect.new()
		mask.name = "CooldownMask"
		mask.color = Color(0.035, 0.05, 0.065, 0.82)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = COOLDOWN_SHADER
		mask.material = material
		mask.hide()
		card.add_child(mask)
		cooldown_masks.append(mask)
		var number := _label(card, 20)
		number.text = str(i + 1) if i < 9 else "0" if i == 9 else "Tab·1"
		numbers.append(number)
		var timer := _label(card, 20)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timers.append(timer)
		number.hide()
		timer.hide()
		var header := WeaponHeader.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.number_source = number
		header.status_source = timer
		card.add_child(header)
		headers.append(header)
		var pulse := PULSE_R02.new()
		card.add_child(pulse)
		pulse.configure(icon, weapons[i])
		var feedback := COOLDOWN_FEEDBACK.new()
		card.add_child(feedback)
		feedback.configure(weapons[i])
		feedbacks.append(feedback)
		var mode := CAST_MODE_ICON_SCRIPT.new() as WeaponCastModeIcon
		mode.icon_extent = CAST_MODE_SIZE
		mode.mask_padding = 1.666667
		mode.configure(weapons[i], false, _style(false).bg_color)
		add_child(mode)
		cast_mode_icons.append(mode)
	apply_layout()


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://assets/font/native_hud/interface.res"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e1f4ff"))
	label.add_theme_color_override("font_outline_color", Color("101c20"))
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label


func _style(selected: bool) -> CombatHudFrame:
	if selected and _aim_style != null:
		return _aim_style
	if not selected and _normal_style != null:
		return _normal_style
	var box := CombatHudFrame.make(1, selected)
	if selected:
		_aim_style = box
	else:
		_normal_style = box
	return box


static func combat_icon(source: Texture2D) -> Texture2D:
	# A single 36px grid at both tiers, independent of window output scaling.
	# Future approved native sources bypass the historical atlas.
	if source == null or source.get_size() == Vector2.ONE * ICON_ART_PIXELS:
		return source
	return ItemIconArt.texture_for(source, ICON_ART_PIXELS)


func apply_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var available := maxf(1.0, floorf(minf(viewport_size.x * 0.8, viewport_size.x - 32.0)))
	var count := weapons.size()
	var compact := count * LARGE_SLOT_SIZE + maxi(0, count - 1) * LARGE_GAP > available
	icon_size = SMALL_ICON_SIZE if compact else LARGE_ICON_SIZE
	slot_size = SMALL_SLOT_SIZE if compact else LARGE_SLOT_SIZE
	slot_gap = SMALL_GAP if compact else LARGE_GAP
	columns = maxi(1, mini(count, floori((available + slot_gap) / (slot_size + slot_gap))))
	var rows := ceili(float(count) / columns)
	var width := columns * slot_size + (columns - 1) * slot_gap if count > 0 else 0.0
	size = Vector2(width, rows * slot_size + maxi(0, rows - 1) * ROW_GAP + ceili(CAST_MODE_SIZE))
	position = Vector2(floorf((viewport_size.x - size.x) * 0.5), floorf(viewport_size.y - size.y - 38))
	for i in cards.size():
		var row := i / columns
		var row_count := mini(columns, count - row * columns)
		var row_width := row_count * slot_size + (row_count - 1) * slot_gap
		cards[i].position = Vector2(floorf((width - row_width) * 0.5) + (i % columns) * (slot_size + slot_gap), row * (slot_size + ROW_GAP))
		cards[i].size = Vector2.ONE * slot_size
		icons[i].position = Vector2((slot_size - icon_size) * 0.5, 24)
		icons[i].size = Vector2.ONE * icon_size
		icons[i].scale = Vector2.ONE
		cooldown_masks[i].position = Vector2(6, 6)
		cooldown_masks[i].size = Vector2.ONE * (slot_size - 12)
		numbers[i].position = Vector2(6.666667, 0)
		timers[i].position = Vector2(28, 0)
		timers[i].size = Vector2(slot_size - 34, 24)
		headers[i].size = Vector2(slot_size, 24)
		headers[i].compact = compact
		headers[i].queue_redraw()
		cast_mode_icons[i].position = cards[i].position + Vector2((slot_size - CAST_MODE_SIZE) * 0.5, slot_size - 1 - CAST_MODE_SIZE * 0.5)
		cast_mode_icons[i].size = Vector2.ONE * CAST_MODE_SIZE


func update_slot(index: int, remaining: float, total: float, executing: bool, selected: bool) -> void:
	if index < 0 or index >= cards.size():
		return
	var returning := weapons[index].is_return_ready()
	var icon_path := weapons[index].get_combat_icon_path()
	if icons[index].texture == null or ItemIconArt.source_path(icons[index].texture) != icon_path:
		icons[index].texture = combat_icon(load(icon_path))
	# Tome animation/return availability must not replace its running countdown.
	if returning or weapons[index].is_star_tome(): executing = false
	var fraction := 1.0 if executing else clampf(remaining / maxf(total, 0.001), 0, 1)
	(cooldown_masks[index].material as ShaderMaterial).set_shader_parameter("remaining", fraction)
	cooldown_masks[index].visible = fraction > 0.0 and not returning
	var text := L10n.text("ui.weapon_bar.casting") if executing else "%d s" % ceili(remaining) if remaining > 0 else ""
	if timers[index].text != text:
		timers[index].text = text
		headers[index].queue_redraw()
	# Mouse events already carry viewport coordinates. Polling the OS cursor
	# once per slot can block the combat frame on Windows.
	var pointer_local := cards[index].get_global_transform_with_canvas().affine_inverse() * _pointer_position
	var hovered := _has_pointer_position and Rect2(Vector2.ZERO, cards[index].size).has_point(pointer_local)
	var frame := _style(selected or hovered)
	if cards[index].get_theme_stylebox("panel") != frame:
		cards[index].add_theme_stylebox_override("panel", frame)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_position = event.position
		_has_pointer_position = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_has_pointer_position = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in cards.size():
			# The display badge overlaps the card; clicking it must not select/cast.
			if cast_mode_icons[i].get_rect().has_point(event.position):
				accept_event()
				return
			var manual_entry := weapons[i].is_mobility_weapon() or not CombatSettings.is_weapon_automatic(weapons[i])
			if manual_entry and Rect2(cards[i].position, cards[i].size).has_point(event.position):
				slot_pressed.emit(i)
				accept_event()
				return


func _get_tooltip(at_position: Vector2) -> String:
	for i in cards.size():
		if cards[i].get_rect().grow_individual(0, 0, 0, CAST_MODE_SIZE * 0.5).has_point(at_position):
			return cast_mode_icons[i].tooltip_text
	return ""


func set_preview_page(page: int) -> void:
	preview_page = page
	for i in numbers.size():
		numbers[i].text = str(i + 1) if i < 9 else "0" if i == 9 else "Tab·1"
	if page == 1 and numbers.size() > 10:
		numbers[10].text = "1"
