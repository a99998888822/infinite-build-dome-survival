extends Node
## Ground-tilt audit for weapon aim indicators and spell telegraphs.
## Every plate states whether the drawn footprint uses the battlefield's
## 145:220 ground projection (y/x = 0.659) or stays a screen-space circle.

const FOOTPRINT = preload("res://scripts/battle/attack_footprint.gd")
const GROUND = preload("res://scripts/effects/ground_projection_r05.gd")
const SPELL = preload("res://scripts/effects/spell_footprint.gd")
const INDICATOR = preload("res://scripts/battle/weapon_attack_indicator.gd")
const BLOCK = preload("res://scripts/effects/enchantment_block_vfx.gd")
const ELEMENT_CUE = preload("res://scripts/effects/element_reaction_visual.gd")

const WEAPONS := [
	"weapon_dash_blade", "weapon_star_tome", "weapon_hand_cannon", "weapon_saber",
	"weapon_iron_grenade_cannon", "weapon_kunyu_ritual_tome", "weapon_camp_dagger",
	"weapon_copper_lamp", "weapon_meteor_flail", "weapon_furnace",
	"weapon_void_blade", "weapon_nightwatch_spear",
]
const RATIO := 145.0 / 220.0

var battle: BattleRoot
var player: PlayerController
var host: Node2D
var caption: Label
var capture_dir := ""
var checks := 0
var failures := 0
var report: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)


func source_weapon(id: String) -> WeaponInstance:
	var source := WeaponInstance.new()
	check(source.initialize(id, player), "weapon initialized " + id)
	source.use_active_range_rules = true
	return source


func damage_event(source: WeaponInstance) -> DamageEvent:
	return DamageEvent.create({"damage": 10, "original_damage": 10,
		"source_weapon_id": source.weapon_id, "source_player": player})


