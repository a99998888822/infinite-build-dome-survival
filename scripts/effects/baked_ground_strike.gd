extends Node2D
## R01 split PNG playback. No paths, meshes, particles or gameplay are created here.
const VISUAL = preload("res://scripts/effects/selected_spell_visual.gd")
const BUDGET = preload("res://scripts/effects/effect_visual_budget.gd")
var age := 0.0
var lifetime_scale := 1.0
var column_scale := Vector2.ONE
var ground_scale := Vector2.ONE
var alpha := 1.0
var tier := 0
var column: Node2D
var ground: Node2D
var impact: Node2D
var _last_frame := Vector2i(-1,-1)

static func flash_alpha_at(t: float) -> float:
	if t < 0.08: return 1.0
	if t < 0.16: return 0.6
	if t < 0.20: return 0.0
	if t < 0.28: return 0.42
	if t < 0.36: return 0.252
	return 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column = Node2D.new()
	ground = Node2D.new()
	impact = Node2D.new()
	for node in [ground,column,impact]: add_child(node)
	CombatRenderWorld.set_world_layer(column,CombatRenderWorld.BEAM_Z)
	CombatRenderWorld.set_effect_layer(ground,-1)
	CombatRenderWorld.set_world_layer(impact,CombatRenderWorld.IMPACT_Z)
	column.draw.connect(_draw_column)
	ground.draw.connect(_draw_ground)
	impact.draw.connect(_draw_impact)
	set_process(false)

func setup(height: float, radius: float, scale_time: float, opacity: float, density: int) -> void:
	column_scale = Vector2(1.0,height/182.0)
	ground_scale = Vector2.ONE*(radius/30.0)
	lifetime_scale = scale_time
	alpha = opacity
	tier = density
	advance(0.0)

func advance(value: float) -> void:
	age = value
	var a := age/lifetime_scale
	var echo := a >= 0.20
	column.modulate.a = flash_alpha_at(a)*alpha
	column.visible = a < 0.36 and not (a >= 0.16 and a < 0.20)
	impact.modulate.a = alpha
	ground.modulate.a = alpha
	var frame := int(a*18.0)
	# A dropped frame or scaled clock can cross an exact flash boundary without
	# crossing an 18fps key. Include the segment in the redraw key.
	var redraw_key := Vector2i(frame*4+int(echo)*2+int(a>=0.08),int(age*18.0))
	if _last_frame != redraw_key:
		_last_frame = redraw_key
		for node in [column,ground,impact]: node.queue_redraw()

func is_active() -> bool:
	return age < maxf(0.55,lifetime_scale*0.36)

func _draw_column() -> void:
	var t := age/lifetime_scale
	VISUAL.draw(column,"strike_echo" if t>=0.20 else "strike_primary",maxf(0.0,t-0.20) if t>=0.20 else t,column_scale)

func _draw_ground() -> void:
	if tier >= BUDGET.Tier.SPARK or age >= 0.42: return
	VISUAL.draw(ground,"strike_ground",age,ground_scale)

func _draw_impact() -> void:
	var t := age/lifetime_scale
	if t<0.16:
		VISUAL.draw(impact,"strike_impact",t,Vector2.ONE,Color(1,1,1,flash_alpha_at(t)))
	if tier < BUDGET.Tier.SPARK and age<0.55:
		VISUAL.draw(impact,"strike_sparks",age,ground_scale)
