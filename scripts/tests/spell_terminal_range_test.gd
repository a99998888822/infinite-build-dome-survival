extends "res://scripts/tests/pixel_combat_effect_test.gd"
## Actual spell entry points, small physical targets just inside/outside each edge.
const FOOTPRINT = preload("res://scripts/effects/spell_footprint.gd")
const PARAMS = preload("res://scripts/effects/effect_parameter_resolver.gd")

func fixture(id: String, axes: Vector2, bonus: float) -> void:
	await setup([Vector2(axes.x-4,0), Vector2(axes.x+4,0), Vector2(0,axes.y-4), Vector2(0,axes.y+4), Vector2(-axes.x+4,0), Vector2(0,-axes.y-4)])
	for enemy in enemies:
		var collider := enemy.get_node("CollisionShape2D") as CollisionShape2D
		var small := CircleShape2D.new()
		small.radius = 1.0
		collider.shape = small
		collider.position = Vector2.ZERO
		collider.rotation = 0.0
	weapon.runtime_stats.damage_area_size = bonus
	weapon._attached_item_instances = [DataRegistry.get_record("augmentations", id).duplicate(true)]
	await frames()

func check_hits(label: String, mode := "damage") -> void:
	for i in enemies.size():
		var hit := enemies[i].current_hp < 10000
		if mode == "fire": hit = enemies[i].has_status("burning")
		if mode == "control": hit = enemies[i]._knockback_timer > 0
		check(hit == (i in [0,2,4]), label + " physical edge " + str(i))

func check_ground(effect: Node2D, dimensions: Vector2, label: String) -> void:
	check(effect.get_terminal_footprint_axes().is_equal_approx(dimensions), label + " terminal axes")
	check(effect._ground_area.terminal_axes.is_equal_approx(dimensions), label + " rendered terminal axes match collision")

