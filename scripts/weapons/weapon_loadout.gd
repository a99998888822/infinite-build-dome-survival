extends Node
class_name WeaponLoadout

signal weapon_equipped(weapon_id: String)
signal weapon_upgraded(weapon_id: String, level: int)
signal equip_failed(weapon_id: String, reason: String)

var owner_player: PlayerController = null
var weapon_instances: Array[WeaponInstance] = []
var targeting_service: TargetingService = null


func _ready() -> void:
	targeting_service = get_node_or_null("TargetingService") as TargetingService
	if targeting_service == null:
		targeting_service = TargetingService.new()
		targeting_service.name = "TargetingService"
		add_child(targeting_service)


func initialize(player: PlayerController) -> bool:
	owner_player = player
	weapon_instances.clear()
	if owner_player == null:
		push_error("[WeaponLoadout] missing owner player.")
		return false

	for weapon_id in owner_player.get_start_weapon_ids():
		if not equip_weapon(weapon_id):
			return false
	return true


func equip_weapon(weapon_id: String) -> bool:
	return _equip_weapon_internal(weapon_id, "equip")


func try_buy_weapon(weapon_id: String) -> bool:
	return _equip_weapon_internal(weapon_id, "purchase")


func remove_weapon(weapon_id: String) -> void:
	for index in range(weapon_instances.size() - 1, -1, -1):
		if weapon_instances[index].weapon_id == weapon_id:
			weapon_instances.remove_at(index)


func upgrade_weapon(weapon_id: String) -> bool:
	var weapon := get_weapon_instance(weapon_id)
	if weapon == null:
		return false
	var upgraded := weapon.upgrade()
	if upgraded:
		weapon_upgraded.emit(weapon_id, weapon.level)
	return upgraded


func get_weapon_instance(weapon_id: String) -> WeaponInstance:
	for weapon in weapon_instances:
		if weapon.weapon_id == weapon_id:
			return weapon
	return null


func get_weapon_instances() -> Array[WeaponInstance]:
	var result: Array[WeaponInstance] = []
	for weapon in weapon_instances:
		result.append(weapon)
	return result


func get_total_load_cost() -> int:
	var total := 0
	for weapon in weapon_instances:
		total += weapon.get_load_cost()
	return total


func can_add_weapon(weapon_id: String) -> bool:
	return get_total_load_cost() + _get_weapon_load_cost(weapon_id) <= _get_load_capacity()


func get_load_capacity() -> int:
	return _get_load_capacity()


func tick(delta: float) -> void:
	for weapon in weapon_instances:
		weapon.tick(delta)


func _equip_weapon_internal(weapon_id: String, action: String) -> bool:
	if owner_player == null:
		_fail(weapon_id, "missing_owner_player")
		return false
	if not DataRegistry.has_record("weapons", weapon_id):
		_fail(weapon_id, "missing_weapon_config")
		return false
	if not can_add_weapon(weapon_id):
		var reason := "load_capacity_exceeded_on_purchase" if action == "purchase" else "load_capacity_exceeded"
		_fail(weapon_id, reason)
		return false

	var weapon := WeaponInstance.new()
	if not weapon.initialize(weapon_id, owner_player):
		_fail(weapon_id, "initialize_failed")
		return false
	weapon_instances.append(weapon)
	weapon_equipped.emit(weapon_id)
	return true


func _get_weapon_load_cost(weapon_id: String) -> int:
	return int(DataRegistry.get_record("weapons", weapon_id).get("load_cost", 0))


func _get_load_capacity() -> int:
	if owner_player == null:
		return 0
	return int(owner_player.get_stat("load_capacity"))


func _fail(weapon_id: String, reason: String) -> void:
	push_warning("[WeaponLoadout] %s failed: %s" % [weapon_id, reason])
	equip_failed.emit(weapon_id, reason)
