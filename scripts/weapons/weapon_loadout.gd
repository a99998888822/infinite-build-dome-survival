extends Node
class_name WeaponLoadout

signal weapon_equipped(weapon_id: String)
signal weapon_upgraded(weapon_id: String, level: int)
signal equip_failed(weapon_id: String, reason: String)
signal weapon_attachment_changed(weapon_id: String, item_instance_id: String)
signal loadout_changed
signal weapon_fired(weapon_id: String, count: int)

const PROJECTILE_VISUAL_SCALE: float = 1.0
const PROJECTILE_INSTANCE_SCRIPT: Script = preload("res://scripts/weapons/projectile_instance.gd")
const HIT_PARTICLE_BURST_SCRIPT = preload("res://scripts/effects/hit_particle_burst.gd")
const PARTICLE_WORLD_SCRIPT = preload("res://scripts/effects/particle_world.gd")
const ATTACHABLE_ITEM_CATEGORIES: Array[String] = ["enchantment_scroll", "wizard_scroll"]

var owner_player: PlayerController = null
var finance_system: BattleFinanceSystem = null
var weapon_instances: Array[WeaponInstance] = []
var targeting_service: TargetingService = null
var _projectile_sequence: int = 0
var _ritual_domains: Dictionary = {}
var _directed_runtimes: Dictionary = {}
var active_combat_enabled := false
var active_casting := ActiveWeaponCasting.new()

func set_active_combat_enabled(enabled: bool) -> void:
	active_combat_enabled = enabled
	active_casting.loadout = self
	for weapon in weapon_instances:
		weapon.use_active_range_rules = enabled

func cast_weapon(weapon: WeaponInstance, point: Vector2) -> bool:
	return active_combat_enabled and active_casting.cast(weapon, point)


func _ready() -> void:
	add_to_group("weapon_loadout")
	targeting_service = get_node_or_null("TargetingService") as TargetingService
	if targeting_service == null:
		targeting_service = TargetingService.new()
		targeting_service.name = "TargetingService"
		add_child(targeting_service)


func initialize(player: PlayerController, bank: BattleFinanceSystem = null) -> bool:
	active_casting.loadout = self
	for previous in weapon_instances:
		_clear_weapon_runtime(previous)
	active_casting.states.clear()
	owner_player = player
	finance_system = bank
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
	var removed := take_weapon_for_trade(weapon_id)
	if removed != null:
		finish_weapon_removal(removed)


func take_weapon_for_trade(weapon_id: String) -> WeaponInstance:
	var weapon := get_weapon_instance(weapon_id)
	if weapon != null:
		weapon_instances.erase(weapon)
		_clear_weapon_runtime(weapon)
	return weapon


func restore_traded_weapon(weapon: WeaponInstance, index: int) -> void:
	weapon_instances.insert(clampi(index, 0, weapon_instances.size()), weapon)


func finish_weapon_removal(weapon: WeaponInstance) -> void:
	if owner_player != null and owner_player.item_inventory != null:
		for item in weapon.get_attached_item_instances():
			owner_player.item_inventory.clear_equipped_weapon(str(item.get("item_instance_id", "")))
	_notify_loadout_changed()


func _notify_loadout_changed() -> void:
	if owner_player != null:
		var ids: Array[String] = []
		for weapon in weapon_instances:
			ids.append(weapon.weapon_id)
		owner_player.sync_relic_weapon_ids(ids)
	loadout_changed.emit()


func request_manual_attachment(weapon_id: String, item_instance_id: String) -> bool:
	if str(GameGlobal.get_runtime_flag("main_flow_state", "")) != "finance_popup":
		return false
	return attach_item_to_weapon(weapon_id, item_instance_id)


func request_manual_detachment(weapon_id: String, item_instance_id: String) -> Dictionary:
	if str(GameGlobal.get_runtime_flag("main_flow_state", "")) != "finance_popup":
		return {}
	return detach_item_from_weapon(weapon_id, item_instance_id)


