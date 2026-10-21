extends Node
## Alternate inputs must survive every production backdrop setup layer.

class FixtureBackdrop extends CavernSunlightBackdrop:
	func _ready() -> void:
		set_process(false)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data_config/cavern_meadow_battlefield.json"))
	config.surface_texture = CavernSunlightBackdrop.CLOUD_TEXTURE.resource_path
	config.surface_context = CavernSunlightBackdrop.ROCK_FACE_MASK.resource_path
	var path := "user://cavern_config_source_test_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(config))
	file.close()
	var player := preload("res://scenes/player/player_root.tscn").instantiate() as PlayerController
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var horizon := CavernPitHorizon.new()
	add_child(horizon)
	var backdrop := FixtureBackdrop.new()
	backdrop.scenery_config_path = path
	backdrop.player = player
	backdrop.horizon = horizon
	add_child(backdrop)
	backdrop._setup()
	backdrop.set_process(false)
	var texture := backdrop.ground_material.get_shader_parameter("surface_texture") as Texture2D
	var expected_context := CavernSunlightBackdrop.ROCK_FACE_MASK.get_image()
	if expected_context.is_compressed(): expected_context.decompress()
	var texture_ok := texture != null and texture.resource_path == str(config.surface_texture)
	var context_ok := backdrop.surface_context.get_data() == expected_context.get_data()
	print("PASS " if texture_ok else "FAIL ", "configured texture survives production sunlight shader setup")
	print("PASS " if context_ok else "FAIL ", "configured context drives terrain sampling after grassland setup")
	backdrop.detach_player()
	backdrop.free()
	horizon.free()
	player.free()
	DirAccess.remove_absolute(path)
	var failures := int(not texture_ok) + int(not context_ok)
	print("CAVERN_CONFIG_SOURCE_TEST checks=2 failures=", failures)
	get_tree().quit(1 if failures else 0)
