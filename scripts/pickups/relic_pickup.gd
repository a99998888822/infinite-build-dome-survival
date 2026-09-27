extends Area2D
class_name RelicPickup

signal collected(pickup: RelicPickup)
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const ICON_SIZE := 24.0
const GLOW_SIZE := 44

static var _glow_texture: GradientTexture2D = null

var target_player: PlayerController = null
var collected_once: bool = false
var reward_snapshot: RewardSnapshot = null
var _age: float = 0.0
var _collect_request: Callable = Callable()
var _glow: Sprite2D = null


func _ready() -> void:
	add_to_group("reward_pickups")
	add_to_group("relic_pickups")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	_create_glow()
	_update_visual()
	queue_redraw()


func initialize_choice(player: PlayerController, request: Callable, snapshot: RewardSnapshot = null) -> void:
	target_player = player
	reward_snapshot = snapshot
	_collect_request = request
	queue_redraw()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) or collected_once:
		return
	_age += delta
	_update_visual()
	queue_redraw()
	if not is_instance_valid(target_player) or not target_player.is_alive():
		return
	if global_position.distance_to(target_player.global_position) <= target_player.get_stat("pickup_radius"):
		global_position = global_position.move_toward(target_player.global_position, 360.0 * delta)
		if global_position.distance_to(target_player.global_position) <= 16.0:
			collect()


func collect() -> bool:
	if collected_once or not is_instance_valid(target_player) or not target_player.is_alive():
		return false
	if not _collect_request.is_valid():
		return false
	# A pickup queues one choice; only the popup grants a selected relic.
	collected_once = true
	if not bool(_collect_request.call()):
		collected_once = false
		return false
	if reward_snapshot != null:
		reward_snapshot.collected_relics += 1
	collected.emit(self)
	queue_free()
	return true


func _on_body_entered(body: Node) -> void:
	if body == target_player and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		collect()


