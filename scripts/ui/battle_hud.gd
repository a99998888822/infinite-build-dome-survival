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
var _damage_tooltip_panel: PanelContainer = null
var _bond_indicator: Button = null
var _bond_indicator_placeholder: PanelContainer = null
var _bond_indicator_label: Label = null
var _bond_tooltip_panel: PanelContainer = null
var _displayed_bond_id: String = ""
var _wave_toast: Label = null
var _resource_pop: Label = null
var _resource_pop_tween: Tween = null
var _stats_scanline_overlay: TextureRect = null
var _progress_tweens: Dictionary = {}
var _pulse_tweens: Dictionary = {}
var _last_hp: int = -1
var _last_max_hp: int = -1
var _last_shield: int = -1
var _last_max_shield: int = -1
var _last_exp: int = -1
var _last_exp_required: int = -1
var _last_level: int = -1
var _last_gold: int = -1
var _last_finance_principal: int = -1

const DRAWER_OPEN_LEFT := -320.0
const DRAWER_OPEN_RIGHT := 0.0
const DRAWER_CLOSED_LEFT := -28.0
const DRAWER_CLOSED_RIGHT := 292.0
const DRAWER_ANIMATION_SECONDS := 0.18
const MODAL_SAFE_EDGE_MARGIN := 16.0
const MODAL_FALLBACK_TOP := 16.0
const MODAL_FALLBACK_RIGHT_OPEN := 336.0
const MODAL_FALLBACK_RIGHT_CLOSED := 44.0
const STAT_PREVIEW_GAIN_COLOR := Color(0.498, 0.847, 0.561, 1.0)
const STAT_PREVIEW_LOSS_COLOR := Color(0.949, 0.545, 0.510, 1.0)
const ELDRITCH_NAMING_THRESHOLD := 60.0
const HP_PULSE_COLOR := Color(1.18, 0.82, 0.78, 1.0)
const SHIELD_PULSE_COLOR := Color(0.84, 0.76, 1.16, 1.0)
const EXP_PULSE_COLOR := Color(0.83, 1.18, 0.76, 1.0)
const GOLD_PULSE_COLOR := Color(1.18, 1.08, 0.68, 1.0)
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
const STATUS_HIDDEN_MODAL_STATES: Array[String] = [
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
	"shield_regen",
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
	"shop_offer_count_bonus",
	"load_capacity",
	"summon_count",
	"enemy_spawn_rate_percent",
	"humanity",
	"divinity",
]

@onready var status_panel: Control = get_node_or_null("StatusPanel")
@onready var top_left: VBoxContainer = get_node_or_null("StatusPanel/TopLeft")
@onready var level_label: Label = get_node_or_null("StatusPanel/TopLeft/LevelLabel")
@onready var hp_bar: ProgressBar = get_node_or_null("StatusPanel/TopLeft/HpRow/HpBar")
@onready var hp_label: Label = get_node_or_null("StatusPanel/TopLeft/HpRow/HpBar/Text")
@onready var shield_bar: ProgressBar = get_node_or_null("StatusPanel/TopLeft/ShieldRow/ShieldBar")
@onready var shield_label: Label = get_node_or_null("StatusPanel/TopLeft/ShieldRow/ShieldBar/Text")
@onready var wave_panel: PanelContainer = get_node_or_null("StatusPanel/WavePanel")
@onready var wave_label: Label = get_node_or_null("StatusPanel/WavePanel/Content/WaveLabel")
@onready var wave_timer_label: Label = get_node_or_null("StatusPanel/WavePanel/Content/TimerLabel")
@onready var economy_panel: VBoxContainer = get_node_or_null("../EconomyOverlay/EconomyPanel")
@onready var gold_label: Label = get_node_or_null("../EconomyOverlay/EconomyPanel/GoldRow/Label")
@onready var finance_label: Label = get_node_or_null("../EconomyOverlay/EconomyPanel/FinanceRow/Label")
@onready var exp_panel: VBoxContainer = get_node_or_null("StatusPanel/ExpPanel")
@onready var exp_label: Label = get_node_or_null("StatusPanel/ExpPanel/ExpLabel")
@onready var exp_bar: ProgressBar = get_node_or_null("StatusPanel/ExpPanel/ExpBar")
@onready var stats_drawer: Control = get_node_or_null("StatsDrawer")
@onready var drawer_toggle_button: Button = get_node_or_null("StatsDrawer/ToggleButton")
@onready var stats_list: VBoxContainer = get_node_or_null("StatsDrawer/DrawerPanel/DrawerBody/ContentMargin/Content/StatsScroll/StatsList")
@onready var stats_scroll: ScrollContainer = get_node_or_null("StatsDrawer/DrawerPanel/DrawerBody/ContentMargin/Content/StatsScroll")
@onready var modal_backdrop: ColorRect = get_node_or_null("../ModalBackdrop/Backdrop")


