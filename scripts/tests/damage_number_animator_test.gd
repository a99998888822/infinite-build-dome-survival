extends Node
const ANIMATOR = preload("res://scripts/effects/damage_number_animator.gd")
const LEGACY = preload("res://scripts/tests/fixtures/legacy_damage_number_animation.gd")
var checks := 0
var failures: Array[String] = []
var capture_dir := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("NUMBER_ANIMATOR " + message)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func label(parent: Node, critical: bool) -> CombatDamageNumber:
	var result := EnemyController._acquire_damage_number(parent, "123456", EnemyController._get_damage_number_theme(123456, critical))
	result.scale = Vector2.ONE * (0.92 if critical else 0.84)
	result.modulate.a = 0.0
	result.size = EnemyController.DAMAGE_NUMBER_SIZE
	result.global_position = Vector2(130, 100)
	return result

func _run() -> void:
	CampProgression.begin_transient_session()
	for critical in [false, true]:
		for steps in [[0.01, 0.04, 0.05, 0.04, 0.16, 0.01, 0.31, 0.1, 0.14, 0.14], [0.033, 0.2, 0.6, 0.3], [1.2]]:
			var host := Node2D.new()
			add_child(host)
			var old := label(host, critical)
			var updated := label(host, critical)
			var tween := LEGACY.animate(old, critical)
			tween.pause()
			var manager := ANIMATOR.for_parent(host)
			EnemyController.active_damage_numbers += 1
			manager.animate(updated, critical)
			manager._clock.pause()
			for dt in steps:
				tween.custom_step(dt)
				manager.advance(dt)
				check(old.global_position.distance_to(updated.global_position) < 0.001, "same trajectory critical=%s dt=%s" % [critical, dt])
				check(old.scale.distance_to(updated.scale) < 0.00001, "same scale curve")
				check(absf(old.modulate.a - updated.modulate.a) < 0.00001, "same opacity")
			check(EnemyController.active_damage_numbers == 1, "release deferred until end of frame")
			manager._recycle_finished()
			check(EnemyController.active_damage_numbers == 0 and not updated.visible, "one release on completion")
			tween.kill()
			host.queue_free()
			await frames()
	await _staggered()
	await _lifecycle()
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless": await _pixels()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("NUMBER_ANIMATOR checks=", checks, " failures=", failures.size())
	FileAccess.open("res://artifacts/reports/number_animator_test.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _staggered() -> void:
	var host := Node2D.new()
	add_child(host)
	var manager := ANIMATOR.for_parent(host)
	var pairs: Array = []
	for step in 12:
		if step % 3 == 0:
			for critical in [true, false]:
				var old := label(host, critical)
				var updated := label(host, critical)
				var tween := LEGACY.animate(old, critical)
				tween.pause()
				EnemyController.active_damage_numbers += 1
				manager.animate(updated, critical)
				manager._clock.pause()
				pairs.append([old, updated, tween])
		for pair in pairs: pair[2].custom_step(0.061)
		manager.advance(0.061)
		for pair in pairs:
			check(pair[0].global_position.distance_to(pair[1].global_position) < 0.001, "staggered groups retain independent trajectories")
			check(pair[0].scale.distance_to(pair[1].scale) < 0.00001 and absf(pair[0].modulate.a - pair[1].modulate.a) < 0.00001, "staggered groups retain scale and alpha")
	for pair in pairs: pair[2].kill()
	host.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 0, "staggered groups cleaned up")

func _lifecycle() -> void:
	var host := Node2D.new()
	host.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(host)
	var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
	host.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.current_hp = 10000
	EnemyController.prepare_damage_number_pool(host)
	var manager := ANIMATOR.for_parent(host)
	var before := get_tree().get_processed_tweens().size()
	for i in 180: enemy._spawn_damage_number(10)
	for i in 40: enemy._spawn_damage_number(999, true)
	check(EnemyController.active_damage_numbers == 160 and manager._active.size() == 160, "128 normal plus 32 reserved critical slots")
	check(get_tree().get_processed_tweens().size() == before + 1, "one clock for 160 popups")
	var popup: CombatDamageNumber = manager._active[0]
	await frames()
	get_tree().paused = true
	var paused_position := popup.position
	await frames(5)
	check(popup.position == paused_position, "tree pause freezes shared animation")
	get_tree().paused = false
	manager._clock.pause()
	var first_id := popup.get_instance_id()
	popup.free()
	check(EnemyController.active_damage_numbers == 159, "external deletion releases once")
	manager.advance(1.2)
	manager._recycle_finished()
	check(EnemyController.active_damage_numbers == 0, "deleted entry and others retire safely")
	enemy._spawn_damage_number(10, true)
	check(manager._active.size() == 1 and manager._active[0].get_instance_id() != first_id, "pool reuse resets animation")
	enemy.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 1, "popup survives victim deletion")
	host.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 0, "battle exit releases all popups")
	# Multiple parents share the same admission budget but own separate lifetimes.
	var other := Node2D.new()
	add_child(other)
	var first := label(other, false)
	EnemyController.active_damage_numbers += 1
	ANIMATOR.for_parent(other).animate(first, false)
	other.queue_free()
	await frames()
	check(EnemyController.active_damage_numbers == 0, "new encounter has no stale budget")

func _pixels() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for critical in [false, true]:
		var views: Array[SubViewport] = []
		for i in 2:
			var view := SubViewport.new()
			view.size = Vector2i(360, 180)
			view.transparent_bg = true
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(view)
			views.append(view)
		var old := label(views[0], critical)
		var updated := label(views[1], critical)
		var tween := LEGACY.animate(old, critical)
		tween.pause()
		var manager := ANIMATOR.for_parent(views[1])
		EnemyController.active_damage_numbers += 1
		manager.animate(updated, critical)
		manager._clock.pause()
		for i in 4:
			var dt: float = [0.05, 0.09, 0.17, 0.49][i]
			tween.custom_step(dt)
			manager.advance(dt)
			await RenderingServer.frame_post_draw
			var a := views[0].get_texture().get_image()
			var b := views[1].get_texture().get_image()
			check(a.get_data() == b.get_data(), "render pixels match critical=%s frame=%d" % [critical, i])
			a.save_png(capture_dir.path_join("before_%s_%d.png" % [critical, i]))
			b.save_png(capture_dir.path_join("after_%s_%d.png" % [critical, i]))
		tween.kill()
		for view in views: view.queue_free()
		await frames()
