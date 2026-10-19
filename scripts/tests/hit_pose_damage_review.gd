extends Node
## Equal-work CPU burst; include the deferred pose flush in the measured scope.
const BASELINE = preload("res://scripts/tests/fixtures/pulse_checked_profiled_grub.gd")
const CURRENT = preload("res://scripts/tests/fixtures/dense_profiled_grub.gd")
const POSE_QUEUE = preload("res://scripts/effects/enemy_hit_visual_queue.gd")
const HITS := 21804
var receipts := 0
var damage_sum := 0
var trace := 0
var hit_index := 0
var failures := 0

func received(_source: String, amount: int, target: int) -> void:
	receipts += 1
	damage_sum += amount
	for value in [hit_index, target, amount]: trace = ((trace * 16777619) ^ value) & 0x7fffffff

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	CombatHitFeedback.active = false
	var rows: Array = []
	for baseline in [true, false, false, true, false, true, true, false]:
		var room := Node2D.new()
		add_child(room)
		var enemies: Array[EnemyController] = []
		for i in 96:
			var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
			enemy.set_script(BASELINE if baseline else CURRENT)
			room.add_child(enemy)
			enemy.set_physics_process(false)
			enemy.current_hp = 1000000
			enemy.damage_received.connect(received.bind(i))
			enemies.append(enemy)
		await get_tree().process_frame
		if EnemyController.active_damage_numbers != 0: failures += 1
		seed(10192026)
		receipts = 0
		damage_sum = 0
		trace = 0
		var event := DamageEvent.create({"damage": 35, "source_weapon_id": "hit_pose_review"})
		var started := Time.get_ticks_usec()
		for i in HITS:
			hit_index = i
			enemies[i % 96].take_attack_damage(35, event)
		var after_damage := Time.get_ticks_usec()
		POSE_QUEUE.flush()
		var after_flush := Time.get_ticks_usec()
		var poses: Array = []
		var hp: Array = []
		for enemy in enemies:
			var visual: Node = enemy._hit_visual
			poses.append([visual.elapsed, visual.applied_offset.x, visual.applied_offset.y,
				visual.flash_white, visual.white_material.get_shader_parameter("white_amount")])
			hp.append(enemy.current_hp)
		var row := {"baseline": baseline, "cpu_ms": (after_flush-started)/1000.0,
			"submit_ms": (after_damage-started)/1000.0, "flush_ms": (after_flush-after_damage)/1000.0,
			"hits": receipts, "damage": damage_sum, "trace": trace, "hp": hp,
			"poses": poses, "next_random": randf(), "numbers": EnemyController.active_damage_numbers}
		if receipts != HITS or damage_sum != HITS * 35: failures += 1
		if not rows.is_empty():
			for key in ["hits", "damage", "trace", "hp", "poses", "next_random", "numbers"]:
				if row[key] != rows[0][key]: failures += 1
		rows.append(row)
		room.queue_free()
		enemies.clear()
		await get_tree().process_frame
		await get_tree().process_frame
	FileAccess.open("artifacts/reports/hit_pose_damage_review.json", FileAccess.WRITE).store_string(JSON.stringify({"failures": failures, "rows": rows,
		"method": "96 live stationary grubs; 21804 synchronous damage calls; ABBA BAAB; real damage, numbers, body visuals and signal trace; CPU timer includes pending pose flush; not a full battle/GPU frame"}, "\t"))
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("HIT_POSE_DAMAGE rows=", rows.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
