extends Control
class_name ZoneHarvestResultPopup

const GOLD := Color("#d3a637")
const GOLD_BRIGHT := Color("#ffe18a")
const PANEL_GREEN := Color("#0d1c14")
const TEXT := Color("#d9d0af")
const MUTED := Color("#827a61")
const CYAN := Color("#8dbda0")
const GREEN := Color("#70bf7d")

signal confirmed

var harvest_payload: Dictionary = {}
var _backdrop: ColorRect = null
var _show_tween: Tween = null
var _reward_tween: Tween = null
var _displayed_gold := 0
var _displayed_extra := 0
var _presentation_token := 0
var _reward_particles: Control = null

@onready var center_container: CenterContainer = get_node_or_null("CenterContainer")
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Content")
@onready var title_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/TitleLabel")
@onready var summary_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/SummaryLabel")
@onready var reward_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/RewardLabel")
@onready var detail_label: Label = get_node_or_null("CenterContainer/MainPanel/Content/DetailLabel")
@onready var confirm_button: Button = get_node_or_null("CenterContainer/MainPanel/Content/ConfirmButton")


func _ready() -> void:
	_prepare_layout()
	_ensure_backdrop()
	_ensure_reward_particles()
	hide_popup()
	_refresh_visual()
	if confirm_button != null and not confirm_button.pressed.is_connected(_on_confirm_button_pressed):
		confirm_button.pressed.connect(_on_confirm_button_pressed)


func configure(payload: Dictionary) -> void:
	harvest_payload = payload.duplicate(true)
	_refresh_visual()


func show_popup() -> void:
	_prepare_layout()
	_presentation_token += 1
	var token := _presentation_token
	visible = true
	_refresh_visual()
	if main_panel == null:
		return
	main_panel.pivot_offset = main_panel.size * 0.5
	main_panel.modulate.a = 0.0
	main_panel.scale = Vector2(0.95, 0.95)
	if confirm_button != null:
		confirm_button.disabled = true
	if _backdrop != null:
		_backdrop.modulate.a = 0.0
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _backdrop != null:
		_show_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.20)
	_show_tween.parallel().tween_property(main_panel, "modulate:a", 1.0, 0.26)
	_show_tween.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.34)
	_show_tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.24).set_delay(0.10)
	_show_tween.parallel().tween_property(summary_label, "modulate:a", 1.0, 0.24).set_delay(0.18)
	_show_tween.parallel().tween_property(reward_label, "modulate:a", 1.0, 0.24).set_delay(0.28)
	_show_tween.parallel().tween_property(detail_label, "modulate:a", 1.0, 0.24).set_delay(0.38)
	_start_reward_counter(token)
	_spawn_reward_particles()
	if AudioManager != null:
		AudioManager.play_ui_sfx("reward_reveal")
	get_tree().create_timer(0.76).timeout.connect(func() -> void:
		if token == _presentation_token and is_instance_valid(confirm_button):
			confirm_button.disabled = false
	)


func hide_popup() -> void:
	_presentation_token += 1
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	if _reward_tween != null and _reward_tween.is_valid():
		_reward_tween.kill()
	visible = false
	if main_panel != null:
		main_panel.modulate.a = 1.0
		main_panel.scale = Vector2.ONE
	if _backdrop != null:
		_backdrop.modulate.a = 1.0


func _prepare_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if center_container != null:
		center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_container.offset_right = -320.0
		center_container.offset_top = 24.0
		center_container.offset_bottom = -24.0
	if main_panel != null:
		main_panel.custom_minimum_size = Vector2(860, 470)
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		main_panel.add_theme_stylebox_override("panel", _make_panel_style())
	if content != null:
		content.add_theme_constant_override("separation", 12)
	if title_label != null:
		title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		title_label.add_theme_font_size_override("font_size", 25)
	if summary_label != null:
		summary_label.add_theme_color_override("font_color", TEXT)
		summary_label.add_theme_font_size_override("font_size", 13)
	if reward_label != null:
		reward_label.add_theme_color_override("font_color", GOLD_BRIGHT)
		reward_label.add_theme_font_size_override("font_size", 22)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if detail_label != null:
		detail_label.add_theme_color_override("font_color", MUTED)
		detail_label.add_theme_font_size_override("font_size", 12)
	if confirm_button != null:
		_style_confirm_button()


func _ensure_backdrop() -> void:
	if _backdrop != null:
		return
	_backdrop = ColorRect.new()
	_backdrop.name = "HarvestBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.01, 0.02, 0.015, 0.84)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = -5
	add_child(_backdrop)
	move_child(_backdrop, 0)


func _refresh_visual() -> void:
	if title_label != null:
		title_label.text = "福缘收割结果"
	if summary_label != null:
		summary_label.text = _build_summary_text()
	if reward_label != null:
		reward_label.text = _build_reward_text(_displayed_gold, _displayed_extra)
	if detail_label != null:
		detail_label.text = _build_detail_text()
	if confirm_button != null:
		confirm_button.text = "继续"


