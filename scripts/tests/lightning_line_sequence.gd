extends Node2D

# Prototype only: schedule existing enchantment instances, leaving their warning,
# visuals, damage, status effects and sounds in the production implementation.
signal point_created(index: int, world_position: Vector2)

@export_range(1, 32) var point_count: int = 8
@export_range(0.01, 1.0) var point_interval: float = 0.1
@export_range(1.0, 128.0) var point_spacing: float = 64.0
@export var first_offset: float = 40.0

var _origin := Vector2.ZERO
var _elapsed := 0.0
var _next_point := 0
var _weapon: WeaponInstance
var _event: DamageEvent
var _attachment_id := ""


func _ready() -> void:
	set_process(false)


func start_wave(origin: Vector2, weapon: WeaponInstance, event: DamageEvent, attachment_id: String) -> bool:
	if is_processing() or weapon == null or event == null:
		return false
	# Lock the origin on cast: later player movement must not bend this row.
	_origin = origin
	_weapon = weapon
	_event = event
	_attachment_id = attachment_id
	_elapsed = 0.0
	_next_point = 0
	set_process(true)
	return true


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	# Emit every point in the same update phase, including the first one.
	if _next_point == 0:
		_emit_point()
		set_process(_next_point < point_count)
		return
	_elapsed += delta
	# Absolute elapsed time avoids cumulative drift from chained timers.
	while _next_point < point_count and _elapsed + 0.00001 >= _next_point * maxf(point_interval, 0.01):
		_emit_point()
	if _next_point >= point_count:
		set_process(false)


func _emit_point() -> void:
	var point := _origin + Vector2.RIGHT * (first_offset + _next_point * point_spacing)
	ElectricSparkEffect.spawn(self, point, _weapon, _event, _attachment_id)
	point_created.emit(_next_point, point)
	_next_point += 1
