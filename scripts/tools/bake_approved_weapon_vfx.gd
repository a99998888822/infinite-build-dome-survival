extends Node
## Offline GPU baking only. Never loaded by gameplay.
const SOURCE=preload("res://scripts/tools/weapon_vfx_sources/approved_geometry.gd")
const OUT="res://artifacts/reviews/approved-weapon-vfx-bake/raw"
var canvas: Node2D
var key: String
var index:=0
var definitions: Dictionary={}

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless" or not "--background-capture" in OS.get_cmdline_user_args(): get_tree().quit(2); return
	WindowSettings._startup_applied=true
	CampProgression.begin_transient_session()
	get_window().size=Vector2i(512,320)
	get_window().content_scale_size=get_window().size
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	get_window().transparent_bg=true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	canvas=Node2D.new()
	add_child(canvas)
	canvas.position=Vector2(128,160)
	canvas.draw.connect(paint)
	for kind in ["arrow","spear","rock0","rock1","rock2","rock3","rock4","branch0","branch1","branch2","branch3","branch4"]:
		key=kind
		var count:=3 if kind=="arrow" else 13 if kind=="spear" else 23
		DirAccess.make_dir_recursive_absolute(OUT.path_join(kind))
		for n in count:
			index=n
			canvas.queue_redraw()
			await RenderingServer.frame_post_draw
			assert(get_window().get_texture().get_image().save_png(OUT.path_join(kind).path_join("%03d.png"%n))==OK)
		definitions[kind]={"count":count,"fps":60 if kind=="spear" else 18,"pivot":[128,160]}
		print("BAKED_WEAPON ",kind," frames=",count)
	FileAccess.open(OUT.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(definitions,"  "))
	CampProgression.end_transient_session()
	get_tree().quit()

func paint() -> void:
	canvas.draw_set_transform(Vector2.ZERO)
	if key=="arrow": SOURCE.arrow(canvas,Vector2.RIGHT,[0.0,0.02,0.06][index])
	elif key=="spear": SOURCE.spear(canvas,Vector2.RIGHT,220.0,23.0,index/60.0,0.12)
	else:
		var variant:=int(key.right(1))
		var point:=Vector2(variant*107,0)
		canvas.draw_set_transform(-point)
		SOURCE.rocks(canvas,point,Vector2.RIGHT,index/18.0,107.0,key.begins_with("branch"),1.0,-10000.0)
