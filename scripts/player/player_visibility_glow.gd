extends ColorRect

## Local visual cue: follows the player and stays beneath their sprite.
var _time := 0.0
@onready var _player: PlayerController = get_parent() as PlayerController
@onready var _glow_material: ShaderMaterial = material as ShaderMaterial


func _process(delta: float) -> void:
	visible = is_instance_valid(_player) and _player.alive
	if not visible or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_time += delta
	_glow_material.set_shader_parameter("glow_time", _time)
