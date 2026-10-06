extends Node
const LEGACY = preload("res://legacy_ring.gd")
var output := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.unfocusable = true
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.size = Vector2(64, 64)
	bg.color = Color(0.12, 0.18, 0.14, 1)
	bg.hide()
	vp.add_child(bg)
	var ring := LEGACY.new()
	ring.position = Vector2(32, 32)
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(ring)
	for index in 48:
		ring._elapsed = float(index) / 60.0
		ring._strike_landed = index >= 30
		ring.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im := vp.get_texture().get_image()
		assert(im.save_png(output.path_join("frame_%02d.png" % index)) == OK)
	for index in [0, 7, 21, 30, 37, 44]:
		bg.show()
		ring._elapsed = float(index) / 60.0
		ring._strike_landed = index >= 30
		ring.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(output.path_join("reference_%02d.png" % index)) == OK)
	print("BAKE_COMPLETE frames=48 size=64x64 fps=60")
	get_tree().quit()
