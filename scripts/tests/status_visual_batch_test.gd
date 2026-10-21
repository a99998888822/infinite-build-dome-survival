extends "res://scripts/tests/pixel_combat_effect_test.gd"
const QUEUE = preload("res://scripts/effects/enemy_status_visual_queue.gd")
const ORIGINAL = preload("res://scripts/tests/fixtures/status_original_enemy_status_visual.gd")
const ANCHORS = preload("res://scripts/effects/enemy_visual_anchors.gd")

func compare_status(old: Node, current: Node, label: String) -> void:
	old._process(0.0)
	current._process(0.0)
	QUEUE.flush()
	check(old._status_mask == current._status_mask, label + " mask")
	for key in ["_foot_frost", "_body_ice", "_flame_visual"]:
		var a: Node2D = old.get(key)
		var b: Node2D = current.get(key)
		check(is_instance_valid(a) == is_instance_valid(b), label + " existence " + key)
		if not is_instance_valid(a) or not is_instance_valid(b): continue
		check(a.visible == b.visible and a.position == b.position, label + " pose " + key)
		if key == "_flame_visual":
			check(a.palette == b.palette and a.parts == b.parts, label + " flame geometry/palette")
		else:
			check(a.body_radius == b.body_radius and a.is_shell == b.is_shell, label + " frost geometry")

func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([Vector2.ZERO])
	var enemy := enemies[0]
	var current := enemy.get_node("EnemyStatusVisual")
	var old := ORIGINAL.new()
	enemy.add_child(old)
	old.set_process(false)
	QUEUE.flush()
	check(not current.is_processing(), "empty actor sleeps")
	for i in 1000:
		enemy.apply_wet(5)
		enemy.clear_wet()
		enemy.apply_light(3)
		enemy.clear_light()
	check(QUEUE._pending.size() == 1, "4000 boundaries enqueue one visual")
	check(not enemy.has_status("wet") and not enemy.has_status("light"), "state changes are immediate")
	QUEUE.flush()
	check(not current.is_processing(), "net empty status returns to sleep")
	for action in ["wet", "slow", "freeze", "fire", "holy", "dark", "resize", "clear"]:
		match action:
			"wet": enemy.apply_wet(5)
			"slow": enemy.apply_slow(2, .5)
			"freeze": enemy.apply_freeze(2)
			"fire": enemy.apply_burning(3, 1, "source")
			"holy": enemy.apply_light(2)
			"dark": enemy.apply_blind(2)
			"resize":
				enemy.apply_body_scale(1.5)
				enemy.sprite.flip_h = true
			"clear":
				enemy.clear_wet()
				enemy.clear_light()
				enemy.clear_blind()
				enemy.clear_burning()
				enemy._frozen_remaining = 0
				enemy._slowed_remaining = 0
		compare_status(old, current, action)
	check(not current.is_processing(), "cleared actor stops polling")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	enemy.apply_wet(3)
	QUEUE.flush()
	check(current._status_mask == 0 and enemy.has_status("wet"), "pause holds presentation, keeps gameplay application")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	await frames()
	check(current._status_mask == 1, "resume submits pending state")
	enemy.apply_lightning_stun(.2, 0)
	var visual: Node = enemy._lightning_visual
	for i in 1000: enemy.apply_lightning_stun(.7 if i % 2 == 0 else .1, 0)
	check(is_equal_approx(enemy._stunned_remaining, .7) and is_equal_approx(visual._remaining, .7), "repeated stun retains maximum immediate duration")
	check(enemy._lightning_visual == visual, "repeated stun reuses one visual")
	enemy._start_super_armor()
	check(not visual.visible and enemy._stunned_remaining == 0, "armor synchronously clears stun")
	enemy._tick_super_armor(.5)
	check(is_equal_approx(enemy._super_armor_visual.remaining, 1.5), "armor visual clock mirrors physics without pose submission")
	for i in 30: enemy._super_armor_visual.request_sync()
	QUEUE.flush()
	check(enemy._super_armor_visual.outline.transform == enemy.sprite.transform, "armor submits final pose")
	enemy._tick_super_armor(1.5)
	check(not enemy._super_armor_visual.visible, "armor expiry is immediate")
	enemy.apply_wet(3)
	enemy.initialize(enemy.enemy_id)
	QUEUE.flush()
	check(current._status_mask == 0 and not current.is_processing(), "reset before flush cannot restore stale icons")
	enemy.apply_wet(3)
	get_tree().paused = true
	QUEUE.flush()
	check(current._status_mask == 0, "SceneTree pause holds presentation")
	get_tree().paused = false
	await frames()
	check(current._status_mask == 1, "SceneTree resume refreshes visual")
	enemy.apply_light(2)
	enemy.queue_free()
	QUEUE.flush()
	await frames()
	check(not is_instance_valid(enemy) and QUEUE._pending.is_empty(), "pending death/removal drains safely")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(.2).timeout
	CampProgression.end_transient_session()
	print("STATUS_VISUAL_BATCH checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