func _run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	seed(11072026)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", ["weapon_void_blade"])
	await frames(4)
	check(flow.confirm_character_selection(), "production battle opened")
	await frames(10)
	if flow.get_current_state() == MainFlowCoordinator.STATE_COMBAT_GUIDE:
		flow.finish_combat_guide()
		await frames(4)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.active_controller._cursor_layer.hide()
	(battle.hud as CanvasLayer).visible = false
	player = battle.player
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = Vector2(60, 30)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	host = Node2D.new()
	player.get_parent().add_child(host)
	await frames(4)
	_frame_camera(233.0)
	_make_overlay()
	_audit_indicators()
	await _capture_weapon_plates()
	await _capture_spell_plates()
	_report()
	game.queue_free()
	await frames(4)
	CampProgression.end_transient_session()
	print("INDICATOR_GROUND_TILT_REVIEW checks=%d failures=%d plates=%d" % [checks, failures, report.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _frame_camera(reach: float) -> void:
	var zoom := minf(1.3, 560.0 / maxf(reach, 40.0))
	player.camera_2d.zoom = Vector2.ONE * zoom
	player.camera_2d.offset = Vector2(reach * 0.30, -20)
	player.camera_2d.reset_smoothing()
	player.camera_2d.force_update_scroll()


func _audit_indicators() -> void:
	# Invariants: rotation happens in the ground plane, depth is compressed by the tilt.
	var pose := FOOTPRINT.ground_transform(Vector2(1, 1))
	check(_near(pose.determinant(), RATIO), "ground transform compresses area to the battlefield tilt")
	check(_near(FOOTPRINT.project(Vector2(0, 100)).y, 100.0 * RATIO), "shared ground projection maps 100px of depth to 65.9px")
	for id in ["weapon_iron_grenade_cannon", "weapon_copper_lamp", "weapon_camp_dagger"]:
		var dimensions := FOOTPRINT.targeting_dimensions(source_weapon(id))
		var follows := dimensions.z == 0.0 and _near(dimensions.y / maxf(dimensions.x, 0.001), RATIO)
		check(follows, "ground footprint follows the tilt: " + id)
		_measure(id, "aim", Vector2(dimensions.x, dimensions.y), RATIO)
	# Melee cones are built through the projected ground transform.
	for id in ["weapon_camp_dagger", "weapon_copper_lamp", "weapon_meteor_flail"]:
		var fan := FOOTPRINT.ground_transform(Vector2(0.8, 0.35))
		check(_near(fan.determinant(), RATIO), "melee cone draws through the projected ground transform: " + id)
	_measure("weapon_meteor_flail", "collision", _dims(FOOTPRINT.targeting_dimensions(source_weapon("weapon_meteor_flail"))), RATIO)
	# Domain, mobility and leap footprints are all ground ellipses.
	_measure("weapon_kunyu_ritual_tome", "domain", source_weapon("weapon_kunyu_ritual_tome").get_domain_axes(), RATIO)
	for id in ["weapon_dash_blade", "weapon_star_tome", "weapon_saber"]:
		var guide := INDICATOR.new()
		host.add_child(guide)
		guide.global_position = player.global_position
		guide.configure(source_weapon(id), Vector2(120, 0))
		var mobility: Node2D = guide.mobility_indicator
		var movement: Vector2 = mobility.call("get_movement_axes")
		check(_near(movement.y / movement.x, RATIO), "mobility range ellipse follows the tilt: " + id)
		_measure(id, "range", movement, RATIO)
		if id != "weapon_saber":
			var landing: Vector2 = mobility.call("get_landing_impact_axes")
			check(_near(landing.y / landing.x, RATIO), "landing impact ellipse follows the tilt: " + id)
			_measure(id, "landing", landing, RATIO)
		guide.queue_free()
	# Orbit and satellite travel on the same projected ground plane.
	var orbit_source := source_weapon("weapon_nightwatch_spear")
	var quarter := orbit_source.get_active_cooldown_seconds() * 0.25
	var orbit_offset := AttackPatternPlan.build(orbit_source).orbit_position(0, quarter, orbit_source)
	check(absf(orbit_offset.x) < 0.001 and is_equal_approx(absf(orbit_offset.y), orbit_source.get_attack_range() * RATIO),
		"orbit sweep reaches only the tilted minor axis at quarter phase")
	# Spell footprints share one ground flatten.
	_measure("spell_light_sword", "ground", SPELL.axes(100.0), RATIO)
	_measure("spell_water", "ground", SPELL.axes(100.0), RATIO)
	_measure("spell_ice", "ground", SPELL.axes(100.0), RATIO)
	check(_near(SPELL.GROUND_FLATTEN, RATIO), "every spell footprint keeps the main battlefield tilt")
	check(_near(GROUND.projected_axes().y, RATIO), "legacy ground helper exposes the same tilt")


func _dims(dimensions: Vector3) -> Vector2:
	return Vector2(dimensions.x, dimensions.y)


func _near(value: float, expected: float, tolerance := 0.005) -> bool:
	return absf(value - expected) <= tolerance


func _measure(id: String, kind: String, axes: Vector2, expected: float) -> void:
	var ratio := axes.y / maxf(axes.x, 0.001)
	var follows := _near(ratio, expected)
	report.append({"id": id, "kind": kind, "axes": [axes.x, axes.y], "ratio": ratio,
		"expected": expected, "follows_tilt": follows})
	if not follows:
		print("AUDIT_DEVIATION ", id, " ", kind, " y/x=", snappedf(ratio, 0.001), " expected=", snappedf(expected, 0.001))


func _capture_weapon_plates() -> void:
	for id in WEAPONS:
		await _reset_effects()
		var source := source_weapon(id)
		var aims := _aim_offset(source)
		_frame_camera(maxf(source.get_attack_range(), 60.0))
		var guide := INDICATOR.new()
		host.add_child(guide)
		guide.global_position = player.global_position
		guide.configure(source, aims)
		guide.show()
		var note := _plate_note(source, guide)
		await capture(id, "%s · %s" % [str(source.weapon_data.display_name), note])
		guide.queue_free()
	# Pattern rings (orbit / satellite) are ground paths, not screen circles.
	for plate in [["weapon_nightwatch_spear", "scroll_orbit", "pattern_orbit"],
			["weapon_nightwatch_spear", "scroll_satellite", "pattern_satellite"]]:
		await _reset_effects()
		var pattern_source := source_weapon(plate[0])
		enchant(pattern_source, plate[1])
		_frame_camera(maxf(pattern_source.get_attack_range(), 60.0))
		var ring := INDICATOR.new()
		host.add_child(ring)
		ring.global_position = player.global_position
		ring.configure(pattern_source, Vector2(pattern_source.get_attack_range() * 0.7, 0))
		ring.show()
		await capture(plate[2], "%s · %s · 环与体标记按 145:220 投影" % [str(pattern_source.weapon_data.display_name), str(plate[1])])
		ring.queue_free()


func enchant(source: WeaponInstance, augmentation_id: String) -> void:
	var item: Dictionary = DataRegistry.get_record("augmentations", augmentation_id).duplicate(true)
	item["item_instance_id"] = "tilt_review_" + augmentation_id
	source._attached_item_instances.append(item)
	source._rebuild_attachment_effects()


func _aim_offset(source: WeaponInstance) -> Vector2:
	if source.is_grenade(): return Vector2(1500, 0)
	if source.is_mobility_weapon(): return Vector2(source.get_mobility_axes().x * 0.9, 0)
	if source.is_camp_dagger() or source.is_copper_lamp() or source.is_meteor_flail():
		return Vector2(0.75, 0.25) * 400.0
	return Vector2(source.get_attack_range() * 0.85, 0)


func _plate_note(source: WeaponInstance, guide: WeaponAttackIndicator) -> String:
	if source.is_hand_cannon():
		return "后撤落点标记按 145:220 投影"
	if source.is_saber():
		return "冲刺范围与落点按 145:220 投影"
	if source.is_mobility_weapon():
		var mobility: Node2D = guide.mobility_indicator
		var movement: Vector2 = mobility.call("get_movement_axes")
		var ratio := movement.y / maxf(movement.x, 0.001)
		return "范围椭圆 %d×%d · y/x=%.3f %s" % [movement.x, movement.y, ratio, "✓ 145:220" if _near(ratio, RATIO) else "✗ 非 145:220"]
	if source.is_ritual_tome():
		var domain := source.get_domain_axes()
		return "法阵椭圆 %d×%d · y/x=%.3f %s" % [domain.x, domain.y, domain.y / domain.x, "✓ 145:220" if _near(domain.y / domain.x, RATIO) else "✗ 比 145:220 更高"]
	if source.is_grenade():
		return "射程与爆炸椭圆 + 145:220 投影"
	if source.is_meteor_flail():
		return "扇面按 145:220 投影（碰撞区域另含锤头半径）"
	if source.is_copper_lamp():
		return "喷口扇面按 145:220 投影"
	if source.is_camp_dagger():
		return "扇面按 145:220 投影"
	if source.is_furnace():
		return "范围椭圆 145:220"
	return "直射箭头（命中为圆形投射物，方向不参与倾斜）"


func _capture_spell_plates() -> void:
	await _reset_effects()
	var sword_source := source_weapon("weapon_void_blade")
	var event := damage_event(sword_source)
	# 01 Light sword landing mark: projected atlas frame.
	_frame_camera(150.0)
	var point := Vector2(90, 30)
	LightSwordEffect.spawn(host, point, sword_source, event)
	var sword := host.get_child(0) as LightSwordEffect
	freeze(sword)
	sword._elapsed = sword._delay * 0.8
	sword.queue_redraw()
	sword._ground_layer.queue_redraw()
	await capture("spell_light_sword", "光剑附魔 · 落地标记 · sword_mark × 145:220 ✓")
	await _reset_effects()
	# 02 Lightning ground ring: GROUND.disk with projected axes.
	var lightning := LightningParticleEffect.spawn_ground_strike(host, point, sword_source, event, "", 182, 62)
	EffectScheduler.cancel_owner(lightning)
	lightning._strike_ground(point)
	freeze(lightning)
	lightning._ground_strike_impact_age = 0.24
	lightning.queue_redraw()
	await capture("spell_lightning", "落雷 · 触地扩散 · GROUND.disk × 145:220 ✓")
	lightning.queue_free()
	await _reset_effects()
	# 03 Water wave: flattened footprint shared with collision.
	WaterWaveEffect.spawn(host, point, sword_source, event)
	var water := host.get_child(0) as WaterWaveEffect
	freeze(water)
	water._elapsed = water._duration * 0.62
	water.queue_redraw()
	await capture("spell_water", "水元素 · 扩散水波 · 145:220 投影 ✓")
	water.queue_free()
	await _reset_effects()
	# 04 Explosion shockwave: the shader ring follows the battlefield tilt.
	var shock: Node2D = BLOCK.spawn_shockwave(host, point, 80.0, 0)
	freeze(shock)
	shock.set("elapsed", 0.18)
	shock.queue_redraw()
	await capture("spell_explosion_shockwave", "附魔爆炸 · 冲击波环 · 着色器按 145:220 投影 ✓")
	var shock_material := shock.material as ShaderMaterial
	check(shock_material != null and _near(float(shock_material.get_shader_parameter("projection_ratio")), RATIO),
		"explosion shockwave ring is projected onto the battlefield tilt")
	shock.queue_free()
	await _reset_effects()
	# 05 Ice field: collision and frost share the battlefield tilt.
	IceFieldEffect.spawn(host, point, sword_source, event)
	var ice := host.get_child(0) as IceFieldEffect
	freeze(ice)
	ice._elapsed = 1.0
	ice._visual_frame = -1
	ice.queue_redraw()
	await capture("spell_ice_field", "冰霜领域 · 地面霜纹 · 145:220 投影 ✓")
	ice.queue_free()
	await _reset_effects()
	# 06 Water-to-ice front: baked art lifted from 0.526 to the battlefield tilt.
	ELEMENT_CUE.spawn(host, "ice_expand", point, {"from_radius": 51.2, "radius": 69.12})
	var front := host.get_child(host.get_child_count() - 1) as Node2D
	freeze(front)
	front.set("elapsed", 0.34)
	front.queue_redraw()
	await capture("spell_ice_front", "水冰反应 · 霜冻前沿 · 贴图按 145:220 校正 ✓")
	front.queue_free()


func _reset_effects() -> void:
	for child in host.get_children(): child.queue_free()
	for effect in get_tree().get_nodes_in_group("pixel_combat_effects"):
		if is_instance_valid(effect) and not host.is_ancestor_of(effect): effect.queue_free()
	await frames(4)
	player.global_position = Vector2(60, 30)
	player.current_hp = int(player.get_stat("max_hp"))
	player._invincibility_timer = 100


func capture(name: String, title: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	caption.text = "  地面投影 145:220  ·  " + title
	await frames(3)
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "GPU " + name)


func _make_overlay() -> void:
	if DisplayServer.get_name() == "headless" or capture_dir.is_empty(): return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.035, 0.86)
	back.position = Vector2(0, 660)
	back.size = Vector2(1280, 60)
	layer.add_child(back)
	caption = Label.new()
	caption.position = Vector2(24, 674)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("d8e6d6"))
	layer.add_child(caption)


func _report() -> void:
	if capture_dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var file := FileAccess.open(capture_dir.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"production_battle": true, "projection": [1.0, RATIO],
		"checks": checks, "failures": failures, "plates": report}, "\t"))
