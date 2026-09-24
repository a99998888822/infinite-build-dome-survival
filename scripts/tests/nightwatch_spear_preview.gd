extends Node2D

# Review prototype: deliberately not registered in weapons.json or the shop.
signal thrust_started(target_id: int)
signal thrust_finished(hit_count: int)
signal impact_registered(target_id: int, child: bool)
signal shard_launched(shard: ProjectileInstance)

const SPEAR = preload("res://assets/sprites/weapons/weapon_nightwatch_spear.png")
const SHARD = preload("res://scripts/tests/nightwatch_spear_shard_preview.gd")
const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
const PARAMETERS = preload("res://scripts/effects/effect_parameter_resolver.gd")
const BASE_DAMAGE := 14
const REACH := 220.0
const WIDTH := 28.0
const INTERVAL := 1.10
const WINDUP := 0.10
const EXTEND := 0.12
const RECOVER := 0.16
# Keep the complete silhouette ahead of the player, even at full windup.
const SPEAR_DRAW_LENGTH := 144.0
const SPEAR_SOURCE_RECT := Rect2(4, 0, 238, 28)
var owner_player: PlayerController
var diagnostic := false
var enabled := true
var cooldown := 0.35
var age := -1.0
var aim := Vector2.RIGHT
var hits: Dictionary = {}
var damage := BASE_DAMAGE
var completed_thrusts := 0
var sparks: Array[Dictionary] = []
var enchantment_weapon: WeaponInstance
var contacts: Array[Dictionary] = []
var split_spawned := false


func initialize(player: PlayerController) -> void:
	owner_player = player
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 40
	global_position = player.global_position


func configure_enchantments(ids: Array[String]) -> void:
	# A review-only adapter to the existing production enchantment pipeline.
	enchantment_weapon = WeaponInstance.new()
	enchantment_weapon.weapon_id = "weapon_nightwatch_spear_preview"
	enchantment_weapon.owner_player = owner_player
	enchantment_weapon.weapon_data = {"tags": ["melee"], "hit_radius": 6.0, "attack_range": REACH, "projectile_speed": 420.0}
	for id in ids:
		var item: Dictionary = DataRegistry.get_record("augmentations", id).duplicate(true)
		item["item_instance_id"] = "spear_review_" + id
		enchantment_weapon._attached_item_instances.append(item)
	enchantment_weapon._rebuild_attachment_effects()


func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(owner_player) or not owner_player.alive:
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	global_position = owner_player.global_position
	for index in range(sparks.size() - 1, -1, -1):
		sparks[index].age += delta
		if sparks[index].age > 0.20:
			sparks.remove_at(index)
	cooldown = maxf(0.0, cooldown - delta)
	if age < 0:
		if cooldown <= 0:
			var nearest := find_nearest()
			if nearest != null:
				aim = global_position.direction_to(nearest.global_position)
				if aim.is_zero_approx(): aim = Vector2.RIGHT
				rotation = aim.angle()
				age = 0
				hits.clear()
				contacts.clear()
				split_spawned = false
				damage = maxi(1, roundi((BASE_DAMAGE + owner_player.get_stat("melee_damage")) * (1.0 + owner_player.get_stat("damage_percent") / 100.0)))
				cooldown = INTERVAL
				thrust_started.emit(nearest.get_instance_id())
	else:
		var previous := age
		age += delta
		if age >= WINDUP and previous < WINDUP + EXTEND:
			_damage_line(lerpf(156.0, REACH, ease(clampf((age - WINDUP) / EXTEND, 0, 1), 0.6)))
		if age >= WINDUP + EXTEND and not split_spawned:
			split_spawned = true
			_spawn_split_shards()
		if age >= WINDUP + EXTEND + RECOVER:
			completed_thrusts += 1
			age = -1
			thrust_finished.emit(hits.size())
	queue_redraw()


func find_nearest() -> EnemyController:
	var nearest: EnemyController
	var distance := REACH * REACH
	for enemy in EnemyRegistry.get_registered_enemies():
		if not enemy.is_alive() or not enemy.is_inside_tree(): continue
		var candidate := global_position.distance_squared_to(enemy.global_position)
		if candidate <= distance:
			distance = candidate
			nearest = enemy
	return nearest


func _damage_line(length: float) -> void:
	for enemy in EnemyRegistry.get_registered_enemies().duplicate():
		if not enemy.is_alive() or hits.has(enemy.get_instance_id()): continue
		var relative: Vector2 = enemy.global_position - global_position
		var along := relative.dot(aim)
		var across := absf(relative.cross(aim))
		if along < 0 or along > length or across > WIDTH * 0.5: continue
		hits[enemy.get_instance_id()] = true
		sparks.append({"position": enemy.global_position, "age": 0.0})
		var event := DamageEvent.create({"damage": damage, "original_damage": damage,
			"element_damage_bonus": maxi(0, roundi(owner_player.get_stat("element_damage"))),
			"source_player": owner_player, "source_weapon_id": "weapon_nightwatch_spear_preview",
			"damage_kind": "melee", "hit_position": enemy.global_position})
		contacts.append({"event": event, "position": enemy.global_position})
		if enchantment_weapon != null:
			EFFECTS.trigger_weapon_impact(get_parent(), enchantment_weapon, event, enemy.global_position, aim, enemy)
		enemy.take_damage(damage, "weapon_nightwatch_spear_preview", false, aim)
		impact_registered.emit(enemy.get_instance_id(), false)