func _ready() -> void:
	_ensure_feedback_ui()
	_create_stats_scanline_overlay()
	_bind_viewport_resize()
	_apply_combat_layout()
	if drawer_toggle_button != null and not drawer_toggle_button.pressed.is_connected(_on_drawer_toggle_pressed):
		drawer_toggle_button.pressed.connect(_on_drawer_toggle_pressed)
	_hide_stats_scroll_bars()
	_set_drawer_locked_open(false)
	_set_drawer_open(false, false)
	_set_modal_backdrop_visible(false)


func _create_stats_scanline_overlay() -> void:
	if _stats_scanline_overlay != null or stats_drawer == null:
		return
	var scanline_image := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	scanline_image.fill(Color.TRANSPARENT)
	scanline_image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.08))
	scanline_image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 0.08))
	_stats_scanline_overlay = TextureRect.new()
	_stats_scanline_overlay.name = "StatsScanlineOverlay"
	_stats_scanline_overlay.texture = ImageTexture.create_from_image(scanline_image)
	_stats_scanline_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_stats_scanline_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stats_scanline_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stats_scanline_overlay.stretch_mode = TextureRect.STRETCH_TILE
	_stats_scanline_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stats_scanline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_scanline_overlay.z_index = 1
	stats_drawer.add_child(_stats_scanline_overlay)


func bind_context(flow: MainFlowCoordinator, player: PlayerController, wave_manager: WaveManager) -> void:
	if _flow != null and _flow != flow and _flow.state_changed.is_connected(_on_flow_state_changed):
		_flow.state_changed.disconnect(_on_flow_state_changed)
	_disconnect_combat_signals()
	_flow = flow
	_player = player
	_wave_manager = wave_manager
	_connect_combat_signals()
	if _flow != null and not _flow.state_changed.is_connected(_on_flow_state_changed):
		_flow.state_changed.connect(_on_flow_state_changed)
	_reset_combat_display_cache()
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


func _ensure_feedback_ui() -> void:
	_wave_toast = Label.new()
	_wave_toast.name = "WaveEndToast"
	_wave_toast.text = "\u767d\u5929\u5230\u4e86\uff0c\u6682\u65f6\u5b89\u5168\u4e86..."
	_wave_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_wave_toast.position = Vector2(-180.0, -96.0)
	_wave_toast.size = Vector2(360.0, 36.0)
	_wave_toast.modulate.a = 0.0
	_wave_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_toast.z_index = 20
	_wave_toast.add_theme_color_override("font_color", Color(0.70, 0.87, 0.54, 1.0))
	_wave_toast.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.96))
	_wave_toast.add_theme_constant_override("outline_size", 4)
	_wave_toast.add_theme_font_size_override("font_size", 14)
	add_child(_wave_toast)

	_resource_pop = Label.new()
	_resource_pop.name = "ResourcePop"
	_resource_pop.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_resource_pop.position = Vector2(-214.0, 64.0)
	_resource_pop.size = Vector2(178.0, 26.0)
	_resource_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resource_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_pop.z_index = 20
	_resource_pop.modulate.a = 0.0
	_resource_pop.add_theme_color_override("font_color", Color(1.0, 0.86, 0.31, 1.0))
	_resource_pop.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.96))
	_resource_pop.add_theme_constant_override("outline_size", 3)
	_resource_pop.add_theme_font_size_override("font_size", 12)
	add_child(_resource_pop)


