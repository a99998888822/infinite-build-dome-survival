extends DirectedWeaponRuntime
class_name MutantTentacle

const BODY := preload("res://assets/sprites/weapons/mutant_tentacle/mutant_tentacle.png")
const FRAME_ENDS := [0.30, 0.46, 0.60, 0.64, 0.68, 0.72, 0.76, 0.80, 0.84, 0.87, 0.90, 0.93, 0.96, 1.04, 1.12, 1.24, 1.32, 1.40, 1.50]
var attacking := false
var hit_done := false
var directions: Array[Vector2] = []
var motion_duration := 0.22
var hit_time := 0.10
var split_used := false
var branches: Array[Dictionary] = []


func initialize(source: WeaponInstance) -> void:
	bind_weapon(source, "mutant_tentacles")
	hide()


func try_attack(direction: Vector2) -> bool:
	if attacking:
		return false
	heading = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	attacking = true
	age = 0
	hit_done = false
	split_used = false
	branches.clear()
	directions.clear()
	for angle in weapon.get_projectile_angles():
		directions.append(heading.rotated(deg_to_rad(angle)))
	motion_duration = float(weapon.weapon_data.tentacle_motion_ms) / 1000.0
	hit_time = float(weapon.weapon_data.tentacle_hit_ms) / 1000.0
	if weapon.use_active_range_rules:
		motion_duration *= 1.5
		hit_time *= 1.5
	show()
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	if not ready_to_tick():
		return
	global_position = weapon.get_attack_origin()
	if attacking:
		age += delta / maxf(speed_scale(), 0.001)
		if age >= hit_time and not hit_done:
			hit_done = true
			for direction in directions:
				_contact(direction, 1.0, 1.0, false)
		if age >= motion_duration:
			attacking = false
	for branch in branches:
		branch.age += delta
	branches = branches.filter(func(branch): return float(branch.age) < 0.18)
	visible = attacking or not branches.is_empty()
	queue_redraw()


func _contact(direction: Vector2, reach: float, power: float, child: bool, continuation: int = 0) -> void:
	var event := weapon.calculate_damage_events()[0]
	event.split_child = child
	event.enchantment_start = continuation
	event.damage = maxi(1, roundi(event.damage * power))
	event.elemental_damage_scale *= power
	var contacts := rectangle_contacts(global_position, direction, weapon.get_attack_range() * reach, weapon.get_hit_radius() * reach)
	AudioManager.begin_combat_audio()
	weapon.reset_hit_sfx_state()
	for enemy in contacts:
		deal_hit(enemy, event, direction, child)
	if not child and not contacts.is_empty() and not split_used:
		split_used = true
		for profile in weapon.get_split_profiles():
			for i in int(profile.child_count):
				var angle := lerpf(-float(profile.spread_angle), float(profile.spread_angle), float(i + 1) / float(int(profile.child_count) + 1))
				var side := direction.rotated(deg_to_rad(angle))
				branches.append({"direction": side, "age": 0.0})
				_contact(side, 0.65, float(profile.damage_multiplier), true, int(profile.enchantment_start))
	AudioManager.end_combat_audio()


func pose_index() -> int:
	if not attacking:
		return 0
	var t := age
	# Retiming both sides of contact preserves the full authored animation and
	# keeps the flattened impact pose aligned with damage at any configured speed.
	if t < hit_time:
		t = t / hit_time * 0.88
	else:
		t = 0.88 + (t - hit_time) / (motion_duration - hit_time) * (1.42 - 0.88)
	t = t if t < 0.84 else 0.84 + (t - 0.84) * 3.0 if t < 0.88 else t + 0.08
	for i in FRAME_ENDS.size():
		if t < float(FRAME_ENDS[i]) - 0.00001:
			return i
	return 0


func _draw() -> void:
	if cancelled:
		return
	var dimensions := Vector2(weapon.get_attack_range() / 140.0, weapon.get_hit_radius() / 20.0)
	if attacking:
		for direction in directions:
			draw_atlas(BODY, 128, pose_index(), Vector2(14, 103), direction * 20 + Vector2(0, 5), direction.angle(), dimensions)
	for branch in branches:
		var direction: Vector2 = branch.direction
		draw_atlas(BODY, 128, 13, Vector2(14, 103), direction * 20 + Vector2(0, 5), direction.angle(), dimensions * 0.65, 1 - float(branch.age) / 0.18)
	if attacking:
		var since_hit := age - hit_time
		if since_hit >= 0 and since_hit < 0.16:
			for direction in directions:
				draw_set_transform(Vector2.ZERO, direction.angle(), dimensions)
				for i in 6:
					draw_rect(Rect2(40 + i * 15, 8 - (i % 3) * 3 - since_hit * 30, 2, 2), Color("939b83"))
			draw_set_transform(Vector2.ZERO)
