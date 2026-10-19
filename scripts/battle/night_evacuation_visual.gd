extends Node2D
## World-space shelter plus UI-space darkness and directional guidance.
const BANK = preload("res://assets/sprites/buildings/goblin_bank/bank.png")
const SHADOW = preload("res://assets/sprites/buildings/goblin_bank/ground_shadow.png")
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const RING_PARTICLES := 144
const RING_COMPANIONS := 18
var phase: NightEvacuation
var building: Node2D
var enemy_barrier: EvacuationBunker
var bank: Sprite2D
var bank_material: ShaderMaterial
var lamp_materials: Array[ShaderMaterial] = []
var ring: Node2D
var ring_particles: Array[Dictionary] = []
var night_layer: CanvasLayer
var night_rect: ColorRect
var night_material: ShaderMaterial
var guide_layer: CanvasLayer
var guide: Node2D
var distance_label: Label
var announcement: Label
var saved_glow_strength := .16
var glow_material: ShaderMaterial
var show_arrow := false
var arrow_position := Vector2.ZERO
var arrow_angle := 0.0
var guide_scale := 1.0
var lit := false

func initialize(owner_phase: NightEvacuation) -> void:
	phase = owner_phase
	process_priority = 60
	night_layer = CanvasLayer.new()
	night_layer.layer = 19
	night_layer.custom_viewport = get_tree().root
	add_child(night_layer)
	night_rect = ColorRect.new()
	night_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_material = ShaderMaterial.new()
	night_material.shader = preload("res://shaders/battle/evacuation_night.gdshader")
	night_rect.material = night_material
	night_layer.add_child(night_rect)
	night_rect.hide()
	guide_layer = CanvasLayer.new()
	guide_layer.layer = 20
	guide_layer.custom_viewport = get_tree().root
	add_child(guide_layer)
	guide = Node2D.new()
	guide.draw.connect(_draw_arrow)
	guide_layer.add_child(guide)
	distance_label = Label.new()
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label.add_theme_font_override("font",FONT)
	distance_label.add_theme_font_size_override("font_size",24)
	distance_label.add_theme_color_override("font_color",Color("ffe9a0"))
	distance_label.add_theme_color_override("font_outline_color",Color("18171d"))
	distance_label.add_theme_constant_override("outline_size",6)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_layer.add_child(distance_label)
	announcement = Label.new()
	announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announcement.add_theme_font_override("font",FONT)
	announcement.add_theme_font_size_override("font_size",24)
	announcement.add_theme_color_override("font_color",Color("d4e6ea"))
	announcement.add_theme_color_override("font_outline_color",Color("10141b"))
	announcement.add_theme_constant_override("outline_size",6)
	announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_layer.add_child(announcement)
	guide_layer.hide()
	var glow := phase.player.get_node_or_null("VisibilityGlow") as CanvasItem
	if glow != null and glow.material is ShaderMaterial:
		glow_material = glow.material
		var strength: Variant = glow_material.get_shader_parameter("strength")
		if strength != null: saved_glow_strength = float(strength)

func begin() -> void:
	reset()
	lit = true
	building = Node2D.new()
	building.name = "EvacuationBunker"
	var world_parent: Node = phase.scenery.roots if is_instance_valid(phase.scenery) else self
	world_parent.add_child(building)
	building.global_position = phase.bank_anchor
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW
	shadow.centered = false
	shadow.position = -NightEvacuation.BANK_ANCHOR
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_index = -1
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://shaders/battle/evacuation_shadow.gdshader")
	shadow.material = shadow_material
	building.add_child(shadow)
	bank = Sprite2D.new()
	bank.texture = BANK
	bank.centered = false
	bank.position = -NightEvacuation.BANK_ANCHOR
	bank.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bank_material = ShaderMaterial.new()
	bank_material.shader = preload("res://shaders/battle/evacuation_bank.gdshader")
	bank_material.set_shader_parameter("cloud_texture",CavernSunlightBackdrop.CLOUD_TEXTURE)
	bank.material = bank_material
	building.add_child(bank)
	var body := StaticBody2D.new()
	body.collision_layer = 6
	body.collision_mask = 0
	building.add_child(body)
	for rect: Rect2 in [Rect2(-252,-75,175,100),Rect2(78,-75,170,100),Rect2(-225,-125,450,55)]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	enemy_barrier = EvacuationBunker.new()
	enemy_barrier.name = "EnemyBarrier"
	building.add_child(enemy_barrier)
	for center in [Vector2(-79,-82),Vector2(72,-66)]:
		var lamp := ColorRect.new()
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lamp.position = center-Vector2(72,88)
		lamp.size = Vector2(144,176)
		var light := ShaderMaterial.new()
		light.shader = preload("res://shaders/battle/evacuation_lamp.gdshader")
		lamp.material = light
		lamp_materials.append(light)
		building.add_child(lamp)
	# The ground ring encloses the bunker; its outline is also the entry boundary.
	ring = Node2D.new()
	ring.z_index = -2
	add_child(ring)
	ring.global_position = phase.ring_center
	_seed_ring_particles()
	ring.draw.connect(_draw_ring)
	night_rect.show()
	guide_layer.show()
	refresh()