func show_wave_end_toast() -> void:
	if _wave_toast == null:
		return
	_wave_toast.position.y = -72.0
	_wave_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_wave_toast, "position:y", -128.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_wave_toast, "modulate:a", 1.0, 0.18)
	tween.tween_interval(1.2)
	tween.tween_property(_wave_toast, "modulate:a", 0.0, 0.4)


func _on_wave_finished_feedback(_wave_id: String) -> void:
	if AudioManager != null:
		AudioManager.play_wave_end_sfx()
	show_wave_end_toast()


func _refresh_labels() -> void:
	_sync_vitals(_last_hp >= 0)
	_sync_progress(_last_exp >= 0)
	_sync_economy(_last_gold >= 0)
	_refresh_wave_display()


func _connect_combat_signals() -> void:
	if _player != null and not _player.hp_changed.is_connected(_on_player_hp_changed):
		_player.hp_changed.connect(_on_player_hp_changed)
	if _wave_manager == null:
		return
	if not _wave_manager.exp_changed.is_connected(_on_exp_changed):
		_wave_manager.exp_changed.connect(_on_exp_changed)
	if not _wave_manager.gold_changed.is_connected(_on_gold_changed):
		_wave_manager.gold_changed.connect(_on_gold_changed)
	if not _wave_manager.finance_changed.is_connected(_on_finance_changed):
		_wave_manager.finance_changed.connect(_on_finance_changed)
	if not _wave_manager.wave_started.is_connected(_on_wave_started_feedback):
		_wave_manager.wave_started.connect(_on_wave_started_feedback)
	if not _wave_manager.wave_finished.is_connected(_on_wave_finished_feedback):
		_wave_manager.wave_finished.connect(_on_wave_finished_feedback)


func _disconnect_combat_signals() -> void:
	if _player != null and _player.hp_changed.is_connected(_on_player_hp_changed):
		_player.hp_changed.disconnect(_on_player_hp_changed)
	if _wave_manager == null:
		return
	if _wave_manager.exp_changed.is_connected(_on_exp_changed):
		_wave_manager.exp_changed.disconnect(_on_exp_changed)
	if _wave_manager.gold_changed.is_connected(_on_gold_changed):
		_wave_manager.gold_changed.disconnect(_on_gold_changed)
	if _wave_manager.finance_changed.is_connected(_on_finance_changed):
		_wave_manager.finance_changed.disconnect(_on_finance_changed)
	if _wave_manager.wave_started.is_connected(_on_wave_started_feedback):
		_wave_manager.wave_started.disconnect(_on_wave_started_feedback)
	if _wave_manager.wave_finished.is_connected(_on_wave_finished_feedback):
		_wave_manager.wave_finished.disconnect(_on_wave_finished_feedback)


func _reset_combat_display_cache() -> void:
	_last_hp = -1
	_last_max_hp = -1
	_last_shield = -1
	_last_max_shield = -1
	_last_exp = -1
	_last_exp_required = -1
	_last_level = -1
	_last_gold = -1
	_last_finance_principal = -1


func _on_player_hp_changed(_current_hp: int, _max_hp: int, _current_shield: int) -> void:
	_sync_vitals(true)


func _on_exp_changed(_current_exp: int, _required_exp: int, _level: int) -> void:
	_sync_progress(true)


func _on_gold_changed(current_gold: int) -> void:
	var delta := current_gold - _last_gold
	var had_displayed_value := _last_gold >= 0
	_sync_economy(true)
	if had_displayed_value and delta != 0:
		_show_resource_pop("%+d 金币" % delta, delta > 0)


func _on_finance_changed(_snapshot: Dictionary) -> void:
	_sync_economy(true)


func _on_wave_started_feedback(_wave_id: String, _duration_seconds: int) -> void:
	_refresh_wave_display()
	_pulse_control(wave_panel, EXP_PULSE_COLOR)


