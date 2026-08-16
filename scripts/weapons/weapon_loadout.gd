extends Node
class_name WeaponLoadout

signal weapon_equipped(weapon_id: String)
signal weapon_upgraded(weapon_id: String, level: int)
signal equip_failed(weapon_id: String, reason: String)

const ATTACK_EFFECT_SECONDS: float = 0.18
const PROJECTILE_VISUAL_SCALE: float = 0.32
const EFFECT_MIN_SCALE: float = 0.35
const PROJECTILE_INSTANCE_SCRIPT: Script = preload("res://scripts/weapons/projectile_instance.gd")

var owner_player: PlayerController = null
var weapon_instances: Array[WeaponInstance] = []
var targeting_service: TargetingService = null
var _projectile_sequence: int = 0


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


func has_weapon(weapon_id: String) -> bool:
	return get_weapon_instance(weapon_id) != null


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
		if weapon.can_attack():
			_try_attack_with_weapon(weapon)


func _equip_weapon_internal(weapon_id: String, action: String) -> bool:
	if owner_player == null:
		_fail(weapon_id, "missing_owner_player")
		return false
	if not DataRegistry.has_record("weapons", weapon_id):
		_fail(weapon_id, "missing_weapon_config")
		return false
	if has_weapon(weapon_id):
		_fail(weapon_id, "weapon_already_owned")
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


func _try_attack_with_weapon(weapon: WeaponInstance) -> bool:
	if weapon == null or owner_player == null or targeting_service == null:
		return false
	var attacked := false
	var damage_events := weapon.calculate_damage_events(false)
	for damage_event in damage_events:
		match damage_event.damage_kind:
			WeaponInstance.DAMAGE_KIND_MELEE:
				attacked = _apply_melee_damage(weapon, damage_event) or attacked
			WeaponInstance.DAMAGE_KIND_RANGED:
				attacked = _apply_ranged_damage(weapon, damage_event) or attacked
	if attacked:
		weapon.reset_attack_timer()
	return attacked


func _apply_melee_damage(weapon: WeaponInstance, damage_event: DamageEvent) -> bool:
	var attack_range := weapon.get_attack_range()
	var hit_enemies := targeting_service.find_enemies_in_radius(owner_player.global_position, attack_range)
	var damaged := false
	var visual_direction := Vector2.RIGHT if owner_player == null or owner_player.facing_right else Vector2.LEFT
	for enemy_node in hit_enemies:
		var enemy := enemy_node as EnemyController
		if enemy == null or not enemy.is_alive():
			continue
		visual_direction = owner_player.global_position.direction_to(enemy.global_position)
		enemy.take_damage(damage_event.damage, damage_event.source_weapon_id)
		damaged = true
	if damaged:
		weapon.play_attack_hit_sfx()
		_spawn_attack_effect_visual(weapon, owner_player.global_position, attack_range, visual_direction)
	return damaged


func _apply_ranged_damage(weapon: WeaponInstance, damage_event: DamageEvent) -> bool:
	var attack_range := weapon.get_attack_range()
	var enemy := targeting_service.find_nearest_enemy_in_radius(owner_player.global_position, attack_range) as EnemyController
	if enemy == null or not enemy.is_alive():
		return false
	if weapon.get_projectile_speed() > 0.0:
		return _spawn_projectiles(weapon, damage_event, enemy.global_position, attack_range)
	enemy.take_damage(damage_event.damage, damage_event.source_weapon_id)
	weapon.play_attack_hit_sfx()
	return true


func _spawn_projectiles(weapon: WeaponInstance, damage_event: DamageEvent, target_position: Vector2, attack_range: float) -> bool:
	var base_direction := owner_player.global_position.direction_to(target_position)
	if base_direction.is_zero_approx():
		base_direction = Vector2.RIGHT if owner_player.facing_right else Vector2.LEFT
	var spawned := false
	for angle_degrees in weapon.get_projectile_angles():
		var direction := base_direction.rotated(deg_to_rad(angle_degrees))
		spawned = _spawn_projectile(weapon, damage_event, direction, attack_range) or spawned
	return spawned


func _spawn_projectile(weapon: WeaponInstance, damage_event: DamageEvent, direction: Vector2, attack_range: float) -> bool:
	if owner_player == null:
		return false
	var texture := _load_weapon_texture(weapon, "projectile_texture")
	var projectile := PROJECTILE_INSTANCE_SCRIPT.new() as ProjectileInstance
	if projectile == null:
		return false
	_projectile_sequence += 1
	var projectile_id := "%s_%d" % [weapon.weapon_id, _projectile_sequence]
	projectile.name = "Projectile_%s" % projectile_id
	projectile.top_level = true
	projectile.z_index = 50
	_get_visual_root().add_child(projectile)
	var initialized := projectile.initialize(
		weapon,
		damage_event.duplicate_event(),
		projectile_id,
		owner_player.global_position,
		direction,
		attack_range,
		texture,
		PROJECTILE_VISUAL_SCALE
	)
	if not initialized:
		projectile.queue_free()
	return initialized


func _spawn_attack_effect_visual(weapon: WeaponInstance, center_position: Vector2, hit_radius: float, direction: Vector2) -> void:
	var texture := _load_weapon_texture(weapon, "attack_effect_texture")
	if texture == null:
		return
	var visual := Sprite2D.new()
	visual.texture = texture
	visual.centered = true
	visual.top_level = true
	visual.z_index = 45
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var anchor_offset := 0.0 if _weapon_has_tag(weapon, "area") else minf(hit_radius * 0.35, 36.0)
	visual.global_position = center_position + safe_direction * anchor_offset
	visual.rotation = safe_direction.angle()
	var texture_size := maxf(texture.get_size().x, 1.0)
	var target_scale := maxf(EFFECT_MIN_SCALE, hit_radius * 2.0 / texture_size)
	visual.scale = Vector2.ONE * target_scale * 0.72
	_get_visual_root().add_child(visual)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ONE * target_scale, ATTACK_EFFECT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 0.0, ATTACK_EFFECT_SECONDS).set_delay(ATTACK_EFFECT_SECONDS * 0.35)
	tween.set_parallel(false)
	tween.tween_callback(Callable(visual, "queue_free"))


func _load_weapon_texture(weapon: WeaponInstance, field_name: String) -> Texture2D:
	if weapon == null:
		return null
	var texture_path := str(weapon.weapon_data.get(field_name, ""))
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	var resource := load(texture_path)
	return resource as Texture2D


func _weapon_has_tag(weapon: WeaponInstance, tag: String) -> bool:
	if weapon == null:
		return false
	var tags: Variant = weapon.weapon_data.get("tags", [])
	if not (tags is Array):
		return false
	for raw_tag in tags:
		if str(raw_tag) == tag:
			return true
	return false


func _get_visual_root() -> Node:
	var parent := get_parent()
	return parent if parent != null else self


func _get_weapon_load_cost(weapon_id: String) -> int:
	return int(DataRegistry.get_record("weapons", weapon_id).get("load_cost", 0))


func _get_load_capacity() -> int:
	if owner_player == null:
		return 0
	return int(owner_player.get_stat("load_capacity"))


func _fail(weapon_id: String, reason: String) -> void:
	push_warning("[WeaponLoadout] %s failed: %s" % [weapon_id, reason])
	equip_failed.emit(weapon_id, reason)
