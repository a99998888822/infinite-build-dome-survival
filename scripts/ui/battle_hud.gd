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
var _bond_tooltip_panel: PanelContainer = null
var _displayed_bond_id: String = ""
var _wave_toast: Label = null
var _resource_pop: Label = null
var _resource_pop_tween: Tween = null
var _drawer_audio: AudioStreamPlayer = null
var _drawer_scroll_hint: Label = null
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
var _vitals_frame: Panel
var _experience_frame: Panel
var _bond_row: HBoxContainer
var _bond_buttons: Dictionary = {}

const DRAWER_OPEN_LEFT := -320.0
const DRAWER_OPEN_RIGHT := 0.0
const DRAWER_CLOSED_LEFT := -28.0
const DRAWER_CLOSED_RIGHT := 292.0
const DRAWER_ANIMATION_SECONDS := 0.36
const DRAWER_CLOSE_SECONDS := 0.32
const DRAWER_SKIN = preload("res://scripts/ui/stats_drawer_skin.gd")
const DRAWER_HANDLE: Texture2D = preload("res://assets/ui/stats_drawer/stats_leather_handle.png")
const DRAWER_OPEN_SOUND: AudioStream = preload("res://assets/audio/sfx/ui/stats_chain_open.wav")
const DRAWER_CLOSE_SOUND: AudioStream = preload("res://assets/audio/sfx/ui/stats_chain_close.wav")
const DRAWER_TEXT_COLOR := Color(0.91, 0.86, 0.70)
const TOP_BAR_HEIGHT := 56.0
const TOP_BAR_MARGIN := 12.0
const TOP_BAR_GAP := 12.0
const TOP_BAR_ACTIONS_WIDTH := 86.0
const MODAL_ECONOMY_WIDTH := 190.0
const WAVE_PANEL_SIZE := Vector2(136.0, 48.0)
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
const TOP_BAR_TIMER_HIDDEN_STATES: Array[String] = [
	MainFlowCoordinator.STATE_SHARED_REWARD_SHOP_POPUP,
	MainFlowCoordinator.STATE_SHOP_POPUP,
	MainFlowCoordinator.STATE_FINANCE_POPUP,
	MainFlowCoordinator.STATE_ESC_OVERLAY,
	MainFlowCoordinator.STATE_INTEREST_SETTLEMENT,
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
	"element_damage",
	"damage_percent",
	"attack_speed",
	"crit_chance",
	"crit_damage",
	"projectile_count",
	"area_size",
	"damage_area_size",
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
@onready var battle_top_bar: CanvasLayer = get_node_or_null("../BattleTopBar")
@onready var wave_panel: PanelContainer = get_node_or_null("../BattleTopBar/WavePanel")
@onready var wave_label: Label = get_node_or_null("../BattleTopBar/WavePanel/Content/WaveLabel")
@onready var wave_timer_label: Label = get_node_or_null("../BattleTopBar/WavePanel/Content/TimerLabel")
@onready var economy_panel: VBoxContainer = get_node_or_null("../BattleTopBar/EconomyPanel")
@onready var encyclopedia_button: TextureButton = get_node_or_null("../BattleTopBar/TopRightActions/BaikeButton")
@onready var settings_button: TextureButton = get_node_or_null("../BattleTopBar/TopRightActions/PluginButton")
@onready var gold_label: Label = get_node_or_null("../BattleTopBar/EconomyPanel/GoldRow/Label")
@onready var finance_label: Label = get_node_or_null("../BattleTopBar/EconomyPanel/FinanceRow/Label")
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
	_style_combat_hud()
	_create_stats_drawer_skin()
	_bind_viewport_resize()
	_apply_combat_layout()
	if drawer_toggle_button != null and not drawer_toggle_button.pressed.is_connected(_on_drawer_toggle_pressed):
		drawer_toggle_button.pressed.connect(_on_drawer_toggle_pressed)
	_hide_stats_scroll_bars()
	_set_drawer_locked_open(false)
	_set_drawer_open(false, false)
	_set_modal_backdrop_visible(false)


func _hud_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.044, 0.039, 0.94)
	style.border_color = Color(0.34, 0.36, 0.25, 0.95)
	style.set_border_width_all(1)
	return style


