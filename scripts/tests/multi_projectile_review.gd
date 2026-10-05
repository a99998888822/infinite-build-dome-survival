extends "res://scripts/tests/combat_hud_style_review.gd"
## Real game capture with fixed, durable targets; no replacement attack animation.

const REVIEW_IDS := ["weapon_rentier_purse", "weapon_void_blade", "weapon_mutant_tentacle",
	"weapon_earth_hammer", "weapon_nightwatch_spear", "weapon_plasma_cannon"]
const GAPS := [10.0, 15.0, 20.0, 20.0, 20.0, 20.0]
var review_title: Label
var review_subtitle: Label
var samples: Dictionary = {}
var observations: Array[Dictionary] = []


func _capture_suite() -> void:
	var chosen: Array[WeaponInstance] = []
	var chosen_states: Array[Dictionary] = []
	for id in REVIEW_IDS:
		var old_index := IDS.find(id)
		chosen.append(weapons[old_index])
		chosen_states.append(states[old_index])
		loadout._clear_weapon_runtime(weapons[old_index])
	weapons = chosen
	states = chosen_states
	bar.setup(weapons)
	_apply_bar_padding()
	_cancel_aim()
	(battle.hud as BattleHud)._weapon_damage_meter.hide()
	player.camera_2d.zoom = Vector2.ONE * 1.45
	player.camera_2d.offset = Vector2(100, 0)
	review_title = Label.new()
	review_title.position = Vector2(34, 116)
	review_title.add_theme_font_size_override("font_size", 24)
	review_title.add_theme_color_override("font_color", PAPER)
	review_title.add_theme_constant_override("outline_size", 5)
	ui.add_child(review_title)
	review_subtitle = Label.new()
	review_subtitle.position = Vector2(35, 152)
	review_subtitle.add_theme_font_size_override("font_size", 16)
	review_subtitle.add_theme_color_override("font_color", ICE)
	review_subtitle.add_theme_constant_override("outline_size", 4)
	ui.add_child(review_subtitle)
	await frames(12)
	for index in weapons.size():
		var only := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--review-weapon="):
				only = arg.trim_prefix("--review-weapon=")
		if not only.is_empty() and weapons[index].weapon_id != only:
			continue
		var weapon := weapons[index]
		var baseline := int(weapon.get_stat("projectile_count"))
		_check(baseline == (3 if index == 0 else 1), "default count " + weapon.weapon_id)
		# Check odd/even layouts independently of the sample counts in the GIF.
		for count in [1, 2, 3, 4, 5, 6]:
			weapon.runtime_stats.projectile_count = count
			var angles := weapon.get_projectile_angles()
			_check(angles.size() == count, "exact ray count")
			for n in count:
				_check(is_equal_approx(angles[n], -angles[count - 1 - n]), "odd/even symmetry")
				if n > 0:
					_check(is_equal_approx(angles[n] - angles[n - 1], GAPS[index]), "adjacent gap")
		var counts := [3, 5] if index == 0 else [1, 3, 5]
		samples[weapon.weapon_id] = []
		if not capture_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(capture_dir.path_join(weapon.weapon_id))
		for count in counts:
			loadout._clear_weapon_runtime(weapon)
			await frames(3)
			weapon.runtime_stats.projectile_count = count
			# Remove starting equipment effects so each branch remains legible.
			for item in weapon.get_attached_item_instances():
				weapon.detach_item_instance(str(item.item_instance_id))
			states[index].active = false
			states[index].body = null
			states[index].left = 0
			states[index].action_left = 0
			states[index].total = 3.0
			synthetic_pointer = Vector2(weapon.get_attack_range(), 0)
			var angles := weapon.get_projectile_angles()
			for n in targets.size():
				targets[n].current_hp = 100000
				var at := Vector2(-900, n * 80)
				if n < count:
					at = Vector2.from_angle(deg_to_rad(angles[n])) * weapon.get_attack_range() * 0.83
				targets[n].global_position = player.global_position + at
			var extra := int(count) - baseline
			review_title.text = "%s · %d 投射物%s" % [weapon.weapon_data.display_name, count, "（默认）" if extra == 0 else "（额外 +%d）" % extra]
			review_subtitle.text = "瞄准预览 · 相邻 %d° · 总展开 %d°" % [GAPS[index], (count - 1) * GAPS[index]]
			_select_weapon(index)
			for n in 18:
				await _sample(weapon.weapon_id)
			var before := int(hit_counts.get(weapon.weapon_id, 0))
			_check(_fire(index), "manual cast " + weapon.weapon_id)
			_check(selected == -1 and not indicator.visible, "successful cast hides aim")
			_check(not _fire(index), "same weapon cannot reenter")
			_validate_directions(index, angles)
			review_subtitle.text = "实际攻击 · 同时展开 · 动作速度不随投射物数量变化"
			var start_tick := Engine.get_physics_frames()
			var action_end := -1
			for n in 45:
				await _sample(weapon.weapon_id)
				if action_end < 0 and not states[index].active:
					action_end = Engine.get_physics_frames() - start_tick
					review_subtitle.text = "攻击完成 → 独立冷却 · 箭头方向与真实攻击一致"
			_check(int(hit_counts.get(weapon.weapon_id, 0)) > before, "actual target damage " + weapon.weapon_id)
			_check(action_end >= 0 and states[index].left > 0, "cooldown follows completed action")
			observations.append({"id": weapon.weapon_id, "count": count, "angles": angles, "action_ticks": action_end,
				"hit_events": int(hit_counts.get(weapon.weapon_id, 0)) - before})
		weapon.runtime_stats.projectile_count = baseline
		loadout._clear_weapon_runtime(weapon)
		if not capture_dir.is_empty():
			var partial := FileAccess.open(capture_dir.path_join(weapon.weapon_id + "_report.json"), FileAccess.WRITE)
			partial.store_string(JSON.stringify({"physics_fps": 60, "samples": samples[weapon.weapon_id], "observations": observations.filter(func(entry): return entry.id == weapon.weapon_id), "failures": failures}, "\t"))
	var report := {"real_game_root": true, "physics_fps": 60, "samples": samples, "observations": observations,
		"checks": assertions, "failures": failures, "fixture": "stationary durable targets, trial cooldowns, no random waves"}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("review_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("MULTI_PROJECTILE_REVIEW checks=", assertions, " failures=", failures)
	review_ready = false
	states.clear()
	weapons.clear()
	targets.clear()
	game.queue_free()
	await frames(4)
	for sound in AudioManager.get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)


