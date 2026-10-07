extends Node2D
const WORLD = preload("res://scripts/effects/particle_world.gd")
const ICE = preload("res://scripts/effects/ice_field_effect.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("FAIL " + message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().size = Vector2i(512,320)
	get_window().content_scale_size = Vector2i(512,320)
	RenderingServer.set_default_clear_color(Color("18262a"))
	position = Vector2(256,160)
	var world := WORLD.new()
	world.name = "ParticleWorld"
	add_child(world)
	world.set_process(false)
	var weapon := WeaponInstance.new()
	check(weapon.initialize("weapon_void_blade",null),"weapon initializes")
	var event := DamageEvent.create({"damage":20,"original_damage":20,"source_weapon_id":weapon.weapon_id})
	for index in 7:
		ICE.spawn(self,global_position,weapon,event)
		var field: Node = get_tree().get_nodes_in_group("ice_fields")[-1]
		field.set_process(false)
		check(field._visual_detail == 2,"dense frost retains full details")
	check(world.get_active_particle_count() == 91,"seven frost hits preserve thirteen fragments each")
	WORLD.emit_profile(self,"explosion_burst",global_position + Vector2(-5000,-5000),Vector2.ZERO,10.0)
	check(world.get_active_particle_count() == 900,"pool remains bounded")
	world._process(0.05)
	var clock_before: float = world._gpu_clock
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	world._process(1.0)
	check(world._gpu_clock == clock_before,"pause freezes GPU clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	ICE.spawn(self,global_position,weapon,event)
	check(world.get_active_particle_count() == 900,"full pool recycles instead of growing")
	var newest := 0
	for slot in world._particle_order:
		if world._particle_ages[slot] == 0.0: newest += 1
	check(newest == 13,"all new frost fragments survive a full pool")
	if DisplayServer.get_name() != "headless":
		for field in get_tree().get_nodes_in_group("ice_fields"): field.hide(); field.set_process(false)
		world._process(0.12)
		await RenderingServer.frame_post_draw
		var bitmap := get_viewport().get_texture().get_image()
		var changed := 0
		var background := bitmap.get_pixel(0,0)
		for y in range(80,240):
			for x in range(176,336):
				if bitmap.get_pixel(x,y) != background: changed += 1
		check(changed >= 4,"full-pool GPU frame contains visible new fragments")
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--gpu-test-output="): bitmap.save_png(argument.trim_prefix("--gpu-test-output="))
		print("GPU_FULL_POOL_VISIBLE_PIXELS=",changed)
	for field in get_tree().get_nodes_in_group("ice_fields"): field.queue_free()
	world._process(2.0)
	check(world.get_active_particle_count() == 0,"expired slots are reclaimed")
	check(world._free_particle_slots.size() == 900,"all slots reusable")
	WORLD.emit_profile(self,"impact_terrain",Vector2.ZERO)
	check(world.get_active_particle_count() == 9,"terrain reuses released slots")
	world.queue_free()
	await get_tree().process_frame
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("PIXEL_BAKED_RUNTIME checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
