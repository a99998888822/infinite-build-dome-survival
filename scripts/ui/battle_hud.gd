extends CanvasLayer
class_name BattleHud

var _flow: MainFlowCoordinator = null
var _player: PlayerController = null
var _wave_manager: WaveManager = null
var _drawer_open: bool = false
var _drawer_locked_open: bool = false
var _drawer_tween: Tween = null
var _stat_value_labels: Dictionary = {}
var _stat_name_labels: Dictionary = {}
var _stat_info_buttons: Dictionary = {}
var _damage_tooltip_panel: PanelContainer = null
var _bond_indicator: Button = null
var _bond_indicator_placeholder: PanelContainer = null
var _bond_indicator_label: Label = null
var _bond_tooltip_panel: PanelContainer = null
var _displayed_bond_id: String = ""

const DRAWER_OPEN_LEFT := -320.0
const DRAWER_OPEN_RIGHT := 0.0
const DRAWER_CLOSED_LEFT := -28.0
const DRAWER_CLOSED_RIGHT := 292.0
const DRAWER_ANIMATION_SECONDS := 0.18
const MODAL_SAFE_EDGE_MARGIN := 16.0
const MODAL_FALLBACK_TOP := 112.0
const MODAL_FALLBACK_RIGHT_OPEN := 336.0
const MODAL_FALLBACK_RIGHT_CLOSED := 44.0
const STAT_PREVIEW_GAIN_COLOR := Color(0.498, 0.847, 0.561, 1.0)
const STAT_PREVIEW_LOSS_COLOR := Color(0.949, 0.545, 0.510, 1.0)
const ELDRITCH_NAMING_THRESHOLD := 60.0
const DRAWER_LOCKED_OPEN_STATES: Array[String] = [
	MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP,
	MainFlowCoordinator.STATE_SHOP_POPUP,
	MainFlowCoordinator.STATE_FINANCE_POPUP,
	MainFlowCoordinator.STATE_ESC_OVERLAY,
]
const DRAWER_AUTO_OPEN_STATES: Array[String] = [
	MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP,
	MainFlowCoordinator.STATE_SHOP_POPUP,
	MainFlowCoordinator.STATE_FINANCE_POPUP,
	MainFlowCoordinator.STATE_ESC_OVERLAY,
	MainFlowCoordinator.STATE_INTEREST_SETTLEMENT,
	MainFlowCoordinator.STATE_ZONE_SELECT,
	MainFlowCoordinator.STATE_ZONE_HARVEST_RESULT,
]
const STAT_DISPLAY_ORDER: Array[String] = [
	"max_hp",
	"hp_regen",
	"shield",
	"revive_count",
	"on_kill_heal",
	"armor",
	"damage_taken_percent",
	"move_speed",
	"melee_damage",
	"ranged_damage",
	"summon_damage",
	"damage_percent",
	"attack_speed",
	"crit_chance",
	"crit_damage",
	"projectile_count",
	"pierce_count",
	"area_size",
	"control_power",
	"pickup_radius",
	"exp_gain_percent",
	"drop_rate_percent",
	"luck",
	"currency_gain_percent",
	"finance",
	"interest_rate",
	"shop_price_percent",
	"load_capacity",
	"summon_count",
	"enemy_spawn_rate_percent",
	"humanity",
	"divinity",
]

@onready var status_panel: PanelContainer = get_node_or_null("StatusPanel")
@onready var hp_label: Label = get_node_or_null("StatusPanel/Content/HpLabel")
@onready var exp_label: Label = get_node_or_null("StatusPanel/Content/ExpLabel")
@onready var gold_label: Label = get_node_or_null("StatusPanel/Content/GoldLabel")
@onready var finance_label: Label = get_node_or_null("StatusPanel/Content/FinanceLabel")
@onready var wave_label: Label = get_node_or_null("StatusPanel/Content/WaveLabel")
@onready var stats_drawer: Control = get_node_or_null("StatsDrawer")
@onready var drawer_toggle_button: Button = get_node_or_null("StatsDrawer/ToggleButton")
@onready var stats_list: VBoxContainer = get_node_or_null("StatsDrawer/DrawerPanel/DrawerBody/ContentMargin/Content/StatsScroll/StatsList")
@onready var stats_scroll: ScrollContainer = get_node_or_null("StatsDrawer/DrawerPanel/DrawerBody/ContentMargin/Content/StatsScroll")
@onready var modal_backdrop: ColorRect = get_node_or_null("../ModalBackdrop/Backdrop")


