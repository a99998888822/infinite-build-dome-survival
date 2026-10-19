extends "res://scripts/tests/dense_combat_cost_review.gd"
## Equal work: 96 stationary live targets, 4 waves, fixed simulation time.
## Wall-clock draw intervals remain real; no hitstop or readback in the sample.
const STEP := 1.0 / 60.0
const LEGACY = preload("res://scripts/tests/fixtures/legacy_light_reflection_effect.gd")
const SHARED_BASELINE = preload("res://scripts/tests/fixtures/shared_baseline_reflection.gd")
const SHARED_BASELINE_GRUB = preload("res://scripts/tests/fixtures/shared_baseline_profiled_grub.gd")
const PULSE_BASELINE_GRUB = preload("res://scripts/tests/fixtures/pulse_checked_profiled_grub.gd")
var count := 1280
var legacy := false
var alternating := false
var current_first := false
var alternate_hit_pose := false
var sites := 32
var current_step := 0
var current_beam := -1
var trace_hash := 0
var hit_total := 0
var damage_total := 0
var beams: Array[Node2D] = []
var last_beam: Node2D

func received(_source: String, damage: int, target_index: int) -> void:
	if not measuring: return
	hit_total += 1
	damage_total += damage
	for value in [current_step, current_beam, target_index, damage]:
		trace_hash = ((trace_hash * 16777619) ^ int(value)) & 0x7fffffff

func track_child(node: Node) -> void:
	if node is LightReflectionEffect or node is LegacyLightReflectionEffect or node.get_script() == SHARED_BASELINE: last_beam = node

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
		if arg.begins_with("--sites="): sites = int(arg.trim_prefix("--sites="))
		if arg == "--legacy": legacy = true
		if arg == "--alternate-shared": alternating = true
		if arg == "--current-first": current_first = true
		if arg == "--alternate-hit-pose": alternate_hit_pose = true
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	for id in WEAPONS: CombatSettings.set_weapon_auto_cast("weapon_" + id, false, false)
	var reports: Array = []
	for repeat in repeats:
		# ABBA balances order; both reflection queries and hit visuals use the
		# frozen immediate-before sources in control rows.
		var shared_baseline := alternating and repeat % 4 in [0, 3]
		if alternating and current_first: shared_baseline = not shared_baseline
		# Two balanced blocks: ABBA then BAAB for the hit-presentation control.
		var hit_pose_baseline := alternate_hit_pose and ((repeat % 8 in [0, 3, 5, 6]) != current_first)
		var enemy_script: Script = SHARED_BASELINE_GRUB if shared_baseline else GRUB
		if hit_pose_baseline: enemy_script = PULSE_BASELINE_GRUB
		await setup({"count": 96, "fixed": true, "enemy_script": enemy_script})
		battle.set_process(false)
		CombatHitFeedback.active = false
		for i in enemies.size():
			enemies[i].set_physics_process(false)
			enemies[i].global_position = Vector2(80 + (i % 12) * 12, (i / 12 - 3.5) * 16)
			enemies[i].damage_received.connect(received.bind(i))
		host.child_entered_tree.connect(track_child)
		await frames(4)
		beams.clear()
		samples.clear()
		var timings: Array = []
		var visual_tiers := [0, 0, 0, 0]
		var factory: Script = LEGACY if legacy else preload("res://scripts/effects/light_reflection_effect.gd")
		if shared_baseline: factory = SHARED_BASELINE
		var event := DamageEvent.create({"damage": 10, "original_damage": 10, "source_weapon_id": "weapon_void_blade", "source_player": battle.player})
		trace_hash = 0
		hit_total = 0
		damage_total = 0
		started = Time.get_ticks_usec()
		previous = started
		measuring = true
		for step in 60:
			current_step = step
			for budget in get_tree().get_nodes_in_group("thunder_fire_visual_budgets"):
				budget.set_process(false)
				budget._process(STEP)
			var begin := Time.get_ticks_usec()
			if step in [0, 6, 12, 18]:
				for i in count / 4:
					# Many beams repeat the same contact origin and sweep geometry.
					var site := i % sites
					var origin := Vector2(80 + (site % 8) * 14, (site / 8 - 1.5) * 18)
					factory.spawn(host, origin, Vector2.RIGHT, event)
					last_beam.set_process(false)
					beams.append(last_beam)
					visual_tiers[last_beam.get("_visual_tier")] += 1
				# claim() re-enables processing: freeze it again after spawning so
				# visual admission uses the same simulation clock on both versions.
				for budget in get_tree().get_nodes_in_group("thunder_fire_visual_budgets"):
					budget.set_process(false)
			var spawn_ms := (Time.get_ticks_usec() - begin) / 1000.0
			begin = Time.get_ticks_usec()
			var alive_count := 0
			for i in beams.size():
				var beam := beams[i]
				if not is_instance_valid(beam) or beam.is_queued_for_deletion(): continue
				current_beam = i
				alive_count += 1
				beam.call("_process", STEP)
			var sweep_ms := (Time.get_ticks_usec() - begin) / 1000.0
			timings.append({"step": step, "spawn_ms": spawn_ms, "sweep_ms": sweep_ms, "active": alive_count, "hits": hit_total})
			if DisplayServer.get_name() == "headless": await frames()
			else: await RenderingServer.frame_post_draw
			await frames()
		measuring = false
		var hp: Array = []
		for enemy in enemies: hp.append(enemy.current_hp)
		var row := {"repeat": repeat, "count": count, "sites": sites, "legacy": legacy, "shared_baseline": shared_baseline, "shared_control_order": "BAAB" if current_first else "ABBA", "visual_tiers": visual_tiers, "hits": hit_total, "damage": damage_total, "trace_hash": trace_hash,
			"hit_pose_baseline": hit_pose_baseline,
			"hp": hp, "timings": timings, "frames": summarize(samples), "samples": samples.duplicate(true),
			"headless": DisplayServer.get_name() == "headless", "method": "96 fixed live enemies; fixed 1/60 steps; 4 birth waves; 60 simulation steps; hitstop off; normal damage and visuals"}
		reports.append(row)
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(reports, "\t"))
		print("REFLECTION_LOAD count=", count, " repeat=", repeat, " hits=", hit_total, " hash=", trace_hash, " frame_ms=", row.frames.get("frame_ms"))
		if hit_total == 0: failures.append("no reflection damage")
		await cleanup()
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
