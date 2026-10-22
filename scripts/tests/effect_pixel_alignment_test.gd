extends Node2D
const ANCHORS = preload("res://scripts/effects/enemy_visual_anchors.gd")
const ALIGNED = preload("res://scripts/effects/aligned_atlas.gd")
var checks := 0
var failures := 0
var paint := true
var atlas: ImageTexture
var surface: Node2D

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	CampProgression.begin_transient_session()
	for name in ["mutated_grub","echo_bat","elite_rusher","underworld_wolf"]:
		var enemy := load("res://scenes/enemy/"+name+".tscn").instantiate() as EnemyController
		add_child(enemy)
		enemy.initialize(enemy.enemy_id)
		enemy.set_physics_process(false)
		var status := enemy.get_node("EnemyStatusVisual")
		var radius: float = status._get_body_radius()
		var original_head := ANCHORS.head(enemy)
		var factor := ANCHORS.factor(enemy)
		var shape := enemy.get_node("CollisionShape2D") as CollisionShape2D
		check(is_equal_approx(radius,shape.shape.radius),name+" uses collider radius for circles and capsules")
		enemy.sprite.scale *= 3.0
		enemy.sprite.position += Vector2(80,90)
		check(is_equal_approx(radius,status._get_body_radius()) and ANCHORS.head(enemy)==original_head,name+" ignores animation fit and canvas size")
		enemy.apply_body_scale(1.5)
		check(is_equal_approx(status._get_body_radius(),radius*1.5) and is_equal_approx(ANCHORS.factor(enemy),factor*1.5),name+" scales status once with body")
		check((ANCHORS.head(enemy)-original_head*1.5).length()<1.6,name+" scales stable head anchor")
		enemy.apply_body_scale(1.0)
		if name=="mutated_grub":
			check(not is_instance_valid(status._foot_frost),"no ice surfaces allocated before an ice status")
			enemy.apply_slow(2.0,0.6)
			status._process(0.01)
			preload("res://scripts/effects/enemy_status_visual_queue.gd").flush()
			check(status._foot_frost.visible and not status._body_ice.visible,"slowed draws ground ice only")
			check(not status._foot_frost.z_as_relative and status._foot_frost.z_index>CombatRenderWorld.GRASS_Z and status._foot_frost.z_index<0,"ground frost stays above grass and below the body independently of status icons")
			enemy.apply_freeze(1.0)
			status._process(0.01)
			preload("res://scripts/effects/enemy_status_visual_queue.gd").flush()
			check(status._body_ice.visible and status._body_ice.is_shell and not status._foot_frost.visible,"frozen restores the original shell without an added ice slab")
			check(not status._body_ice.z_as_relative and status._body_ice.z_index>CombatRenderWorld.GRASS_Z and status._body_ice.z_index<0,"frozen shell follows the spell layer above grass and below enemies")
			enemy._frozen_remaining=0
			enemy._slowed_remaining=0
			status._process(0.01)
			preload("res://scripts/effects/enemy_status_visual_queue.gd").flush()
			check(not status._foot_frost.visible and not status._body_ice.visible,"expired ice leaves no stale surface")
		enemy.queue_free()
		await frames()
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	add_child(viewport)
	var presentation := TextureRect.new()
	add_child(presentation)
	var sky := CanvasLayer.new()
	add_child(sky)
	CombatHitFeedback.bind_battle(viewport,[sky],presentation)
	for offset in [Vector2(1,0),Vector2(2,-1),Vector2(6,3)]:
		CombatHitFeedback._set_screen_offset(offset)
		var uv: Vector2 = CombatHitFeedback._presentation_material.get_shader_parameter("shake_uv")
		check((uv*Vector2(viewport.size)).is_equal_approx(offset),"screen shake is measured in actual world pixels")
	CombatHitFeedback.unbind_battle()
	presentation.queue_free()
	viewport.queue_free()
	sky.queue_free()
	if DisplayServer.get_name()!="headless":
		get_tree().root.size=Vector2i(300,240)
		get_tree().root.content_scale_size=Vector2i(300,240)
		var pixels := Image.create(64,32,false,Image.FORMAT_RGBA8)
		pixels.fill(Color.BLUE)
		pixels.fill_rect(Rect2i(0,0,32,32),Color.RED)
		atlas=ImageTexture.create_from_image(pixels)
		surface=Node2D.new()
		add_child(surface)
		surface.draw.connect(draw_sample)
		surface.queue_redraw()
		await frames(5)
		await RenderingServer.frame_post_draw
		var image := get_tree().root.get_texture().get_image()
		var reds := 0
		var blues := 0
		var split_cells := 0
		for y in range(0,240,3):
			for x in range(0,300,3):
				var center := image.get_pixel(x+1,y+1)
				for yy in 3:
					for xx in 3:
						var color := image.get_pixel(x+xx,y+yy)
						if color.r>0.9 and color.b<0.1: reds+=1
						if color.b>0.9 and color.r<0.1: blues+=1
						if color!=center: split_cells+=1
		check(reds>100 and blues==0,"rotated scaled atlas never samples the adjacent blue frame")
		check(split_cells==0,"final 3px cells remain uniform after rotation and noninteger scale")
		for i in 12: surface.queue_redraw(); await frames(1)
		check(surface.get_child_count()==1,"redraw reuses one surface instead of accumulating nodes")
		paint=false
		surface.queue_redraw()
		await frames()
		check(not surface.get_child(0).visible,"unused draw slots are hidden on the next redraw")
		surface.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("EFFECT_PIXEL_ALIGNMENT_TEST checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func draw_sample() -> void:
	ALIGNED.begin(surface)
	if paint: ALIGNED.draw(surface,atlas,Rect2(-24,-20,48,40),Rect2(0,0,32,32),Color.WHITE,Transform2D(0.41,Vector2(2.2,1.35),0,Vector2(150,120)))