func _ready() -> void:
	if drawer_toggle_button != null and not drawer_toggle_button.pressed.is_connected(_on_drawer_toggle_pressed):
		drawer_toggle_button.pressed.connect(_on_drawer_toggle_pressed)
	_hide_stats_scroll_bars()
	_set_drawer_locked_open(false)
	_set_drawer_open(false, false)
	_set_modal_backdrop_visible(false)


func bind_context(flow: MainFlowCoordinator, player: PlayerController, wave_manager: WaveManager) -> void:
	if _flow != null and _flow != flow and _flow.state_changed.is_connected(_on_flow_state_changed):
		_flow.state_changed.disconnect(_on_flow_state_changed)
	_flow = flow
	_player = player
	_wave_manager = wave_manager
	if _flow != null and not _flow.state_changed.is_connected(_on_flow_state_changed):
		_flow.state_changed.connect(_on_flow_state_changed)
	_set_drawer_locked_open(false)
	_set_drawer_open(false, false)
	_set_modal_backdrop_visible(false)
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_all()


func _refresh_all() -> void:
	if _player == null or _wave_manager == null or _flow == null:
		return
	_refresh_labels()
	_refresh_stats_drawer()
	_refresh_bond_indicator()
	_refresh_visibility()


func _refresh_labels() -> void:
	var max_hp := int(_player.get_stat("max_hp"))
	var shield := int(_player.get_stat("shield"))
	if hp_label != null:
		hp_label.text = "生命：%d/%d  护盾：%d" % [_player.current_hp, max_hp, shield]
	if exp_label != null:
		exp_label.text = "等级：%d  经验：%d/%d" % [
			_wave_manager.player_level,
			_wave_manager.current_exp,
			_wave_manager.get_required_exp_for_next_level(),
		]
	if gold_label != null:
		gold_label.text = "金币：%d" % _wave_manager.current_gold
	if finance_label != null:
		var finance_snapshot := _wave_manager.get_finance_snapshot()
		finance_label.text = "理财本金：%d" % int(finance_snapshot.get("principal", 0))
	if wave_label != null:
		var wave_number := _wave_manager.current_wave_index + 1
		var time_left := maxf(_wave_manager.wave_time_left, 0.0)
		wave_label.text = "第 %d 波  剩余 %.1f 秒" % [wave_number, time_left]


func get_modal_safe_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := MODAL_SAFE_EDGE_MARGIN
	var top := minf(MODAL_FALLBACK_TOP, viewport_size.y * 0.18)
	var state := _flow.get_current_state() if _flow != null else ""
	var right := MODAL_FALLBACK_RIGHT_CLOSED
	if _drawer_open or DRAWER_AUTO_OPEN_STATES.has(state):
		right = MODAL_FALLBACK_RIGHT_OPEN
	if stats_drawer != null:
		var drawer_rect := stats_drawer.get_global_rect()
		if drawer_rect.size.x > 0.0 and drawer_rect.position.x < viewport_size.x:
			var drawer_reserved_right := viewport_size.x - drawer_rect.position.x + MODAL_SAFE_EDGE_MARGIN
			right = maxf(right, drawer_reserved_right)
	var safe_left := clampf(left, 0.0, viewport_size.x)
	var safe_top := clampf(top, 0.0, viewport_size.y)
	var safe_right := clampf(right, 0.0, viewport_size.x - safe_left)
	var bottom := MODAL_SAFE_EDGE_MARGIN
	return Rect2(
		Vector2(safe_left, safe_top),
		Vector2(maxf(viewport_size.x - safe_left - safe_right, 0.0), maxf(viewport_size.y - safe_top - bottom, 0.0))
	)


func _refresh_visibility() -> void:
	var in_battle := _flow.get_current_mode() == MainFlowCoordinator.MODE_BATTLE
	var state := _flow.get_current_state()
	if not in_battle or _flow.battle_resolved:
		visible = false
	elif state == MainFlowCoordinator.STATE_BATTLE_RESULT:
		visible = false
	else:
		visible = true


func _on_drawer_toggle_pressed() -> void:
	if _drawer_locked_open:
		return
	_set_drawer_open(not _drawer_open, true)