func request_manual_attachment_move(weapon_id: String, item_instance_id: String, target_index: int) -> bool:
	if str(GameGlobal.get_runtime_flag("main_flow_state", "")) != "finance_popup":
		return false
	var weapon := get_weapon_instance(weapon_id)
	if weapon == null or not weapon.move_attachment_instance(item_instance_id, target_index):
		return false
	weapon_attachment_changed.emit(weapon_id, item_instance_id)
	return true


func request_manual_attachment_replacement(weapon_id: String, item_instance_id: String, target_index: int) -> bool:
	if str(GameGlobal.get_runtime_flag("main_flow_state", "")) != "finance_popup":
		return false
	if owner_player == null or owner_player.item_inventory == null:
		return false
	var weapon := get_weapon_instance(weapon_id)
	var inventory := owner_player.item_inventory
	var item := inventory.find_item(item_instance_id)
	if weapon == null or item.is_empty() or not str(item.get("equipped_weapon_id", "")).is_empty():
		return false
	if not ATTACHABLE_ITEM_CATEGORIES.has(str(item.get("category", ""))):
		return false
	var replaced := weapon.replace_attachment_instance(target_index, item)
	if replaced.is_empty():
		return false
	if not inventory.replace_equipped_item(weapon_id, str(replaced.get("item_instance_id", "")), item_instance_id):
		weapon.replace_attachment_instance(target_index, replaced)
		return false
	weapon_attachment_changed.emit(weapon_id, item_instance_id)
	return true


func attach_item_to_weapon(weapon_id: String, item_instance_id: String) -> bool:
	if owner_player == null or owner_player.item_inventory == null:
		return false
	var weapon := get_weapon_instance(weapon_id)
	if weapon == null or not weapon.has_available_attachment_slot():
		return false
	var item := owner_player.item_inventory.find_item(item_instance_id)
	if item.is_empty():
		return false
	if not ATTACHABLE_ITEM_CATEGORIES.has(str(item.get("category", ""))):
		return false
	if not weapon.get_attachment_incompatibility(item).is_empty():
		return false
	var equipped_weapon_id := str(item.get("equipped_weapon_id", ""))
	if equipped_weapon_id == weapon_id:
		return false
	var source_weapon: WeaponInstance = null
	var detached_source_item: Dictionary = {}
	if not equipped_weapon_id.is_empty() and equipped_weapon_id != weapon_id:
		source_weapon = get_weapon_instance(equipped_weapon_id)
		if source_weapon != null:
			detached_source_item = source_weapon.detach_item_instance(item_instance_id)
			if detached_source_item.is_empty():
				return false
			weapon_attachment_changed.emit(equipped_weapon_id, "")
		owner_player.item_inventory.clear_equipped_weapon(item_instance_id)
	if not weapon.attach_item_instance(item):
		if source_weapon != null and not detached_source_item.is_empty():
			source_weapon.attach_item_instance(detached_source_item)
			owner_player.item_inventory.set_equipped_weapon(item_instance_id, equipped_weapon_id)
		return false
	if not owner_player.item_inventory.set_equipped_weapon(item_instance_id, weapon_id):
		weapon.detach_item_instance(item_instance_id)
		if source_weapon != null and not detached_source_item.is_empty():
			source_weapon.attach_item_instance(detached_source_item)
			owner_player.item_inventory.set_equipped_weapon(item_instance_id, equipped_weapon_id)
		return false
	weapon_attachment_changed.emit(weapon_id, item_instance_id)
	return true


func detach_item_from_weapon(weapon_id: String, item_instance_id: String = "") -> Dictionary:
	if owner_player == null or owner_player.item_inventory == null:
		return {}
	var weapon := get_weapon_instance(weapon_id)
	if weapon == null:
		return {}
	var detached := weapon.detach_item_instance(item_instance_id)
	if detached.is_empty():
		return {}
	owner_player.item_inventory.clear_equipped_weapon(str(detached.get("item_instance_id", "")))
	weapon_attachment_changed.emit(weapon_id, "")
	return detached


