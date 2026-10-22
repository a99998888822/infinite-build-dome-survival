extends Node2D
class_name CombatRenderWorld

## Shared visual host for one battle viewport. Simulation owners keep their
## existing nodes; transient visuals share a layer band above grass, below actors.

# Grass never shares an actor's sorting plane. Authored effect layers (-8..100)
# retain their internal order between grass and actors (0), regardless of parent.
const GROUND_Z := -256
const GROUND_DECALS_Z := -240
const GRASS_Z := -192
const EFFECT_BASE_Z := -128


static func set_effect_layer(item: CanvasItem, authored_layer: int) -> void:
	item.z_as_relative = false
	item.z_index = EFFECT_BASE_Z + authored_layer


func _ready() -> void:
	if not is_in_group("combat_render_world"):
		add_to_group("combat_render_world")