func _sample(id: String) -> void:
	await frames(3)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var entries: Array = samples[id]
	var name := "%s/frame_%04d.png" % [id, entries.size()]
	var screenshot := get_tree().root.get_texture().get_image()
	_check(screenshot.save_png(capture_dir.path_join(name)) == OK, "capture frame")
	entries.append({"file": name, "tick": Engine.get_physics_frames()})


func _validate_directions(index: int, angles: Array[float]) -> void:
	var weapon := weapons[index]
	var actual: Array[Vector2] = []
	var body: Variant = states[index].body
	if body is MutantTentacle:
		actual.assign(body.directions)
	elif body is EarthHammer:
		_check(body.node_count == 5, "hammer retains five nodes per ray")
		for ray in body.rays:
			actual.append(ray.direction)
	elif body is NightwatchSpear:
		for thrust in body.thrusts:
			actual.append(thrust.direction)
	else:
		for node in loadout._get_visual_root().get_children():
			if node is CoinProjectile and node.weapon == weapon and not node.cancelled:
				actual.append(node.direction)
			elif node is ProjectileInstance and node.weapon == weapon and not node.is_queued_for_deletion():
				actual.append(node.direction)
	_check(actual.size() == angles.size(), "runtime emits N branches, not N squared " + weapon.weapon_id)
	for n in mini(actual.size(), angles.size()):
		_check(actual[n].is_equal_approx(Vector2.from_angle(deg_to_rad(angles[n]))), "runtime/indicator angle agreement")