func _style_combat_hud() -> void:
	_vitals_frame = Panel.new()
	_vitals_frame.name = "VitalsFrame"
	_vitals_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_frame.add_theme_stylebox_override("panel", _hud_frame_style())
	status_panel.add_child(_vitals_frame)
	status_panel.move_child(_vitals_frame, 0)
	_experience_frame = Panel.new()
	_experience_frame.name = "ExperienceFrame"
	_experience_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_experience_frame.add_theme_stylebox_override("panel", _hud_frame_style())
	status_panel.add_child(_experience_frame)
	status_panel.move_child(_experience_frame, 0)
	top_left.add_theme_constant_override("separation", 2)
	level_label.visible = false
	for label in [hp_label, shield_label, gold_label, finance_label]:
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_constant_override("outline_size", 2)
	wave_label.add_theme_font_size_override("font_size", 12)
	wave_timer_label.add_theme_font_size_override("font_size", 22)
	wave_timer_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.65))
	gold_label.add_theme_color_override("font_color", Color(0.89, 0.76, 0.45))
	finance_label.add_theme_color_override("font_color", Color(0.65, 0.8, 0.67))
	exp_label.add_theme_font_size_override("font_size", 12)
	exp_label.add_theme_color_override("font_color", Color(0.72, 0.83, 0.62))
	exp_panel.add_theme_constant_override("separation", 2)
	exp_bar.custom_minimum_size.y = 8
	for button in [encyclopedia_button, settings_button]:
		button.custom_minimum_size = Vector2(40, 40)
		button.mouse_entered.connect(func() -> void: button.modulate = Color(1.2, 1.16, 1.03))
		button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
		button.button_down.connect(func() -> void: button.modulate = Color(0.76, 0.84, 0.75))
		button.button_up.connect(func() -> void: button.modulate = Color.WHITE)
	encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	encyclopedia_button.tooltip_text = "游戏百科"
	settings_button.tooltip_text = "游戏设置"
	drawer_toggle_button.tooltip_text = "展开 / 收起玩家属性"


func _on_encyclopedia_pressed() -> void:
	if _flow != null:
		_flow.request_battle_utility("encyclopedia")


func _on_settings_pressed() -> void:
	if _flow != null:
		_flow.request_battle_utility("settings")


func _create_stats_drawer_skin() -> void:
	if stats_drawer == null:
		return
	var panel := stats_drawer.get_node("DrawerPanel") as PanelContainer
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var skin := Control.new()
	skin.name = "WoodAndChainSkin"
	skin.set_script(DRAWER_SKIN)
	stats_drawer.add_child(skin)
	stats_drawer.move_child(skin, 0)
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.offset_left = 28.0
	stats_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var content := stats_scroll.get_parent() as VBoxContainer
	content.add_theme_constant_override("separation", 8)
	var title := content.get_node("TitleLabel") as Label
	title.custom_minimum_size = Vector2(108.0, 26.0)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", DRAWER_TEXT_COLOR)
	title.add_theme_constant_override("outline_size", 2)
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.09, 0.08, 0.055, 0.86)
	title_style.border_color = Color(0.48, 0.41, 0.26, 0.85)
	title_style.set_border_width_all(1)
	title.add_theme_stylebox_override("normal", title_style)
	stats_list.add_theme_constant_override("separation", 2)
	_drawer_scroll_hint = Label.new()
	_drawer_scroll_hint.name = "ScrollHint"
	_drawer_scroll_hint.custom_minimum_size.y = 16.0
	_drawer_scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drawer_scroll_hint.add_theme_font_size_override("font_size", 12)
	_drawer_scroll_hint.add_theme_color_override("font_color", Color(0.64, 0.62, 0.50))
	_drawer_scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_drawer_scroll_hint)
	stats_scroll.get_v_scroll_bar().changed.connect(_update_drawer_scroll_hint)
	stats_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _update_drawer_scroll_hint())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		drawer_toggle_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	drawer_toggle_button.flat = false
	drawer_toggle_button.offset_top = -22.0
	drawer_toggle_button.offset_bottom = 22.0
	drawer_toggle_button.add_theme_font_size_override("font_size", 14)
	drawer_toggle_button.add_theme_color_override("font_color", DRAWER_TEXT_COLOR)
	drawer_toggle_button.add_theme_color_override("font_disabled_color", Color(0.65, 0.63, 0.52))
	drawer_toggle_button.add_theme_constant_override("outline_size", 3)
	var handle := TextureRect.new()
	handle.name = "LeatherPullHandle"
	handle.texture = DRAWER_HANDLE
	handle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	handle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.show_behind_parent = true
	drawer_toggle_button.add_child(handle)
	# The rivet sits over the board, while the loose end stays visible when closed.
	handle.anchor_top = 0.5
	handle.anchor_bottom = 0.5
	handle.offset_left = 4.0
	handle.offset_right = 68.0
	handle.offset_top = -20.0
	handle.offset_bottom = 20.0
	drawer_toggle_button.mouse_entered.connect(func() -> void: handle.modulate = Color(1.2, 1.15, 1.0))
	drawer_toggle_button.mouse_exited.connect(func() -> void: handle.modulate = Color.WHITE)
	_drawer_audio = AudioStreamPlayer.new()
	_drawer_audio.name = "DrawerChainAudio"
	_drawer_audio.bus = AudioManager.BUS_SFX
	_drawer_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_drawer_audio.volume_db = -2.0
	add_child(_drawer_audio)