func _run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("review_visual_adaptive", false)
	for bonus in [0.0,100.0]:
		var multiplier: float = 1.0 + bonus * 0.005
		var axes := Vector2(75.3984,49.762944) * multiplier
		await fixture("scroll_water", axes, bonus)
		var water := spawn_effect("water_wave") as WaterWaveEffect
		check_hits("water " + str(bonus))
		check(water.get_terminal_footprint_axes().is_equal_approx(axes), "water uses terminal ellipse")
		water._process(0.55)
		check_hits("water expansion does not repeat damage")

		axes = Vector2.ONE * 94.5 * multiplier
		await fixture("scroll_black_hole", axes, bonus)
		var hole := spawn_effect("black_hole") as BlackHoleEffect
		await frames()
		check_hits("hole " + str(bonus))
		check(is_equal_approx(hole._radius, hole._sphere_radius*3.0), "hole damage radius is three sphere radii")
		check(is_equal_approx(hole._sphere_radius, 31.5*multiplier), "hole keeps reviewed sphere size")

		axes = FOOTPRINT.axes(78.0*multiplier)
		await fixture("scroll_light_sword", axes, bonus)
		var sword := spawn_effect("light_sword") as LightSwordEffect
		check_ground(sword, axes, "sword warning")
		sword._process(0.71)
		check(enemies.all(func(e): return e.current_hp == 10000), "sword still waits for landing")
		sword._process(0.02)
		check_hits("sword " + str(bonus))
		sword._process(0.2)
		check_ground(sword, axes, "sword landing")
		check(enemies[0].current_hp == 9935, "sword dissolving does not apply another hit")

		axes = FOOTPRINT.axes(30.0*multiplier)
		await fixture("scroll_fire", axes, bonus)
		var context := PARAMS.build_weapon_context(weapon,"fire",{"original_damage":100.0,"patch_duration":3.0})
		var fire := FirePatch.spawn(host,Vector2.ZERO,context)
		fire.set_physics_process(false)
		await frames()
		fire._apply_tick_damage()
		check_hits("fire " + str(bonus), "fire")
		check_ground(fire,axes,"fire ground")
		var radius := fire._radius
		fire.expand_from_wind()
		check_ground(fire,FOOTPRINT.axes(radius*1.35),"wind-expanded fire")
		check(fire._collision_shape.shape.get_rect().size.is_equal_approx(fire.get_terminal_footprint_axes()*2), "expanded fire physics uses same ellipse")
		var merged := FirePatch.spawn(host,Vector2(8,0),context)
		check(merged == fire and fire._radius >= radius*1.35, "merge does not shrink expanded fire")
		check_ground(fire,fire.get_terminal_footprint_axes(),"merged fire")

		axes = Vector2(51.2,28.16)*multiplier
		await fixture("scroll_ice",axes,bonus)
		weapon._attached_item_instances[0]["effect_ids"] = ["ice"]
		IceFieldEffect.spawn(host,Vector2.ZERO,weapon,event)
		var ice: IceFieldEffect
		for child in host.get_children():
			if child is IceFieldEffect: ice=child
		ice.set_process(false)
		check_hits("ice " + str(bonus))
		check_ground(ice,axes,"growing ice")
		ice._process(0.65)
		check(is_equal_approx(ice._ground_area.growth,1.0),"ice reaches full ground coverage")
		ice.expand_from_wind()
		check_ground(ice,axes*1.35,"wind-expanded ice")
		check(ice._ground_shape.get_rect().size.is_equal_approx(axes*2.7),"expanded ice physics matches terminal visual")

		axes = FOOTPRINT.axes(30.0*multiplier)
		await fixture("scroll_electric_spark",axes,bonus)
		var spark := spawn_effect("electric_spark") as ElectricSparkEffect
		await frames()
		check_ground(spark,axes,"lightning warning")
		check(is_equal_approx(spark._ring_radius,spark._radius),"warning and strike share one radius")
		check(enemies.all(func(e): return e.current_hp == 10000),"lightning warning does not deal early damage")
		spark._process(0.51)
		await frames()
		check_hits("ground strike " + str(bonus))

		axes = Vector2.ONE*72.0*multiplier
		await fixture("scroll_wind",axes,bonus)
		weapon.runtime_stats.area_size = 200.0
		WindBladeEffect.spawn(host,Vector2.ZERO,Vector2.RIGHT,480,0.46,weapon,event)
		var wind: WindBladeEffect
		for child in host.get_children():
			if child is WindBladeEffect: wind=child
		wind.set_process(false)
		wind._damage_path_enemies()
		check_hits("wind " + str(bonus))
		check(is_equal_approx(wind._hit_radius,72.0*multiplier),"wind circle ignores source attack distance")
		check(wind._speed == 480 and wind._lifetime == 0.46,"wind flight timing unchanged")

		await fixture("scroll_explosion",Vector2.ONE*55.2,bonus)
		ExplosionEffect.spawn(host,Vector2.ZERO,weapon,event)
		await frames()
		check_hits("shockwave " + str(bonus),"control")
		check(enemies.all(func(e): return e.current_hp == 10000),"shockwave remains damage-free")
		var wave := get_tree().get_nodes_in_group("enchantment_block_shockwaves")[-1]
		check(is_equal_approx(wave.radius,55.2),"shockwave keeps its approved fixed control radius")

	# Essential coverage is present even when all optional warning particles are suppressed.
	await fixture("scroll_electric_spark",FOOTPRINT.axes(30),0)
	var suppressed := ElectricSparkEffect.new()
	suppressed._visual_count=0
	host.add_child(suppressed)
	suppressed._radius=30
	suppressed.set_process(false)
	suppressed._sync_warning()
	check(suppressed._warning_sprite == null and suppressed._ground_area != null,"warning ground coverage survives decoration suppression")
	check_ground(suppressed,FOOTPRINT.axes(30),"suppressed warning")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	# Let the audio mixer release stopped WAV playbacks before the test exits.
	await get_tree().create_timer(0.2).timeout
	CampProgression.end_transient_session()
	print("SPELL_TERMINAL_RANGE_TEST checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
