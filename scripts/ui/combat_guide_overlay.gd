extends CanvasLayer
class_name CombatGuideOverlay
## Static walkthrough: production views under an input-blocking spotlight.
## Flow owns pause/resume and the first-wave gate; this layer only presents it.

class Spotlight extends Control:
	var focus_rect := Rect2()
	var ground_demo := false
	var origin := Vector2.ZERO
	var destination := Vector2.ZERO
	const ACCENT := Color("e2c682")

	func _draw() -> void:
		var hole := focus_rect.intersection(Rect2(Vector2.ZERO, size))
		var gray := Color(0.16, 0.17, 0.17, 0.82)
		draw_rect(Rect2(0, 0, size.x, hole.position.y), gray)
		draw_rect(Rect2(0, hole.end.y, size.x, size.y - hole.end.y), gray)
		draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), gray)
		draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), gray)
		draw_rect(hole, ACCENT, false, 2)
		if not ground_demo: return
		var start := origin + Vector2(24, 10)
		var end := destination - Vector2(22, 0)
		draw_dashed_line(start, end, ACCENT, 2, 7)
		draw_line(end, end + Vector2(-9, -6), ACCENT, 2)
		draw_line(end, end + Vector2(-9, 6), ACCENT, 2)
		draw_arc(destination, 18, 0, TAU, 40, ACCENT, 2, true)
		draw_arc(destination, 9, 0, TAU, 32, ACCENT, 2, true)
		for offset in [Vector2(0, 23), Vector2(0, -23), Vector2(23, 0), Vector2(-23, 0)]:
			draw_line(destination + offset * 0.75, destination + offset * 1.2, ACCENT, 2)
		# Fixed mouse illustration: the right button is filled, no synthetic click.
		var mouse := destination + Vector2(34, -54)
		var shell := StyleBoxFlat.new()
		shell.bg_color = Color("19231e")
		shell.border_color = ACCENT
		shell.set_border_width_all(2)
		shell.set_corner_radius_all(14)
		draw_style_box(shell, Rect2(mouse, Vector2(40, 62)))
		var right := StyleBoxFlat.new()
		right.bg_color = ACCENT
		right.corner_radius_top_right = 11
		draw_style_box(right, Rect2(mouse + Vector2(21, 3), Vector2(16, 25)))
		draw_line(mouse + Vector2(20, 0), mouse + Vector2(20, 30), ACCENT, 2)
		draw_line(mouse + Vector2(1, 30), mouse + Vector2(39, 30), ACCENT, 2)

var step := 0
var previous_button: Button
var next_button: Button
var skip_button: Button
var preview_esc: EscOverlay
var preview_settings: GameSettingsPanel
var spotlight: Spotlight
var card: PanelContainer
var _root: Control
var _previews: Control
var _heading: Label
var _body: Label
var _context: Label
var _legend: HBoxContainer
var _progress: Label
var _battle: BattleRoot
var _flow: MainFlowCoordinator


func _ready() -> void:
	layer = 90
	name = "CombatGuide"
	visible = false
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_previews = Control.new()
	_root.add_child(_previews)
	_previews.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spotlight = Spotlight.new()
	spotlight.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(spotlight)
	spotlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()
	get_viewport().size_changed.connect(_layout)
	L10n.locale_changed.connect(_refresh_text)


func initialize(battle: BattleRoot, flow: MainFlowCoordinator) -> void:
	_battle = battle
	_flow = flow
	if _flow != null: _flow.state_changed.connect(_on_state_changed)


func _on_state_changed(_before: String, state: String) -> void:
	visible = state == MainFlowCoordinator.STATE_COMBAT_GUIDE
	if visible:
		_show_step(0)
	else:
		for child in _previews.get_children():
			child.queue_free()
		preview_esc = null
		preview_settings = null


