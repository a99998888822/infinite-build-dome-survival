extends Node2D
## Shared approved furnace/saber visuals. Weapon runtimes own contacts and time.
const FIRE_SHADER = preload("res://shaders/effects/candidate_furnace_ring.gdshader")
const CUT_SHADER = preload("res://shaders/effects/candidate_saber_cut.gdshader")
const FIRE_LAYERS = preload("res://scripts/effects/split_flame_visual.gd")
static var noise_texture: Texture2D
var kind := "ring"
var age := 0.0
var lifetime := 0.72
var manual_clock := false
var layered := true
var bounds := Rect2()
var _front_material: ShaderMaterial
var _last_visual_tick := -1


static func ring(parent: Node, at: Vector2, radius := 160.0, split := false, phase := 0.0, flares := 18) -> Node2D:
	var effect := new()
	effect.kind = "split" if split else "ring"
	effect.lifetime = 0.62 if split else 0.72
	effect.bounds = Rect2(-radius - 64.0, -(radius + 64.0) * 0.659091, (radius + 64.0) * 2.0, (radius + 64.0) * 1.318182)
	effect.material = ShaderMaterial.new()
	effect.material.shader = FIRE_SHADER
	if noise_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 4102026
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise_texture = ImageTexture.create_from_image(noise.get_seamless_image(128, 128))
	effect.material.set_shader_parameter("flow_noise", noise_texture)
	effect.material.set_shader_parameter("reach", radius)
	effect.material.set_shader_parameter("fragmented", split)
	effect.material.set_shader_parameter("flare_count", float(flares))
	effect.material.set_shader_parameter("seed_phase", phase)
	parent.add_child(effect)
	effect.global_position = at
	effect.sample(0.0)
	return effect


static func cut(parent: Node, from: Vector2, to: Vector2, angle_offset_degrees := 0.0, width_scale := 1.0) -> Node2D:
	var effect := new()
	effect.kind = "cut"
	effect.lifetime = 0.30
	effect.bounds = Rect2(-from.distance_to(to) * 0.5 - 12, -28 * width_scale, from.distance_to(to) + 24, 56 * width_scale)
	effect.material = ShaderMaterial.new()
	effect.material.shader = CUT_SHADER
	effect.material.set_shader_parameter("length", from.distance_to(to))
	effect.material.set_shader_parameter("width_scale", width_scale)
	parent.add_child(effect)
	effect.global_position = (from + to) * 0.5
	effect.rotation = from.angle_to_point(to) + deg_to_rad(angle_offset_degrees)
	CombatRenderWorld.set_world_layer(effect, CombatRenderWorld.ATTACK_Z)
	effect.sample(0.0)
	return effect


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("candidate_weapon_art")
	queue_redraw()


func sample(seconds: float) -> void:
	age = seconds
	var tick := floori(age * (48.0 if kind == "cut" else 18.0))
	visible = age >= 0.0 and age < lifetime
	if tick == _last_visual_tick and layered: return
	_last_visual_tick = tick
	material.set_shader_parameter("age", age)
	material.set_shader_parameter("lifetime", lifetime)
	if kind != "cut" and layered:
		if _front_material == null:
			FIRE_LAYERS.sync(self, material, bounds)
			_front_material = get_meta("flame_front").material
		_front_material.set_shader_parameter("age", age)
		_front_material.set_shader_parameter("lifetime", lifetime)
	elif kind != "cut":
		material.set_shader_parameter("render_part", 0)
		if has_meta("flame_front"): get_meta("flame_front").hide()


func _physics_process(delta: float) -> void:
	if manual_clock or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	sample(age + delta)
	if age >= lifetime: queue_free()


func _draw() -> void:
	draw_rect(bounds, Color.WHITE)
