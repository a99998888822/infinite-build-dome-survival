extends Node
var checks := 0
var failures := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var manager := WaveManager.new()
	add_child(manager)
	var initial_children := manager.get_child_count()
	var initial_enemies := EnemyRegistry.get_registered_enemies().duplicate()
	var quota_rng := manager._elite_quota_rng.state
	seed(20261021)
	var expected_random := randf()
	seed(20261021)
	for data: Dictionary in DataRegistry.get_table("enemies"):
		if not bool(data.get("enabled", true)): continue
		check(manager.prepare_enemy_scene(data), "prepares " + str(data.id))
		var scene: PackedScene = manager.enemy_scene_cache.get(str(data.scene))
		check(scene != null and ResourceLoader.has_cached(str(data.scene)), "scene dependencies stay resident")
		check(manager.prepare_enemy_scene(data) and manager._load_enemy_scene(data) == scene, "repeat preparation and spawn lookup reuse the same scene")
	check(manager.get_child_count() == initial_children and EnemyRegistry.get_registered_enemies() == initial_enemies, "preparation creates no gameplay nodes or registry entries")
	check(randf() == expected_random and manager._elite_quota_rng.state == quota_rng, "preparation consumes neither combat nor elite RNG")
	check(not manager.running and manager.current_wave_index == -1 and manager.spawn_timers_ms.is_empty(), "preparation does not start or advance a wave")
	check(not manager.prepare_enemy_scene({}), "missing scene returns failure")
	manager.free()
	await get_tree().process_frame
	print("ENEMY_SCENE_WARMUP checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
