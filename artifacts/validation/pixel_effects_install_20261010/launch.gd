extends SceneTree
func _initialize() -> void:
	boot.call_deferred()
func boot() -> void:
	root.add_child(load("res://artifacts/validation/pixel_effects_install_20261010/capture.gd").new())
