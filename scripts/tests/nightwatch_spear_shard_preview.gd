extends ProjectileInstance

# Production projectile collision, damage, pause and enchantments; review-only art.
signal shard_hit(target_id: int)
const SPEAR = preload("res://assets/sprites/weapons/weapon_nightwatch_spear.png")
var accent := Color("a9bfba")
var travelled := 0.0


func _ready() -> void:
	z_index = 42
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("nightwatch_review_shards")


func _physics_process(delta: float) -> void:
	var previous := global_position
	super._physics_process(delta)
	travelled += previous.distance_to(global_position)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	var valid_hit: bool = active and body is EnemyController and body.is_alive() and not hit_targets.has(body.get_instance_id())
	var target_id := body.get_instance_id()
	super._on_body_entered(body)
	if valid_hit: shard_hit.emit(target_id)


func _draw() -> void:
	if not active: return
	draw_set_transform(Vector2.ZERO, direction.angle())
	var length := minf(54.0, travelled + 8.0)
	draw_texture_rect_region(SPEAR, Rect2(6 - length, -6, length, 12), Rect2(4, 0, 238, 28), accent)
	for index in 4:
		if 52 + index * 6 > travelled + 8: break
		draw_rect(Rect2(-52 - index * 6, index % 2 * 2 - 1, 3, 2), Color(accent, 0.65 - index * 0.13))
	draw_set_transform(Vector2.ZERO)
