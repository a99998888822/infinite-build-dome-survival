extends Node2D
const FIRE = preload("res://scripts/effects/pixel_fire_visual.gd")
const QUEUE = preload("res://scripts/effects/enemy_status_visual_queue.gd")
const REACTION = preload("res://scripts/effects/element_reaction_visual.gd")
const PARTICLES = preload("res://scripts/effects/particle_world.gd")
const SORTED = preload("res://scripts/effects/combat_sorted_visual.gd")
var checks := 0
var failures := 0
var output := ""
var actors: Node2D
var back: EnemyController
var front: EnemyController
var status: Node2D
var metrics := {}

func _ready() -> void:
	WindowSettings._startup_applied = true
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(9)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(99))

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", note)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func picture(viewport: Viewport, name: String) -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	var bitmap := viewport.get_texture().get_image()
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		bitmap.save_png(output.path_join(name + ".png"))
	return bitmap

func changes(a: Image, b: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var delta := a.get_pixel(x,y) - b.get_pixel(x,y)
			if absf(delta.r)+absf(delta.g)+absf(delta.b) > 0.02: count += 1
	return count

func fixture(enemy: EnemyController, tint: Color) -> void:
	var bitmap := Image.create(80, 90, false, Image.FORMAT_RGBA8)
	bitmap.fill(tint)
	enemy.sprite.texture = ImageTexture.create_from_image(bitmap)
	enemy.sprite.hframes = 1
	enemy.sprite.vframes = 1
	enemy.sprite.scale = Vector2.ONE
	enemy.sprite.position = Vector2(0,-35)
	enemy.sprite.modulate = Color.WHITE
	enemy.sprite.self_modulate = Color.WHITE
	enemy.sprite.material = null

func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().unfocusable = true
	get_window().size = Vector2i(640,360)
	get_window().content_scale_size = Vector2i(640,360)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	actors.add_to_group("combat_actor_sort_root")
	add_child(actors)
	back = load("res://scenes/enemy/mutated_grub.tscn").instantiate()
	front = load("res://scenes/enemy/mutated_grub.tscn").instantiate()
	actors.add_child(back)
	actors.add_child(front)
	back.position = Vector2(160,180)
	front.position = Vector2(160,185)
	for enemy in [back,front]:
		enemy.current_hp = 10000
		enemy.set_physics_process(false)
	fixture(back, Color(0.05,0.15,0.9))
	fixture(front, Color(0.9,0.06,0.08))
	front.hide()
	await frames()
	status = back.get_node("EnemyStatusVisual")
	back.apply_burning(5,1,"layer_test")
	QUEUE.flush()
	status.set_process(false)
	FIRE.clock.set_process(false)
	FIRE.clock.advance(0.24)
	check(status._flame_visual.actor_local, "burning uses actor-local rendering")
	check(status._body_effects.get_parent() == status and status.get_index() > back.sprite.get_index(), "state draws after own body inside the same Y-sort group")
	check(status._body_effects.z_index == 0 and status._icons.z_index == CombatRenderWorld.INFO_Z, "body state and head icons have separate depth")
	check(FIRE.clock.counts.get(25,0) == 0 and status._flame_visual._local_batch != null, "local flame never appears in a second global batch")
	if DisplayServer.get_name() != "headless": await _state_pixels("burning")
	back.clear_burning()
	back.apply_freeze(5)
	status.request_sync()
	QUEUE.flush()
	status.set_process(false)
	check(status._body_ice.get_parent() == status._body_effects and status._body_ice.z_index == 0, "ice shell shares actor sorting and keeps ground frost separate")
	if DisplayServer.get_name() != "headless": await _state_pixels("frozen")
	var high := Node2D.new()
	high.z_index = 500
	add_child(high)
	for kind in ["freeze", "thaw", "steam", "wet_spread", "ice_expand"]:
		REACTION.spawn(high,kind,Vector2(400,160))
		var cue: Node2D = high.get_child(high.get_child_count()-1)
		cue.set_process(false)
		cue.elapsed = 0.23
		cue.queue_redraw()
		await frames()
		var expected := CombatRenderWorld.REACTION_Z if kind in ["freeze","thaw"] else (CombatRenderWorld.STEAM_Z if kind == "steam" else (-135 if kind == "wet_spread" else -133))
		check(not cue.z_as_relative and cue.z_index == expected, kind + " keeps its role after drawing under a high parent")
		cue.queue_free()
		await frames()
	REACTION.spawn(high,"conduct",back.global_position,{"follow":weakref(back)})
	var conduct: Node2D
	for node in back.get_children():
		if node.get_script() == REACTION: conduct = node
	check(conduct != null and conduct.z_index == 0, "conduct attaches to the affected actor")
	if conduct != null: conduct.queue_free()
	var proxy := SORTED.attach(high)
	check(proxy.get_parent() == actors and proxy.z_index == 0, "persistent visual joins real actor sorting without moving simulation")
	high.position = Vector2(80,50)
	proxy.sync()
	check(proxy.global_transform == high.global_transform and high.get_parent() == self, "sorted proxy tracks position without reparenting logic")
	high.hide()
	proxy.sync()
	check(not proxy.visible, "hidden simulation hides detached visual")
	high.queue_free()
	await frames()
	check(not is_instance_valid(proxy), "detached visual is released with its simulation owner")
	await _particle_roles()
	if DisplayServer.get_name() != "headless": await _flame_passes()
	await _dense_flames()
	actors.queue_free()
	await frames()
	check(FIRE.visual_count == 0, "all actor-local flame resources are released")
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics,"\t"))
	print("COMBAT_LAYER_SEMANTICS checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _state_pixels(label: String) -> void:
	front.hide()
	front.position.y = 185
	status._body_effects.hide()
	var plain := await picture(get_viewport(),label+"_plain")
	status._body_effects.show()
	var covered := await picture(get_viewport(),label+"_own_body")
	check(changes(plain,covered,Rect2i(125,125,70,55)) > 12, label+" visibly covers its own body")
	front.show()
	var occluded := await picture(get_viewport(),label+"_front_actor")
	status._body_effects.hide()
	var control := await picture(get_viewport(),label+"_front_control")
	check(changes(occluded,control,Rect2i(130,125,60,50)) == 0,label+" does not bleed through another actor in front")
	status._body_effects.show()
	front.position.y = 140
	var crossed := await picture(get_viewport(),label+"_crossed")
	status._body_effects.hide()
	var crossed_control := await picture(get_viewport(),label+"_crossed_control")
	check(changes(crossed,crossed_control,Rect2i(125,125,70,55)) > 12,label+" becomes visible when actors exchange depth")
	status._body_effects.show()
	front.hide()

func _particle_roles() -> void:
	var world := PARTICLES.new()
	add_child(world)
	world.set_process(false)
	for profile in ["impact_terrain","projectile_trail","impact_green","ice_burst","steam_burst","fire_spark"]:
		PARTICLES.emit_profile(world,profile,Vector2(400,100))
	world._sync_render_batches()
	var total := 0
	for layer: int in world._render_batches:
		var batch: MultiMeshInstance2D = world._render_batches[layer]
		check(batch.z_index == layer and not batch.z_as_relative,"particle batch keeps independent role %d" % layer)
		total += batch.multimesh.visible_instance_count
	check(total == world.get_active_particle_count(), "each particle is submitted exactly once across render roles")
	var clock: float = world._gpu_clock
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	world._process(1.0)
	check(world._gpu_clock == clock, "all particle roles share the same paused clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	PARTICLES.emit_profile(world,"impact_green",Vector2.ZERO,Vector2.RIGHT,100.0)
	world._sync_render_batches()
	check(world.get_active_particle_count() == 900,"render partitions retain one global 900-particle budget")
	world._process(10.0)
	check(world.get_active_particle_count() == 0, "all roles expire through original shared simulation")
	world.queue_free()
	await frames()

func _flame_passes() -> void:
	for script in ["res://scripts/effects/copper_lamp_flame.gd","res://scripts/enemies/underworld_wolf_flame.gd"]:
		var view := SubViewport.new()
		view.size = Vector2i(320,280)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		var flame: Node2D = load(script).new()
		view.add_child(flame)
		flame.position = Vector2(60,140)
		if "copper" in script: flame.configure(Vector2.RIGHT,200,60,0.43,false)
		else: flame.configure(Vector2.RIGHT,200,60,0.43)
		var edges: Node2D = flame.get_meta("flame_front")
		check(flame.z_index == CombatRenderWorld.BACK_Z and edges.z_index == CombatRenderWorld.BEAM_Z,"spray separates broad background from foreground edges")
		edges.hide()
		flame.flame_material.set_shader_parameter("render_part",1)
		var a := await picture(view,"spray_back_"+str(view.get_instance_id()))
		flame.flame_material.set_shader_parameter("render_part",2)
		var b := await picture(view,"spray_front_"+str(view.get_instance_id()))
		var overlap := 0
		var front_count := 0
		for y in view.size.y:
			for x in view.size.x:
				if b.get_pixel(x,y).a > 0.01:
					front_count += 1
					if a.get_pixel(x,y).a > 0.01: overlap += 1
		check(overlap == 0 and front_count > 10,"spray passes are complementary with visible sparse foreground")
		view.queue_free()
		await frames()

func _dense_flames() -> void:
	var crowd := Node2D.new()
	actors.add_child(crowd)
	for i in 160:
		var flame := FIRE.new()
		crowd.add_child(flame)
		flame.position = Vector2(20+(i%20)*28,230+(i/20)*12)
		flame.setup_status(10)
		flame.set_palette(i%3)
	await frames()
	FIRE.clock.set_process(false)
	FIRE.clock.flush()
	var times: Array[int] = []
	for i in 40:
		var start := Time.get_ticks_usec()
		FIRE.clock.advance(1.0/60.0)
		times.append(Time.get_ticks_usec()-start)
	times.sort()
	metrics["160_local_flames_cpu_flush_median_us"] = times[20]
	metrics["160_local_flames_cpu_flush_p95_us"] = times[38]
	print("DENSE_FLAME_CPU ",JSON.stringify(metrics))
	check(crowd.get_child_count() == 160 and FIRE.clock.counts.get(25,0) == 0,"dense actor states share time and avoid duplicate global geometry")
	if DisplayServer.get_name() != "headless": await picture(get_viewport(),"dense_flames")
	crowd.queue_free()
	await frames()