func _on_flow_state_changed(_previous_state: String, current_state: String) -> void:
	var lock_drawer_open := DRAWER_LOCKED_OPEN_STATES.has(current_state)
	_set_drawer_locked_open(lock_drawer_open)
	_set_modal_backdrop_visible(lock_drawer_open)
	if DRAWER_AUTO_OPEN_STATES.has(current_state):
		_set_drawer_open(true, true)
	elif current_state == MainFlowCoordinator.STATE_WAVE_COMBAT:
		_set_drawer_open(false, true)
	else:
		_set_modal_backdrop_visible(false)


func _set_drawer_open(open: bool, animated: bool) -> void:
	if stats_drawer == null:
		return

	_drawer_open = open
	if drawer_toggle_button != null:
		drawer_toggle_button.text = ">" if open else "<"

	var target_left := DRAWER_OPEN_LEFT if open else DRAWER_CLOSED_LEFT
	var target_right := DRAWER_OPEN_RIGHT if open else DRAWER_CLOSED_RIGHT
	if _drawer_tween != null:
		_drawer_tween.kill()
		_drawer_tween = null

	if not animated:
		stats_drawer.offset_left = target_left
		stats_drawer.offset_right = target_right
		return

	_drawer_tween = create_tween()
	_drawer_tween.set_trans(Tween.TRANS_CUBIC)
	_drawer_tween.set_ease(Tween.EASE_OUT)
	_drawer_tween.parallel().tween_property(stats_drawer, "offset_left", target_left, DRAWER_ANIMATION_SECONDS)
	_drawer_tween.parallel().tween_property(stats_drawer, "offset_right", target_right, DRAWER_ANIMATION_SECONDS)


func _set_drawer_locked_open(locked: bool) -> void:
	_drawer_locked_open = locked
	if drawer_toggle_button != null:
		drawer_toggle_button.disabled = locked


func _set_modal_backdrop_visible(is_visible: bool) -> void:
	if modal_backdrop != null:
		modal_backdrop.visible = is_visible


func _hide_stats_scroll_bars() -> void:
	if stats_scroll == null:
		return
	stats_scroll.get_h_scroll_bar().visible = false
	stats_scroll.get_v_scroll_bar().visible = false


func _input(event: InputEvent) -> void:
	if stats_scroll == null or not stats_scroll.visible or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or not stats_scroll.get_global_rect().has_point(mouse_event.position):
		return
	var target_scroll := stats_scroll.scroll_vertical
	var max_scroll := int(stats_scroll.get_v_scroll_bar().max_value)
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		target_scroll -= 48
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		target_scroll += 48
	else:
		return
	stats_scroll.scroll_vertical = clampi(target_scroll, 0, max_scroll)
	get_viewport().set_input_as_handled()


func _refresh_stats_drawer() -> void:
	_ensure_stat_rows()
	var preview := _flow.get_stat_preview() if _flow != null else {}
	for stat_id_variant in _stat_value_labels:
		var stat_id := str(stat_id_variant)
		var value_label := _stat_value_labels[stat_id_variant] as Label
		if value_label != null:
			if preview.has(stat_id):
				var preview_value := float(preview[stat_id])
				var current_value := _get_display_stat_value(stat_id)
				value_label.text = _format_stat_value(stat_id, preview_value)
				value_label.add_theme_color_override("font_color", STAT_PREVIEW_GAIN_COLOR if preview_value >= current_value else STAT_PREVIEW_LOSS_COLOR)
			else:
				value_label.text = _format_stat_value(stat_id, _get_display_stat_value(stat_id))
				value_label.remove_theme_color_override("font_color")
		var name_label := _stat_name_labels.get(stat_id_variant, null) as Label
		if name_label != null:
			name_label.text = _get_stat_display_name(stat_id)


func _ensure_stat_rows() -> void:
	if stats_list == null or not _stat_value_labels.is_empty():
		return

	for stat_id in _get_ordered_stat_ids():
		if stat_id == "damage_taken_percent" or stat_id == "shield" or stat_id == "finance":
			continue
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = _get_stat_display_name(stat_id)
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if stat_id == "armor" else Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		if stat_id == "armor":
			var info_button := _create_stat_info_button()
			row.add_child(info_button)
			_stat_info_buttons[stat_id] = info_button
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)

		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(80.0, 0.0)

		row.add_child(value_label)
		stats_list.add_child(row)
		_stat_value_labels[stat_id] = value_label
		_stat_name_labels[stat_id] = name_label