func _ensure_reward_particles() -> void:
	if _reward_particles != null:
		return
	_reward_particles = Control.new()
	_reward_particles.name = "RewardParticles"
	_reward_particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_particles.z_index = 8
	add_child(_reward_particles)
	move_child(_reward_particles, get_child_count() - 1)


func _spawn_reward_particles() -> void:
	if _reward_particles == null or reward_label == null:
		return
	var origin := reward_label.get_global_rect().get_center()
	for index in range(8):
		var coin := Label.new()
		coin.text = "●"
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.add_theme_color_override("font_color", GOLD_BRIGHT)
		coin.add_theme_font_size_override("font_size", 10 + index % 3 * 2)
		coin.position = origin - Vector2(5.0, 5.0)
		_reward_particles.add_child(coin)
		var target := origin + Vector2((index - 3.5) * 28.0, -40.0 - float(index % 3) * 16.0)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "position", target, 0.34 + index * 0.025)
		tween.tween_property(coin, "modulate:a", 0.0, 0.18)
		tween.tween_callback(coin.queue_free)


func _start_reward_counter(token: int) -> void:
	_displayed_gold = 0
	_displayed_extra = 0
	_refresh_visual()
	var target_gold := int(harvest_payload.get("gold_gain", 0))
	var target_extra := int(harvest_payload.get("extra_offer_count", 0))
	_reward_tween = create_tween()
	_reward_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_method(_set_reward_counter.bind(target_gold, target_extra), 0.0, 1.0, 0.62)
	_reward_tween.tween_callback(func() -> void:
		if token == _presentation_token:
			_displayed_gold = target_gold
			_displayed_extra = target_extra
			_refresh_visual()
			if reward_label != null:
				reward_label.pivot_offset = reward_label.size * 0.5
				var bump := create_tween()
				bump.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				bump.tween_property(reward_label, "scale", Vector2(1.10, 1.10), 0.12)
				bump.tween_property(reward_label, "scale", Vector2.ONE, 0.20)
	)


func _set_reward_counter(progress: float, target_gold: int, target_extra: int) -> void:
	_displayed_gold = int(roundf(lerpf(0.0, float(target_gold), progress)))
	_displayed_extra = int(roundf(lerpf(0.0, float(target_extra), progress)))
	if reward_label != null:
		reward_label.text = _build_reward_text(_displayed_gold, _displayed_extra)


func _build_summary_text() -> String:
	return "来源区域：%s    →    下一驻守：%s" % [str(harvest_payload.get("source_zone_name", "")), str(harvest_payload.get("next_zone_name", ""))]


func _build_reward_text(gold_gain: int, extra_offer_count: int) -> String:
	return "获得金币：%d    ·    额外候选：%d" % [gold_gain, extra_offer_count]


func _build_detail_text() -> String:
	var streak_count := int(harvest_payload.get("streak_count", 0))
	var fortune_storage := int(harvest_payload.get("fortune_storage", 0))
	var tendency_tags := _join_strings(harvest_payload.get("tendency_tags", []))
	var target_pools := _join_strings(harvest_payload.get("target_pools", []))
	var tag_weight_bonus := int(harvest_payload.get("tag_weight_bonus", 0))
	var rarity_bonus := int(harvest_payload.get("rarity_bonus", 0))
	return "连驻层数：%d\n福缘储备：%d\n倾向标签：%s\n目标池：%s\n标签权重加成：%d\n稀有度加成：%d" % [streak_count, fortune_storage, tendency_tags, target_pools, tag_weight_bonus, rarity_bonus]


func _join_strings(value_data: Variant) -> String:
	if not (value_data is Array) or (value_data as Array).is_empty():
		return "无"
	var parts: Array[String] = []
	for value in value_data:
		var text := str(value).strip_edges()
		if not text.is_empty():
			parts.append(text)
	return ", ".join(parts) if not parts.is_empty() else "无"


func _style_confirm_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#3d3217")
	normal.border_color = GOLD
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#5a481d")
	hover.border_color = GOLD_BRIGHT
	confirm_button.add_theme_stylebox_override("normal", normal)
	confirm_button.add_theme_stylebox_override("hover", hover)
	confirm_button.add_theme_stylebox_override("pressed", hover)
	confirm_button.add_theme_color_override("font_color", TEXT)
	confirm_button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_GREEN
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	style.shadow_size = 10
	style.content_margin_left = 20
	style.content_margin_top = 18
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	return style


func _on_confirm_button_pressed() -> void:
	if confirm_button != null and confirm_button.disabled:
		return
	if AudioManager != null:
		AudioManager.play_ui_sfx("confirm")
	confirmed.emit()