func _spawn_split_shards() -> void:
	if enchantment_weapon == null or not enchantment_weapon.has_effect("split"): return
	# Wait for the full thrust so every primary victim can be excluded from children.
	var reserved := hits.duplicate()
	var plans: Array[Dictionary] = []
	for contact in contacts:
		var origin: Vector2 = contact.position
		for item in enchantment_weapon.get_effect_instances("split"):
			var context := PARAMETERS.build_weapon_context(enchantment_weapon, "split", {}, str(item.get("item_instance_id", "")))
			var count := clampi(roundi(context.get_resolved_parameter("child_count", 2.0)), 1, 8)
			var spread := clampf(context.get_resolved_parameter("spread_angle", 36.0), 0, 150)
			for index in count:
				var nearest: EnemyController
				var distance := REACH * REACH
				for enemy in EnemyRegistry.get_registered_enemies():
					if not enemy.is_alive() or not enemy.is_inside_tree() or reserved.has(enemy.get_instance_id()): continue
					var relative: Vector2 = enemy.global_position - origin
					if relative.dot(aim) <= 0: continue
					if relative.length_squared() < distance:
						nearest = enemy
						distance = relative.length_squared()
				var direction := aim.rotated(deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(index) / maxf(count - 1, 1))))
				var target_id := 0
				if nearest != null:
					direction = origin.direction_to(nearest.global_position)
					target_id = nearest.get_instance_id()
					reserved[target_id] = true
				var event: DamageEvent = contact.event.duplicate_event()
				var multiplier := maxf(context.get_resolved_parameter("damage_multiplier", 0.6), 0)
				event.damage = maxi(1, roundi(event.damage * multiplier))
				event.original_damage = maxi(1, roundi(event.original_damage * multiplier))
				event.element_damage_bonus = maxi(0, roundi(event.element_damage_bonus * multiplier))
				plans.append({"origin": origin, "direction": direction, "target": target_id, "event": event})
	for plan in plans:
		var ignored := reserved.duplicate()
		ignored.erase(plan.target)
		var shard = SHARD.new()
		get_parent().add_child(shard)
		shard.accent = _element_color()
		shard.initialize(enchantment_weapon, plan.event, "spear_shard_%d_%d" % [completed_thrusts, shard.get_instance_id()],
			plan.origin + plan.direction * 8, plan.direction, REACH, null, 1.0, Callable(), ignored, 1)
		shard.shard_hit.connect(func(target_id: int): impact_registered.emit(target_id, true))
		shard_launched.emit(shard)


func _element_color() -> Color:
	if enchantment_weapon != null:
		if enchantment_weapon.has_effect("fire"): return Color("ffad60")
		if enchantment_weapon.has_effect("ice"): return Color("82d9f0")
		if enchantment_weapon.has_effect("lightning"): return Color("c6b9ff")
	return Color("a9bfba")


func _draw() -> void:
	if not enabled: return
	if age >= 0:
		_draw_thrust()
	for spark in sparks:
		var center: Vector2 = (spark.position - global_position).rotated(-rotation)
		var progress := float(spark.age) / 0.20
		for index in 6:
			var offset := Vector2.RIGHT.rotated(TAU * index / 6.0) * (3 + progress * 15)
			var color := Color(0.83, 0.89, 0.78, 1.0 - progress)
			draw_rect(Rect2((center + offset).snapped(Vector2(2, 2)), Vector2(2, 2)), color)


func _draw_thrust() -> void:
	var push := 0.0
	if age >= 0 and age < WINDUP:
		push = lerpf(0, -16, age / WINDUP)
	elif age >= WINDUP and age < WINDUP + EXTEND:
		push = lerpf(-16, 48, ease((age - WINDUP) / EXTEND, 0.6))
	elif age >= WINDUP + EXTEND:
		push = lerpf(48, 0, clampf((age - WINDUP - EXTEND) / RECOVER, 0, 1))
	var tip := minf(172 + push, REACH)
	if diagnostic:
		draw_rect(Rect2(0, -WIDTH * 0.5, REACH, WIDTH), Color(0.34, 0.73, 0.65, 0.10))
		for x in range(0, int(REACH), 8):
			draw_rect(Rect2(x, -WIDTH * 0.5, 4, 1), Color(0.54, 0.89, 0.77, 0.8))
			draw_rect(Rect2(x, WIDTH * 0.5, 4, 1), Color(0.54, 0.89, 0.77, 0.8))
		draw_rect(Rect2(REACH, -WIDTH * 0.5, 1, WIDTH), Color(0.54, 0.89, 0.77, 0.8))
	if age >= WINDUP and age <= WINDUP + EXTEND + 0.08:
		var fade := 1.0 - clampf((age - WINDUP - EXTEND) / 0.08, 0, 1)
		for index in 22:
			var x := tip - index * 7.0
			if x < 20: break
			var alpha := fade * (1.0 - float(index) / 22.0)
			draw_rect(Rect2(x, -7 - index % 2 * 2, 4, 2), Color(0.67, 0.83, 0.80, alpha * 0.55))
			draw_rect(Rect2(x - 3, 7 + index % 3, 3, 2), Color(0.38, 0.65, 0.66, alpha * 0.45))
	# Anchor the visible tip to the existing reach curve (156 -> 220).
	# The tail stays at least 12 pixels in front of the player's origin.
	draw_texture_rect_region(SPEAR, Rect2(roundf(tip) - SPEAR_DRAW_LENGTH, -13, SPEAR_DRAW_LENGTH, 28), SPEAR_SOURCE_RECT)
	if enchantment_weapon != null and _element_color() != Color("a9bfba"):
		var accent := _element_color()
		for index in 8:
			var x := roundf(tip) - 3 - index * 5
			var y := -5 - (index + int(age * 30)) % 3 * 2
			draw_rect(Rect2(x, y, 3, 2), Color(accent, 0.85))
			draw_rect(Rect2(x - 2, -y, 2, 2), Color(accent, 0.65))
