extends Node2D
## Approved production styles. Tests may disable these to compare legacy rendering.
## Ice fields and frozen shells retain their restored original atlas paths.
const SHADER = preload("res://shaders/effects/reaction_blocks.gdshader")
static var enabled := true
static var thunder_fire_enabled := true
var radius := 72.0
var elapsed := 0.0
var duration := 0.46
var detail := 2
var burst_variant := 0.0

static func paint(canvas: CanvasItem, kind: int, bounds: Rect2, age: float,
		progress: float, reach: float = 1.0, direction := Vector2.RIGHT, extra := 0.0,
		quality := 2) -> void:
	var mat: ShaderMaterial
	if not canvas.has_meta("reaction_block_material"):
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		canvas.material = mat
		canvas.set_meta("reaction_block_material", mat)
		canvas.set_meta("reaction_block_visual", true)
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
		"conduct":
			paint(canvas,5,Rect2(-32,-38,64,44),canvas.elapsed,t)
		_: return false
	return true

static func draw_thaw(canvas: Node2D) -> void:
	CombatRenderWorld.set_effect_layer(canvas, 83)
	paint(canvas,7,Rect2(-65,-60,130,90),canvas.elapsed,canvas.elapsed/canvas.duration)

static func draw_reflection(canvas: Node2D, reach: float, age: float, lifetime: float,
		angle: float, quality: int) -> void:
	paint(canvas,6,Rect2(-reach-35,-reach-35,(reach+35)*2,(reach+35)*2),age,age/lifetime,reach,Vector2.from_angle(angle),0,quality)

static func spawn_blast(parent: Node, point: Vector2, reach: float, tier: int) -> void:
	var effect := new()
	effect.radius = reach if tier == 0 else (reach*0.75 if tier == 1 else minf(18.0,reach*0.22))
	effect.duration = 0.46 if tier == 0 else (0.32 if tier == 1 else 0.20)
	effect.detail = maxi(0,2-tier)
	# Spatial variation is independent of gameplay randomness and stable in flight.
	effect.burst_variant = fposmod(point.dot(Vector2(0.173,0.317)),31.0)
	CombatRenderWorld.set_effect_layer(effect, 78)
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
	paint(self,1,Rect2(-radius*1.4,-radius*1.5,radius*2.8,radius*2.7),elapsed,elapsed/duration,radius,Vector2.RIGHT,burst_variant,detail)