func _update_drawer_scroll_hint() -> void:
	if _drawer_scroll_hint == null:
		return
	var bar := stats_scroll.get_v_scroll_bar()
	var maximum := maxf(bar.max_value - bar.page, 0.0)
	if maximum <= 0.0:
		_drawer_scroll_hint.text = ""
	elif bar.value >= maximum - 1.0:
		_drawer_scroll_hint.text = "已到底部 · 向上滚动"
	else:
		_drawer_scroll_hint.text = "拖动查看更多" if OS.has_feature("mobile") else "滚轮查看更多"


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
		shield_label.text = "%d/%d" % [current_shield, max_shield] if current_shield > 0 else "0/0"
		var shield_row := shield_bar.get_parent() as Control
		shield_row.modulate.a = 1.0 if current_shield > 0 else 0.5
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
	if _flow != null and _flow.get_current_state() == MainFlowCoordinator.STATE_FINANCE_POPUP:
		var compact := get_viewport().get_visible_rect().size.x < 1000
		_set_drawer_locked_open(not compact)
		_set_drawer_open(not compact, false)
	call_deferred("_apply_combat_layout")


func _apply_combat_layout() -> void:
	if get_viewport() == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var bar_width := clampf(viewport_width * 0.24, 120.0, 226.0)
	var timer_size := WAVE_PANEL_SIZE if viewport_width >= 800.0 else Vector2(112, 48)
	top_left.position = Vector2(18, 6)
	_vitals_frame.position = Vector2(10, 2)
	_vitals_frame.size = Vector2(bar_width + 44, 52)
	if hp_bar != null:
		hp_bar.custom_minimum_size.x = bar_width
	if shield_bar != null:
		shield_bar.custom_minimum_size.x = bar_width
	if wave_panel != null:
		wave_panel.anchor_left = 0.0
		wave_panel.anchor_top = 0.0
		wave_panel.anchor_right = 0.0
		wave_panel.anchor_bottom = 0.0
		wave_panel.position = Vector2(
			(viewport_width - timer_size.x) * 0.5,
			(TOP_BAR_HEIGHT - timer_size.y) * 0.5
		)
		wave_panel.custom_minimum_size = timer_size
		wave_panel.size = timer_size
	var actions := encyclopedia_button.get_parent() as Control
	actions.offset_left = -TOP_BAR_MARGIN - TOP_BAR_ACTIONS_WIDTH
	actions.offset_right = -TOP_BAR_MARGIN
	actions.offset_top = 8.0
	actions.offset_bottom = 48.0
	if economy_panel != null:
		var wave_right := (viewport_width + timer_size.x) * 0.5
		var actions_left := viewport_width - TOP_BAR_MARGIN - TOP_BAR_ACTIONS_WIDTH
		var timer_hidden := _flow != null and TOP_BAR_TIMER_HIDDEN_STATES.has(_flow.get_current_state())
		var economy_left := wave_right + TOP_BAR_GAP
		var economy_width := 168.0
		if timer_hidden:
			economy_width = minf(MODAL_ECONOMY_WIDTH, maxf(actions_left - TOP_BAR_GAP, 0.0))
			economy_left = actions_left - TOP_BAR_GAP - economy_width
		else:
			var available_width := maxf(actions_left - TOP_BAR_GAP - economy_left, 0.0)
			economy_width = minf(economy_width, available_width)
		var economy_size := Vector2(economy_width, 44.0)
		economy_panel.anchor_left = 0.0
		economy_panel.anchor_top = 0.0
		economy_panel.anchor_right = 0.0
		economy_panel.anchor_bottom = 0.0
		economy_panel.position = Vector2(economy_left, (TOP_BAR_HEIGHT - economy_size.y) * 0.5)
		economy_panel.size = economy_size
	if exp_panel != null:
		if OS.has_feature("mobile"):
			exp_panel.anchor_left = 0.28
		else:
			exp_panel.anchor_left = 0.10 if viewport_width < 720.0 else 0.15
		exp_panel.anchor_right = 0.90 if viewport_width < 720.0 else 0.85
		exp_panel.offset_top = -39.0
		exp_panel.offset_bottom = -10.0
		_experience_frame.position = Vector2(viewport_width * exp_panel.anchor_left - 10, get_viewport().get_visible_rect().size.y - 43)
		_experience_frame.size = Vector2(viewport_width * (exp_panel.anchor_right - exp_panel.anchor_left) + 20, 37)
	if _bond_row != null:
		_bond_row.position = Vector2(viewport_width * exp_panel.anchor_left, get_viewport().get_visible_rect().size.y - 75)


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
	# HUD controls are positioned in the stretched logical canvas.  Using the
	# physical window size here makes modal panels too tall whenever it differs
	# from the 1152x648 design canvas.
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left := MODAL_SAFE_EDGE_MARGIN
	var top := minf(MODAL_FALLBACK_TOP, viewport_size.y * 0.18)
	var state := _flow.get_current_state() if _flow != null else ""
	var right := MODAL_FALLBACK_RIGHT_CLOSED
	var compact_finance := state == MainFlowCoordinator.STATE_FINANCE_POPUP and viewport_size.x < 1000
	if _drawer_open or (DRAWER_AUTO_OPEN_STATES.has(state) and not compact_finance):
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
		if battle_top_bar != null:
			battle_top_bar.visible = false
		if status_panel != null:
			status_panel.visible = false
		return
	var in_battle := _flow.get_current_mode() == MainFlowCoordinator.MODE_BATTLE
	var state := _flow.get_current_state()
	var utility_available := state in [MainFlowCoordinator.STATE_WAVE_COMBAT, MainFlowCoordinator.STATE_BATTLE_PREPARE]
	encyclopedia_button.disabled = not utility_available
	settings_button.disabled = not utility_available
	if not in_battle or _flow.battle_resolved:
		visible = false
	elif state == MainFlowCoordinator.STATE_BATTLE_RESULT:
		visible = false
	else:
		visible = true
	if battle_top_bar != null:
		battle_top_bar.visible = in_battle and not _flow.battle_resolved and state != MainFlowCoordinator.STATE_BATTLE_RESULT
	if wave_panel != null:
		wave_panel.visible = battle_top_bar != null and battle_top_bar.visible and not TOP_BAR_TIMER_HIDDEN_STATES.has(state)
	if status_panel != null:
		status_panel.visible = visible and not STATUS_HIDDEN_MODAL_STATES.has(state)


