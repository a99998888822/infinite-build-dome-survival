extends Node2D
class_name EchoBatSonic
## One preloaded atlas and one swept shape query; no runtime pixel particles.
const WAVE := preload("res://assets/sprites/enemies/echo_bat/sonic_wave.png")
const HIT := preload("res://assets/sprites/enemies/echo_bat/sonic_hit.png")
var target: PlayerController
var direction := Vector2.RIGHT
var speed := 300.0
var max_distance := 320.0
var damage := 7
var travelled := 0.0
var age := 0.0
var impacted := false
var dealt_damage := 0
var visual: Sprite2D
var sweep: ShapeCast2D


func _ready() -> void:
	top_level = true
	add_to_group("echo_bat_projectiles")
	visual = Sprite2D.new()
	visual.texture = WAVE
	visual.hframes = 8
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.scale = Vector2.ONE * 0.625
	visual.rotation = direction.angle()
	add_child(visual)
	sweep = ShapeCast2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	sweep.shape = shape
	sweep.collision_mask = 5 # Player and terrain, not other enemies.
	sweep.collide_with_areas = false
	sweep.enabled = false
	add_child(sweep)


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	if not is_instance_valid(target) or not target.is_alive():
		queue_free()
		return
	age += delta
	if impacted:
		visual.frame = mini(5, int(age * 24))
		if age >= 0.25: queue_free()
		return
	var distance := minf(speed * delta, maxf(0.0, max_distance - travelled))
	sweep.target_position = direction * distance
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		global_position += direction * distance * sweep.get_closest_collision_safe_fraction()
		for i in sweep.get_collision_count():
			if sweep.get_collider(i) == target:
				dealt_damage = target.take_damage(damage, "enemy_echo_bat_sonic")
				break
		impact()
		return
	global_position += direction * distance
	travelled += distance
	visual.frame = int(age * 24) % 8
	if travelled >= max_distance: queue_free()


func impact() -> void:
	impacted = true
	age = 0.0
	visual.texture = HIT
	visual.hframes = 6
	visual.frame = 0
	visual.scale = Vector2.ONE * 0.75
	visual.rotation = 0.0
