extends Node2D
const SPARK = preload("res://scripts/effects/electric_spark_effect.gd")
const WARNING = preload("res://scripts/effects/electric_spark_warning_sprite.gd")
const WORLD = preload("res://scripts/effects/particle_world.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	check(WARNING.ATLAS.get_size()==Vector2(128,128),"compact PNG frame atlas")
	var warning := SPARK.new()
	add_child(warning)
	warning.set_process(false)
	check(warning.get_active_particle_count()==24,"original 24 particles preserved")
	check(warning.get_child_count()==1 and warning._warning_sprite is MultiMeshInstance2D,"one batch replaces individual draw calls")
	check(warning._warning_sprite.multimesh.instance_count==24,"24 sprite instances")
	check(not warning._warning_sprite.is_processing(),"no independent sprite clock")
	var shader_material: ShaderMaterial = warning._warning_sprite.material
	var before_age: float = warning._elapsed
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	warning._process(0.2)
	check(warning._elapsed==before_age,"pause stops warning clock")
	check(shader_material.get_shader_parameter("elapsed")==before_age,"pause stops PNG animation")
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	warning._struck = true
	for radius in [0.9,1.0,1.5,2.5,5.0]:
		warning._ring_radius = 20.0*radius
		warning._process(0.01)
		check(is_equal_approx(shader_material.get_shader_parameter("radius_scale"),radius),"orbit radius follows damage area")
		check(warning._warning_sprite.multimesh.mesh.size==Vector2(8,8),"particle size independent of radius")
		var bounds: AABB = warning._warning_sprite.multimesh.custom_aabb
		check(bounds.size.x>=25.8*radius*2.0 and bounds.size.y>=15.26*radius*2.0,"shader movement stays within render bounds")
	warning._elapsed = 0.5
	warning._on_ground_strike_landed()
	warning._process(0.14)
	check(is_equal_approx(shader_material.get_shader_parameter("fade"),0.5),"original landing fade")
	warning._process(0.15)
	check(warning.is_queued_for_deletion(),"warning retires after original landing fade")
	warning.free()
	var missing := SPARK.new()
	add_child(missing)
	missing.set_process(false)
	missing._process(0.49)
	check(not missing._struck,"does not trigger before half a second")
	missing._process(0.02)
	check(missing._struck and missing._strike_landed,"half-second activation and missing-weapon fallback retained")
	missing.free()
	var world := WORLD.new()
	world.name = "ParticleWorld"
	add_child(world)
	world.set_process(false)
	WORLD.emit_profile(self,"explosion_burst",Vector2(-5000,-5000),Vector2.ZERO,10.0)
	check(world.get_active_particle_count()==900,"full pool fixture")
	var full := SPARK.new()
	add_child(full)
	full.set_process(false)
	check(full._warning_sprite.multimesh.instance_count==24,"warning PNG bypasses full pool")
	var sprite = full._warning_sprite
	full.free()
	check(not is_instance_valid(sprite),"early owner removal frees batch")
	world.free()
	for frame in 3: await get_tree().process_frame
	CampProgression.end_transient_session()
	print("WARNING_PNG_TEST checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