func _sync_vitals(animate: bool) -> void:
	if _player == null:
		return
	var max_hp := maxi(int(_player.get_stat("max_hp")), 1)
	var max_shield := maxi(_player.current_shield_capacity, _player.current_shield)
	var current_hp := clampi(_player.current_hp, 0, max_hp)
	var current_shield := clampi(_player.current_shield, 0, max_shield)
	if level_label != null:
		level_label.text = "Lv. %d" % maxi(_wave_manager.player_level if _wave_manager != null else 1, 1)
	if hp_label != null:
		hp_label.text = "%d/%d" % [current_hp, max_hp]
	if shield_label != null:
		shield_label.text = "%d/%d" % [current_shield, max_shield]
	if _last_hp != current_hp or _last_max_hp != max_hp:
		_set_progress_value(hp_bar, float(current_hp) * 100.0 / float(max_hp), animate)
		if animate and _last_hp >= 0:
			_pulse_control(hp_bar, HP_PULSE_COLOR)
	if _last_shield != current_shield or _last_max_shield != max_shield:
		_set_progress_value(shield_bar, float(current_shield) * 100.0 / float(maxi(max_shield, 1)), animate)
		if animate and _last_shield >= 0:
			_pulse_control(shield_bar, SHIELD_PULSE_COLOR)
	_last_hp = current_hp
	_last_max_hp = max_hp
	_last_shield = current_shield
	_last_max_shield = max_shield


func _sync_progress(animate: bool) -> void:
	if _wave_manager == null:
		return
	var current_exp := maxi(_wave_manager.current_exp, 0)
	var required_exp := maxi(_wave_manager.get_required_exp_for_next_level(), 1)
	var level := maxi(_wave_manager.player_level, 1)
	if exp_label != null:
		exp_label.text = "等级 %d  经验 %d/%d" % [level, current_exp, required_exp]
	if level_label != null:
		level_label.text = "Lv. %d" % level
	if _last_exp != current_exp or _last_exp_required != required_exp:
		_set_progress_value(exp_bar, float(current_exp) * 100.0 / float(required_exp), animate)
		if animate and _last_exp >= 0:
			_pulse_control(exp_bar, EXP_PULSE_COLOR)
	if animate and _last_level >= 0 and _last_level != level:
		_pulse_control(exp_panel, EXP_PULSE_COLOR)
	_last_exp = current_exp
	_last_exp_required = required_exp
	_last_level = level


func _sync_economy(animate: bool) -> void:
	if _wave_manager == null:
		return
	var current_gold := maxi(_wave_manager.current_gold, 0)
	var finance_snapshot := _wave_manager.get_finance_snapshot()
	var principal := maxi(int(finance_snapshot.get("principal", 0)), 0)
	if gold_label != null:
		gold_label.text = "金币：%s" % _format_number(current_gold)
	if finance_label != null:
		finance_label.text = "本金：%s" % _format_number(principal)
	if animate and _last_gold >= 0 and _last_gold != current_gold:
		_pulse_control(gold_label, GOLD_PULSE_COLOR)
	if animate and _last_finance_principal >= 0 and _last_finance_principal != principal:
		_pulse_control(finance_label, GOLD_PULSE_COLOR)
	_last_gold = current_gold
	_last_finance_principal = principal


func _refresh_wave_display() -> void:
	if _wave_manager == null:
		return
	var wave_number := maxi(_wave_manager.current_wave_index + 1, 1)
	var time_left := maxf(_wave_manager.wave_time_left, 0.0)
	if wave_label != null:
		wave_label.text = "第 %d 波" % wave_number
	if wave_timer_label != null:
		wave_timer_label.text = "%ds" % ceili(time_left)
		if time_left > 0.0 and time_left <= 10.0:
			wave_timer_label.add_theme_color_override("font_color", Color(0.92, 0.25, 0.22, 1.0))
			var warning_pulse := 0.92 + 0.08 * sin(Time.get_ticks_msec() / 160.0)
			wave_timer_label.modulate = Color(1.14, 0.92, 0.88, warning_pulse)
		else:
			wave_timer_label.remove_theme_color_override("font_color")
			wave_timer_label.modulate = Color.WHITE
func _set_progress_value(progress_bar: ProgressBar, target_value: float, animate: bool) -> void:
	if progress_bar == null:
		return
	var clamped_value := clampf(target_value, 0.0, 100.0)
	if is_equal_approx(float(progress_bar.value), clamped_value):
		return
	var old_tween: Tween = _progress_tweens.get(progress_bar, null)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	if not animate:
		progress_bar.value = clamped_value
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_bar, "value", clamped_value, 0.20)
	_progress_tweens[progress_bar] = tween