func reset() -> void:
	lit = false
	if is_instance_valid(enemy_barrier): enemy_barrier.deactivate()
	enemy_barrier = null
	if is_instance_valid(building):
		building.hide()
		building.queue_free()
	building = null
	bank = null
	lamp_materials.clear()
	if is_instance_valid(ring):
		ring.draw.disconnect(_draw_ring)
		ring.hide()
		ring.queue_free()
	ring = null
	ring_particles.clear()
	if is_instance_valid(night_rect): night_rect.hide()
	hide_guidance()
	if glow_material != null: glow_material.set_shader_parameter("strength",saved_glow_strength)

func hide_guidance() -> void:
	show_arrow = false
	if is_instance_valid(guide_layer): guide_layer.hide()

func _exit_tree() -> void:
	reset()

func _process(_delta: float) -> void:
	if lit: refresh()

func to_screen(point: Vector2) -> Vector2:
	var view := phase.player.get_viewport()
	return (view.get_canvas_transform()*point)*get_tree().root.get_visible_rect().size/view.get_visible_rect().size

func refresh() -> void:
	if not lit or not is_instance_valid(bank): return
	var size := get_tree().root.get_visible_rect().size
	guide_scale = size.y/1080.0
	var night := smoothstep(0.0,float(phase.config.night_seconds),phase.elapsed)
	announcement.size = Vector2(size.x,50*guide_scale)
	announcement.position = Vector2(0,112*guide_scale)
	announcement.add_theme_font_size_override("font_size",maxi(12,roundi(24*guide_scale)))
	announcement.visible = phase.elapsed<4.5 or (phase.elapsed>=phase.next_hunter_at-3.0 and phase.elapsed<phase.next_hunter_at)
	announcement.text = L10n.text("ui.evacuation.open" if phase.elapsed<4.5 else "ui.evacuation.hunters")
	night_rect.size = size
	night_material.set_shader_parameter("darkness",night*float(phase.config.night_darkness))
	night_material.set_shader_parameter("view_size",size)
	night_material.set_shader_parameter("pixel_scale",guide_scale)
	night_material.set_shader_parameter("hero",to_screen(phase.foot_position()+Vector2(0,-38)))
	night_material.set_shader_parameter("bank",to_screen(phase.bank_anchor+Vector2(-10,-90)))
	night_material.set_shader_parameter("lamp_left",to_screen(phase.bank_anchor+Vector2(-79,-82)))
	night_material.set_shader_parameter("lamp_right",to_screen(phase.bank_anchor+Vector2(72,-66)))
	night_material.set_shader_parameter("entrance",to_screen(phase.bank_anchor+Vector2(0,74)))
	bank_material.set_shader_parameter("night",night)
	for light in lamp_materials: light.set_shader_parameter("night",night)
	bank_material.set_shader_parameter("object_root",phase.bank_anchor)
	bank_material.set_shader_parameter("sun_time",phase.scenery.environment_time if is_instance_valid(phase.scenery) else 0.0)
	if glow_material != null: glow_material.set_shader_parameter("strength",lerpf(saved_glow_strength,.36,night))
	if is_instance_valid(ring): ring.queue_redraw()
	if not phase.active:
		hide_guidance()
		return
	var target := to_screen(phase.ring_center)
	var hero := to_screen(phase.foot_position())
	var direction := (target-hero).normalized()
	var margin := Vector2(86,150)*guide_scale
	var area := Rect2(margin,size-margin*2.0)
	show_arrow = not area.has_point(target)
	if show_arrow:
		var length_to_edge := INF
		if absf(direction.x)>.001: length_to_edge = minf(length_to_edge,((area.end.x if direction.x>0 else area.position.x)-hero.x)/direction.x)
		if absf(direction.y)>.001: length_to_edge = minf(length_to_edge,((area.end.y if direction.y>0 else area.position.y)-hero.y)/direction.y)
		arrow_position = (hero+direction*maxf(70*guide_scale,length_to_edge)).round()
		arrow_angle = direction.angle()
		distance_label.text = L10n.text("ui.evacuation.distance") % ceili(float(phase.distance_to_shelter())/100.0)
		distance_label.position = arrow_position+Vector2(-110,36)*guide_scale
	else:
		distance_label.text = L10n.text("ui.evacuation.enter")
		distance_label.position = to_screen(phase.ring_center+Vector2(0,phase.ring_axes().y))+Vector2(-110,12)*guide_scale
	distance_label.size = Vector2(220,36)*guide_scale
	distance_label.add_theme_font_size_override("font_size",maxi(12,roundi(24*guide_scale)))
	guide.queue_redraw()

