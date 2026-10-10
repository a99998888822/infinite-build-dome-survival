extends SceneTree
func _initialize() -> void:
	boot.call_deferred()
func boot() -> void:
	root.add_child(load("res://artifacts/previews/pixel_effects_r01_20261010/capture.gd").new())
