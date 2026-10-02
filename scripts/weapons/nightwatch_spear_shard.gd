extends ProjectileInstance
class_name NightwatchSpearShard

const SPEAR := preload("res://assets/sprites/weapons/weapon_nightwatch_spear.png")
var _paused_contacts: Dictionary = {}


func _ready() -> void:
	z_index = 50
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("nightwatch_spear_shards")
	add_to_group("weapon_runtime_effects")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	# An Area2D overlap can arrive on the same frame the battle is paused.
	# Retain that contact so pausing neither deals damage nor loses the hit.
	var pending := _paused_contacts.keys()
	_paused_contacts.clear()
	for id in pending:
		var body := instance_from_id(id) as Node
		if is_instance_valid(body):
			_on_body_entered(body)
	super._physics_process(delta)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		_paused_contacts[body.get_instance_id()] = true
		return
	if body is PhysicsBody2D and ((body as PhysicsBody2D).collision_layer & TERRAIN_COLLISION_LAYER) != 0:
		cancel()
		return
	super._on_body_entered(body)


func cancel() -> void:
	_paused_contacts.clear()
	hide()
	set_physics_process(false)
	_destroy()


func _draw() -> void:
	if not active:
		return
	var tint := Color.WHITE
	if weapon.has_effect("fire"): tint = Color("ffc38a")
	elif weapon.has_effect("ice"): tint = Color("b4efff")
	elif weapon.has_effect("lightning"): tint = Color("dbccff")
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_texture_rect_region(SPEAR, Rect2(-48, -6, 54, 12), Rect2(4, 0, 238, 28), tint)
	draw_set_transform(Vector2.ZERO)
