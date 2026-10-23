extends Node2D
const ANCHORS = preload("res://scripts/effects/enemy_visual_anchors.gd")
const FROST_VISUAL = preload("res://scripts/effects/enemy_frost_visual.gd")
const VISUAL_QUEUE = preload("res://scripts/effects/enemy_status_visual_queue.gd")

const FIRE_VISUAL = preload("res://scripts/effects/pixel_fire_visual.gd")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")

var _flame_visual: Node2D
var _enemy: Node2D = null
var _foot_frost: Node2D
var _body_ice: Node2D
var _body_effects: Node2D
var _icons: Node2D
var _anchor_factor := -1.0
var _elapsed: float = 0.0
var _draw_frame: int = -1
var _draw_status_mask: int = -1
var _status_revision := -1
var _status_mask := 0
var _draw_body_radius := -1.0
var _pending := false
var _flame_mask := -1
var _flame_radius := -1.0


func _ready() -> void:
	CombatRenderWorld.set_actor_local(self)
	_enemy = get_parent()
	_icons = Node2D.new()
	_icons.name = "StatusIcons"
	CombatRenderWorld.set_world_layer(_icons, CombatRenderWorld.INFO_Z)
	add_child(_icons)
	_icons.draw.connect(_draw_icons)
	# Both this root and the body group stay in the actor's Y-sorted plane.
	_body_effects = Node2D.new()
	_body_effects.name = "BodyStatusEffects"
	CombatRenderWorld.set_actor_local(_body_effects)
	add_child(_body_effects)
	request_sync()


func _exit_tree() -> void:
	_pending = false


func request_sync() -> void:
	# Empty actors sleep until a status boundary changes. Active actors still
	# follow collider resizing and sprite facing once per idle batch.
	set_process(true)
	if _pending or not is_inside_tree(): return
	_pending = true
	VISUAL_QUEUE.enqueue(self)

func _ensure_frost() -> void:
	if is_instance_valid(_foot_frost): return
	_foot_frost = FROST_VISUAL.new()
	_foot_frost.name = "FootFrost"
	CombatRenderWorld.set_effect_layer(_foot_frost, -1)
	add_child(_foot_frost)
	_body_ice = FROST_VISUAL.new()
	_body_ice.name = "BodyIce"
	# The frozen shell covers its actor; ground frost remains below actors.
	CombatRenderWorld.set_actor_local(_body_ice)
	_body_effects.add_child(_body_ice)
	_foot_frost.hide()
	_body_ice.hide()


