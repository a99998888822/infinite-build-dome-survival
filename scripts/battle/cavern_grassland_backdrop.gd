extends CavernPopulationBackdrop
class_name CavernGrasslandBackdrop
## Approved R03 grassland: dark soil, layered grass and sparse per-battle props.

var contact_texture: Texture2D
var cast_shadow_material: ShaderMaterial
var shelter_clearance := Rect2()

func reserve_shelter(area: Rect2) -> void:
	var changed := shelter_clearance.merge(area) if shelter_clearance.has_area() and area.has_area() else (shelter_clearance if not area.has_area() else area)
	shelter_clearance = area
	if not initialized or not is_inside_tree(): return
	for key: Vector2i in cells.keys():
		if not Rect2(Vector2(key)*CELL,CELL).grow(40).intersects(changed): continue
		_retire_cell(key)
		cells.erase(key)
		_cell_jobs.erase(key)
		grass_cells.erase(key)
	cell_rect = Rect2i()
	_update_area()

func _setup() -> void:
	if initialized or not is_instance_valid(player) or not is_inside_tree(): return
	contact_texture = load("res://assets/sprites/background/meadow/pit-contact-shadow.png")
	cast_shadow_material = ShaderMaterial.new()
	cast_shadow_material.shader = load("res://shaders/battle/meadow/pit_shadow.gdshader")
	super._setup()
	grass_material.shader = load("res://shaders/battle/meadow/pit_grass.gdshader")

func _begin_plan(key: Vector2i) -> Dictionary:
	var state := super._begin_plan(key)
	# The second layer starts at the same post-solid RNG position, independently
	# of the first layer. Copy the state instead of planning the solids twice.
	var undergrowth_rng := RandomNumberGenerator.new()
	undergrowth_rng.seed = state.rng.seed
	undergrowth_rng.state = state.rng.state
	state.undergrowth_solids = {"entries":state.solids,"rng":undergrowth_rng}
	state.population_done = false
	state.undergrowth_patch = 0
	return state

func _step_plan(state: Dictionary) -> bool:
	if not state.population_done:
		if super._step_plan(state):
			for entry: Dictionary in state.plan:
				if entry.kind=="grass":
					entry.tint = Color(.65,.73,.70) if entry.index!=3 else Color(.66,.69,.65)
			state.population_done = true
		return false
	if state.undergrowth_patch < 119:
		_plan_undergrowth_patch(state, int(state.undergrowth_patch)/17, int(state.undergrowth_patch)%17)
		state.undergrowth_patch += 1
		return false
	if shelter_clearance.has_area():
		state.plan = state.plan.filter(func(entry: Dictionary): return not shelter_clearance.has_point(entry.point))
	return true

func _allows_solid(entry: Dictionary) -> bool:
	return not shelter_clearance.has_area() or not shelter_clearance.has_point(entry.point)

func _plan_undergrowth_patch(state: Dictionary, row: int, col: int) -> void:
	var plan: Array[Dictionary] = state.plan
	var solids: Dictionary = state.undergrowth_solids
	var rng: RandomNumberGenerator = solids.rng
	var origin := Vector2(state.key)*CELL
	var center := origin+Vector2((col+.5)*CELL.x/17,(row+.5)*CELL.y/7)
	center += Vector2(rng.randf_range(-13,13),rng.randf_range(-12,12))
	var moisture := sample_surface(center).a
	if moisture<.5 or rng.randf()>moisture: return
	for blade in rng.randi_range(4,7):
		var point := center+Vector2(rng.randf_range(-22,22),rng.randf_range(-13,13))
		point = point.clamp(origin+Vector2(3,3),origin+CELL-Vector2(3,3)).round()
		var surface := sample_surface(point)
		if surface.a<.43: continue
		var clear := true
		for solid: Dictionary in solids.entries:
			var d: Vector2 = point-solid.point
			if solid.kind=="prop" and absf(d.x)<66 and d.y>-22 and d.y<7: clear = false
			if solid.kind=="rubble" and d.length()<16: clear = false
		if not clear: continue
		var index := rng.randi_range(0,2)
		rng.randf_range(.48,.78) # Keep placement/mirror randomness, not size jitter.
		var entry := _placement("grass",index,point,1.0,rng.randf()<.5)
		var shade := rng.randf_range(.93,1.04)
		entry.tint = Color(.60*shade,.67*shade,.65*shade)
		entry.suitability = surface.a
		entry.undergrowth = true
		plan.append(entry)

func _decorate_solid(sprite: Sprite2D, nodes: Array[Node]) -> void:
	super._decorate_solid(sprite, nodes)
	var entry: Dictionary = sprite.get_meta("scenery")
	var contact := Sprite2D.new()
	contact.texture = contact_texture
	contact.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	contact.position = sprite.position+Vector2(0,2)
	var width := 94.0 if entry.kind=="prop" and entry.index==0 else (90.0 if entry.kind=="prop" else 18.0)
	var height := 25.0 if entry.kind=="prop" and entry.index==0 else (13.0 if entry.kind=="prop" else 7.0)
	contact.scale = Vector2(width/96,height/48)
	contact.material = decoration_material
	contact.set_meta("scenery",{"kind":"contact"})
	decals.add_child(contact)
	nodes.append(contact)
	if entry.kind!="prop": return
	var shadow := Sprite2D.new()
	shadow.texture = sprite.texture
	shadow.offset = sprite.offset
	shadow.flip_h = sprite.flip_h
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.material = cast_shadow_material
	var factor := sprite.scale.x
	shadow.transform = Transform2D(Vector2(factor,0),Vector2(-factor*.48,-factor*.22),sprite.position+Vector2(2,1))
	shadow.set_meta("scenery",{"kind":"cast_shadow"})
	decals.add_child(shadow)
	nodes.append(shadow)

func _update_area() -> void:
	super._update_area()
	if not initialized: return
	if cast_shadow_material != null:
		cast_shadow_material.set_shader_parameter("view_size",horizon.view_size)
		cast_shadow_material.set_shader_parameter("fade_start",horizon.far_height()*.62)
		cast_shadow_material.set_shader_parameter("fade_end",horizon.far_height()+68.0*horizon.art_scale)