func _on_drawer_toggle_pressed() -> void:
	if _drawer_locked_open:
		return
	_set_drawer_open(not _drawer_open, true)


func _on_flow_state_changed(_previous_state: String, current_state: String) -> void:
	var compact_finance := current_state == MainFlowCoordinator.STATE_FINANCE_POPUP and get_viewport().get_visible_rect().size.x < 1000
	var lock_drawer_open := DRAWER_LOCKED_OPEN_STATES.has(current_state) and not compact_finance
	_set_drawer_locked_open(lock_drawer_open)
	_set_modal_backdrop_visible(lock_drawer_open or compact_finance)
	if compact_finance:
		_set_drawer_open(false, false)
	elif DRAWER_AUTO_OPEN_STATES.has(current_state):
		_set_drawer_open(true, true)
	elif current_state == MainFlowCoordinator.STATE_WAVE_COMBAT:
		_set_drawer_open(false, true)
	else:
		_set_modal_backdrop_visible(false)
	call_deferred("_apply_combat_layout")


func is_stats_drawer_open() -> bool:
	return _drawer_open


func _set_drawer_open(open: bool, animated: bool) -> void:
	if stats_drawer == null:
		return
	# Flow transitions can request the same target repeatedly. Do not restart sound or motion.
	if animated and open == _drawer_open:
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
		if _drawer_audio != null:
			_drawer_audio.stop()
		stats_drawer.offset_left = target_left
		stats_drawer.offset_right = target_right
		_refresh_visibility()
		return

	_hide_damage_tooltip()
	var full_duration := DRAWER_ANIMATION_SECONDS if open else DRAWER_CLOSE_SECONDS
	var remaining := clampf(absf(target_left - stats_drawer.offset_left) / 292.0, 0.0, 1.0)
	var duration := lerpf(0.18, full_duration, remaining)
	if _drawer_audio != null:
		_drawer_audio.stop()
		_drawer_audio.stream = DRAWER_OPEN_SOUND if open else DRAWER_CLOSE_SOUND
		_drawer_audio.pitch_scale = full_duration / duration
		_drawer_audio.play()
	_drawer_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_drawer_tween.set_trans(Tween.TRANS_SINE)
	_drawer_tween.set_ease(Tween.EASE_IN_OUT)
	_drawer_tween.parallel().tween_property(stats_drawer, "offset_left", target_left, duration)
	_drawer_tween.parallel().tween_property(stats_drawer, "offset_right", target_right, duration)
	_drawer_tween.finished.connect(func() -> void: _drawer_tween = null)
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
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER


