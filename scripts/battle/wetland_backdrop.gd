extends Node2D
class_name WetlandBackdrop

## Visual-only ground. World coordinates and private RNG keep decoration
## stable without changing movement, enemy spawning or gameplay randomness.
const GROUND_SHADER = preload("res://shaders/battle/wetland_ground.gdshader")
const DECAL_SHADER = preload("res://shaders/battle/wetland_decal_depth.gdshader")
const RIPPLE_TEXTURE = preload("res://assets/sprites/background/wetland/fx_wet_ripple.png")
const STEP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/environment/wet_step_01.wav"),
	preload("res://assets/audio/sfx/environment/wet_step_02.wav"),
]
const DROP_SOUND = preload("res://assets/audio/sfx/environment/water_drop.wav")
const DECALS: Array[Texture2D] = [
	preload("res://assets/sprites/background/wetland/decal_brick_01.png"),
	preload("res://assets/sprites/background/wetland/decal_brick_02.png"),
	preload("res://assets/sprites/background/wetland/decal_crack_01.png"),
	preload("res://assets/sprites/background/wetland/decal_crack_02.png"),
	preload("res://assets/sprites/background/wetland/decal_crack_03.png"),
	preload("res://assets/sprites/background/wetland/decal_moss_01.png"),
	preload("res://assets/sprites/background/wetland/decal_moss_02.png"),
	preload("res://assets/sprites/background/wetland/decal_rubble_01.png"),
	preload("res://assets/sprites/background/wetland/decal_rubble_02.png"),
]
const CELL_SIZE := 192.0
const RIPPLE_COUNT := 24
const RIPPLE_SECONDS := 1.35
const STEP_DISTANCE := 64.0

var camera_position := Vector2.ZERO
var _player: PlayerController
var _floor: Sprite2D
var _floor_image: Image
var _ground: ColorRect
var _material: ShaderMaterial
var _decal_material: ShaderMaterial
var _cells: Dictionary = {}
var _cell_rect := Rect2i()
var _ripples: Array[Sprite2D] = []
var _ripple_ages: Array[float] = []
var _ripple_strengths: Array[float] = []
var _ripple_cursor := 0
var _step_player: AudioStreamPlayer
var _drop_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _last_foot := Vector2.ZERO
var _has_foot := false
var _step_distance := 0.0
var _step_cooldown := 0.0
var _step_side := 1.0
var _drop_timer := 2.0
var _time := 0.0


func _ready() -> void:
	add_to_group("battle_wetland")
	_floor = get_node_or_null("../StoneBrickFloor") as Sprite2D
	if _floor != null and _floor.texture != null:
		_floor_image = _floor.texture.get_image()
	_rng.seed = 90317
	_ground = ColorRect.new()
	_ground.name = "ContinuousWetGround"
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = GROUND_SHADER
	_decal_material = ShaderMaterial.new()
	_decal_material.shader = DECAL_SHADER
	_ground.material = _material
	add_child(_ground)
	for index in range(RIPPLE_COUNT):
		var ripple := Sprite2D.new()
		ripple.texture = RIPPLE_TEXTURE
		ripple.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ripple.z_index = 20
		ripple.visible = false
		add_child(ripple)
		_ripples.append(ripple)
		_ripple_ages.append(RIPPLE_SECONDS)
		_ripple_strengths.append(1.0)
	_step_player = _make_audio_player("WetFootsteps", -8.0)
	_drop_player = _make_audio_player("WaterDrops", -12.0)
	_update_ground()


func set_world_context(player: PlayerController, _wave_manager: WaveManager) -> void:
	_player = player
	_has_foot = false


func get_environment_time() -> float:
	return _time


func set_horizon_view(horizon: float, height: float, ui_size: Vector2, units_per_pixel: Vector2, sky_texture: Texture2D) -> void:
	var stone_material: ShaderMaterial = _floor.material as ShaderMaterial if is_instance_valid(_floor) else null
	for surface in [_material, _decal_material, stone_material]:
		if surface == null:
			continue
		surface.set_shader_parameter("horizon_y", horizon)
		surface.set_shader_parameter("fold_height", height)
		surface.set_shader_parameter("ui_view_size", ui_size)
	if stone_material != null:
		stone_material.set_shader_parameter("environment_time", _time)
	_material.set_shader_parameter("world_units_per_pixel", units_per_pixel)
	_material.set_shader_parameter("sky_texture", sky_texture)


