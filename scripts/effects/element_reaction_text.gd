extends Label
## Approved reaction names are on by default; comparisons can override them.
const FLAG := "element_reaction_text_r04_enabled"
const GROUP := "element_reaction_texts"
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const FONT_SIZE := 14
const DURATION := 0.82
const RISE := 40.0
const COLORS := {"thunder_fire": Color("ffc365"), "conduct": Color("c5eaff")}
var kind := ""
var age := 0.0
var origin := Vector2.ZERO


static func enabled() -> bool:
	return bool(GameGlobal.get_runtime_flag(FLAG, true))


static func spawn(parent: Node, reaction: String, at: Vector2) -> Label:
	if not enabled() or not COLORS.has(reaction) or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var label := new()
	label.kind = reaction
	label.text = L10n.text("ui.combat.reaction." + reaction)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_index = 104
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLORS[reaction])
	label.add_theme_color_override("font_outline_color", Color("15212b"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.03,0.05,0.07,0.7))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	label.reset_size()
	# Every reaction starts at its actual contact, including repeated hits.
	label.global_position = (at - label.size * 0.5).round()
	label.origin = label.global_position
	label.add_to_group(GROUP)
	label._paint()
	return label


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
	hide()
	queue_free()