func _input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		# No Esc closing, shortcuts, or input leaking to the showcased controls.
		get_viewport().set_input_as_handled()


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "GuideCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15231c")
	style.border_color = Color("ab9361")
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	_root.add_child(card)
	card.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_context = _label(header, 12, Color("b3bdb5"))
	_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress = _label(header, 14, Color("e2c682"))
	_heading = _label(content, 24, Color("f0dfb5"))
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body = _label(content, 16, Color("e2e5dc"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend = HBoxContainer.new()
	_legend.add_theme_constant_override("separation", 26)
	content.add_child(_legend)
	for automatic in [true, false]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_legend.add_child(row)
		var icon := TextureRect.new()
		icon.texture = WeaponCastModeIcon.AUTO_ICON if automatic else WeaponCastModeIcon.MANUAL_ICON
		icon.modulate = Color("91dcb8") if automatic else Color("ddbe79")
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		_label(row, 14, Color("e2e5dc")).text = "ui.weapon.cast_mode.auto" if automatic else "ui.weapon.cast_mode.manual"
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	skip_button = _button(actions, "ui.guide.skip")
	skip_button.pressed.connect(_finish)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	previous_button = _button(actions, "ui.guide.previous")
	previous_button.pressed.connect(func(): _show_step(step - 1))
	next_button = _button(actions, "ui.guide.next")
	next_button.pressed.connect(func():
		if step < 2: _show_step(step + 1)
		else: _finish())


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, key: String) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(112, 36)
	button.focus_mode = Control.FOCUS_NONE
	SettingsUIStyle.apply_button(button)
	parent.add_child(button)
	return button


func _show_step(index: int) -> void:
	if not visible: return
	step = clampi(index, 0, 2)
	if step == 1 and preview_esc == null:
		preview_esc = preload("res://scenes/ui/esc/esc_overlay.tscn").instantiate()
		_previews.add_child(preview_esc)
		preview_esc.configure(_battle.player, _battle.loadout)
		# Use the actual inventory without its opening animation or live input.
		preview_esc.show()
		preview_esc._layout_overlay()
	if step == 2 and preview_settings == null:
		preview_settings = GameSettingsPanel.new()
		_previews.add_child(preview_settings)
		preview_settings.open_page(true)
		preview_settings.guide_button.hide()
		preview_settings.select_page(1)
		preview_settings.mode_buttons[0].resized.connect(_layout, CONNECT_DEFERRED)
	if preview_esc != null: preview_esc.visible = step == 1
	if preview_settings != null: preview_settings.visible = step == 2
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	_refresh_text()


func _refresh_text() -> void:
	if not visible: return
	_context.text = "ui.guide.context"
	_progress.text = "%02d / 03" % (step + 1)
	var topic: String = ["move", "cast", "settings"][step]
	_heading.text = L10n.text("ui.guide.title." + topic)
	_body.text = L10n.text("ui.guide.body." + topic)
	if step == 0 and CombatSettings.keyboard_movement:
		_body.text += "\n" + L10n.text("ui.guide.keyboard_preserved")
	_legend.visible = step == 1
	previous_button.visible = step > 0
	next_button.text = "ui.guide.next" if step < 2 else "ui.guide.start" if _flow._first_guide_pending else "ui.guide.done"
	_layout()
	_layout.call_deferred()


func _layout() -> void:
	if not visible: return
	var viewport_size := get_viewport().get_visible_rect().size
	spotlight.ground_demo = step == 0
	if step == 0:
		var world := _battle.player.get_viewport()
		var player_screen := _battle.player.get_global_transform_with_canvas().origin * viewport_size / world.get_visible_rect().size
		spotlight.origin = player_screen
		spotlight.destination = player_screen + Vector2(130, 12)
		spotlight.focus_rect = Rect2(player_screen - Vector2(65, 85), Vector2(300, 145))
	elif step == 1 and preview_esc != null:
		preview_esc._layout_overlay()
		spotlight.focus_rect = preview_esc.weapon_strip.get_global_rect().grow(12)
	elif step == 2 and preview_settings != null:
		preview_settings.fit_to_viewport(viewport_size)
		spotlight.focus_rect = preview_settings.mode_buttons[0].get_global_rect().merge(preview_settings.mode_buttons[1].get_global_rect()).grow(8)
	var beside_ground := step == 0 and viewport_size.y < 650
	var width := minf(720, viewport_size.x - 48)
	if beside_ground: width = minf(400, spotlight.focus_rect.position.x - 48)
	card.size = Vector2(width, 0)
	card.position = Vector2(24, (viewport_size.y - card.size.y) * 0.5).floor() if beside_ground else Vector2((viewport_size.x - card.size.x) * 0.5, viewport_size.y - card.size.y - 24).floor()
	spotlight.queue_redraw()


func _finish() -> void:
	if visible: _flow.finish_combat_guide()
