extends Control
class_name ActiveCombatWeaponBar
## Battle-only display; the existing Esc WeaponStrip remains independent.

const COOLDOWN_SHADER := preload("res://shaders/ui/weapon_cooldown.gdshader")
class WeaponHeader extends Control:
	var number_source: Label
	var status_source: Label
	func _draw() -> void:
		var font := number_source.get_theme_font("font")
		for side in 2:
			var text := number_source.text if side == 0 else status_source.text
			var align := HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			draw_string_outline(font, Vector2(6, 17), text, align, size.x - 12, 12, 1, Color("101c20"))
			draw_string(font, Vector2(6, 17), text, align, size.x - 12, 12, Color("e1f4ff"))

var headers: Array[WeaponHeader] = []
var weapons: Array[WeaponInstance] = []
var cards: Array[Panel] = []
var icons: Array[TextureRect] = []
var cooldown_masks: Array[ColorRect] = []
var numbers: Array[Label] = []
var timers: Array[Label] = []
var selected_index := -1
var slot_size := 64.0
var preview_page := 0
var _normal_style: StyleBoxFlat
var _aim_style: StyleBoxFlat


func setup(sources: Array[WeaponInstance]) -> void:
	weapons = sources.duplicate()
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		child.queue_free()
	cards.clear()
	icons.clear()
	cooldown_masks.clear()
	numbers.clear()
	timers.clear()
	headers.clear()
	for i in weapons.size():
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _style(false))
		add_child(card)
		cards.append(card)
		var icon := TextureRect.new()
		icon.texture = load(str(weapons[i].weapon_data.icon))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		icons.append(icon)
		# A separate disk also covers transparent pixels around narrow weapon art.
		var mask := ColorRect.new()
		mask.name = "CooldownMask"
		mask.color = Color(0.16, 0.17, 0.18, 0.55)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = COOLDOWN_SHADER
		mask.material = material
		mask.hide()
		card.add_child(mask)
		cooldown_masks.append(mask)
		var number := _label(card, 12)
		number.text = str(i + 1) if i < 9 else "0" if i == 9 else "Tab·1"
		numbers.append(number)
		var timer := _label(card, 12)
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
	apply_layout()


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e1f4ff"))
	label.add_theme_color_override("font_outline_color", Color("101c20"))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label


func _style(selected: bool) -> StyleBoxFlat:
	if selected and _aim_style != null:
		return _aim_style
	if not selected and _normal_style != null:
		return _normal_style
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.028, 0.049, 0.052, 0.90)
	box.border_color = Color("c5edff") if selected else Color("455857")
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(3)
	if selected:
		_aim_style = box
	else:
		_normal_style = box
	return box


func apply_layout() -> void:
	var viewport_size := get_viewport_rect().size
	slot_size = clampf((viewport_size.x * 0.8 - maxf(0, weapons.size() - 1) * 7) / maxf(1, weapons.size()), 38, 64)
	size = Vector2(weapons.size() * (slot_size + 7) - 7, slot_size)
	position = Vector2((viewport_size.x - size.x) * 0.5, viewport_size.y - slot_size - 23)
	for i in cards.size():
		cards[i].position = Vector2(i * (slot_size + 7), 0)
		cards[i].size = Vector2.ONE * slot_size
		icons[i].position = Vector2(8, 14)
		icons[i].size = Vector2(slot_size - 16, slot_size - 18)
		cooldown_masks[i].position = Vector2(4, 4)
		cooldown_masks[i].size = Vector2.ONE * (slot_size - 8)
		numbers[i].position = Vector2(4, 0)
		timers[i].position = Vector2(20, 0)
		timers[i].size = Vector2(slot_size - 24, 20)
		headers[i].size = Vector2(slot_size, 22)
		headers[i].queue_redraw()


func update_slot(index: int, remaining: float, total: float, executing: bool, selected: bool) -> void:
	if index < 0 or index >= cards.size():
		return
	var fraction := 1.0 if executing else clampf(remaining / maxf(total, 0.001), 0, 1)
	(cooldown_masks[index].material as ShaderMaterial).set_shader_parameter("remaining", fraction)
	cooldown_masks[index].visible = fraction > 0.0
	var text := "施放中" if executing else "%d s" % ceili(remaining) if remaining > 0 else ""
	if timers[index].text != text:
		timers[index].text = text
		headers[index].queue_redraw()
	cards[index].add_theme_stylebox_override("panel", _style(selected))


func set_preview_page(page: int) -> void:
	preview_page = page
	for i in numbers.size():
		numbers[i].text = str(i + 1) if i < 9 else "0" if i == 9 else "Tab·1"
	if page == 1 and numbers.size() > 10:
		numbers[10].text = "1"
