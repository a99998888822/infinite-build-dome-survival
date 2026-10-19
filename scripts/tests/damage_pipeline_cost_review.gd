extends Node
## CPU-only diagnostic ablations, never used by production enemy scenes.
const HITS := 21804

class ProbeEnemy extends EnemyController:
	var skip_stats := false
	var skip_visual := false
	var skip_numbers := false
	var skip_random := false
	func get_stat(id: String, fallback: float = 0.0) -> float:
		if skip_stats and id == "damage_taken_percent": return 100.0
		return super.get_stat(id, fallback)
	func _show_hit_visual() -> void:
		if not skip_visual: super._show_hit_visual()
	func _spawn_damage_number(amount: int, critical := false, index := 0, count := 1, light := false, base := 0) -> void:
		if not skip_numbers: super._spawn_damage_number(amount, critical, index, count, light, base)
	func _consume_legacy_hit_random_sample() -> void:
		if not skip_random: super._consume_legacy_hit_random_sample()

var receipts := 0
var damage_total := 0
var rows: Array = []
var failures := 0

func received(_source: String, damage: int) -> void:
	receipts += 1
	damage_total += damage

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	CombatHitFeedback.active = false
	for repeat in 3:
		var modes := ["full", "no_stats", "no_visual", "no_numbers", "no_random"]
		if repeat % 2 == 1: modes.reverse()
		for mode in modes:
			var room := Node2D.new()
			add_child(room)
			var enemies: Array[EnemyController] = []
			for i in 96:
				var enemy := preload("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
				enemy.set_script(ProbeEnemy)
				room.add_child(enemy)
				enemy.set_physics_process(false)
				enemy.current_hp = 1000000
				enemy.skip_stats = mode == "no_stats"
				enemy.skip_visual = mode == "no_visual"
				enemy.skip_numbers = mode == "no_numbers"
				enemy.skip_random = mode == "no_random"
				enemy.damage_received.connect(received)
				enemies.append(enemy)
			var event := DamageEvent.new()
			event.original_damage = 10
			event.source_weapon_id = "diagnostic_source"
			await get_tree().process_frame
			receipts = 0
			damage_total = 0
			var started := Time.get_ticks_usec()
			for i in HITS:
				enemies[i % 96].take_attack_damage(event.get_elemental_damage(3.5), event)
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			if receipts != HITS or damage_total != HITS * 35: failures += 1
			rows.append({"repeat": repeat, "mode": mode, "cpu_ms": elapsed, "hits": receipts, "damage": damage_total})
			room.queue_free()
			enemies.clear()
			await get_tree().process_frame
			await get_tree().process_frame
	FileAccess.open("artifacts/reports/damage_pipeline_cost_review.json", FileAccess.WRITE).store_string(JSON.stringify({"rows": rows, "failures": failures,
		"method": "CPU diagnostic only; 21804 synchronous contacts on 96 real grubs; per-hit signal accounting; no scene rendering/physics/reactions or gameplay hitstop; ablations are not production changes"}, "\t"))
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("DAMAGE_PIPELINE_COST failures=", failures, " rows=", rows.size())
	get_tree().quit(0 if failures == 0 else 1)
