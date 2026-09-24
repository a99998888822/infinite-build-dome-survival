extends Node2D
class_name GrenadeProjectile

signal detonated(hit_count: int)

const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
const BLAST_LIFETIME := 0.52

var weapon: WeaponInstance
var damage_event: DamageEvent
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var elapsed := 0.0
var flight_seconds := 0.45
var arc_height := 56.0
var blast_radius := 64.0
var exploded := false
var cancelled := false
var impact_batches := 0
var hit_target_ids: Array[int] = []
var split_generation := 0
# Shared read-only snapshot for siblings, avoiding one copy per child.
var excluded_target_ids: Dictionary = {}


func initialize(source: WeaponInstance, event: DamageEvent, start: Vector2, target: Vector2) -> void:
	weapon = source
	damage_event = event
	start_position = start
	target_position = target
	flight_seconds = maxf(0.01, float(weapon.weapon_data.get("grenade_flight_seconds", 0.45)))
	arc_height = maxf(0.0, float(weapon.weapon_data.get("grenade_arc_height", 56)))
	blast_radius = weapon.get_grenade_blast_radius()
	global_position = start
	z_index = 50
	add_to_group("grenade_projectiles")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if cancelled or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	elapsed += delta
	if not exploded:
		global_position = start_position.lerp(target_position, clampf(elapsed / flight_seconds, 0.0, 1.0))
		if elapsed >= flight_seconds:
			_detonate()
	elif elapsed >= flight_seconds + BLAST_LIFETIME:
		queue_free()
	queue_redraw()


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


func _collect_victims() -> Array[EnemyController]:
	var victims: Array[EnemyController] = []
	for node in EnemyRegistry.get_registered_enemies():
		var enemy := node as EnemyController
		if enemy == null or not enemy.is_alive() or not enemy.is_inside_tree():
			continue
		if excluded_target_ids.has(enemy.get_instance_id()):
			continue
		var distance := enemy.global_position.distance_squared_to(target_position)
		if distance > blast_radius * blast_radius:
			continue
		victims.append(enemy)
	return victims


func _detonate() -> void:
	if exploded or cancelled:
		return
	exploded = true
	global_position = target_position
	damage_event.hit_position = target_position
	# Snapshot all contacts before damage or reactions can remove a target.
	var victims := _collect_victims()
	var contacts: Array[DamageEvent] = []
	for enemy in victims:
		hit_target_ids.append(enemy.get_instance_id())
		var contact := damage_event.duplicate_event()
		contact.hit_position = enemy.global_position
		contacts.append(contact)
	var split_profiles: Array[Dictionary] = []
	if split_generation == 0:
		split_profiles = weapon.get_grenade_split_profiles()
	AudioManager.begin_combat_audio()
	for index in victims.size():
		var enemy := victims[index]
		if not is_instance_valid(enemy):
			continue
		impact_batches += 1
		var contact := contacts[index]
		EFFECTS.trigger_weapon_impact(get_parent(), weapon, contact, contact.hit_position, start_position.direction_to(contact.hit_position), enemy)
	for enemy in victims:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		enemy.take_damage(damage_event.damage, damage_event.source_weapon_id, damage_event.is_critical, target_position.direction_to(enemy.global_position))
	if not cancelled and not is_queued_for_deletion() and not split_profiles.is_empty():
		_spawn_split_grenades(contacts, split_profiles)
	AudioManager.play_weapon_hit_sfx(weapon.weapon_id, 150)
	AudioManager.end_combat_audio()
	detonated.emit(hit_target_ids.size())


func _spawn_split_grenades(contacts: Array[DamageEvent], profiles: Array) -> void:
	var excluded: Dictionary = {}
	for target_id in hit_target_ids:
		excluded[target_id] = true
	var reserved := excluded.duplicate()
	excluded.make_read_only()
	var candidates: Array[EnemyController] = []
	for enemy in EnemyRegistry.get_registered_enemies():
		if enemy.is_alive() and enemy.is_inside_tree() and not excluded.has(enemy.get_instance_id()):
			candidates.append(enemy)
	var search_range := weapon.get_attack_range()
	for contact in contacts:
		# Use the captured hit position even if native damage killed the enemy.
		var origin := contact.hit_position
		for profile: Dictionary in profiles:
			var count := int(profile.child_count)
			for index in count:
				var nearest: EnemyController
				var nearest_distance := search_range * search_range
				for enemy in candidates:
					if reserved.has(enemy.get_instance_id()):
						continue
					var distance := origin.distance_squared_to(enemy.global_position)
					if distance < nearest_distance:
						nearest = enemy
						nearest_distance = distance
				var angle := deg_to_rad(float(profile.spread_angle))
				var forward := start_position.direction_to(origin)
				if forward.is_zero_approx():
					forward = Vector2.RIGHT
				var direction := forward.rotated(lerpf(-angle * 0.5, angle * 0.5, float(index) / maxf(count - 1, 1)))
				var landing := origin + direction * minf(blast_radius * 1.5, search_range)
				if nearest != null:
					landing = nearest.global_position
					reserved[nearest.get_instance_id()] = true
				var event := damage_event.duplicate_event()
				var multiplier := float(profile.damage_multiplier)
				event.damage = maxi(1, roundi(event.damage * multiplier))
				event.original_damage = maxi(1, roundi(event.original_damage * multiplier))
				event.element_damage_bonus = maxi(0, roundi(event.element_damage_bonus * multiplier))
				var child := GrenadeProjectile.new()
				get_parent().add_child(child)
				child.initialize(weapon, event, origin, landing)
				child.split_generation = split_generation + 1
				child.excluded_target_ids = excluded
				child.blast_radius = blast_radius * float(profile.radius_multiplier)
				child.flight_seconds = float(profile.flight_seconds)
				child.arc_height = float(profile.arc_height)