func _draw_arrow() -> void:
	if not show_arrow: return
	var pulse := .85+.15*sin(phase.elapsed*3.2)
	guide.draw_set_transform(arrow_position,arrow_angle,Vector2.ONE*guide_scale)
	var polygon := PackedVector2Array([Vector2(27,0),Vector2(0,-23),Vector2(0,-10),Vector2(-24,-10),Vector2(-24,10),Vector2(0,10),Vector2(0,23)])
	for factor in [1.65,1.35,1.12]:
		var glow := PackedVector2Array()
		for point in polygon: glow.append(point*factor)
		guide.draw_colored_polygon(glow,Color(1,.69,.12,.07*pulse))
	guide.draw_colored_polygon(polygon,Color(1,.80,.24,pulse))
	guide.draw_set_transform(Vector2.ZERO)

func _seed_ring_particles() -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	for companion in [false,true]:
		var count := RING_COMPANIONS if companion else RING_PARTICLES
		for i in count:
			ring_particles.append({
				"angle": TAU*(float(i)+random.randf_range(-.2,.2))/float(count),
				"phase": random.randf()*TAU,
				"speed": random.randf_range(.6,1.15),
				"rotation": random.randf()*TAU,
				"spin": random.randf_range(.1,.26)*(-1.0 if random.randf()<.5 else 1.0),
				"size": random.randi_range(2,3) if companion else random.randi_range(3,5),
				"offset": 8.0 if companion else 0.0,
				"alpha": .4 if companion else .85
			})

func _draw_ring() -> void:
	if not is_instance_valid(ring) or ring.is_queued_for_deletion(): return
	var axes := phase.ring_axes()
	var time := phase.elapsed
	# Stable random seeds prevent flicker; motion stays close to the fixed entry boundary.
	for particle: Dictionary in ring_particles:
		var angle := float(particle.angle)
		var oscillation := time*float(particle.speed)+float(particle.phase)
		var normal := Vector2(cos(angle),sin(angle))
		var point := normal*(axes+Vector2.ONE*float(particle.offset))
		point += normal*sin(oscillation)*1.5+Vector2(sin(oscillation*.7),-sin(oscillation*.9)*2.0)
		var rotation := float(particle.rotation)+time*float(particle.spin)
		var size := float(particle.size)
		var pulse := .8+.2*sin(oscillation)
		ring.draw_set_transform(point.round(),rotation)
		ring.draw_rect(Rect2(Vector2.ONE*(-size*.5-3.0),Vector2.ONE*(size+6.0)),Color(.24,.71,1,.075*pulse))
		ring.draw_rect(Rect2(Vector2.ONE*(-size*.5),Vector2.ONE*size),Color(.47,.86,1,float(particle.alpha)*pulse))
	ring.draw_set_transform(Vector2.ZERO)