func _create_stat_info_button() -> Button:
	var info_button := Button.new()
	info_button.custom_minimum_size = Vector2(13.0, 13.0)
	info_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_button.focus_mode = Control.FOCUS_NONE
	info_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_button.text = "?"
	info_button.tooltip_text = ""
	info_button.add_theme_font_size_override("font_size", 8)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.20, 0.22, 0.25, 0.95)
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.75)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.35, 0.38, 0.42, 1.0)
	info_button.add_theme_stylebox_override("normal", normal_style)
	info_button.add_theme_stylebox_override("hover", hover_style)
	info_button.add_theme_color_override("font_color", Color.WHITE)
	info_button.add_theme_color_override("font_hover_color", Color.WHITE)
	info_button.mouse_entered.connect(_show_damage_tooltip.bind(info_button))
	info_button.mouse_exited.connect(_hide_damage_tooltip)
	return info_button


func _show_damage_tooltip(info_button: Button) -> void:
	_hide_damage_tooltip()
	_damage_tooltip_panel = PanelContainer.new()
	_damage_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_tooltip_panel.z_index = 100
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	panel_style.border_color = Color(0.75, 0.78, 0.82, 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_damage_tooltip_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_damage_tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	_damage_tooltip_panel.add_child(margin)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(120, 0)
	var damage_taken_percent := _format_stat_value("damage_taken_percent", _player.get_stat("damage_taken_percent"))
	label.text = "[color=#FFFFFF]受到 [/color][color=#FFF0A6]%s[/color][color=#FFFFFF] 的伤害[/color]" % damage_taken_percent
	margin.add_child(label)
	call_deferred("_position_damage_tooltip", info_button, _damage_tooltip_panel)


func _position_damage_tooltip(info_button: Button, tooltip_panel: PanelContainer) -> void:
	if not is_instance_valid(info_button) or not is_instance_valid(tooltip_panel):
		return
	var button_rect := info_button.get_global_rect()
	var tooltip_position := button_rect.position + Vector2(button_rect.size.x + 8.0, -4.0)
	var viewport_size := get_viewport().get_visible_rect().size
	if tooltip_position.x + tooltip_panel.size.x > viewport_size.x:
		tooltip_position.x = button_rect.position.x - tooltip_panel.size.x - 8.0
	tooltip_position.y = clampf(tooltip_position.y, 4.0, viewport_size.y - tooltip_panel.size.y - 4.0)
	tooltip_panel.position = tooltip_position


func _hide_damage_tooltip() -> void:
	if _damage_tooltip_panel != null:
		_damage_tooltip_panel.queue_free()
		_damage_tooltip_panel = null


func _get_ordered_stat_ids() -> Array[String]:
	var stat_ids: Array[String] = []
	var defined_stat_ids := StatDefinitions.get_all_stat_ids()
	for stat_id in STAT_DISPLAY_ORDER:
		if defined_stat_ids.has(stat_id):
			stat_ids.append(stat_id)
	for stat_id in defined_stat_ids:
		if not stat_ids.has(stat_id):
			stat_ids.append(stat_id)
	return stat_ids


func _get_display_stat_value(stat_id: String) -> float:
	if stat_id == "revive_count":
		return float(_player.get_remaining_revives())
	return _player.get_stat(stat_id)


func _get_stat_display_name(stat_id: String) -> String:
	var eldritch_name_changed := _player != null and _player.get_stat("divinity") > ELDRITCH_NAMING_THRESHOLD
	if stat_id == "humanity":
		return "人性" if eldritch_name_changed else "理智值"
	if stat_id == "divinity":
		return "神性" if eldritch_name_changed else "侵蚀度"
	return StatDefinitions.get_display_name(stat_id)


func _format_stat_value(stat_id: String, value: float) -> String:
	if StatDefinitions.is_integer_stat(stat_id):
		return "%d%%" % roundi(value) if StatDefinitions.is_percent_stat(stat_id) else "%d" % roundi(value)
	if is_equal_approx(value, roundf(value)):
		return "%d%%" % roundi(value) if StatDefinitions.is_percent_stat(stat_id) else "%d" % roundi(value)
	return "%.2f%%" % value if StatDefinitions.is_percent_stat(stat_id) else "%.2f" % value


func _refresh_bond_indicator() -> void:
	if _flow == null or _flow.get_current_state() != MainFlowCoordinator.STATE_WAVE_COMBAT:
		_displayed_bond_id = ""
		_hide_bond_tooltip()
		if _bond_indicator != null:
			_bond_indicator.visible = false
		return
	var bond_id := _get_displayed_bond_id()
	_displayed_bond_id = bond_id
	if bond_id.is_empty():
		_hide_bond_tooltip()
		if _bond_indicator != null:
			_bond_indicator.visible = false
		return
	_ensure_bond_indicator()
	_update_bond_indicator_visual(bond_id)
	_bond_indicator.visible = true


func _get_displayed_bond_id() -> String:
	if _player == null:
		return ""
	for bond in DataRegistry.get_table("bonds"):
		if not (bond is Dictionary):
			continue
		var bond_id := str(bond.get("id", ""))
		if bond_id.is_empty():
			continue
		if _player.relic_system.get_bond_count(bond_id) > 0:
			return bond_id
	return ""


func _ensure_bond_indicator() -> void:
	if _bond_indicator != null:
		return
	_bond_indicator = Button.new()
	_bond_indicator.name = "BondIndicator"
	_bond_indicator.flat = true
	_bond_indicator.focus_mode = Control.FOCUS_NONE
	_bond_indicator.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bond_indicator.anchor_left = 1.0
	_bond_indicator.anchor_right = 1.0
	_bond_indicator.anchor_top = 0.0
	_bond_indicator.anchor_bottom = 0.0
	_bond_indicator.offset_left = -380.0
	_bond_indicator.offset_top = 16.0
	_bond_indicator.offset_right = -336.0
	_bond_indicator.offset_bottom = 60.0
	_bond_indicator.visible = false
	_bond_indicator_placeholder = PanelContainer.new()
	_bond_indicator_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bond_indicator_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var placeholder_style := StyleBoxFlat.new()
	placeholder_style.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	placeholder_style.border_color = Color(0.96, 0.84, 0.45, 1.0)
	placeholder_style.set_border_width_all(2)
	placeholder_style.set_corner_radius_all(8)
	_bond_indicator_placeholder.add_theme_stylebox_override("panel", placeholder_style)
	_bond_indicator.add_child(_bond_indicator_placeholder)
	_bond_indicator_label = Label.new()
	_bond_indicator_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bond_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bond_indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bond_indicator_label.add_theme_font_size_override("font_size", 24)
	_bond_indicator_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.45, 1.0))
	_bond_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bond_indicator.add_child(_bond_indicator_label)
	_bond_indicator.mouse_entered.connect(_show_bond_tooltip)
	_bond_indicator.mouse_exited.connect(_hide_bond_tooltip)
	add_child(_bond_indicator)