func _input(event: InputEvent) -> void:
	if not visible or not _drawer_open or stats_scroll == null or not stats_scroll.is_visible_in_tree() or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or not stats_scroll.get_global_rect().has_point(mouse_event.position):
		return
	var target_scroll := stats_scroll.scroll_vertical
	var bar := stats_scroll.get_v_scroll_bar()
	var max_scroll := maxi(roundi(bar.max_value - bar.page), 0)
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
					value_label.add_theme_color_override("font_color", DRAWER_TEXT_COLOR)
				else:
					value_label.add_theme_color_override("font_color", STAT_PREVIEW_GAIN_COLOR if preview_value > current_value else STAT_PREVIEW_LOSS_COLOR)
			else:
				value_label.text = _format_stat_value(stat_id, _get_display_stat_value(stat_id))
				value_label.add_theme_color_override("font_color", DRAWER_TEXT_COLOR)
		var name_label := _stat_name_labels.get(stat_id_variant, null) as Label
		if name_label != null:
			name_label.text = _get_stat_display_name(stat_id)
			name_label.tooltip_text = name_label.text
			if stat_id == "armor":
				# Use the custom tooltip panel below; the built-in tooltip would show a duplicate.
				name_label.tooltip_text = ""


func _ensure_stat_rows() -> void:
	if stats_list == null or not _stat_value_labels.is_empty():
		return

	for stat_id in _get_ordered_stat_ids():
		if stat_id == "damage_taken_percent" or stat_id == "shield" or stat_id == "finance":
			continue
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = 28.0
		row.add_theme_constant_override("separation", 6)
		var backing := PanelContainer.new()
		backing.mouse_filter = Control.MOUSE_FILTER_PASS
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.055, 0.05, 0.037, 0.55 if _stat_value_labels.size() % 2 == 0 else 0.34)
		row_style.border_color = Color(0.40, 0.36, 0.25, 0.35)
		row_style.border_width_bottom = 1
		row_style.content_margin_left = 5.0
		row_style.content_margin_right = 5.0
		backing.add_theme_stylebox_override("panel", row_style)
		backing.add_child(row)

		var name_label := Label.new()
		name_label.text = _get_stat_display_name(stat_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 14)
		if name_label.text.length() > 7:
			name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", DRAWER_TEXT_COLOR)
		name_label.add_theme_constant_override("outline_size", 2)
		name_label.tooltip_text = name_label.text
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name_label)

		if stat_id == "armor":
			name_label.mouse_filter = Control.MOUSE_FILTER_STOP
			name_label.mouse_default_cursor_shape = Control.CURSOR_HELP
			name_label.tooltip_text = ""
			name_label.mouse_entered.connect(_show_damage_tooltip.bind(name_label))
			name_label.mouse_exited.connect(_hide_damage_tooltip)

		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(58.0, 0.0)
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", DRAWER_TEXT_COLOR)
		value_label.add_theme_constant_override("outline_size", 2)

		row.add_child(value_label)
		stats_list.add_child(backing)
		_stat_value_labels[stat_id] = value_label
		_stat_name_labels[stat_id] = name_label