func _create_glow() -> void:
	# A shared radial texture gives a soft additive halo without requiring bloom.
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, 0.78, 0.34, 0.42), Color(0.92, 0.62, 0.23, 0.28), Color(0.65, 0.44, 0.14, 0.08), Color(0.65, 0.44, 0.14, 0.0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.width = GLOW_SIZE
		_glow_texture.height = GLOW_SIZE
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
	_glow = Sprite2D.new()
	_glow.name = "RewardGlow"
	_glow.texture = _glow_texture
	_glow.z_index = -1
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = glow_material
	add_child(_glow)


func _hover_offset() -> Vector2:
	return Vector2(0, -3 + roundf(sin(_age * 2.6)))


func _update_visual() -> void:
	if _glow == null:
		return
	var pulse := 0.5 + 0.5 * sin(_age * 2.6)
	_glow.position = _hover_offset()
	_glow.modulate.a = 0.5 + pulse * 0.25
	_glow.scale = Vector2.ONE * (0.94 + pulse * 0.06)


static func _cube_project(point: Vector3) -> Vector2:
	# Equal unit edges on all three axes, viewed from 45 degrees around the
	# cube and 35.264 degrees above it. The projected height is 48 drawing units.
	return Vector2((point.x - point.z) * sqrt(3.0) * 0.5,
		(point.x + point.z) * 0.5 - point.y) * 24.0


func _cube_face(points: Array[Vector3], color: Color) -> void:
	var projected := PackedVector2Array()
	for point in points:
		projected.append(_cube_project(point))
	PIXEL.polygon(self, projected, color)


func _cube_line(points: Array[Vector3], color: Color) -> void:
	var projected := PackedVector2Array()
	for point in points:
		projected.append(_cube_project(point))
	PIXEL.path(self, projected, color, 2)


func _draw() -> void:
	draw_set_transform(Vector2(0, 11))
	PIXEL.ellipse(self, Vector2(12, 3), Color(0.025, 0.035, 0.03, 0.4))
	# All faces, trim and runes share the same unit-cube projection. The 2-unit
	# drawing grid becomes a 1px grid at the final 24px icon size.
	var hover := _hover_offset()
	draw_set_transform(hover, 0.0, Vector2.ONE * (ICON_SIZE / 48.0))
	_cube_face([Vector3(0,1,1), Vector3(0,1,0), Vector3(1,1,0), Vector3(1,0,0), Vector3(1,0,1), Vector3(0,0,1)], Color("111c1a"))
	# Square lid and two equally wide square side faces.
	_cube_face([Vector3(0.04,1,0.04), Vector3(0.96,1,0.04), Vector3(0.96,1,0.96), Vector3(0.04,1,0.96)], Color("c0a26a"))
	_cube_face([Vector3(0.16,1,0.16), Vector3(0.84,1,0.16), Vector3(0.84,1,0.84), Vector3(0.16,1,0.84)], Color("728560"))
	_cube_face([Vector3(0.06,0.94,1), Vector3(0.94,0.94,1), Vector3(0.94,0.06,1), Vector3(0.06,0.06,1)], Color("53694a"))
	_cube_face([Vector3(1,0.94,0.06), Vector3(1,0.94,0.94), Vector3(1,0.06,0.94), Vector3(1,0.06,0.06)], Color("2f4738"))
	# Brass framing follows the same square geometry on both vertical faces.
	_cube_line([Vector3(0.08,0.92,1), Vector3(0.08,0.08,1), Vector3(0.92,0.08,1), Vector3(0.92,0.92,1)], Color("b69a62"))
	_cube_line([Vector3(1,0.92,0.08), Vector3(1,0.08,0.08), Vector3(1,0.08,0.92), Vector3(1,0.92,0.92)], Color("8b7549"))
	_cube_line([Vector3(0.04,0.78,1), Vector3(0.96,0.78,1)], Color("263c2d"))
	_cube_line([Vector3(1,0.78,0.04), Vector3(1,0.78,0.96)], Color("1c3026"))
	# Compact latch and three quiet, plane-aligned rune decorations.
	_cube_face([Vector3(0.4,0.86,1), Vector3(0.6,0.86,1), Vector3(0.6,0.61,1), Vector3(0.4,0.61,1)], Color("e2c58a"))
	PIXEL.block(self, _cube_project(Vector3(0.5,0.68,1)), Vector2(2,2), Color("384633"))
	_cube_line([Vector3(0.35,1,0.42), Vector3(0.55,1,0.35), Vector3(0.65,1,0.55), Vector3(0.48,1,0.62)], Color("aac6a0"))
	_cube_line([Vector3(0.43,0.46,1), Vector3(0.6,0.46,1), Vector3(0.6,0.28,1)], Color("95ae8a"))
	_cube_line([Vector3(1,0.44,0.4), Vector3(1,0.44,0.59), Vector3(1,0.26,0.59)], Color("72977e"))
	# Sparse square motes vary in phase and horizontal spacing;
	# their envelope stays compact.
	for index in 4:
		var phase := fposmod(_age * (0.28 + index * 0.013) + index * 0.3819, 1.0)
		var side := -1.0 if index % 2 == 0 else 1.0
		var point := Vector2(side * (13.0 + index % 3 * 1.5) + sin(phase * TAU + index * 2.4) * 1.5, 5.0 - phase * 25.0)
		var alpha := sin(phase * PI) * 0.65
		draw_set_transform(hover + point.round(), sin(index * 7.1) * 0.35 + phase * 0.2)
		var color := Color(1.0, 0.84, 0.48, alpha) if index % 3 != 0 else Color(0.58, 1.0, 0.84, alpha)
		draw_rect(Rect2(Vector2(-1,-1), Vector2(2,2)), color)
	# A brief highlight crosses the rim once per cycle, rather than flashing
	# the entire icon or filling the ground with a large opaque marker.
	var glint := pow(maxf(0.0, sin(_age * 2.0)), 12.0)
	draw_set_transform(hover + Vector2(-2,-10))
	draw_rect(Rect2(-2,0,5,1), Color(1.0,0.96,0.75,glint * 0.7))
	draw_rect(Rect2(0,-2,1,5), Color(1.0,0.96,0.75,glint * 0.7))
	draw_set_transform(Vector2.ZERO)
