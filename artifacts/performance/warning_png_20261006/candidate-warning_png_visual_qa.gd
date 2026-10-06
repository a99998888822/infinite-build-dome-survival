extends Node
const EFFECT = preload("res://scripts/effects/electric_spark_effect.gd")
var output := ""

func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.unfocusable = true
	var vp := SubViewport.new()
	vp.size = Vector2i(128,64)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.size = Vector2(128,64)
	bg.color = Color(0.12,0.18,0.14)
	vp.add_child(bg)
	var native := EFFECT.new()
	var baked := EFFECT.new()
	for ring in [native, baked]:
		ring.set_meta("warning_png_override", ring == baked)
		vp.add_child(ring)
		ring.set_process(false)
		ring._ring_radius = 20.0
	native.position = Vector2(32,32)
	baked.position = Vector2(96,32)
	var max_error := 0
	var sum_error := 0
	var channels := 0
	for i in 48:
		for ring in [native,baked]:
			ring._elapsed = float(i)/60.0
			ring._strike_landed = i >= 30
			ring._ring_fade_start_elapsed = 0.5
			ring.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im := vp.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		var a := im.get_region(Rect2i(0,0,64,64)).get_data()
		var b := im.get_region(Rect2i(64,0,64,64)).get_data()
		for k in a.size():
			if k % 4 == 3: continue
			var error := absi(int(a[k])-int(b[k]))
			max_error = maxi(max_error,error)
			sum_error += error
			channels += 1
		assert(im.save_png(output.path_join("pair_%02d.png" % i)) == OK)
	# Expanded orbit radii preserve particle size via the existing renderer.
	baked._ring_radius = 30.0
	assert(not baked._using_warning_atlas())
	baked._ring_radius = 20.0
	# Delayed landing must not let the atlas prematurely fade the warning.
	baked._elapsed = 0.7
	baked._strike_landed = false
	assert(baked._warning_frame() == 30)
	baked._strike_landed = true
	baked._ring_fade_start_elapsed = 0.7
	assert(baked._warning_frame() == 30)
	baked._elapsed = 0.84
	assert(baked._warning_frame() == 38)
	var result := {"frames":48,"max_channel_error":max_error,"mean_channel_error":float(sum_error)/channels,"radius_fallback_passed":true,"delayed_landing_passed":true}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WARNING_PNG_QA ",result)
	get_tree().quit()