func _make_audio_player(node_name: String, gain: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.name = node_name
	audio.bus = "SFX"
	audio.volume_db = gain
	add_child(audio)
	return audio


func _process(delta: float) -> void:
	_update_ground()
	var active := is_instance_valid(_player) and _player.alive and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	if not active:
		_has_foot = false
		_step_distance = 0.0
		_step_player.stop()
		_drop_player.stop()
		return
	_time += delta
	_step_cooldown = maxf(_step_cooldown - delta, 0.0)
	_material.set_shader_parameter("environment_time", _time)
	_material.set_shader_parameter("player_position", _player.global_position + Vector2(0, 21))
	_update_ripples(delta)
	_update_footsteps()
	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = _rng.randf_range(2.2, 4.8)
		var size := get_viewport_rect().size
		var drop := camera_position + Vector2(_rng.randf_range(-size.x * 0.42, size.x * 0.42), _rng.randf_range(-size.y * 0.18, size.y * 0.40))
		if is_wet_at(drop):
			spawn_ripple(drop, 0.42)
			_drop_player.stream = DROP_SOUND
			_drop_player.pitch_scale = _rng.randf_range(0.86, 1.12)
			_drop_player.play()


func _update_ground() -> void:
	var camera := get_viewport().get_camera_2d()
	camera_position = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var view_size := get_viewport_rect().size
	var origin := (camera_position - view_size * 0.5 - Vector2(4, 4)).floor()
	_ground.position = origin
	_ground.size = view_size + Vector2(8, 8)
	_material.set_shader_parameter("world_origin", origin)
	_material.set_shader_parameter("surface_size", _ground.size)
	var first := Vector2i((origin / CELL_SIZE).floor()) - Vector2i.ONE
	var cell_size := Vector2i((view_size / CELL_SIZE).ceil()) + Vector2i(4, 4)
	var next_rect := Rect2i(first, cell_size)
	if next_rect != _cell_rect:
		_cell_rect = next_rect
		_refresh_decals()


func is_wet_at(world_position: Vector2) -> bool:
	if _floor_image == null or not is_instance_valid(_floor):
		return true
	var local := _floor.to_local(world_position) + _floor.texture.get_size() * 0.5
	var pixel := Vector2i(local.floor())
	if not Rect2i(Vector2i.ZERO, _floor_image.get_size()).has_point(pixel):
		return true
	return _floor_image.get_pixelv(pixel).a < 0.5


func _refresh_decals() -> void:
	for key in _cells.keys():
		if not _cell_rect.has_point(key):
			(_cells[key] as Node2D).queue_free()
			_cells.erase(key)
	for cy in range(_cell_rect.position.y, _cell_rect.end.y):
		for cx in range(_cell_rect.position.x, _cell_rect.end.x):
			var key := Vector2i(cx, cy)
			if _cells.has(key):
				continue
			var cell := Node2D.new()
			cell.name = "GroundDetail_%d_%d" % [cx, cy]
			cell.z_index = 1
			add_child(cell)
			_cells[key] = cell
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(cx * 73856093 ^ cy * 19349663 ^ 94103)
			for index in range(rng.randi_range(1, 3)):
				var point := Vector2(cx, cy) * CELL_SIZE + Vector2(rng.randf_range(30, 160), rng.randf_range(28, 164))
				if not is_wet_at(point):
					continue
				var decal := Sprite2D.new()
				decal.texture = DECALS[rng.randi_range(0, DECALS.size() - 1)]
				decal.material = _decal_material
				decal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				decal.position = point.round()
				decal.flip_h = rng.randf() > 0.5
				decal.modulate = Color(0.65, 0.74, 0.69, rng.randf_range(0.5, 0.8))
				cell.add_child(decal)


func _update_footsteps() -> void:
	var foot := _player.global_position + Vector2(0, 21)
	if not _has_foot:
		_last_foot = foot
		_has_foot = true
	var distance := foot.distance_to(_last_foot)
	_last_foot = foot
	if distance > 64.0 or not is_wet_at(foot):
		_step_distance = 0.0
		return
	if distance < 0.1:
		return
	_step_distance += distance
	if _step_distance >= STEP_DISTANCE and _step_cooldown <= 0.0:
		_step_distance = fmod(_step_distance, STEP_DISTANCE)
		_step_cooldown = 0.26
		_step_side *= -1.0
		spawn_ripple(foot + Vector2(3.0 * _step_side, 0), 0.9)
		_step_player.stream = STEP_SOUNDS[0 if _step_side > 0 else 1]
		_step_player.pitch_scale = _rng.randf_range(0.94, 1.06)
		_step_player.play()


func spawn_ripple(world_position: Vector2, strength: float = 1.0) -> void:
	var index := _ripple_cursor
	_ripple_cursor = (_ripple_cursor + 1) % RIPPLE_COUNT
	_ripples[index].position = world_position.round()
	_ripples[index].scale = Vector2.ONE * 0.18
	_ripples[index].modulate.a = strength
	_ripples[index].visible = true
	_ripple_ages[index] = 0.0
	_ripple_strengths[index] = strength


func _update_ripples(delta: float) -> void:
	for index in range(RIPPLE_COUNT):
		_ripple_ages[index] += delta
		var progress := clampf(_ripple_ages[index] / RIPPLE_SECONDS, 0.0, 1.0)
		_ripples[index].visible = progress < 1.0
		if progress >= 1.0:
			continue
		_ripples[index].scale = Vector2.ONE * lerpf(0.18, 0.9, progress)
		_ripples[index].modulate.a = (1.0 - progress) * _ripple_strengths[index]
