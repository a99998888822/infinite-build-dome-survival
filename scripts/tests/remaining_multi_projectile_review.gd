extends "res://scripts/tests/multi_projectile_review.gd"
## Full, real-time attacks in the independent active-combat review scene.

const REMAINING_IDS := ["weapon_camp_dagger", "weapon_meteor_flail", "weapon_copper_lamp",
	"weapon_iron_grenade_cannon", "weapon_kunyu_ritual_tome"]
var sample_stride := 3


func _capture_suite() -> void:
	var chosen: Array[WeaponInstance] = []
	var chosen_states: Array[Dictionary] = []
	for id in REMAINING_IDS:
		chosen.append(weapons[IDS.find(id)])
		chosen_states.append(states[IDS.find(id)])
	for weapon in weapons:
		loadout._clear_weapon_runtime(weapon)
	weapons = chosen
	states = chosen_states
	bar.setup(weapons)
	_apply_bar_padding()
	_cancel_aim()
	(battle.hud as BattleHud)._weapon_damage_meter.hide()
	player.camera_2d.zoom = Vector2.ONE * 1.7
	player.camera_2d.offset = Vector2(65, 0)
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
		var only_count := -1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--review-weapon="):
				only = arg.trim_prefix("--review-weapon=")
			if arg.begins_with("--review-count="):
				only_count = arg.trim_prefix("--review-count=").to_int()
		var weapon := weapons[index]
		if not only.is_empty() and not weapon.weapon_id in only.split(","):
			continue
		var baseline := int(weapon.get_stat("projectile_count"))
		_check(baseline == 1, "default projectile count " + weapon.weapon_id)
		samples[weapon.weapon_id] = []
		if not capture_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(capture_dir.path_join(weapon.weapon_id))
		for item in weapon.get_attached_item_instances():
			weapon.detach_item_instance(str(item.item_instance_id))
		weapon.runtime_stats.crit_chance = 0
		for count in [1, 3, 5]:
			if only_count > 0 and count != only_count:
				continue
			loadout._clear_weapon_runtime(weapon)
			await frames(3)
			weapon.runtime_stats.projectile_count = count
			states[index].active = false
			states[index].body = null
			states[index].left = 0
			states[index].action_left = 0
			states[index].total = 3.0
			last_direction = Vector2.RIGHT
			sample_stride = 2 if weapon.is_camp_dagger() else (4 if weapon.is_copper_lamp() else 3)
			player.camera_2d.zoom = Vector2.ONE * (1.45 if weapon.is_grenade() or weapon.is_ritual_tome() else 1.7)
			synthetic_pointer = Vector2(weapon.get_attack_range(), 0)
			if weapon.is_grenade():
				synthetic_pointer = Vector2(weapon.get_attack_range() * 0.6, 0) if count < 5 else Vector2(5000, 0)
			_place_review_targets(weapon, count)
			review_title.text = "%s · %d 投射物（额外 +%d）" % [weapon.weapon_data.display_name, count, count - 1]
			if weapon.is_copper_lamp():
				review_subtitle.text = "范围说明 · 单束 60° · 喷射 %.1f 秒 · 按数字键直接释放" % weapon.get_lamp_spray_seconds()
				# Explanatory range plate only; this instant-cast weapon has no aim phase.
				indicator.global_position = player.global_position
				indicator.configure(weapon, Vector2.RIGHT)
				indicator.show()
			elif weapon.is_ritual_tome():
				review_subtitle.text = "按数字键展开随身法阵 · 本次点名 %d 次 · 间隔 %.2f 秒" % [count + 2, RitualDomain.MARK_INTERVAL]
			else:
				_select_weapon(index)
				review_subtitle.text = "瞄准预览 · 共用一个扇面 · 连击期间不压缩动作" if not weapon.is_grenade() else "瞄准预览 · 一个射程椭圆 + %d 个落点椭圆%s" % [count, " · 鼠标越界时落点被限制在最大距离" if count == 5 else ""]
			for n in 12:
				await _sample(weapon.weapon_id)
			var before := int(hit_counts.get(weapon.weapon_id, 0))
			if weapon.is_copper_lamp() or weapon.is_ritual_tome():
				_select_weapon(index)
				_check(states[index].active, "numeric key instantly casts " + weapon.weapon_id)
			else:
				_check(_fire(index), "manual cast " + weapon.weapon_id)
			_check(selected == -1 and not indicator.visible, "successful release exits aim")
			_check(not _fire(index), "same weapon cannot reenter while active")
			var body: Variant = states[index].body
			var expected := _expected_duration(index, count)
			var start_tick := Engine.get_physics_frames()
			var action_end := -1
			var marks_done := 0
			for n in 400:
				if weapon.is_copper_lamp():
					review_subtitle.text = "持续喷射 · 单束 60° · %.1f / %.1f 秒 · 结束后冷却" % [minf((Engine.get_physics_frames() - start_tick) / 60.0, expected), expected]
				elif weapon.is_ritual_tome():
					if is_instance_valid(body):
						marks_done = body.marks_completed
					review_subtitle.text = "随身法阵 · 已点名 %d / %d 次%s" % [marks_done, count + 2, " · 同一个存活敌人可重复点名" if count == 3 else ""]
				elif weapon.is_grenade():
					review_subtitle.text = "实际攻击 · %d 枚同时抛射 · 每个椭圆独立爆炸" % count
				elif weapon.is_camp_dagger():
					var current := 1
					if is_instance_valid(body):
						for i in body.cuts.size():
							if body.age >= float(body.cuts[i].start):
								current = i + 1
					review_subtitle.text = "无间隔连续斩击 · 第 %d / %d 刀 · 只在首刀起手、末刀收刀" % [current, count]
				else:
					var unit: float = expected / count
					var current := mini(count, int((Engine.get_physics_frames() - start_tick) / 60.0 / unit) + 1)
					review_subtitle.text = "完整连续挥击 · 第 %d / %d 次 · 每次 %.2f 秒 · 最后收招后冷却" % [current, count, unit]
				await _sample(weapon.weapon_id)
				if not states[index].active:
					action_end = Engine.get_physics_frames() - start_tick
					break
			_check(action_end >= 0 and states[index].left > 0, "full action completes before cooldown")
			_check(absf(action_end - expected * 60) <= sample_stride + 3, "observed action duration matches full sequence " + weapon.weapon_id)
			var damage_hits := int(hit_counts.get(weapon.weapon_id, 0)) - before
			_check(damage_hits > 0, "real enemies take damage " + weapon.weapon_id)
			if weapon.is_ritual_tome():
				_check(damage_hits == count + 2, "one native hit per mark, exact budget")
			review_subtitle.text = "全部攻击完成 → 独立冷却 · 本段为原速实机录制"
			for n in 12:
				await _sample(weapon.weapon_id)
			observations.append({"id": weapon.weapon_id, "count": count, "action_ticks": action_end,
				"expected_seconds": expected, "tolerance_ticks": sample_stride + 3, "hit_events": damage_hits})
		weapon.runtime_stats.projectile_count = baseline
		loadout._clear_weapon_runtime(weapon)
		if not capture_dir.is_empty():
			var partial := FileAccess.open(capture_dir.path_join(weapon.weapon_id + "_report.json"), FileAccess.WRITE)
			partial.store_string(JSON.stringify({"observations": observations, "failures": failures}, "\t"))
	var report := {"real_game_root": true, "physics_fps": 60, "samples": samples, "observations": observations,
		"checks": assertions, "failures": failures, "fixture": "independent art review, real weapon runtimes, stationary durable targets, trial cooldowns"}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("review_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("REMAINING_MULTI_PROJECTILE_REVIEW checks=", assertions, " failures=", failures)
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


func _place_review_targets(weapon: WeaponInstance, count: int) -> void:
	for n in targets.size():
		targets[n].current_hp = 100000
		var at := Vector2(-900, n * 80)
		if weapon.is_grenade():
			var landings := AttackFootprint.grenade_landings(weapon, synthetic_pointer)
			if n < landings.size():
				at = landings[n]
		elif weapon.is_ritual_tome():
			if n < (1 if count == 3 else 3):
				at = [Vector2(90, -65), Vector2(130, 45), Vector2(-95, 55)][n]
		elif n < 3:
			var distance := 64.0 if weapon.is_camp_dagger() else (85.0 if weapon.is_copper_lamp() else 112.0)
			var angle := (n - 1) * (16.0 if weapon.is_copper_lamp() else 40.0)
			at = Vector2.from_angle(deg_to_rad(angle)) * distance
		targets[n].global_position = player.global_position + at


func _expected_duration(index: int, count: int) -> float:
	var weapon := weapons[index]
	var body: Variant = states[index].body
	if body is CampDagger:
		_check(body.cuts.size() == count, "dagger exact sequential cut count")
		return body.cut_end(body.cuts[-1]) * body.time_scale
	if body is MeteorFlail:
		_check(body.swings.size() == count, "flail exact sequential swing count")
		return body.sequence_duration() * body.time_scale
	if body is CopperLamp:
		return weapon.get_lamp_spray_seconds()
	if body is RitualDomain:
		return 0.22 + (count + 1) * RitualDomain.MARK_INTERVAL + RitualDomain.MARK_RECOVERY
	return float(weapon.weapon_data.get("grenade_flight_seconds", 0.45)) + GrenadeProjectile.BLAST_LIFETIME


func _sample(id: String) -> void:
	await frames(sample_stride)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var entries: Array = samples[id]
	var name := "%s/frame_%04d.png" % [id, entries.size()]
	_check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name)) == OK, "capture frame")
	entries.append({"file": name, "tick": Engine.get_physics_frames()})
