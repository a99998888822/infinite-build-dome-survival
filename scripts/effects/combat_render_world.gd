extends Node2D
class_name CombatRenderWorld

## Shared visual host for one battle viewport.
##
## Simulation owners such as the player, enemies and terrain stay in their
## existing nodes. Only transient visual nodes are routed here, so rendering
## has one stable ownership boundary without changing gameplay ownership.

func _ready() -> void:
	if not is_in_group("combat_render_world"):
		add_to_group("combat_render_world")