func _pulse_control(control: Control, pulse_color: Color) -> void:
	if control == null:
		return
	var old_tween: Tween = _pulse_tweens.get(control, null)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	control.modulate = Color.WHITE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", pulse_color, 0.08)
	tween.tween_property(control, "modulate", Color.WHITE, 0.24)
	_pulse_tweens[control] = tween


func _show_resource_pop(text: String, is_gain: bool) -> void:
	if _resource_pop == null:
		return
	if _resource_pop_tween != null and _resource_pop_tween.is_valid():
		_resource_pop_tween.kill()
	_resource_pop.text = text
	_resource_pop.position = Vector2(-214.0, 64.0)
	_resource_pop.modulate = Color(0.72, 1.0, 0.66, 1.0) if is_gain else Color(1.0, 0.58, 0.48, 1.0)
	_resource_pop_tween = create_tween()
	_resource_pop_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_resource_pop_tween.tween_property(_resource_pop, "position:y", 42.0, 0.52)
	_resource_pop_tween.parallel().tween_property(_resource_pop, "modulate:a", 0.0, 0.52)


func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits.substr(index, 1)
	return "-" + result if value < 0 else result


func _bind_viewport_resize() -> void:
	if get_viewport() == null:
		return
	var resize_callable := Callable(self, "_on_viewport_resized")
	if not get_viewport().size_changed.is_connected(resize_callable):
		get_viewport().size_changed.connect(resize_callable)


func _on_viewport_resized() -> void:
	call_deferred("_apply_combat_layout")


func _apply_combat_layout() -> void:
	if get_viewport() == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var bar_width := clampf(viewport_width * 0.26, 144.0, 220.0)
	var weapon_strip_rect := _get_weapon_strip_rect()
	if hp_bar != null:
		hp_bar.custom_minimum_size.x = bar_width
	if shield_bar != null:
		shield_bar.custom_minimum_size.x = bar_width
	if wave_panel != null:
		var wave_size := Vector2(116.0, 68.0)
		wave_panel.anchor_left = 0.0
		wave_panel.anchor_top = 0.0
		wave_panel.anchor_right = 0.0
		wave_panel.anchor_bottom = 0.0
		wave_panel.position = Vector2(
			(viewport_width - wave_size.x) * 0.5,
			weapon_strip_rect.position.y + (weapon_strip_rect.size.y - wave_size.y) * 0.5
		)
		wave_panel.size = wave_size
		wave_panel.custom_minimum_size = wave_size
	if economy_panel != null:
		var economy_width := clampf(viewport_width * 0.20, 170.0, 220.0)
		var economy_position := weapon_strip_rect.position + Vector2(weapon_strip_rect.size.x + 12.0, (weapon_strip_rect.size.y - 52.0) * 0.5)
		if economy_position.x + economy_width > viewport_width - 12.0:
			economy_position.x = maxf(12.0, weapon_strip_rect.position.x - economy_width - 12.0)
		economy_panel.anchor_left = 0.0
		economy_panel.anchor_top = 0.0
		economy_panel.anchor_right = 0.0
		economy_panel.anchor_bottom = 0.0
		economy_panel.position = economy_position
		economy_panel.size = Vector2(economy_width, 52.0)
	if exp_panel != null:
		if OS.has_feature("mobile"):
			exp_panel.anchor_left = 0.28
		else:
			exp_panel.anchor_left = 0.10 if viewport_width < 720.0 else 0.15
		exp_panel.anchor_right = 0.90 if viewport_width < 720.0 else 0.85


func _get_weapon_strip_rect() -> Rect2:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		for candidate in current_scene.find_children("WeaponStrip", "Control", true, false):
			var strip := candidate as Control
			if strip == null or not strip.is_visible_in_tree():
				continue
			var visible_rect := strip.get_global_rect()
			if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
				return visible_rect

	var safe := get_modal_safe_rect()
	if safe.size.x <= 0.0:
		return Rect2(Vector2(12.0, 18.0), Vector2(560.0, 62.0))
	var strip_width := minf(560.0, maxf(safe.size.x - 32.0, 0.0))
	return Rect2(
		Vector2(safe.position.x + (safe.size.x - strip_width) * 0.5, safe.position.y + 12.0),
		Vector2(strip_width, 62.0)
	)


