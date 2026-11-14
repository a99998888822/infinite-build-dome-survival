extends Area2D
class_name ExpOrb

signal collected(orb: ExpOrb, exp_amount: int, gold_amount: int)
signal collection_completed(orb: ExpOrb)

const DEFAULT_AMOUNT: int = 1
const DEFAULT_ATTRACT_SPEED: float = 480.0
const WAVE_END_ATTRACT_SPEED: float = 960.0

@export var amount: int = DEFAULT_AMOUNT
@export var attract_speed: float = DEFAULT_ATTRACT_SPEED

var target_player: PlayerController = null
var collected_once: bool = false
## Ground orbs outside the pickup radius skip their per-frame callback. The
## field manager also takes distant orbs out of the physics world (collision
## and monitoring) while keeping the node and every orb value intact.
var dormant: bool = false
var field_collidable := true
var contributions: Array[int] = []
static var field_manager: Node = null
var force_collecting: bool = false
var forced_attract_speed: float = WAVE_END_ATTRACT_SPEED
var _collection_time: float = 0.0
var _collection_start: Vector2 = Vector2.ZERO
var gold_multiplier := 1.0
var gold_lifetime := 0.0
var gold_age := 0.0
var gold_expired := false
var _gold_locked := false
var recycle_callback: Callable
var _sprite_color := Color.WHITE
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null: _sprite_color = sprite.modulate
	add_to_group("exp_orbs")
	add_to_group("reward_pickups")
	body_entered.connect(_on_body_entered)


func _exit_tree() -> void:
	# Freed, pooled or reparented orbs must leave the field registry; otherwise a
	# long run keeps stale references and the merge cap drifts.
	if field_manager != null and is_instance_valid(field_manager):
		field_manager.call("unregister_orb", self)


func initialize(exp_amount: int) -> void:
	if not is_in_group("exp_orbs"):
		add_to_group("exp_orbs")
	if not is_in_group("reward_pickups"):
		add_to_group("reward_pickups")
	amount = maxi(exp_amount, 0)
	contributions.clear()
	if amount > 0:
		contributions.append(amount)
	collected_once = false
	force_collecting = false
	dormant = false
	field_collidable = true
	gold_age = 0.0
	gold_expired = false
	_gold_locked = false
	gold_multiplier = 1.0
	gold_lifetime = 0.0
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	_collection_time = 0.0
	_collection_start = Vector2.ZERO
	forced_attract_speed = WAVE_END_ATTRACT_SPEED
	attract_speed = DEFAULT_ATTRACT_SPEED
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null: sprite.modulate = _sprite_color
	show()
	if collision_shape != null: collision_shape.disabled = false
	monitoring = true
	monitorable = true
	set_physics_process(true)
	queue_redraw()
	if field_manager != null and is_instance_valid(field_manager):
		field_manager.call("register_orb", self)


func park_for_pool() -> void:
	collected_once = true
	dormant = true
	target_player = null
	force_collecting = false
	if field_manager != null and is_instance_valid(field_manager):
		field_manager.call("unregister_orb", self)
	hide()
	set_physics_process(false)
	monitoring = false
	monitorable = false
	if collision_shape != null: collision_shape.disabled = true
	remove_from_group("exp_orbs")
	remove_from_group("reward_pickups")
	for connection in collected.get_connections():
		collected.disconnect(connection.callable)
	for connection in collection_completed.get_connections():
		collection_completed.disconnect(connection.callable)


func configure_gold(terms: Dictionary) -> void:
	gold_multiplier = float(terms.get("multiplier", 1.0))
	gold_lifetime = float(terms.get("lifetime", 0.0))
	queue_redraw()
	refresh_activity()


func advance_gold_clock(delta: float) -> void:
	if gold_lifetime <= 0 or gold_expired or _gold_locked: return
	gold_age += maxf(0, delta)
	if gold_age >= gold_lifetime:
		gold_expired = true
		var sprite := get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null: sprite.modulate = Color(0.35, 0.55, 0.65, 0.65)
		# Re-evaluate now that the coin expired; a far away expired coin is then
		# put to sleep by the field scan.
		refresh_activity()
	queue_redraw()


## The field manager owns collision culling. It never changes the amount,
## position, gold terms or collected state.
func set_field_collision(value: bool) -> void:
	if collected_once or field_collidable == value:
		return
	field_collidable = value
	set_deferred("monitoring", value)
	set_deferred("monitorable", value)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not value)
	if value:
		refresh_activity()


