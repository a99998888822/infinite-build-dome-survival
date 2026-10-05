extends "res://scripts/tests/multi_projectile_review.gd"
## R02 opts real weapon runtimes into the reviewed tag-based range rules.
## The production battle still uses its existing range mode until migration.

const CASES := [[0, 0], [50, 0], [100, 0], [0, 100], [100, 100]]
const CASE_NAMES := ["基础数值", "攻击距离 +50%", "攻击距离 +100%", "伤害范围 +100%", "两项均 +100%"]
var detail_label: Label
var result_label: Label
var target_hits: Array[int] = []
var target_labels: Array[Label] = []
var case_samples: Array[Dictionary] = []


func _capture_suite() -> void:
	_cancel_aim()
	_apply_bar_padding()
	(battle.hud as BattleHud)._weapon_damage_meter.hide()
	heading_label.get_parent().get_parent().hide()
	for weapon in weapons:
		loadout._clear_weapon_runtime(weapon)
		weapon.use_active_range_rules = true
		for item in weapon.get_attached_item_instances():
			weapon.detach_item_instance(str(item.item_instance_id))
		for stat in ["area_size", "damage_area_size", "crit_chance", "attack_speed"]:
			_set_total(weapon, stat, 0)
		_set_total(weapon, "projectile_count", 3 if weapon.is_coin_purse() else 1)
	for n in targets.size():
		target_hits.append(0)
		targets[n].damage_received.connect(_target_hit.bind(n))
		var label := Label.new()
		label.text = String.chr(65 + n)
		label.position = Vector2(-7, -38)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_constant_override("outline_size", 4)
		targets[n].add_child(label)
		target_labels.append(label)
	review_title = _label(Vector2(32, 104), 23, PAPER)
	review_subtitle = _label(Vector2(33, 138), 17, ICE)
	detail_label = _label(Vector2(33, 166), 15, PAPER)
	result_label = _label(Vector2(33, 575), 16, ICE)
	await frames(4)
	for index in weapons.size():
		var weapon := weapons[index]
		var only := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--review-weapon="):
				only = arg.trim_prefix("--review-weapon=")
		if not only.is_empty() and not weapon.weapon_id in only.split(","):
			continue
		var base_reach := weapon.get_attack_range()
		var base_radius := weapon.get_hit_radius()
		_set_camera(weapon, base_reach)
		var points := _target_points(weapon, base_reach, base_radius)
		for c in CASES.size():
			loadout._clear_weapon_runtime(weapon)
			# Let previous impact visuals and floating numbers expire before the next plate.
			await frames(65)
			states[index].active = false
			states[index].body = null
			states[index].left = 0
			states[index].action_left = 0
			states[index].total = 3.0
			weapon.volley_index = 0
			last_direction = Vector2.RIGHT
			synthetic_pointer = Vector2(5000, 0)
			for n in targets.size():
				target_hits[n] = 0
				targets[n].current_hp = 100000
				targets[n].global_position = player.global_position + points[n]
				target_labels[n].modulate = Color.WHITE
			# Select at baseline, then mutate stats without reselecting the weapon.
			_set_total(weapon, "area_size", 0)
			_set_total(weapon, "damage_area_size", 0)
			selected = index
			indicator.show()
			await frames(2)
			_set_total(weapon, "area_size", CASES[c][0])
			_set_total(weapon, "damage_area_size", CASES[c][1])
			await frames(3)
			_check(selected == index and indicator.weapon == weapon, "live stats retain selected indicator")
			var reach_bonus: float = CASES[c][0] + (CASES[c][1] if weapon.has_combat_tag("扇形") else 0)
			_check(is_equal_approx(weapon.get_attack_range(), base_reach * (1.0 + reach_bonus / 100.0)), "tag-based linear reach scaling")
			_check(is_equal_approx(weapon.get_stat("damage_area_size"), CASES[c][1]), "isolated damage area stat")
			var metrics := _metrics(weapon)
			review_title.text = "%s · %s" % [weapon.weapon_data.display_name, CASE_NAMES[c]]
			review_subtitle.text = "攻击距离 %+d%%  /  伤害范围 %+d%%  · 同一武器固定镜头、固定 A—G 目标" % CASES[c]
			detail_label.text = _metric_text(weapon)
			result_label.text = "范围说明预览（实战按数字键立即释放）" if weapon.is_copper_lamp() or weapon.is_ritual_tome() else "瞄准预览 · 属性变化后实时重绘"
			var key := "%s_c%d" % [weapon.weapon_id, c]
			case_samples = []
			if not capture_dir.is_empty():
				DirAccess.make_dir_recursive_absolute(capture_dir.path_join(key))
			await _range_sample(key, "aim", 1)
			await frames(17)
			var before := int(hit_counts.get(weapon.weapon_id, 0))
			_check(_fire(index), "real runtime cast " + key)
			_check(selected == -1 and not indicator.visible, "cast hides indicator")
			var body: Variant = states[index].body
			if body is RitualDomain:
				body.target_rng.seed = 1005
				var eligible: Array[String] = []
				for n in targets.size():
					if body.contains_enemy(targets[n]):
						eligible.append(String.chr(65 + n))
				metrics["eligible_targets"] = eligible
			var start := Engine.get_physics_frames()
			var stride := 3 if weapon.is_camp_dagger() or weapon.is_meteor_flail() or weapon.is_nightwatch_spear() else 5
			var limit := ceili((weapon.get_attack_range() / 140.0 + 2.0) * 60.0) if weapon.weapon_id == "weapon_plasma_cannon" else 240
			var elapsed := 0
			while elapsed < limit:
				result_label.text = "实际攻击 · %0.2fs · 受击目标：%s" % [elapsed / 60.0, _hit_names()]
				await _range_sample(key, "attack", stride)
				elapsed = Engine.get_physics_frames() - start
				if elapsed >= 18 and not states[index].active and not _projectiles_alive(weapon):
					break
			_check(not states[index].active and not _projectiles_alive(weapon), "complete native action/flight " + key)
			if is_instance_valid(body) and body is RitualDomain:
				_check(body.marks_completed == 3, "tome retains mark budget")
			var hits := int(hit_counts.get(weapon.weapon_id, 0)) - before
			if weapon.is_ritual_tome():
				_check(hits == 3, "three real marks")
			result_label.text = "本次受击：%s · 命中记录 %d 次（固定目标测试，非伤害排行）" % [_hit_names(), hits]
			await _range_sample(key, "result", 12)
			observations.append({"id": weapon.weapon_id, "name": weapon.weapon_data.display_name,
				"tags": weapon.get_combat_tags(),
				"case": c, "case_name": CASE_NAMES[c], "range_bonus": CASES[c][0], "area_bonus": CASES[c][1],
				"metrics": metrics, "hit_events": hits, "target_hits": target_hits.duplicate(),
				"target_positions": points.map(func(p): return [p.x, p.y]), "action_ticks": elapsed,
				"camera_zoom": player.camera_2d.zoom.x, "samples": case_samples.duplicate()})
			print("RANGE_CASE ", key, " hits=", hits, " targets=", _hit_names(), " ticks=", elapsed)
		_set_total(weapon, "area_size", 0)
		_set_total(weapon, "damage_area_size", 0)
		loadout._clear_weapon_runtime(weapon)
		_write_report()
	print("WEAPON_RANGE_REVIEW checks=", assertions, " failures=", failures)
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


