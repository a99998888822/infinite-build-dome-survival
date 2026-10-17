extends Node2D
## Candidate visuals only. The review scene enables this; normal games keep originals.
const SHADER = preload("res://shaders/reviews/reaction_blocks.gdshader")
static var enabled := false
var radius := 72.0
var elapsed := 0.0
var duration := 0.46
var detail := 2

static func paint(canvas: CanvasItem, kind: int, bounds: Rect2, age: float,
		progress: float, reach: float = 1.0, direction := Vector2.RIGHT, extra := 0.0,
		quality := 2) -> void:
	var mat: ShaderMaterial
	if not canvas.has_meta("reaction_block_material"):
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		canvas.material = mat
		canvas.set_meta("reaction_block_material", mat)
		canvas.set_meta("reaction_block_candidate", true)
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		mat = canvas.get_meta("reaction_block_material")
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("effect_time", age)
	mat.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("direction", direction)
	mat.set_shader_parameter("extra", extra)
	mat.set_shader_parameter("detail", quality)
	canvas.draw_rect(bounds, Color.WHITE)

static func draw_cue(canvas: Node2D) -> bool:
	var t: float = canvas.elapsed / canvas.duration
	match str(canvas.kind):
		"steam":
			paint(canvas, 0, Rect2(-65,-115,130,125), canvas.elapsed,t)
		"wet_spread":
			var offset: Vector2 = canvas.options.get("target",canvas.global_position) - canvas.global_position
			var bounds := Rect2(Vector2.ZERO,Vector2.ZERO).expand(offset).grow(28.0)
			paint(canvas, 2, bounds, canvas.elapsed,t,offset.length(),offset.normalized())
		"ice_expand":
			var radius: float = canvas.options.get("radius",69.12)
			var previous: float = canvas.options.get("from_radius",51.2)
			_paint_ground(canvas,4,canvas.elapsed,t,radius,previous)
		"conduct":
			paint(canvas,5,Rect2(-32,-38,64,44),canvas.elapsed,t)
		"thaw":
			canvas.z_index = 83
			paint(canvas,7,Rect2(-65,-60,130,90),canvas.elapsed,t)
		_: return false
	return true

static func draw_ice(canvas: Node2D, reach: float, age: float, lifetime: float) -> void:
	_paint_ground(canvas,3,age,age/lifetime,reach)

static func _paint_ground(source: Node2D, kind: int, age: float, progress: float,
		reach: float, previous := 0.0) -> void:
	# A render-only proxy joins the existing ground depth sort. The damage field
	# keeps its parent, transform, query, timers and resolved radius untouched.
	var visual: Node2D
	if source.has_meta("reaction_ground_proxy"):
		visual = source.get_meta("reaction_ground_proxy").get_ref()
	if not is_instance_valid(visual):
		var world := source.get_tree().get_first_node_in_group("combat_render_world")
		var ground: Node = world.get_node_or_null("Backdrop/RootDepthSort") if world != null else null
		if ground == null:
			paint(source,kind,Rect2(-reach*1.16,-reach*0.8,reach*2.32,reach*1.6),age,progress,reach,Vector2.RIGHT,previous)
			return
		visual = Node2D.new()
		visual.name = "ReactionIceGroundPreview"
		ground.add_child(visual)
		source.set_meta("reaction_ground_proxy",weakref(visual))
		source.tree_exiting.connect(visual.queue_free)
		var reference: WeakRef = weakref(visual)
		visual.draw.connect(func():
			var surface: Node2D = reference.get_ref()
			if not is_instance_valid(surface): return
			var data: Array = surface.get_meta("reaction_ground_data")
			var radius: float = data[3]
			paint(surface,data[0],Rect2(-radius*1.16,-radius*0.8,radius*2.32,radius*1.6),data[1],data[2],radius,Vector2.RIGHT,data[4]))
	visual.global_position = source.global_position
	visual.set_meta("reaction_ground_data",[kind,age,progress,reach,previous])
	source.set_meta("reaction_block_candidate",true)
	visual.queue_redraw()

static func draw_reflection(canvas: Node2D, reach: float, age: float, lifetime: float,
		angle: float, quality: int) -> void:
	paint(canvas,6,Rect2(-reach-35,-reach-35,(reach+35)*2,(reach+35)*2),age,age/lifetime,reach,Vector2.from_angle(angle),0,quality)

static func spawn_blast(parent: Node, point: Vector2, reach: float, tier: int) -> void:
	var effect := new()
	effect.radius = reach if tier == 0 else (reach*0.75 if tier == 1 else minf(18.0,reach*0.22))
	effect.duration = 0.46 if tier == 0 else (0.32 if tier == 1 else 0.20)
	effect.detail = maxi(0,2-tier)
	effect.z_index = 78
	parent.add_child(effect)
	effect.global_position = point
	effect.add_to_group("reaction_block_blasts")

func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused",false)): return
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	paint(self,1,Rect2(-radius*1.4,-radius*1.5,radius*2.8,radius*2.7),elapsed,elapsed/duration,radius,Vector2.RIGHT,0,detail)