func get_modal_safe_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var viewport_size := Vector2(viewport.size)
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
	if _flow == null:
		visible = false
		if status_panel != null:
			status_panel.visible = false
		if economy_panel != null:
			economy_panel.visible = false
		return
	var in_battle := _flow.get_current_mode() == MainFlowCoordinator.MODE_BATTLE
	var state := _flow.get_current_state()
	if not in_battle or _flow.battle_resolved:
		visible = false
	elif state == MainFlowCoordinator.STATE_BATTLE_RESULT:
		visible = false
	else:
		visible = true
	if status_panel != null:
		status_panel.visible = visible and not STATUS_HIDDEN_MODAL_STATES.has(state)
	if economy_panel != null:
		economy_panel.visible = in_battle and not _flow.battle_resolved and state != MainFlowCoordinator.STATE_BATTLE_RESULT


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
	call_deferred("_apply_combat_layout")


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
		_refresh_visibility()
		return

	_drawer_tween = create_tween()
	_drawer_tween.set_trans(Tween.TRANS_CUBIC)
	_drawer_tween.set_ease(Tween.EASE_OUT)
	_drawer_tween.parallel().tween_property(stats_drawer, "offset_left", target_left, DRAWER_ANIMATION_SECONDS)
	_drawer_tween.parallel().tween_property(stats_drawer, "offset_right", target_right, DRAWER_ANIMATION_SECONDS)
	_refresh_visibility()


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
				if is_equal_approx(preview_value, current_value):
					value_label.remove_theme_color_override("font_color")
				else:
					value_label.add_theme_color_override("font_color", STAT_PREVIEW_GAIN_COLOR if preview_value > current_value else STAT_PREVIEW_LOSS_COLOR)
			else:
				value_label.text = _format_stat_value(stat_id, _get_display_stat_value(stat_id))
				value_label.remove_theme_color_override("font_color")
		var name_label := _stat_name_labels.get(stat_id_variant, null) as Label
		if name_label != null:
			name_label.text = _get_stat_display_name(stat_id)
			if stat_id == "armor":
				var tooltip_text := _get_damage_tooltip_text()
				if name_label.tooltip_text != tooltip_text:
					name_label.tooltip_text = tooltip_text


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
			name_label.mouse_filter = Control.MOUSE_FILTER_STOP
			name_label.mouse_default_cursor_shape = Control.CURSOR_HELP
			name_label.tooltip_text = _get_damage_tooltip_text()
			name_label.mouse_entered.connect(_show_damage_tooltip.bind(name_label))
			name_label.mouse_exited.connect(_hide_damage_tooltip)
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


func _get_damage_tooltip_text() -> String:
	if _player == null:
		return "护甲减免后的当前承伤百分比"
	var damage_taken_percent := _format_stat_value("damage_taken_percent", _player.get_stat("damage_taken_percent"))
	return "护甲减免后，玩家当前承受 %s 的伤害" % damage_taken_percent



func _show_damage_tooltip(anchor_control: Control) -> void:
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
	label.text = "[color=#FFFFFF]%s[/color]" % _get_damage_tooltip_text()
	margin.add_child(label)
	call_deferred("_position_damage_tooltip", anchor_control, _damage_tooltip_panel)


func _position_damage_tooltip(anchor_control: Control, tooltip_panel: PanelContainer) -> void:
	if not is_instance_valid(anchor_control) or not is_instance_valid(tooltip_panel):
		return
	var anchor_rect := anchor_control.get_global_rect()
	var tooltip_position := anchor_rect.position + Vector2(anchor_rect.size.x + 8.0, -4.0)
	var viewport_size := get_viewport().get_visible_rect().size
	if tooltip_position.x + tooltip_panel.size.x > viewport_size.x:
		tooltip_position.x = anchor_rect.position.x - tooltip_panel.size.x - 8.0
	tooltip_position.x = clampf(tooltip_position.x, 4.0, maxf(4.0, viewport_size.x - tooltip_panel.size.x - 4.0))
	tooltip_position.y = clampf(tooltip_position.y, 4.0, maxf(4.0, viewport_size.y - tooltip_panel.size.y - 4.0))
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
		return "侵蚀度"
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