func _draw() -> void:
	if cancelled:
		return
	if exploded:
		_draw_explosion()
		return
	var progress := clampf(elapsed / flight_seconds, 0.0, 1.0)
	var landing := target_position - global_position
	# Sparse square pixels replace the smooth gold reticle.
	var mark_radius := lerpf(16.0, 7.0, progress)
	for index in 4:
		_draw_pixel(landing + Vector2.RIGHT.rotated(PI * 0.5 * index) * mark_radius, 2, Color(0.79, 0.64, 0.34, 0.5))
	draw_rect(Rect2(-5, -2, 10, 4), Color(0.02, 0.025, 0.025, 0.55))
	var height := -4.0 * arc_height * progress * (1.0 - progress)
	var center := Vector2(0, height).round()
	_draw_shell(center)


func _draw_shell(center: Vector2) -> void:
	if split_generation > 0:
		draw_set_transform(center, 0, Vector2(0.65, 0.65))
		center = Vector2.ZERO
	draw_rect(Rect2(center + Vector2(-4, -6), Vector2(8, 12)), Color("171e1d"))
	draw_rect(Rect2(center + Vector2(-6, -3), Vector2(12, 7)), Color("171e1d"))
	draw_rect(Rect2(center + Vector2(-4, -4), Vector2(8, 8)), Color("566462"))
	draw_rect(Rect2(center + Vector2(-3, -4), Vector2(4, 3)), Color("b3bda6"))
	draw_rect(Rect2(center + Vector2(-4, 1), Vector2(8, 2)), Color("a78b50"))
	draw_rect(Rect2(center + Vector2(-1, -7), Vector2(3, 2)), Color("d9b775"))
	draw_set_transform(Vector2.ZERO)


func _draw_explosion() -> void:
	var progress := clampf((elapsed - flight_seconds) / BLAST_LIFETIME, 0.0, 1.0)
	var fade := 1.0 - progress
	# Every mark is an axis-aligned square on a two-pixel grid. No smooth
	# outline, translucent filled disk or shared soft-glow burst is drawn.
	for index in 18:
		var angle := TAU * index / 18.0 + sin(index * 2.7) * 0.18
		var radius := blast_radius * (0.12 + progress * 0.46) * (0.7 + 0.3 * sin(index * 1.8))
		var center := Vector2.RIGHT.rotated(angle) * radius + Vector2.UP * progress * 12
		var size := (4.0 + float(index % 3) * 2.0) * (0.7 + progress) * blast_radius / 64.0
		var shade := 0.17 + float(index % 3) * 0.045
		_draw_pixel(center, size + 2, Color(0.065, 0.075, 0.07, fade * 0.82))
		_draw_pixel(center, size, Color(shade, shade * 1.04, shade * 0.91, fade * 0.95))
	for index in 44:
		var angle := TAU * index / 44.0 + sin(index * 4.1) * 0.055
		var reach := 1.0 if index % 4 == 0 else 0.35 + 0.6 * absf(sin(index * 2.3))
		var radius := blast_radius * reach * lerpf(0.35, 1.0, minf(progress * 5, 1))
		var center := Vector2.RIGHT.rotated(angle) * radius
		var size := 2.0 + float(index % 3) * 2.0
		var color := Color("ffc45b") if index % 3 == 0 else Color("cf662d")
		color.a = fade * maxf(0, 1.0 - progress * (0.7 if index % 3 == 0 else 1.0))
		_draw_pixel(center, size * blast_radius / 64.0, color)
	if progress < 0.32:
		for index in 13:
			var center := Vector2(float(index % 5 - 2), float(index / 5 - 1)) * 7.0
			var color := Color("ffdf88") if index % 3 == 0 else Color("ed963d")
			color.a = 1.0 - progress / 0.32
			_draw_pixel(center * blast_radius / 64.0, 6.0 * blast_radius / 64.0, color)


func _draw_pixel(center: Vector2, size: float, color: Color) -> void:
	var side := maxf(2.0, snappedf(size, 2.0))
	var corner := (center - Vector2.ONE * side * 0.5).snapped(Vector2(2, 2))
	draw_rect(Rect2(corner, Vector2.ONE * side), color)
