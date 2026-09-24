extends Node2D

# Asset review prototype; not registered in the production weapon pool.
signal attack_emitted(count: int)
signal target_hit(target_id: int, damage: int, volley_id: int)
const BOOK = preload("res://assets/sprites/weapons/weapon_kunyu_ritual_tome_animated.png")
const COIN = preload("res://assets/sprites/weapons/rentier_coin_spin.png")
const RUNE = preload("res://assets/sprites/weapons/kunyu_domain_rune.png")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const DOMAIN := Vector2(220, 145)
const COIN_SPEED := 380.0
const COIN_RANGE := 280.0
const COIN_COUNT := 3
var player: PlayerController
var kind := "tome"
var elapsed := 0.0
var cooldown := 0.35
var cast_age := 1.0
var volley := 0
var hits: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var domain_layer: Node2D
var equipment_layer: Node2D
var rng := RandomNumberGenerator.new()
var boundary_particles: Array[Dictionary] = []
var outer_particles: Array[Dictionary] = []


func initialize(owner: PlayerController, weapon_kind: String) -> void:
	player = owner
	kind = weapon_kind
	rng.seed = 250925
	_initialize_domain_particles()
	global_position = player.global_position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 45
	domain_layer = PIXEL.layer(self, -8, _draw_domain)
	equipment_layer = PIXEL.layer(self, 40, _draw_equipment)
	equipment_layer.visible = false


func contains_enemy(enemy: EnemyController) -> bool:
	var relative := (enemy.global_position - global_position) / DOMAIN
	return enemy.is_alive() and enemy.is_inside_tree() and relative.length_squared() <= 1.0


func damage_value() -> int:
	var base := 10.0 + player.get_stat("element_damage")
	if kind == "purse":
		base = 4.0 + player.get_stat("ranged_damage") * 0.6 + 0.3 * sqrt(maxf(player.get_stat("finance"), 0))
	return maxi(1, roundi(base * (1.0 + player.get_stat("damage_percent") / 100.0)))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.alive: return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	global_position = player.global_position
	elapsed += delta
	cast_age += delta
	for index in range(hits.size() - 1, -1, -1):
		hits[index].age += delta
		if hits[index].age > 0.40: hits.remove_at(index)
	_tick_coins(delta)
	cooldown -= delta
	if cooldown <= 0:
		if kind == "tome":
			var candidates: Array[EnemyController] = []
			for enemy in EnemyRegistry.get_registered_enemies():
				if contains_enemy(enemy): candidates.append(enemy)
			if not candidates.is_empty():
				var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
				_hit(chosen, damage_value(), volley)
				volley += 1
				cast_age = 0
				attack_emitted.emit(1)
				cooldown = 0.8
		else:
			_fire_coins()
			cooldown = 1.1
	queue_redraw()
	domain_layer.queue_redraw()
	equipment_layer.queue_redraw()


func _hit(enemy: EnemyController, damage: int, volley_id: int) -> void:
	var where := enemy.global_position
	hits.append({"position": where, "age": 0.0, "kind": kind})
	enemy.take_damage(damage, "weapon_kunyu_ritual_tome_preview" if kind == "tome" else "weapon_rentier_purse_preview", false, global_position.direction_to(where))
	target_hit.emit(enemy.get_instance_id(), damage, volley_id)


func _fire_coins() -> void:
	var origin := global_position + Vector2(0, -12)
	var shared_hits: Dictionary = {}
	for index in COIN_COUNT:
		var direction := Vector2.RIGHT.rotated(TAU * index / float(COIN_COUNT) + deg_to_rad(30.0 * volley))
		coins.append({"position": origin, "direction": direction, "distance": 0.0, "age": float(index) * 0.04,
			"damage": damage_value(), "volley": volley, "hits": shared_hits})
	volley += 1
	cast_age = 0
	attack_emitted.emit(COIN_COUNT)


func _tick_coins(delta: float) -> void:
	for index in range(coins.size() - 1, -1, -1):
		var coin: Dictionary = coins[index]
		var from: Vector2 = coin.position
		var step := minf(COIN_SPEED * delta, COIN_RANGE - float(coin.distance))
		var to: Vector2 = from + coin.direction * step
		var nearest: EnemyController
		var nearest_distance := INF
		# Swept contacts avoid frame-dependent tunnelling in this review prototype.
		for enemy in EnemyRegistry.get_registered_enemies():
			if not enemy.is_alive() or coin.hits.has(enemy.get_instance_id()): continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
			if closest.distance_squared_to(enemy.global_position) > 14.0 * 14.0: continue
			var distance := from.distance_squared_to(closest)
			if distance < nearest_distance:
				nearest = enemy
				nearest_distance = distance
		if nearest != null:
			coin.hits[nearest.get_instance_id()] = true
			_hit(nearest, int(coin.damage), int(coin.volley))
			coins.remove_at(index)
			continue
		coin.position = to
		coin.distance += step
		coin.age += delta
		if coin.distance >= COIN_RANGE: coins.remove_at(index)