func apply_augmentation(augmentation_id: String) -> bool:
	if weapon_instances.is_empty() or owner_player == null or owner_player.item_inventory == null:
		return false
	for item in owner_player.item_inventory.get_available_items():
		if str(item.get("base_item_id", "")) == augmentation_id:
			return attach_item_to_weapon(weapon_instances[0].weapon_id, str(item.get("item_instance_id", "")))
	return false


func upgrade_weapon(weapon_id: String) -> bool:
	var weapon := get_weapon_instance(weapon_id)
	if weapon == null:
		return false
	var upgraded := weapon.upgrade()
	if upgraded:
		weapon_upgraded.emit(weapon_id, weapon.level)
		_notify_loadout_changed()
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
	if not is_instance_valid(owner_player) or not owner_player.alive or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	if active_combat_enabled:
		active_casting.tick(delta)
		if CombatSettings.wheelchair_mode and str(GameGlobal.get_runtime_flag("main_flow_state", "")) == MainFlowCoordinator.STATE_WAVE_COMBAT:
			active_casting.auto_attack()
		return
	for weapon in weapon_instances:
		if weapon.is_ritual_tome():
			_ensure_ritual_domain(weapon)
		if weapon.is_copper_lamp() or weapon.is_mutant_tentacle():
			_ensure_directed_runtime(weapon)
		weapon.tick(delta)
		if weapon.is_copper_lamp():
			continue
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
	weapon.principal_getter = Callable(self, "get_current_principal")
	weapon.use_active_range_rules = active_combat_enabled
	if owner_player.item_inventory != null:
		for starting_item in owner_player.item_inventory.get_equipped_items_for_weapon(weapon_id):
			if not weapon.attach_item_instance(starting_item):
				owner_player.item_inventory.clear_equipped_weapon(str(starting_item.get("item_instance_id", "")))
	weapon_instances.append(weapon)
	weapon_equipped.emit(weapon_id)
	_notify_loadout_changed()
	return true


func get_current_principal() -> float:
	return float(finance_system.principal) if finance_system != null else 0.0


func _try_attack_with_weapon(weapon: WeaponInstance) -> bool:
	if weapon == null:
		return false
	var previous_context := weapon.attack_context
	weapon.begin_attack()
	var fired := _perform_weapon_attack(weapon)
	if not fired:
		weapon.attack_context = previous_context
	return fired


