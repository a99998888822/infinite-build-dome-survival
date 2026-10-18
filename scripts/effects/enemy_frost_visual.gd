extends Node2D
const BAKED = preload("res://scripts/effects/baked_pixel_frames.gd")
var body_radius := -1.0
var is_shell := false

func configure(radius: float, shell: bool) -> void:
	if body_radius == radius and is_shell == shell: return
	body_radius = radius
	is_shell = shell
	queue_redraw()

func _draw() -> void:
	BAKED.ALIGNED.begin(self)
	if is_shell:
		var frame := int(round(clampf(body_radius*1.1,15,25)-15))
		BAKED.draw_aligned(self,"ice_shell",frame,Vector2.ONE,Color.WHITE,Transform2D.IDENTITY,1.0)
	else:
		# Keep the original six-armed snowflake; never infer scale from sprite padding.
		var size := Vector2.ONE*maxf(1.0,body_radius*0.88/16.0)
		BAKED.draw_aligned(self,"slowed",0,size,Color.WHITE,Transform2D.IDENTITY,1.0)
