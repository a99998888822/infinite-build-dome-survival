extends Node2D
class_name RitualDomain

signal target_hit(target_id: int, damage: int, child: bool)

const RUNE = preload("res://assets/sprites/weapons/kunyu_domain_rune.png")
const PIXEL = preload("res://scripts/effects/pixel_effect_draw.gd")
const EFFECTS = preload("res://scripts/effects/combat_effect_world.gd")
const HIT = preload("res://scripts/weapons/ritual_coin_hit.gd")
const DOMAIN := Vector2(220, 145)

var weapon: WeaponInstance
var elapsed := 0.0
var cancelled := false
var domain_layer: Node2D
var boundary_particles: Array[Dictionary] = []
var outer_particles: Array[Dictionary] = []
var target_rng := RandomNumberGenerator.new()


func initialize(source: WeaponInstance) -> void:
	weapon = source
	global_position = weapon.owner_player.global_position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target_rng.randomize()
	_initialize_domain_particles()
	domain_layer = PIXEL.layer(self, -8, _draw_domain)
	domain_layer.scale = weapon.get_domain_axes() / DOMAIN
	add_to_group("weapon_runtime_effects")
	add_to_group("ritual_domains")


func _physics_process(delta: float) -> void:
	if cancelled:
		return
	if not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive:
		cancel()
		return
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return
	global_position = weapon.owner_player.global_position
	domain_layer.scale = weapon.get_domain_axes() / DOMAIN
	elapsed += delta
	domain_layer.queue_redraw()


func contains_enemy(enemy: EnemyController) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_alive() or not enemy.is_inside_tree():
		return false
	var relative := (enemy.global_position - weapon.owner_player.global_position) / weapon.get_domain_axes().max(Vector2.ONE)
	return relative.length_squared() <= 1.0


func try_attack() -> bool:
	if cancelled or not is_instance_valid(weapon.owner_player) or not weapon.owner_player.alive or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return false
	var candidates: Array[EnemyController] = []
	for enemy in EnemyRegistry.get_registered_enemies():
		if contains_enemy(enemy):
			candidates.append(enemy)
	# Shuffle once, then reserve all primary targets before allocating split hits.
	for index in range(candidates.size() - 1, 0, -1):
		var other := target_rng.randi_range(0, index)
		var swap := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	var count := mini(maxi(1, int(weapon.get_stat("projectile_count"))), candidates.size())
	if count == 0:
		return false
	var primaries: Array[Dictionary] = []
	for index in count:
		primaries.append({"enemy": candidates.pop_back(), "event": weapon.calculate_damage_events()[0]})
	for primary in primaries:
		_apply_hit(primary.enemy, primary.event, false)
		for profile in weapon.get_split_profiles():
			for _index in int(profile.child_count):
				while not candidates.is_empty() and not contains_enemy(candidates.back()):
					candidates.pop_back()
				if candidates.is_empty():
					break
				var event: DamageEvent = primary.event.duplicate_event()
				var multiplier := float(profile.damage_multiplier)
				event.damage = maxi(1, roundi(event.damage * multiplier))
				event.original_damage = maxi(1, roundi(event.original_damage * multiplier))
				event.element_damage_bonus = maxi(0, roundi(event.element_damage_bonus * multiplier))
				_apply_hit(candidates.pop_back(), event, true)
	return true


func _apply_hit(enemy: EnemyController, event: DamageEvent, child: bool) -> void:
	if not contains_enemy(enemy):
		return
	var position_snapshot := enemy.global_position
	var direction := weapon.owner_player.global_position.direction_to(position_snapshot)
	event.hit_position = position_snapshot
	# Dispatch before native lethal damage so attached effects retain their contact.
	EFFECTS.trigger_weapon_impact(get_parent(), weapon, event, position_snapshot, direction, enemy)
	enemy.take_damage(event.damage, event.source_weapon_id, event.is_critical, direction)
	HIT.spawn(get_parent(), weapon, position_snapshot, true)
	weapon.play_attack_hit_sfx()
	target_hit.emit(enemy.get_instance_id(), event.damage, child)


func cancel() -> void:
	cancelled = true
	hide()
	set_physics_process(false)
	queue_free()


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