func _update_bond_indicator_visual(bond_id: String) -> void:
	if _bond_indicator_label == null:
		return
	var first_char := BondDisplay.get_bond_name(bond_id).substr(0, 1)
	if _bond_indicator_label.text != first_char:
		_bond_indicator_label.text = first_char


func _show_bond_tooltip() -> void:
	if _displayed_bond_id.is_empty() or _player == null:
		return
	_hide_bond_tooltip()
	_bond_tooltip_panel = PanelContainer.new()
	_bond_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bond_tooltip_panel.z_index = 100
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	panel_style.border_color = Color(0.96, 0.84, 0.45, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_bond_tooltip_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_bond_tooltip_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	_bond_tooltip_panel.add_child(margin)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(220, 0)
	label.text = BondDisplay.build_bond_tooltip_text(_displayed_bond_id, _player.relic_system)
	margin.add_child(label)
	call_deferred("_position_bond_tooltip", _bond_tooltip_panel)


func _position_bond_tooltip(tooltip_panel: PanelContainer) -> void:
	if not is_instance_valid(tooltip_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_position := Vector2.ZERO
	if _bond_indicator != null:
		var indicator_rect := _bond_indicator.get_global_rect()
		tooltip_position = indicator_rect.position + Vector2(-tooltip_panel.size.x - 8.0, 0.0)
	tooltip_position.x = maxf(tooltip_position.x, 4.0)
	tooltip_position.y = clampf(tooltip_position.y, 4.0, viewport_size.y - tooltip_panel.size.y - 4.0)
	tooltip_panel.position = tooltip_position


func _hide_bond_tooltip() -> void:
	if _bond_tooltip_panel != null:
		_bond_tooltip_panel.queue_free()
		_bond_tooltip_panel = null
