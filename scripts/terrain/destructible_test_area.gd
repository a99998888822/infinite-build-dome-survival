extends StaticBody2D
class_name DestructibleTestArea

const CELL_SIZE: float = 16.0
const GRID_SIZE := Vector2i(18, 10)
const GRID_ORIGIN := Vector2(-144.0, -80.0)
const TERRAIN_COLLISION_LAYER: int = 4

const MATERIAL_COLORS: Dictionary = {
	"soil": Color(0.28, 0.20, 0.13, 1.0),
	"wood": Color(0.42, 0.27, 0.13, 1.0),
	"stone": Color(0.30, 0.34, 0.32, 1.0),
}

var _cells: Dictionary = {}
var _collision_shapes: Dictionary = {}
var _damage_flash_cells: Dictionary = {}


func _ready() -> void:
	collision_layer = TERRAIN_COLLISION_LAYER
	collision_mask = 0
	_build_grid()
	queue_redraw()


func _build_grid() -> void:
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var cell := Vector2i(x, y)
			_cells[cell] = _get_material_for_cell(cell)
			var collision_shape := CollisionShape2D.new()
			collision_shape.name = "Cell_%d_%d" % [x, y]
			collision_shape.position = _cell_center(cell)
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(CELL_SIZE - 1.0, CELL_SIZE - 1.0)
			collision_shape.shape = rectangle
			add_child(collision_shape)
			_collision_shapes[cell] = collision_shape


func _get_material_for_cell(cell: Vector2i) -> String:
	if cell.x == 0 or cell.y == 0 or cell.x == GRID_SIZE.x - 1 or cell.y == GRID_SIZE.y - 1:
		return "stone"
	if (cell.x + cell.y * 3) % 9 == 0:
		return "wood"
	return "soil"


func destroy_point(global_position: Vector2) -> bool:
	var cell := _local_to_cell(to_local(global_position))
	if not _cells.has(cell):
		return false
	if str(_cells[cell]).is_empty():
		return false
	_cells[cell] = ""
	var collision_shape := _collision_shapes.get(cell) as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_damage_flash_cells[cell] = 0.12
	queue_redraw()
	return true


func _local_to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori((local_position.x - GRID_ORIGIN.x) / CELL_SIZE),
		floori((local_position.y - GRID_ORIGIN.y) / CELL_SIZE)
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(
		float(cell.x) * CELL_SIZE + CELL_SIZE * 0.5,
		float(cell.y) * CELL_SIZE + CELL_SIZE * 0.5
	)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		GRID_ORIGIN + Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE),
		Vector2(CELL_SIZE - 1.0, CELL_SIZE - 1.0)
	)


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	for cell_key in _damage_flash_cells.keys():
		var remaining := float(_damage_flash_cells[cell_key]) - delta
		if remaining <= 0.0:
			_damage_flash_cells.erase(cell_key)
		else:
			_damage_flash_cells[cell_key] = remaining
	if not _damage_flash_cells.is_empty():
		queue_redraw()


func _draw() -> void:
	var area_size := Vector2(float(GRID_SIZE.x) * CELL_SIZE, float(GRID_SIZE.y) * CELL_SIZE)
	draw_rect(Rect2(GRID_ORIGIN, area_size), Color(0.04, 0.05, 0.045, 0.9), true)
	for cell_key in _cells.keys():
		var cell: Vector2i = cell_key
		var material_id := str(_cells[cell])
		if material_id.is_empty():
			continue
		var color: Color = MATERIAL_COLORS.get(material_id, Color.WHITE)
		if _damage_flash_cells.has(cell):
			color = color.lightened(0.35)
		draw_rect(_cell_rect(cell), color, true)
	draw_rect(Rect2(GRID_ORIGIN, area_size), Color(0.62, 0.72, 0.62, 0.7), false, 2.0)