## Sleep/wake only changes per-frame processing. The orb keeps its node,
## position, amount, gold terms, monitoring and expiry state, so waking it
## later yields exactly the same pickup and gold as before.
func sleep_orb() -> void:
	if dormant or collected_once or force_collecting:
		return
	# A live temporary coin must keep its lifetime clock running. Only expire it
	# (advance_gold_clock calls refresh_activity) before allowing sleep.
	if gold_lifetime > 0.0 and not gold_expired:
		return
	dormant = true
	set_physics_process(false)


func wake_orb() -> void:
	if collected_once or not dormant:
		return
	if not field_collidable and not force_collecting:
		return
	dormant = false
	set_physics_process(true)


func refresh_activity() -> void:
	# A coin with a live lifetime must keep aging while it exists, even when it
	# lies far away. Exp-only orbs may sleep immediately.
	if not is_instance_valid(target_player) or collected_once or force_collecting:
		return
	if not field_collidable:
		return
	if gold_lifetime > 0.0 and not gold_expired:
		wake_orb()
		return
	if not is_instance_valid(target_player.pickup_area) or not target_player.pickup_area.monitoring:
		# Preview fixtures and bare players have no active PickupArea to wake orbs.
		wake_orb()
		return
	if global_position.distance_to(target_player.global_position) <= target_player.get_stat("pickup_radius"):
		wake_orb()
	else:
		sleep_orb()


func _draw() -> void:
	if gold_lifetime <= 0 or gold_expired: return
	var ratio := clampf(1.0 - gold_age / gold_lifetime, 0, 1)
	draw_arc(Vector2.ZERO, 8, -PI / 2, -PI / 2 + TAU * ratio, 24, Color("edc86b"), 2)


func set_target_player(player: PlayerController) -> void:
	target_player = player
	refresh_activity()


func start_wave_end_collection(player: PlayerController) -> void:
	_gold_locked = true # Only still-valid coins survive the existing wave-end sweep.
	target_player = player
	force_collecting = true
	forced_attract_speed = WAVE_END_ATTRACT_SPEED
	_collection_time = 0.0
	_collection_start = global_position
	wake_orb()


func _physics_process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	if target_player == null or collected_once:
		return
	advance_gold_clock(delta)
	var pickup_radius := INF if force_collecting else target_player.get_stat("pickup_radius")
	var distance_to_player := global_position.distance_to(target_player.global_position)
	if distance_to_player > pickup_radius:
		return
	_gold_locked = true
	var speed := forced_attract_speed if force_collecting else attract_speed
	if force_collecting:
		_collection_time += delta
		var target_position := target_player.global_position
		var next_position := global_position.move_toward(target_position, speed * delta)
		var arc := sin(clampf(_collection_time * 5.0, 0.0, PI)) * 18.0
		global_position = next_position + Vector2(0.0, -arc)
		rotation += delta * 8.0
	else:
		global_position = global_position.move_toward(target_player.global_position, speed * delta)
	if global_position.distance_to(target_player.global_position) <= 8.0:
		collect()


## Merging only adds a contribution; collection still applies the per-orb
## percent/rounding path once per contribution, so exp and gold stay exact.
func merge_amount(extra: int) -> void:
	if extra <= 0 or collected_once:
		return
	amount += extra
	contributions.append(extra)


func collect() -> void:
	if collected_once:
		return
	collected_once = true
	if field_manager != null and is_instance_valid(field_manager):
		field_manager.call("unregister_orb", self)
	field_collidable = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if AudioManager != null:
		AudioManager.play_exp_orb_collect_sfx()
	if contributions.is_empty():
		collected.emit(self, amount, 0 if gold_expired else amount)
	else:
		for contribution in contributions:
			collected.emit(self, contribution, 0 if gold_expired else contribution)
	# Wave settlement may freeze rewards immediately, so notify only after
	# every contribution and its collection listeners have finished.
	collection_completed.emit(self)
	if recycle_callback.is_valid():
		hide()
		set_physics_process(false)
		remove_from_group("exp_orbs")
		remove_from_group("reward_pickups")
		# Collection can run inside a physics query. Reparent only after it exits.
		recycle_callback.call_deferred(self)
	else:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		target_player = body
		collect()