func _get_damage_tooltip_text() -> String:
	if _player == null:
		return "护甲减免后，承受xx%的伤害"
	var damage_taken_percent := _format_stat_value("damage_taken_percent", _player.get_stat("damage_taken_percent"))
	return "护甲减免后，承受%s的伤害" % damage_taken_percent



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
	var finance := _wave_manager.finance_system if _wave_manager != null else null
	return StatPreviewBuilder.get_display_stat_value(_player, stat_id, finance)


func _get_stat_display_name(stat_id: String) -> String:
	var eldritch_name_changed := _player != null and _player.get_stat("divinity") > ELDRITCH_NAMING_THRESHOLD
	if stat_id == "humanity":
		return "人性" if eldritch_name_changed else "理智值"
	if stat_id == "divinity":
		return "侵蚀度"
	return StatDefinitions.get_display_name(stat_id)


func _format_stat_value(stat_id: String, value: float) -> String:
	var text_value := "%.2f" % value
	if (StatDefinitions.is_integer_stat(stat_id) and stat_id != "shop_price_percent") or is_equal_approx(value, roundf(value)):
		text_value = "%d" % roundi(value)
	return text_value + ("%" if StatDefinitions.is_percent_stat(stat_id) else "")


func _refresh_bond_indicator() -> void:
	if _flow == null or _flow.get_current_state() != MainFlowCoordinator.STATE_WAVE_COMBAT:
		_displayed_bond_id = ""
		_hide_bond_tooltip()
		if _bond_row != null:
			_bond_row.visible = false
		return
	if _bond_row == null:
		_bond_row = HBoxContainer.new()
		_bond_row.name = "BondRow"
		_bond_row.add_theme_constant_override("separation", 6)
		_bond_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bond_row)
		call_deferred("_apply_combat_layout")
	_bond_row.visible = true
	for bond in DataRegistry.get_table("bonds"):
		if not (bond is Dictionary):
			continue
		var bond_id := str(bond.get("id", ""))
		if bond_id.is_empty():
			continue
		var count := _player.relic_system.get_bond_count(bond_id)
		if not _bond_buttons.has(bond_id):
			var button := Button.new()
			button.name = bond_id
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(86, 26)
			button.add_theme_font_size_override("font_size", 12)
			button.add_theme_stylebox_override("normal", _hud_frame_style())
			button.mouse_entered.connect(_inspect_bond.bind(bond_id, button))
			button.mouse_exited.connect(_hide_bond_tooltip)
			button.pressed.connect(_inspect_bond.bind(bond_id, button))
			_bond_row.add_child(button)
			_bond_buttons[bond_id] = button
		var indicator := _bond_buttons[bond_id] as Button
		indicator.visible = count > 0
		indicator.text = "%s %d" % [BondDisplay.get_bond_name(bond_id), count]
		indicator.modulate = Color.WHITE if count >= 2 else Color(0.75, 0.8, 0.72)


func _inspect_bond(bond_id: String, indicator: Button) -> void:
	_displayed_bond_id = bond_id
	_bond_indicator = indicator
	_show_bond_tooltip()


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
		tooltip_position = indicator_rect.position - Vector2(0.0, tooltip_panel.size.y + 8.0)
	tooltip_position.x = maxf(tooltip_position.x, 4.0)
	tooltip_position.y = clampf(tooltip_position.y, 4.0, viewport_size.y - tooltip_panel.size.y - 4.0)
	tooltip_panel.position = tooltip_position


func _hide_bond_tooltip() -> void:
	if _bond_tooltip_panel != null:
		_bond_tooltip_panel.queue_free()
		_bond_tooltip_panel = null
