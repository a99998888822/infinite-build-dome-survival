extends "res://scripts/tests/weapon_block_visual_review.gd"
## Real production casts against compact groups. Only the tome equips split.
var hit_batches: Dictionary = {}


func _clip(name: String, caption: String, weapon_id: String, _aim: Vector2, _expected: Array) -> void:
	_clear_units()
	for previous in battle.loadout.weapon_instances.duplicate():
		battle.loadout.remove_weapon(previous.weapon_id)
	if not battle.loadout.equip_weapon(weapon_id):
		push_error("CROWD_REVIEW cannot equip " + weapon_id)
		failures += 1
		return
	var weapon := battle.loadout.get_weapon_instance(weapon_id)
	weapon.runtime_stats["crit_chance"] = 0
	var attachments: Array[String] = []
	if name == "tome":
		var split := battle.player.item_inventory.add_item_from_base("scroll_split", "crowd_visual_review")
		if not weapon.attach_item_instance(split):
			push_error("CROWD_REVIEW cannot attach split")
			failures += 1
			return
		attachments.append("scroll_split")
	var origin := battle.player.global_position
	var aim := origin + Vector2(200, 0)
	var points: Array[Vector2] = []
	match name:
		"grenade":
			var center := Vector2(180, 0)
			aim = origin + center
			for x in [-36, -12, 12, 36]:
				for y in [-24, 0, 24]: points.append(center + Vector2(x, y))
		"tome":
			for x in [75, 125, 175]:
				for y in [-60, -20, 20, 60]: points.append(Vector2(x, y))
		"tentacle":
			for x in [48, 78, 108, 138]:
				for y in [-18, 4, 26]: points.append(Vector2(x, y))
		"hammer":
			aim = origin + Vector2(296, 0)
			for column in [[64, 3], [112, 3], [176, 6], [240, 3], [294, 3]]:
				for index in int(column[1]):
					points.append(Vector2(float(column[0]) + (-6 if index >= 3 else 0), (index % 3 - 1) * 22 + 7))
		"spear":
			for x in [90, 130, 170, 210]:
				for y in [-12, 7, 26]: points.append(Vector2(x, y))
		"flail":
			for radius in [70, 103, 136]:
				for angle in [-45, -15, 15, 45]:
					points.append(AttackFootprint.project(Vector2.RIGHT.rotated(deg_to_rad(angle)) * radius))
		"cannon":
			aim = origin + Vector2(150, 0)
			for angle in [-28, 0, 28]:
				# Place each real collider on a native pellet's path.
				points.append(AttackFootprint.project(Vector2.RIGHT.rotated(deg_to_rad(angle)) * 120) - Vector2(4, -7))
	for point in points:
		_spawn("enemy_echo_bat", origin + point)
		var unit := units[-1]
		var id := unit.get_instance_id()
		unit.damage_received.connect(func(_source: String, _damage: int):
			var frame := Engine.get_physics_frames()
			if not hit_batches.has(frame): hit_batches[frame] = {}
			hit_batches[frame][id] = true)
	title.text = caption + (" · 分裂附魔" if name == "tome" else " · 基础配置")
	receipt.text = "怪群 %d 只 · 等待施放" % points.size()
	await get_tree().create_timer(0.6, true, false, true).timeout
	feedback_events.clear()
	damage_events.clear()
	hit_batches.clear()
	var images: Array[Image] = []
	var samples: Array[Dictionary] = []
	var cast_id := 0
	var cast_count := 0
	clip_start = Time.get_ticks_usec()
	var duration_usec := 3600000 if name == "hammer" or name == "tome" else 3000000
	while Time.get_ticks_usec() - clip_start < duration_usec:
		if cast_count == 0 and Time.get_ticks_usec() - clip_start >= 600000:
			if not battle.loadout.active_casting.cast(weapon, aim):
				push_error("CROWD_REVIEW cast failed " + name)
				failures += 1
			cast_count += 1
			cast_id = DamageEvent.feedback_attack_id(weapon.attack_context)
			receipt.text = "实际武器施放"
		if DisplayServer.get_name() == "headless": await get_tree().process_frame
		else: await RenderingServer.frame_post_draw
		var at := Time.get_ticks_usec()
		if DisplayServer.get_name() != "headless": images.append(get_tree().root.get_texture().get_image())
		var offset := CombatHitFeedback.screen_offset
		samples.append({"time_ms": (at - clip_start) / 1000.0, "paused": get_tree().paused,
			"offset": [offset.x, offset.y], "local_count": CombatHitFeedback.last_local_count})
	var unique: Dictionary = {}
	for row in damage_events: unique[row.enemy] = true
	var max_batch := 0
	for batch in hit_batches.values(): max_batch = maxi(max_batch, batch.size())
	if unique.size() < 3 or feedback_events.is_empty():
		push_error("CROWD_REVIEW insufficient group hits %s unique=%d feedback=%s" % [name, unique.size(), feedback_events])
		failures += 1
	var directory := capture_dir.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	for index in images.size(): images[index].save_jpg(directory.path_join("frame_%04d.jpg" % index), 0.96)
	records.append({"name": name, "weapon": weapon_id, "casts": cast_count, "attack_id": cast_id,
		"enemy_count": points.size(), "enemy_type": "enemy_echo_bat", "stationary_targets": true,
		"attachments": attachments, "range": weapon.get_attack_range(), "hit_radius": weapon.get_hit_radius(),
		"unique_targets": unique.size(), "max_same_physics_frame": max_batch,
		"feedback": feedback_events.duplicate(true), "damage": damage_events.duplicate(true),
		"frames": samples, "duration_ms": samples[-1].time_ms})
	print("WEAPON_CROWD_CLIP ", name, " targets=", unique.size(), " same_frame=", max_batch,
		" feedback=", feedback_events.map(func(row: Dictionary): return row.count))
