extends Node2D
const BATCH = preload("res://scripts/effects/pixel_particle_batch.gd")
var output := ""
var shapes := [
	[Vector2(24,24),Vector2(12,8),0.0,Color.WHITE,false],
	[Vector2(54,24),Vector2(16,6),0.7,Color(1,0.4,0.1,0.6),false],
	[Vector2(84,24),Vector2(14,14),0.0,Color(0.5,0.8,1,0.4),true],
	[Vector2(54,64),Vector2(30,30),0.0,Color(1,1,1,0.1),true],
	[Vector2(54,64),Vector2(6,4),0.2,Color.WHITE,false]]

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	var batch := BATCH.create(shapes.size())
	add_child(batch)
	batch.position.x = 128
	for i in shapes.size():
		var s: Array = shapes[i]
		BATCH.put(batch.multimesh,i,s[0],s[1],s[2],s[3],s[4])
	batch.multimesh.visible_instance_count = shapes.size()
	_run.call_deferred()

func _draw() -> void:
	for s in shapes:
		draw_set_transform(s[0],s[2],Vector2.ONE)
		if s[4]: draw_circle(Vector2.ZERO,s[1].x/2,s[3])
		else: draw_rect(Rect2(-s[1]/2,s[1]),s[3])
	draw_set_transform(Vector2.ZERO)

func _run() -> void:
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(256,128)
	get_tree().root.content_scale_size = Vector2i(256,128)
	RenderingServer.set_default_clear_color(Color(0.1,0.1,0.1,1))
	for _i in 8: await get_tree().process_frame
	if DisplayServer.get_name() != "headless" and not output.is_empty():
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		get_tree().root.get_texture().get_image().save_png(output.path_join("batch_shapes.png"))
	print("PIXEL_BATCH_TEST_COMPLETE")
	get_tree().quit()
