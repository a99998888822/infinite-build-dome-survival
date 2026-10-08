extends CoinProjectile
class_name CannonPellet
## Reuses the swept collision/pierce/split path, with one prepared PNG atlas.
const ATLAS := preload("res://assets/sprites/weapons/mobility/pellet.png")
var _candidate_shape := RectangleShape2D.new()
var _candidate_query := PhysicsShapeQueryParameters2D.new()

func _collision_candidates(start: Vector2, end: Vector2, radius: float) -> Array:
	# Broad phase avoids scanning the entire enemy registry for every pellet/frame.
	_candidate_shape.size = Vector2(start.distance_to(end) + radius * 2, radius * 2)
	_candidate_query.shape = _candidate_shape
	_candidate_query.transform = Transform2D(direction.angle(), (start + end) * 0.5)
	_candidate_query.collision_mask = 2
	_candidate_query.collide_with_areas = false
	var result: Array = []
	for contact in get_world_2d().direct_space_state.intersect_shape(_candidate_query, maxi(32, EnemyRegistry.get_registered_enemies().size())):
		if contact.collider is EnemyController: result.append(contact.collider)
	return result

func _create_child() -> CoinProjectile:
	return CannonPellet.new()

func _spawn_hit_visual(point: Vector2) -> void:
	# A shared per-cast budget limits overdraw on packed enemy groups.
	var count := int(damage_event.attack_context.get("cannon_hit_visuals", 0))
	if count >= 12: return
	damage_event.attack_context["cannon_hit_visuals"] = count + 1
	MobilityAtlasEffect.spawn(get_parent(), weapon, "pellet_hit", point)

func _spawn_children(origin: Vector2) -> void:
	# Splits share their parent's hit ledger; different native pellets can stack.
	if int(damage_event.attack_context.get("cannon_split_batches", 0)) >= 3: return
	damage_event.attack_context["cannon_split_batches"] = int(damage_event.attack_context.get("cannon_split_batches", 0)) + 1
	super._spawn_children(origin)

func _draw() -> void:
	if cancelled: return
	var dimensions := weapon.get_projectile_visual_scale() * (0.65 if split_generation > 0 else 1.0)
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE * dimensions)
	draw_texture_rect_region(ATLAS, Rect2(-40,-8,48,16), Rect2((int(age * 20) % 4) * 48,0,48,16))
	draw_set_transform(Vector2.ZERO)
