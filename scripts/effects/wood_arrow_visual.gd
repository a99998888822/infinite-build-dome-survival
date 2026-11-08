extends Node2D
## Compact shared atlas. No emitter, no runtime textures, no damage ownership.
const ART=preload("res://scripts/effects/approved_weapon_vfx.gd")
var elapsed:=0.0
var frame:=-1

func advance(delta: float) -> void:
	elapsed+=delta
	var next:=0 if elapsed<0.02 else 1 if elapsed<0.06 else 2
	if next!=frame:
		frame=next
		queue_redraw()

func _draw() -> void:
	ART.draw(self,"arrow",maxi(frame,0))
