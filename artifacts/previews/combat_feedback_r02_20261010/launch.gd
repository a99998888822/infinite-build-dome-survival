extends SceneTree
func _initialize() -> void:
	boot.call_deferred()
func boot() -> void:
	root.add_child(load("res://artifacts/previews/combat_feedback_r02_20261010/capture.gd").new())