func _process(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	_elapsed += delta
	request_sync()


func _flush_visual() -> void:
	_pending = false
	if not is_instance_valid(_enemy) or _enemy.is_queued_for_deletion(): return
	if not can_process() or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	var changed: bool = _status_revision != _enemy.status_visual_revision
	if changed:
		_status_revision = _enemy.status_visual_revision
		_status_mask = _enemy.get_status_visual_mask()
		_icons.queue_redraw()
	# One collider query supplies all radius/position work for this actor.
	var bounds := ANCHORS.body_bounds(_enemy) if _status_mask != 0 else Rect2()
	var radius := maxf(4.0, minf(bounds.size.x, bounds.size.y) * 0.5) if _status_mask != 0 else -1.0
	var flame_mask := _status_mask & (128 | 32 | 64)
	if changed or flame_mask != _flame_mask or radius != _flame_radius:
		_flame_mask = flame_mask
		_flame_radius = radius
		_sync_flame(radius)
	var slowed := (_status_mask & 16) != 0
	var frozen := (_status_mask & 8) != 0
	var frosted := slowed or frozen
	if frosted:
		_ensure_frost()
		_foot_frost.position = ANCHORS.foot(_enemy)
		_foot_frost.configure(radius,false)
		# The original shell frame is centered six pixels above its drawing origin.
		_body_ice.position = (bounds.get_center()+Vector2(0,6)).round()
		_body_ice.configure(radius,true)
	if is_instance_valid(_foot_frost):
		_foot_frost.visible = slowed and not frozen
		_body_ice.visible = frozen
	if is_instance_valid(_flame_visual):
		var point := (bounds.get_center()-Vector2(0,8)).round()
		if _flame_visual.position != point:
			_flame_visual.position = point
			VISUAL_QUEUE.request_flame_flush(FIRE_VISUAL.clock)
	var mask := _status_mask & 31
	# These icons, the ice shell and the slowed footprint contain no clock.
	# Position is inherited; flames continue to animate on their shared clock.
	var factor := ANCHORS.factor(_enemy) if mask != 0 else -1.0
	if mask != _draw_status_mask or radius != _draw_body_radius or factor != _anchor_factor:
		_draw_body_radius = radius
		_draw_status_mask = mask
		_anchor_factor = factor
		_icons.queue_redraw()
	set_process(_status_mask != 0)


func _sync_flame(radius: float) -> void:
	var burning := (_status_mask & (128 | 32 | 64)) != 0
	if burning and not is_instance_valid(_flame_visual):
		_flame_visual = FIRE_VISUAL.new()
		_body_effects.add_child(_flame_visual)
	elif not burning and is_instance_valid(_flame_visual):
		_flame_visual.hide()
		_flame_visual.queue_free()
		_flame_visual = null
	if is_instance_valid(_flame_visual):
		_flame_visual.setup_status(radius)
		_flame_visual.set_palette(2 if (_status_mask & 64) != 0 else (1 if (_status_mask & 32) != 0 else 0))
	VISUAL_QUEUE.request_flame_flush(FIRE_VISUAL.clock)


func _draw_icons() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var icon_index := 0
	var icon_origin := ANCHORS.head(_enemy) + Vector2(12,0)
	if _enemy.has_status("wet"):
		var body_radius := _get_body_radius()
		_draw_water_drop(icon_origin+Vector2(icon_index*15,0), clampf(body_radius * 0.18, 3.0, 5.0))
		icon_index += 1
	if _enemy.has_status("light"):
		var light_radius := _get_body_radius()
		_draw_light_sun(icon_origin+Vector2(icon_index*15,0), clampf(light_radius * 0.19, 3.0, 5.0))
		icon_index += 1
	if _enemy.has_status("dark"):
		var dark_radius := _get_body_radius()
		_draw_dark_eye(icon_origin+Vector2(icon_index*15,0), clampf(dark_radius * 0.20, 3.0, 5.0))
		icon_index += 1


func _get_body_radius() -> float:
	if _enemy == null:
		return 10.0
	return ANCHORS.radius(_enemy)


func _draw_water_drop(center: Vector2, icon_radius: float) -> void:
	var half_width := icon_radius * 0.78
	var points := PackedVector2Array([
		center + Vector2(0.0, -icon_radius),
		center + Vector2(half_width, icon_radius * 0.22),
		center + Vector2(icon_radius * 0.62, icon_radius * 0.72),
		center + Vector2(icon_radius * 0.28, icon_radius),
		center + Vector2(-icon_radius * 0.28, icon_radius),
		center + Vector2(-icon_radius * 0.62, icon_radius * 0.72),
		center + Vector2(-half_width, icon_radius * 0.22),
	])
	for index in points.size(): points[index] = points[index].round()
	_icons.draw_colored_polygon(points, Color(0.30, 0.78, 1.0, 0.95))


func _draw_light_sun(center: Vector2, icon_radius: float) -> void:
	PIXEL.block(_icons,center,Vector2(4,4),Color.WHITE)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var inner := center + Vector2.from_angle(angle) * icon_radius * 0.76
		var outer := center + Vector2.from_angle(angle) * icon_radius * 1.08
		PIXEL.line(_icons,inner.round(),outer.round(),Color.WHITE,1)


func _draw_dark_eye(center: Vector2, icon_radius: float) -> void:
	var eye_width := icon_radius * 1.35
	var eye_height := icon_radius * 0.72
	var points := PackedVector2Array([
		center + Vector2(-eye_width, 0.0),
		center + Vector2(-eye_width * 0.42, -eye_height),
		center + Vector2.ZERO,
		center + Vector2(eye_width * 0.42, -eye_height),
		center + Vector2(eye_width, 0.0),
		center + Vector2(eye_width * 0.42, eye_height),
		center + Vector2.ZERO,
		center + Vector2(-eye_width * 0.42, eye_height),
	])
	for index in points.size(): points[index] = points[index].round()
	_icons.draw_colored_polygon(points, Color(0.58, 0.60, 0.64, 0.96))
	_icons.draw_circle(center, icon_radius * 0.34, Color(0.20, 0.22, 0.26, 1.0))
	PIXEL.line(_icons,center + Vector2(-eye_width * 0.92, eye_height * 1.15), center + Vector2(eye_width * 0.92, -eye_height * 1.15), Color(0.36, 0.38, 0.42, 1.0),1)
