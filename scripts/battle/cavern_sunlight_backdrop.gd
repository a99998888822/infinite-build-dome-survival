extends CavernGrasslandBackdrop
class_name CavernSunlightBackdrop
## R02 cloud shadows and moving sunlit patches on the approved grassland.
const SHADERS := "res://shaders/battle/meadow/sunlight/"
const CLOUD_TEXTURE: Texture2D = preload("res://assets/sprites/background/meadow/sunlight/cloud_noise.png")
const ROCK_FACE_MASK: Texture2D = preload("res://assets/sprites/background/meadow/sunlight/rock_face_mask.png")

var lighting_ready := false
var lit_objects: Array[Sprite2D] = []
var hero_material: ShaderMaterial
var old_hero_material: Material
var _receiver_view := Vector4.ZERO

func _setup() -> void:
	if initialized or not is_instance_valid(player) or not is_inside_tree(): return
	super._setup()
	ground_material.shader = preload(SHADERS + "ground.gdshader")
	grass_material.shader = preload(SHADERS + "grass.gdshader")
	ground_material.set_shader_parameter("surface_texture", surface_texture)
	ground_material.set_shader_parameter("sample_offset", sample_offset)
	for material: ShaderMaterial in [ground_material, grass_material]: _bind_light(material)
	for key: Vector2i in cells: _light_cell(key)
	old_hero_material = player.sprite.material
	hero_material = ShaderMaterial.new()
	hero_material.shader = preload(SHADERS + "player.gdshader")
	_bind_light(hero_material)
	player.sprite.material = hero_material
	# Receiver materials replace the old additive screen-space light pool.
	(horizon as CavernPitHorizon).pit_light.visible = false
	lighting_ready = true

func _bind_light(material: ShaderMaterial) -> void:
	material.set_shader_parameter("cloud_texture", CLOUD_TEXTURE)

func _set_receiver_view(material: ShaderMaterial, view: Vector4) -> void:
	material.set_shader_parameter("view_size", Vector2(view.x, view.y))
	material.set_shader_parameter("fade_start", view.z)
	material.set_shader_parameter("fade_end", view.w)

func _grass_batch(blades: Array[Dictionary], key: Vector2i, reverse: bool) -> MultiMeshInstance2D:
	var batch := super._grass_batch(blades, key, reverse)
	for i in blades.size():
		var entry: Dictionary = blades[blades.size() - 1 - i if reverse else i]
		batch.multimesh.set_instance_custom_data(i, Color(float(entry.index), entry.point.x, entry.point.y, float(entry.scale)))
	return batch

func _decorate_solid(sprite: Sprite2D, nodes: Array[Node]) -> void:
	var first := nodes.size()-1
	super._decorate_solid(sprite, nodes)
	if lighting_ready:
		for index in range(first,nodes.size()): _light_sprite(nodes[index] as Sprite2D)

func _light_cell(key: Vector2i) -> void:
	for node: Node in cells[key]:
		if node is Sprite2D: _light_sprite(node)

func _retire_cell(key: Vector2i) -> void:
	for node: Node in cells[key]:
		if node is Sprite2D: lit_objects.erase(node)
	super._retire_cell(key)

func _light_sprite(sprite: Sprite2D) -> void:
	var entry: Dictionary = sprite.get_meta("scenery")
	if entry.kind == "contact": return
	var material := ShaderMaterial.new()
	if entry.kind == "cast_shadow":
		material.shader = preload(SHADERS + "shadow.gdshader")
	elif entry.kind == "prop" and entry.index == 0:
		material.shader = preload(SHADERS + "rock.gdshader")
		material.set_shader_parameter("face_mask", ROCK_FACE_MASK)
		material.set_shader_parameter("mask_flip", sprite.flip_h)
	else:
		material.shader = preload(SHADERS + "decoration.gdshader")
	_bind_light(material)
	material.set_shader_parameter("object_root", sprite.position)
	# Streaming can add a receiver while the view stays unchanged.
	_set_receiver_view(material, Vector4(horizon.view_size.x, horizon.view_size.y,
		horizon.far_height() * .62, horizon.ground_fade_end()))
	sprite.material = material
	lit_objects.append(sprite)

func _update_area() -> void:
	super._update_area()
	if not lighting_ready: return
	# Inherited environment_time advances only while combat is running, so
	# all receivers pause together and continue without jumping after a modal.
	for material: ShaderMaterial in [ground_material, grass_material, hero_material]:
		material.set_shader_parameter("sun_time", environment_time)
	hero_material.set_shader_parameter("object_root", player.global_position)
	var view := Vector4(horizon.view_size.x, horizon.view_size.y,
		horizon.far_height() * .62, horizon.ground_fade_end())
	var view_changed := view != _receiver_view
	_receiver_view = view
	for i in range(lit_objects.size() - 1, -1, -1):
		var sprite := lit_objects[i]
		if not is_instance_valid(sprite) or sprite.is_queued_for_deletion():
			lit_objects.remove_at(i)
			continue
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter("sun_time", environment_time)
		if view_changed:
			_set_receiver_view(material, view)

func detach_player() -> void:
	if is_instance_valid(player) and is_instance_valid(player.sprite) and hero_material != null:
		player.sprite.material = old_hero_material
	if is_instance_valid(horizon): (horizon as CavernPitHorizon).pit_light.visible = true
	super.detach_player()
