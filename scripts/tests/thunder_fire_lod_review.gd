extends Node2D
## GPU visual review: first contacts, dense overlap, and separated clusters.
const WORLD = preload("res://scripts/effects/particle_world.gd")
const BUDGET = preload("res://scripts/effects/thunder_fire_visual_budget.gd")
class VisualExplosion extends ExplosionEffect:
	func _damage_enemies(_radius: float, _damage: int, _falloff: float) -> void: pass
	func _damage_terrain(_radius: float) -> Array[Dictionary]: return []

var output := ""
var failures := 0
var rows: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport

func _run() -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty():
		push_error("GPU and --output=<directory> required")
		get_tree().quit(1)
		return
	CampProgression.begin_transient_session()
	WindowSettings._startup_applied = true
	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var weapon := WeaponInstance.new()
	weapon.initialize("weapon_void_blade", player)
	var event := DamageEvent.create({"damage": 10, "source_weapon_id": weapon.weapon_id, "source_player": player})
	for layout in ["single", "four", "dense", "separated"]:
		for age in [0.06, 0.18]:
			var images: Array[Image] = []
			var counts: Array[int] = []
			for mode in ["full", "adaptive"]:
				var viewport := _viewport()
				var host := Node2D.new()
				viewport.add_child(host)
				var world := WORLD.new()
				world.name = "ParticleWorld"
				host.add_child(world)
				world.set_process(false)
				world._random.seed = 819
				GameGlobal.set_runtime_flag("thunder_fire_visual_mode", mode)
				var count := 1 if layout == "single" else 4 if layout == "four" else 96 if layout == "dense" else 16
				for i in count:
					var point := Vector2(320, 180)
					if layout in ["four", "dense"]: point += Vector2.from_angle(TAU * i / count) * 28.0
					if layout == "separated": point = Vector2(150 if i % 4 < 2 else 490, 85 if i % 2 == 0 else 275)
					var explosion := VisualExplosion.new()
					host.add_child(explosion)
					explosion._weapon = weapon
					explosion._damage_event = event
					explosion._reaction_id = "thunder_fire"
					explosion._hit_position = point
					explosion._radius_override = 72.0
					explosion._detonate()
				world._process(age)
				counts.append(world.get_active_particle_count())
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var captured := viewport.get_texture().get_image()
				images.append(captured)
				captured.save_png(output.path_join("thunder_%s_%s_%d.png" % [layout, mode, roundi(age * 1000)]))
				viewport.queue_free()
				await get_tree().process_frame
			var identical := images[0].get_data() == images[1].get_data()
			if layout != "dense" and not identical: failures += 1
			rows.append({"layout": layout, "age": age, "pixel_identical": identical, "particles": counts})
	GameGlobal.clear_runtime_flag("thunder_fire_visual_mode")
	player.queue_free()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	print("THUNDER_FIRE_LOD_REVIEW ", JSON.stringify({"rows": rows, "failures": failures}))
	get_tree().quit(0 if failures == 0 else 1)
