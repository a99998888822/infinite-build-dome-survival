extends Node2D
## Approved reaction names are on by default; comparisons can override them.
const FLAG := "element_reaction_text_r04_enabled"
const GROUP := "element_reaction_texts"
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const FONT_SIZE := 14
const DURATION := 0.82
const RISE := 40.0
const COLORS := {"thunder_fire": Color("ffc365"), "conduct": Color("c5eaff")}
const POOL_META := &"_idle_reaction_texts"
const MAX_IDLE := 128
static var _lines: Dictionary = {}
var kind := ""
var age := 0.0
var origin := Vector2.ZERO
var _line: TextLine


func _ready() -> void:
	L10n.locale_changed.connect(_on_locale_changed)


func _on_locale_changed() -> void:
	if visible and not kind.is_empty():
		_line = _line_for(kind)
		queue_redraw()


static func enabled() -> bool:
	return bool(GameGlobal.get_runtime_flag(FLAG, true))


static func spawn(parent: Node, reaction: String, at: Vector2) -> Node2D:
	if not enabled() or not COLORS.has(reaction) or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var idle: Array = parent.get_meta(POOL_META, [])
	var label: Node2D = null
	while not idle.is_empty():
		var candidate: Variant = idle.pop_back()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			label = candidate
			# New contacts retain the same painter order as newly created text.
			parent.move_child(label, -1)
			break
	if label == null:
		label = new()
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		label.z_index = 104
		parent.add_child(label)
	label.age = 0.0
	label.kind = reaction
	label._line = _line_for(reaction)
	label.set_physics_process(true)
	label.show()
	# Every reaction starts at its actual contact, including repeated hits.
	label.global_position = (at - label._line.get_size() * 0.5).round()
	label.origin = label.global_position
	label.add_to_group(GROUP)
	label._paint()
	label.queue_redraw()
	return label


static func _line_for(reaction: String) -> TextLine:
	# Shape each localized name once, instead of constructing a UI layout for
	# every target of a chain reaction. Keep at most the current locale's lines.
	var key := str(L10n.revision) + ":" + reaction
	if not _lines.has(key):
		if _lines.size() >= COLORS.size():
			_lines.clear()
		var line := TextLine.new()
		line.add_string(L10n.text("ui.combat.reaction." + reaction), FONT, FONT_SIZE)
		_lines[key] = line
	return _lines[key]


func _draw() -> void:
	if _line == null:
		return
	_line.draw_outline(get_canvas_item(), Vector2(1, 1), 1, Color(0.03, 0.05, 0.07, 0.7))
	_line.draw(get_canvas_item(), Vector2(1, 1), Color(0.03, 0.05, 0.07, 0.7))
	_line.draw_outline(get_canvas_item(), Vector2.ZERO, 2, Color("15212b"))
	_line.draw(get_canvas_item(), Vector2.ZERO, COLORS[kind])


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	age += delta
	if age >= DURATION or not enabled():
		cancel()
		return
	_paint()


func _paint() -> void:
	global_position = origin + Vector2(0, -roundf(RISE * clampf(age / DURATION, 0, 1)))
	modulate.a = minf(1.0, (age + 0.025) / 0.065) * (1.0 - smoothstep(0.56, DURATION, age))


func cancel() -> void:
	if not is_in_group(GROUP):
		return
	hide()
	set_physics_process(false)
	remove_from_group(GROUP)
	var parent := get_parent()
	if parent == null or parent.is_queued_for_deletion():
		queue_free()
		return
	if not parent.has_meta(POOL_META):
		parent.set_meta(POOL_META, [])
	var idle: Array = parent.get_meta(POOL_META)
	if idle.size() < MAX_IDLE:
		idle.append(self)
	else:
		queue_free()
