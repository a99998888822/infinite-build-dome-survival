extends Node

class SurvivalChecks extends "res://scripts/core/bootstrap.gd":
	func _ready() -> void:
		pass

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	var checks := SurvivalChecks.new()
	add_child(checks)
	var passed := checks._run_survival_relic_checks()
	await get_tree().process_frame
	checks.free()
	print("BOOTSTRAP_SURVIVAL_COMPLETE passed=", passed)
	get_tree().quit(0 if passed else 1)