func _perform_weapon_attack(weapon: WeaponInstance) -> bool:
	if weapon == null or owner_player == null or targeting_service == null:
		return false
	if not owner_player.alive or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return false
	if weapon.is_copper_lamp():
		_ensure_directed_runtime(weapon)
		return false
	if weapon.is_mutant_tentacle():
		var target := DirectedWeaponRuntime.nearest(weapon, weapon.get_attack_range())
		if target == null:
			return false
		var tentacle := _ensure_directed_runtime(weapon) as MutantTentacle
		if not tentacle.try_attack(owner_player.global_position.direction_to(target.global_position)):
			return false
		weapon.volley_index += 1
		weapon.reset_attack_timer()
		weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
		return true
	if weapon.is_earth_hammer():
		for active in get_tree().get_nodes_in_group("earth_hammers"):
			if active.weapon == weapon and active.is_attacking():
				return false
		var target := DirectedWeaponRuntime.nearest(weapon, weapon.get_attack_range())
		var direction := Vector2.RIGHT if owner_player.facing_right else Vector2.LEFT
		if target != null:
			direction = owner_player.global_position.direction_to(target.global_position)
		var hammer := EarthHammer.new()
		_get_visual_root().add_child(hammer)
		hammer.initialize(weapon, direction)
		weapon.volley_index += 1
		weapon.reset_attack_timer()
		weapon_fired.emit(weapon.weapon_id, weapon.get_projectile_angles().size())
		return true
	if weapon.is_camp_dagger():
		for active in get_tree().get_nodes_in_group("camp_daggers"):
			if active.weapon == weapon and active.is_attacking():
				return false
		var target := CampDagger.find_target(weapon)
		if target == null or not target.is_alive():
			return false
		var dagger := CampDagger.new()
		_get_visual_root().add_child(dagger)
		dagger.initialize(weapon, owner_player.global_position.direction_to(target.global_position))
		weapon.volley_index += 1
		weapon.reset_attack_timer()
		weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
		return true
	if weapon.is_nightwatch_spear():
		for active in get_tree().get_nodes_in_group("nightwatch_spears"):
			if active.weapon == weapon and active.is_attacking():
				return false
		var target := targeting_service.find_nearest_enemy_in_radius(owner_player.global_position, weapon.get_attack_range()) as EnemyController
		if target == null or not target.is_alive():
			return false
		var spear := NightwatchSpear.new()
		_get_visual_root().add_child(spear)
		spear.initialize(weapon, owner_player.global_position.direction_to(target.global_position))
		weapon.volley_index += 1
		weapon.reset_attack_timer()
		weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
		return true
	if weapon.is_meteor_flail():
		# Only one attack sequence per instance, including split follow-throughs.
		for active in get_tree().get_nodes_in_group("meteor_flails"):
			if active.weapon == weapon and active.is_swinging():
				return false
		var targeting_radius := StatDefinitions.calculate_attack_radius(float(weapon.weapon_data.get("hit_radius", 0)), weapon.get_stat("area_size"))
		var target := targeting_service.find_nearest_enemy_in_radius(owner_player.global_position, weapon.get_attack_range() + targeting_radius) as EnemyController
		if target == null or not target.is_alive():
			return false
		var flail := MeteorFlail.new()
		_get_visual_root().add_child(flail)
		flail.initialize(weapon, owner_player.global_position.direction_to(target.global_position))
		weapon.volley_index += 1
		weapon.reset_attack_timer()
		weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
		return true
	if weapon.is_ritual_tome():
		var domain := _ensure_ritual_domain(weapon)
		if domain.try_attack():
			weapon.reset_attack_timer()
			weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
			return true
		return false
	if weapon.is_coin_purse():
		return _fire_coins(weapon)
	if weapon.is_grenade():
		return _fire_grenades(weapon)
	var attacked := false
	var damage_events := weapon.calculate_damage_events(false)
	for damage_event in damage_events:
		if damage_event.damage_kind == WeaponInstance.DAMAGE_KIND_RANGED:
			attacked = _apply_ranged_damage(weapon, damage_event) or attacked
	if attacked:
		weapon.reset_attack_timer()
		weapon.volley_index += 1
		weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count"))))
	return attacked


func _ensure_directed_runtime(weapon: WeaponInstance) -> DirectedWeaponRuntime:
	var cached: Variant = _directed_runtimes.get(weapon.instance_id)
	if is_instance_valid(cached) and not cached.cancelled:
		return cached as DirectedWeaponRuntime
	var effect: DirectedWeaponRuntime = CopperLamp.new() if weapon.is_copper_lamp() else MutantTentacle.new()
	_get_visual_root().add_child(effect)
	effect.initialize(weapon)
	if effect is CopperLamp:
		effect.spray_started.connect(func():
			if effect.externally_driven:
				return
			weapon.volley_index += 1
			weapon_fired.emit(weapon.weapon_id, maxi(1, int(weapon.get_stat("projectile_count")))))
	_directed_runtimes[weapon.instance_id] = effect
	return effect


func _ensure_ritual_domain(weapon: WeaponInstance) -> RitualDomain:
	var cached: Variant = _ritual_domains.get(weapon.instance_id)
	if is_instance_valid(cached) and not cached.cancelled:
		return cached as RitualDomain
	var domain := RitualDomain.new()
	_get_visual_root().add_child(domain)
	domain.initialize(weapon)
	_ritual_domains[weapon.instance_id] = domain
	return domain


