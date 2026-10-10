extends SceneTree
func _initialize() -> void:
	boot.call_deferred()
func boot() -> void:
	var script := load("res://artifacts/validation/element_reaction_text_install_20261010/capture.gd") as Script
	if script == null or not script.can_instantiate():
		quit(2)
		return
	root.add_child(script.new())