func _label(at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	ui.add_child(label)
	return label


func _set_total(weapon: WeaponInstance, stat: String, value: float) -> void:
	weapon.runtime_stats[stat] = value - player.get_stat(stat) + StatDefinitions.get_default_value(stat)


func _set_camera(weapon: WeaponInstance, reach: float) -> void:
	var zoom := minf(1.7, 820.0 / (reach * 2 + 100))
	var screen_x := 270.0
	if weapon.is_grenade() or weapon.is_ritual_tome():
		zoom = minf(1.2, 190.0 / (reach * 2 * AttackFootprint.ELLIPSE_RATIO))
		screen_x = 640
	elif weapon.is_copper_lamp():
		zoom = 0.92
		screen_x = 480
	elif weapon.is_meteor_flail():
		zoom = 0.48
		screen_x = 440
	elif weapon.is_camp_dagger():
		zoom = 0.85
		screen_x = 440
	player.camera_2d.zoom = Vector2.ONE * zoom
	player.camera_2d.offset = Vector2((640 - screen_x) / zoom, -25 / zoom)
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()
	for label in target_labels:
		label.scale = Vector2.ONE / zoom


func _target_points(weapon: WeaponInstance, reach: float, radius: float) -> Array[Vector2]:
	if weapon.is_ritual_tome():
		return [Vector2(reach * 0.6, 0), Vector2(reach * 1.25, 0), Vector2(reach * 1.8, 0),
			Vector2(0, -110), Vector2(0, -190), Vector2(0, 255), Vector2(-reach * 1.3, 0)]
	if weapon.is_grenade():
		return [Vector2(125, 0), Vector2(210, 0), Vector2(300, 0), Vector2(345, 0),
			Vector2(95, -70), Vector2(265, -65), Vector2(280, 55)]
	if weapon.is_copper_lamp():
		return [Vector2(70, 0), Vector2(155, 0), Vector2(210, 0), Vector2(70, -60),
			Vector2(130, -135), Vector2(90, 65), Vector2(140, 120)]
	if weapon.is_camp_dagger() or weapon.is_meteor_flail():
		return [Vector2.from_angle(-0.5) * reach * 0.6, Vector2.from_angle(0.3) * reach * 1.25,
			Vector2.from_angle(-0.3) * reach * 1.8, Vector2.from_angle(1.4) * reach * 0.7,
			Vector2.from_angle(-0.8) * reach * 1.10, Vector2.from_angle(0.9) * reach * 1.7,
			Vector2.from_angle(-1.5) * reach * 0.9]
	var ranged := weapon.weapon_id in ["weapon_void_blade", "weapon_plasma_cannon", "weapon_rentier_purse"]
	var first := reach * 1.7 if ranged else reach * 0.6
	return [Vector2(first, 0), Vector2(reach * 1.25, -radius - 23), Vector2(reach * 1.8, radius + 24),
		Vector2(reach * 0.6, -radius - 23), Vector2(reach * 0.8, radius * 2.0 + 27),
		Vector2(reach * 1.08, -radius - 85 if ranged else 0), Vector2(reach * 1.9, -radius - 40)]


func _metrics(weapon: WeaponInstance) -> Dictionary:
	var m := {"reach": weapon.get_attack_range(), "hit_radius": weapon.get_hit_radius(),
		"projectiles": weapon.get_stat("projectile_count"), "clearance": indicator.clearance}
	if weapon.has_combat_tag("投射物"):
		m["projectile_visual_scale"] = weapon.get_projectile_visual_scale()
	if weapon.is_ritual_tome():
		m["domain_axes"] = [weapon.get_domain_axes().x, weapon.get_domain_axes().y]
	elif weapon.is_grenade():
		m["blast_axes"] = [AttackFootprint.grenade_blast_axes(weapon).x, AttackFootprint.grenade_blast_axes(weapon).y]
		m["landing"] = [AttackFootprint.grenade_landings(weapon, synthetic_pointer)[0].x, 0]
	elif weapon.is_copper_lamp():
		m["cone_degrees"] = weapon.get_lamp_cone_degrees()
		m["spray_seconds"] = weapon.get_lamp_spray_seconds()
	elif weapon.is_camp_dagger():
		m["fan_outer_radius"] = weapon.get_dagger_outer_radius()
		m["blade_sprite_scale"] = [weapon.get_dagger_body_scale().x, weapon.get_dagger_body_scale().y]
	elif weapon.is_meteor_flail():
		m["fan_degrees"] = AttackFootprint.FLAIL_ARC
	else:
		m["indicator_shaft_width"] = indicator.get_arrow_width_parameter() * 0.62 * 0.8 * 2
		if weapon.is_mutant_tentacle():
			m["motion_seconds"] = float(weapon.weapon_data.tentacle_motion_ms) / 1000.0 * 1.5
		if weapon.is_earth_hammer():
			m["last_node_outer_edge"] = weapon.get_attack_range()
	return m


func _metric_text(weapon: WeaponInstance) -> String:
	if weapon.is_ritual_tome():
		return "法阵半轴 %.0f × %.0f · 3 次点名 · 间隔 0.35s" % [weapon.get_domain_axes().x, weapon.get_domain_axes().y]
	if weapon.is_grenade():
		return "射程 %.0f · 爆炸半轴 %.0f × %.0f · 最远落点中心 %.0f" % [weapon.get_attack_range(), AttackFootprint.grenade_blast_axes(weapon).x, AttackFootprint.grenade_blast_axes(weapon).y, AttackFootprint.grenade_landings(weapon, synthetic_pointer)[0].x]
	if weapon.is_copper_lamp():
		return "射程 %.0f · 扩散角 %.0f° · 喷射 %.1fs" % [weapon.get_attack_range(), weapon.get_lamp_cone_degrees(), weapon.get_lamp_spray_seconds()]
	return "攻击距离 %.0f · %s %.0f · 默认 %d 投射物" % [weapon.get_attack_range(), "锤头半径" if weapon.is_meteor_flail() else "命中半径/半宽", weapon.get_hit_radius(), weapon.get_stat("projectile_count")]


func _target_hit(_weapon_id: String, _damage: int, index: int) -> void:
	target_hits[index] += 1
	target_labels[index].modulate = Color("f4c975")


func _hit_names() -> String:
	var names: Array[String] = []
	for n in target_hits.size():
		if target_hits[n] > 0:
			names.append(String.chr(65 + n))
	return "、".join(names) if not names.is_empty() else "无"


func _projectiles_alive(weapon: WeaponInstance) -> bool:
	for node in loadout._get_visual_root().get_children():
		if node is ProjectileInstance and node.weapon == weapon and node.active:
			return true
		if node is CoinProjectile and node.weapon == weapon and not node.cancelled:
			return true
	return false


func _range_sample(key: String, phase: String, stride: int) -> void:
	await frames(stride)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%04d.png" % [key, case_samples.size()]
	_check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(path)) == OK, "capture range frame")
	case_samples.append({"file": path, "tick": Engine.get_physics_frames(), "phase": phase})


func _write_report() -> void:
	if capture_dir.is_empty():
		return
	var file := FileAccess.open(capture_dir.path_join("review_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"revision": "R02", "physics_fps": 60, "real_game_root": true, "checks": assertions,
		"failures": failures, "observations": observations,
		"fixture": "fixed targets/camera per weapon; native runtimes; no attachments; default projectile count; independent active combat review"}, "\t"))
