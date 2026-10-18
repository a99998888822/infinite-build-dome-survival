extends Node
## F6 review: normal controls and progression, first wave reaches night after five seconds.
var game: GameRoot

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	CampProgression.begin_transient_session()
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	for i in 12: await get_tree().process_frame
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	for i in 4: await get_tree().process_frame
	if not flow.confirm_character_selection(): return
	for i in 10: await get_tree().process_frame
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	if flow.current_state==MainFlowCoordinator.STATE_COMBAT_GUIDE:
		battle.combat_guide.skip_button.pressed.emit()
		for i in 4: await get_tree().process_frame
	battle.wave_manager.wave_time_left = 5.0

func _exit_tree() -> void:
	CampProgression.end_transient_session()
