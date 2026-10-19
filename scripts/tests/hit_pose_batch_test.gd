extends Node
const QUEUE = preload("res://scripts/effects/enemy_hit_visual_queue.gd")

class CountedVisual extends "res://scripts/effects/enemy_hit_visual.gd":
	var pulses := 0
	var syncs := 0
	func pulse(white: bool) -> void:
		pulses += 1
		super.pulse(white)
	func _sync() -> void:
		syncs += 1
		super._sync()

var checks := 0
var failures := 0
var receipts := 0
var sum_damage := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func received(_source: String, damage: int) -> void:
	receipts += 1
	sum_damage += damage

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	CombatHitFeedback.active = false
	var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.current_hp = 100000
	enemy.damage_received.connect(received)
	var visual := CountedVisual.new()
	enemy.add_child(visual)
	enemy._hit_visual = visual
	var at := enemy.position
	for i in 100: enemy.take_damage(5, "burst")
	check(receipts == 100 and sum_damage == 500 and enemy.current_hp == 99500, "damage and receipts are immediate and complete")
	check(visual.pulses == 1 and visual.syncs == 1, "100 contacts submit one immediate hit pose")
	check(enemy.sprite.offset != Vector2.ZERO and visual.elapsed == 0, "first contact is visible immediately")
	check(enemy._hit_visual_pending and QUEUE._pending.size() == 1, "one queued actor for the burst")
	enemy.sprite.scale = Vector2(2.3, 0.7)
	enemy.take_damage(5, "changed_pose")
	QUEUE.flush()
	check(visual.pulses == 1 and visual.syncs == 2, "one final pose sync includes the later animation")
	check(enemy.sprite.global_transform.basis_xform(visual.applied_offset).is_equal_approx(Vector2(5,-2)), "final world-space shake amplitude is unchanged")
	check(enemy.position == at and not enemy._hit_visual_pending, "collision body unchanged and pending flag released")
	# Material edits before another hit and after the last hit keep their ordering.
	enemy.take_damage(5, "material_before")
	var replacement := CanvasItemMaterial.new()
	enemy.sprite.material = replacement
	enemy.take_damage(5, "material_after")
	check(enemy.sprite.material == visual.white_material and visual.original_material == replacement, "later hit restores white over a replaced material")
	var after_last := CanvasItemMaterial.new()
	enemy.sprite.material = after_last
	QUEUE.flush()
	check(enemy.sprite.material == after_last, "final sync does not overwrite a material assigned after damage")
	enemy.take_damage(5, "disabled")
	visual.set_process(false)
	enemy.take_damage(5, "reactivate")
	check(visual.is_processing(), "new damage reactivates a manually disabled visual")
	visual.reset()
	check(not enemy._hit_visual_pending, "manual visual reset cancels the pending actor")
	enemy.take_damage(5, "after_reset")
	check(visual.is_processing() and visual.elapsed == 0 and enemy.sprite.offset != Vector2.ZERO, "same-batch damage after reset restarts feedback")
	enemy.initialize("enemy_mutated_grub")
	QUEUE.flush()
	check(not enemy._hit_visual_pending and visual.elapsed == visual.SHAKE_SECONDS and enemy.sprite.offset == Vector2.ZERO, "reinitialize cancels stale feedback")
	enemy.current_hp = 10
	enemy.take_damage(100, "lethal")
	check(not enemy.alive and enemy.current_hp == 0, "lethal damage is never delayed")
	QUEUE.flush()
	check(visual.elapsed == 0 and enemy.sprite.material == visual.white_material, "lethal frame retains white pose during death fade")
	enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(QUEUE._pending.is_empty(), "cleanup leaves no queued actors")
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("HIT_POSE_BATCH checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