func _clear_weapon_runtime(weapon: WeaponInstance) -> void:
	if active_combat_enabled:
		active_casting.interrupt(weapon)
	_ritual_domains.erase(weapon.instance_id)
	_directed_runtimes.erase(weapon.instance_id)
	if not is_inside_tree():
		return
	for effect in get_tree().get_nodes_in_group("weapon_runtime_effects"):
		if effect.weapon == weapon or effect.weapon.source_instance_id == weapon.instance_id:
			effect.cancel()


func _fire_coins(weapon: WeaponInstance, aim: Vector2 = Vector2.ZERO) -> bool:
	if aim.is_zero_approx():
		var target := DirectedWeaponRuntime.nearest(weapon, weapon.get_attack_range())
		if target == null:
			return false
		aim = weapon.get_attack_origin().direction_to(target.global_position)
	var shared_hits: Dictionary = {}
	var origin := weapon.get_attack_origin()
	var angles := weapon.get_projectile_angles()
	for angle in angles:
		var direction := aim.normalized().rotated(deg_to_rad(angle))
		var coin := CoinProjectile.new()
		_get_visual_root().add_child(coin)
		coin.initialize(weapon, weapon.calculate_damage_events()[0], origin, direction, shared_hits)
	weapon.volley_index += 1
	weapon.reset_attack_timer()
	weapon_fired.emit(weapon.weapon_id, angles.size())
	return true


func _fire_grenades(weapon: WeaponInstance) -> bool:
	var count := maxi(1, int(weapon.get_stat("projectile_count")))
	var targets := targeting_service.find_cluster_targets(owner_player.global_position, weapon.get_attack_range(), weapon.get_grenade_blast_radius(), count)
	if targets.is_empty():
		return false
	for target in targets:
		var grenade := GrenadeProjectile.new()
		_get_visual_root().add_child(grenade)
		# Each grenade rolls independently, then shares that roll across its victims.
		grenade.initialize(weapon, weapon.calculate_damage_events()[0], owner_player.global_position, target)
	weapon.reset_attack_timer()
	AudioManager.play_sfx_path(str(weapon.weapon_data.get("launch_sfx", "")), 100, "grenade_launch")
	weapon.volley_index += 1
	weapon_fired.emit(weapon.weapon_id, targets.size())
	return true


func _apply_ranged_damage(weapon: WeaponInstance, damage_event: DamageEvent) -> bool:
	var attack_range := weapon.get_attack_range()
	var enemy := targeting_service.find_nearest_enemy_in_radius(owner_player.global_position, attack_range) as EnemyController
	if enemy == null or not enemy.is_alive():
		return false
	if weapon.get_projectile_speed() <= 0.0:
		return false
	return _spawn_projectiles(weapon, damage_event, enemy.global_position, attack_range)


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
	return _spawn_projectile_from(
		weapon,
		damage_event,
		direction,
		attack_range,
		owner_player.global_position,
		{},
		0
	)


func _spawn_projectile_from(
	weapon: WeaponInstance,
	damage_event: DamageEvent,
	direction: Vector2,
	attack_range: float,
	start_position: Vector2,
	ignored_target_ids: Dictionary = {},
	split_depth: int = 0
) -> bool:
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
		start_position,
		direction,
		attack_range,
		texture,
		PROJECTILE_VISUAL_SCALE,
		Callable(self, "_spawn_projectile_from"),
		ignored_target_ids,
		split_depth
	)
	if not initialized:
		projectile.queue_free()
	return initialized




func _spawn_hit_sparks(hit_position: Vector2, burst_direction: Vector2 = Vector2.ZERO) -> void:
	HIT_PARTICLE_BURST_SCRIPT.spawn(_get_visual_root(), hit_position, burst_direction)


func _load_weapon_texture(weapon: WeaponInstance, field_name: String) -> Texture2D:
	if weapon == null:
		return null
	var texture_path := str(weapon.weapon_data.get(field_name, ""))
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	var resource := load(texture_path)
	return resource as Texture2D


func _get_visual_root() -> Node:
	var render_world := PARTICLE_WORLD_SCRIPT.find_render_world(self)
	if render_world != null:
		return render_world
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
