extends "res://scripts/tests/pixel_combat_effect_test.gd"
const FIRE = preload("res://scripts/effects/pixel_fire_visual.gd")
const STATUSES := ["wet","light","dark","frozen","slowed","holy_flame","dark_flame"]

func check_mask(enemy: EnemyController, label: String) -> void:
	var expected := 0
	for i in STATUSES.size(): expected |= int(enemy.has_status(STATUSES[i])) << i
	expected |= int(enemy.has_status("burning") and not enemy.has_status("holy_flame") and not enemy.has_status("dark_flame")) << 7
	check(enemy.get_status_visual_mask() == expected,label)

func check_slot(index: int, node: Node2D, label: String) -> void:
	FIRE.clock.flush()
	var expected: Transform2D = node.global_transform * node.parts[0].transform
	var actual: Transform2D = FIRE.clock.batches[43].multimesh.get_instance_transform_2d(index)
	if DisplayServer.get_name() == "headless":
		var b: PackedFloat32Array = FIRE.clock.buffers[43]
		var start := index*16
		actual = Transform2D(Vector2(b[start],b[start+4]),Vector2(b[start+1],b[start+5]),Vector2(b[start+3],b[start+7]))
	check(actual.is_equal_approx(expected),label)

func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2.ZERO])
	var enemy := enemies[0]
	check_mask(enemy,"empty status mask")
	enemy.apply_burning(3,1,"same")
	check_mask(enemy,"ordinary burning mask")
	var revision := enemy.status_visual_revision
	enemy.apply_burning(5,1,"same")
	check(enemy.status_visual_revision==revision,"duration refresh does not invalidate visual state")
	enemy.apply_light(2)
	check_mask(enemy,"holy transition mask")
	enemy.apply_blind(2)
	check_mask(enemy,"dark transition mask")
	enemy.clear_burning()
	enemy.clear_light()
	enemy.clear_blind()
	enemy.apply_wet(2)
	enemy.apply_freeze(1)
	check_mask(enemy,"wet and frozen coexist")
	enemy._frozen_remaining = 0
	check_mask(enemy,"direct status expiry invalidates mask")
	enemy.clear_wet()
	var status = enemy.get_node("EnemyStatusVisual")
	status._process(.1)
	var age: float = status._elapsed
	status._process(.25)
	check(is_equal_approx(status._elapsed,age+.25),"empty-status clock keeps original animation phase")
	await frames()
	var a:=FIRE.new()
	var b:=FIRE.new()
	host.add_child(a)
	host.add_child(b)
	a.position=Vector2(10,20)
	b.position=Vector2(40,60)
	a.setup_single(Vector2(24,36),3)
	b.setup_single(Vector2(18,30),3)
	await frames()
	check_slot(0,a,"initial first slot")
	check_slot(1,b,"initial second slot")
	a.hide()
	check_slot(0,b,"hidden predecessor compacts slots correctly")
	a.show()
	check_slot(0,a,"reshown predecessor restores its data")
	check_slot(1,b,"reshown predecessor restores following slot")
	b.transform = Transform2D(.4,Vector2(1.2,.8),0,Vector2(90,33))
	check_slot(1,b,"moving and rotating instance refreshes transform")
	b.setup_single(Vector2(30,45),3)
	check_slot(1,b,"geometry change refreshes cached dimensions")
	b.modulate=Color(.5,.8,.9,.7)
	FIRE.clock.flush()
	var data: PackedFloat32Array=FIRE.clock.buffers[43]
	check(is_equal_approx(data[24],.5) and is_equal_approx(data[27],.7),"tint change refreshes instance colors")
	a.queue_free()
	await frames()
	check_slot(0,b,"released predecessor does not leave stale data")
	var extra: Array[Node2D] = []
	for i in 40:
		var flame := FIRE.new()
		host.add_child(flame)
		flame.position = Vector2(i * 3, 90)
		flame.setup_single(Vector2(18,30),3)
		extra.append(flame)
	check_slot(0,b,"buffer growth preserves cached predecessor")
	check_slot(40,extra.back(),"buffer growth writes the last new instance")
	for flame in extra: flame.hide()
	b.hide()
	FIRE.clock.flush()
	check(FIRE.clock.batches[43].multimesh.visible_instance_count == 0,"empty layer stops drawing stale instances")
	b.show()
	check_slot(0,b,"empty layer reactivation restores cached data")
	b.layer = 42
	FIRE.clock.flush()
	check(FIRE.clock.batches[43].multimesh.visible_instance_count == 0 and FIRE.clock.batches[42].multimesh.visible_instance_count == 1,"layer change migrates visible instance")
	b.layer = 43
	check_slot(0,b,"returning to previous layer restores its slot")
	host.queue_free()
	await frames()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(.2).timeout
	CampProgression.end_transient_session()
	print("RUNTIME_CACHE_TEST checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
