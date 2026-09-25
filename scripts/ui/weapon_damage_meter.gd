extends Control
## Damage is recorded by the wave, so opening UI or rebinding the HUD cannot reset it.

const ROW_HEIGHT := 24.0
const ROW_GAP := 7.0
const HEADER_HEIGHT := 22.0
const FONT_SIZE := 10
const COLORS: Array[Color] = [Color("8d7542"), Color("4b8179"), Color("796393"), Color("8c5749"), Color("577c9a"), Color("748653")]

var _manager: WaveManager
var _loadout: WeaponLoadout
var _dirty := true
var _elapsed := 0.0
var _entries: Array[Dictionary] = []
var _icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func bind_context(manager: WaveManager, loadout: WeaponLoadout) -> void:
	if is_instance_valid(_manager) and _manager.weapon_damage_changed.is_connected(_mark_dirty):
		_manager.weapon_damage_changed.disconnect(_mark_dirty)
	if is_instance_valid(_loadout) and _loadout.loadout_changed.is_connected(_mark_dirty):
		_loadout.loadout_changed.disconnect(_mark_dirty)
	_manager = manager
	_loadout = loadout
	if _manager != null:
		_manager.weapon_damage_changed.connect(_mark_dirty)
	if _loadout != null:
		_loadout.loadout_changed.connect(_mark_dirty)
	refresh()


func _mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _dirty and _elapsed >= 0.1:
		refresh()


func refresh() -> void:
	_dirty = false
	_elapsed = 0.0
	_entries.clear()
	if not is_instance_valid(_manager) or not is_instance_valid(_loadout):
		queue_redraw()
		return
	var ids: Array[String] = []
	for weapon in _loadout.get_weapon_instances():
		ids.append(weapon.weapon_id)
	for weapon_id in _manager.weapon_damage_this_wave:
		if not ids.has(weapon_id):
			ids.append(weapon_id)
	for index in ids.size():
		var weapon_id := ids[index]
		var data := DataRegistry.get_record("weapons", weapon_id)
		if not _icons.has(weapon_id):
			var path := str(data.get("icon", ""))
			_icons[weapon_id] = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
		_entries.append({
			"weapon_id": weapon_id, "name": str(data.get("display_name", weapon_id)),
			"damage": int(_manager.weapon_damage_this_wave.get(weapon_id, 0)),
			"order": index, "color": COLORS[index % COLORS.size()], "icon": _icons[weapon_id],
		})
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.damage) > int(b.damage) if a.damage != b.damage else int(a.order) < int(b.order))
	size.y = HEADER_HEIGHT + _entries.size() * (ROW_HEIGHT + ROW_GAP)
	queue_redraw()


func _draw() -> void:
	if _entries.is_empty():
		return
	var font := get_theme_font("font", "Label")
	draw_string(font, Vector2(3, 15), "统计", HORIZONTAL_ALIGNMENT_LEFT, size.x, 11, Color("c7c6a7"))
	var maximum := maxi(int(_entries[0].damage), 1)
	for index in _entries.size():
		var entry := _entries[index]
		var y := HEADER_HEIGHT + index * (ROW_HEIGHT + ROW_GAP)
		var rect := Rect2(0, y, size.x, ROW_HEIGHT)
		draw_rect(rect, Color(0.025, 0.04, 0.035, 0.87))
		var fill_width := size.x * float(entry.damage) / float(maximum)
		if fill_width > 0:
			draw_rect(Rect2(0, y, fill_width, ROW_HEIGHT), entry.color)
		draw_rect(rect, Color(0.43, 0.46, 0.34, 0.45), false, 1.0)
		var icon := entry.icon as Texture2D
		if icon != null:
			var icon_size := icon.get_size() * (16.0 / maxf(icon.get_width(), icon.get_height()))
			draw_texture_rect(icon, Rect2(Vector2(11, y + ROW_HEIGHT * 0.5) - icon_size * 0.5, icon_size), false)
		var amount := _format_damage(int(entry.damage))
		var amount_width := font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var name_width := maxf(size.x - amount_width - 32, 0)
		var weapon_name := str(entry.name)
		while weapon_name.length() > 1 and font.get_string_size(weapon_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > name_width:
			weapon_name = weapon_name.substr(0, weapon_name.length() - 2) + "…"
		_draw_text(font, Vector2(23, y + 16), weapon_name)
		_draw_text(font, Vector2(size.x - amount_width - 5, y + 16), amount)


func _draw_text(font: Font, at: Vector2, text: String) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color(0.015, 0.025, 0.02, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("f0ecda"))


func _format_damage(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
