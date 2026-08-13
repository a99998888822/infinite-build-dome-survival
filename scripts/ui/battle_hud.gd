extends CanvasLayer
class_name BattleHud

var _flow: MainFlowCoordinator = null
var _player: PlayerController = null
var _wave_manager: WaveManager = null

@onready var hp_label: Label = get_node_or_null("StatusPanel/Content/HpLabel")
@onready var exp_label: Label = get_node_or_null("StatusPanel/Content/ExpLabel")
@onready var gold_label: Label = get_node_or_null("StatusPanel/Content/GoldLabel")
@onready var wave_label: Label = get_node_or_null("StatusPanel/Content/WaveLabel")
@onready var prepare_panel: PanelContainer = get_node_or_null("PreparePanel")
@onready var start_button: Button = get_node_or_null("PreparePanel/Content/StartButton")


func _ready() -> void:
	if start_button != null and not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)


func bind_context(flow: MainFlowCoordinator, player: PlayerController, wave_manager: WaveManager) -> void:
	_flow = flow
	_player = player
	_wave_manager = wave_manager
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_all()


func _refresh_all() -> void:
	if _player == null or _wave_manager == null or _flow == null:
		return
	_refresh_labels()
	_refresh_prepare_panel()


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
	if wave_label != null:
		var wave_number := _wave_manager.current_wave_index + 1
		var time_left := maxf(_wave_manager.wave_time_left, 0.0)
		wave_label.text = "第 %d 波  剩余 %.1f 秒" % [wave_number, time_left]


func _refresh_prepare_panel() -> void:
	var in_battle := _flow.get_current_mode() == MainFlowCoordinator.MODE_BATTLE
	var state := _flow.get_current_state()
	var show_prepare := in_battle and not _flow.battle_resolved and state == MainFlowCoordinator.STATE_BATTLE_PREPARE
	if prepare_panel != null:
		prepare_panel.visible = show_prepare
	if not in_battle or _flow.battle_resolved:
		visible = false
	elif state == MainFlowCoordinator.STATE_BATTLE_RESULT:
		visible = false
	else:
		visible = true


func _on_start_pressed() -> void:
	if _flow != null:
		_flow.request_next_wave()