func _initialize_domain_particles() -> void:
	# Cache visual randomness independently of combat targeting; never reroll per frame.
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.seed = 250926
	boundary_particles.clear()
	outer_particles.clear()
	for index in 48:
		var angle := TAU * (index + 0.5) / 48.0
		var tangent_length := Vector2(-sin(angle) * DOMAIN.x, cos(angle) * DOMAIN.y).length()
		var group_offset := visual_rng.randf_range(-4.0, 4.0)
		for part in 3:
			boundary_particles.append({
				"angle": angle + ((part - 1) * 5.0 + group_offset + visual_rng.randf_range(-1.5, 1.5)) / tangent_length,
				"tangent_length": tangent_length,
				"radial_offset": visual_rng.randf_range(-0.6, 0.6),
				"phase": visual_rng.randf_range(0.0, TAU),
				"speed": visual_rng.randf_range(0.6, 0.95),
				"rotation": visual_rng.randf_range(-PI / 4.0, PI / 4.0)})
	for index in 24:
		outer_particles.append({"angle": TAU * index / 24.0 + visual_rng.randf_range(-0.03, 0.03),
			"phase": visual_rng.randf_range(0.0, TAU), "speed": visual_rng.randf_range(0.6, 0.95),
			"rotation": visual_rng.randf_range(-PI / 4.0, PI / 4.0)})


func _draw_domain_square(point: Vector2, size: float, color: Color, rotation_angle: float) -> void:
	domain_layer.draw_set_transform(point, rotation_angle)
	domain_layer.draw_rect(Rect2(Vector2.ONE * (-size * 0.5), Vector2.ONE * size), color)
	domain_layer.draw_set_transform(Vector2.ZERO)


func _draw_domain() -> void:
	if kind != "tome": return
	# Preserve particle count while gaps visibly expand and contract along the ellipse.
	for particle in boundary_particles:
		var motion := elapsed * float(particle.speed) + float(particle.phase)
		var angle := float(particle.angle) + sin(motion) * 4.0 / float(particle.tangent_length)
		var radius_offset := float(particle.radial_offset) + sin(motion * 0.8) * 0.35
		var point := Vector2(cos(angle), sin(angle)) * (DOMAIN + Vector2.ONE * radius_offset)
		var pulse := 0.5 + 0.5 * sin(elapsed * 2.8 + float(particle.phase))
		var rotation_angle := float(particle.rotation) + sin(motion * 0.85) * deg_to_rad(8.0)
		_draw_domain_square(point, 2.0, Color(0.62, 0.85, 0.98, 0.50 + pulse * 0.28), rotation_angle)
	# Sparse companions retain their slow drift, each with its own phase and angle.
	for particle in outer_particles:
		var motion := elapsed * float(particle.speed) + float(particle.phase)
		var angle := float(particle.angle) + elapsed * 0.045 + sin(motion) * 0.022
		var pulse := 0.5 + 0.5 * sin(elapsed * 2.0 + float(particle.phase))
		var point := Vector2(cos(angle), sin(angle)) * (DOMAIN + Vector2.ONE * (4.0 + pulse * 3.0))
		var rotation_angle := float(particle.rotation) + sin(motion * 0.85) * deg_to_rad(8.0)
		_draw_domain_square(point, 1.0, Color(0.67, 0.86, 0.97, 0.20 + pulse * 0.30), rotation_angle)
	# One centered glyph slowly breathes from almost invisible to 20% opacity.
	# The PNG itself has max alpha 51/255; modulation remains within [0.08, 1].
	var fade := lerpf(0.08, 1.0, (1.0 - cos(TAU * elapsed / 4.4)) * 0.5)
	domain_layer.draw_texture(RUNE, Vector2(-192, -120), Color(1, 1, 1, fade))


func _draw_equipment() -> void:
	if kind != "tome": return
	var frame := 0
	if cast_age < 0.32: frame = mini(3, int(cast_age / 0.08))
	var bob := roundf(sin(elapsed * 3.0) * 1.5)
	var rect := Rect2(18, -37 + bob, 36, 36)
	equipment_layer.draw_texture_rect_region(BOOK, rect, Rect2(frame * 64, 0, 64, 64))


func _draw() -> void:
	for coin in coins:
		var center: Vector2 = coin.position - global_position
		var frame := int(float(coin.age) * 18.0) % 8
		for index in 3:
			if coin.distance < 10 + index * 5: continue
			var point: Vector2 = center - coin.direction * (10 + index * 5)
			draw_rect(Rect2(point.round(), Vector2(2,2)), Color(0.81, 0.64, 0.31, 0.48 - index * 0.12))
		draw_texture_rect_region(COIN, Rect2(center.round() - Vector2(8,8), Vector2(16,16)), Rect2(frame * 16, 0, 16,16))
	for impact in hits:
		var center: Vector2 = impact.position - global_position
		var progress := float(impact.age) / 0.40
		if impact.kind == "tome":
			var color := Color(0.56, 0.86, 0.97, (1.0 - progress) * 0.85)
			if progress < 0.60:
				var span := 14.0 + progress * 8
				PIXEL.path(self, PackedVector2Array([center + Vector2(-span,0), center + Vector2(0,-span),
					center + Vector2(span,0), center + Vector2(0,span), center + Vector2(-span,0)]), color, 1)
				PIXEL.line(self, center + Vector2(-6,-7), center + Vector2(6,7), color, 1)
				PIXEL.line(self, center + Vector2(-6,7), center + Vector2(6,-7), color, 1)
			for index in 8:
				var offset := Vector2.RIGHT.rotated(index * TAU / 8.0) * (10 + progress * 20)
				offset.y -= progress * 16
				draw_rect(Rect2((center + offset).round(), Vector2(2,2)), color)
		else:
			for index in 10:
				var offset := Vector2.RIGHT.rotated(index * 2.4) * (4 + progress * (12 + index % 3 * 5))
				offset.y += progress * progress * 10
				var color := Color(0.94, 0.74, 0.35, 1.0 - progress)
				draw_rect(Rect2((center + offset).round(), Vector2(2,2)), color)
