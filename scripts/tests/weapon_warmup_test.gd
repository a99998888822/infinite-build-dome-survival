extends Node2D
const WARMUP = preload("res://scripts/effects/weapon_render_warmup.gd")
const HIT_WARMUP = preload("res://scripts/effects/combat_hit_render_warmup.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)

func frames(count := 1) -> void:
	for i in count: await get_tree().process_frame

func find_ground_sample(parent: Node) -> Node2D:
	if is_instance_valid(parent):
		for node in parent.get_children():
			if node.get_script() == HIT_WARMUP.GROUND: return node
	return null

func run() -> void:
	CampProgression.begin_transient_session()
	seed(20261020)
	var expected_random := randf()
	seed(20261020)
	var sample := Node2D.new()
	add_child(sample)
	var count_before := WARMUP.FLAME.visual_count
	for kind in WARMUP.KINDS: WARMUP.prepare(sample,kind)
	check(randf() == expected_random,"warmup preserves combat RNG")
	check(sample.get_child_count() == WARMUP.KINDS.size(),"one sample family per stage")
	check(WARMUP.FLAME.visual_count == count_before+2,"two render-only flame samples")
	check(sample.get_child(0).material.shader == WARMUP.FLAME.SHADER,"native lamp shader")
	check(sample.get_child(1).material.shader == WARMUP.JET.JET_SHADER,"native cannon shader")
	check(sample.get_child(0).material.get_shader_parameter("flow_noise") == WARMUP.FLAME.flow_texture,"native noise texture")
	check(sample.get_child(2).get_child_count() == 16,"all plasma core frames submitted")
	var mask := sample.get_node("CooldownRenderWarmup") as ColorRect
	check(mask != null and mask.visible and mask.size == Vector2(48, 48), "cooldown sample is drawable")
	check(mask.material.shader == ActiveCombatWeaponBar.COOLDOWN_SHADER, "cooldown sample uses the HUD shader")
	check(mask.material.get_shader_parameter("remaining") == 0.5, "cooldown sample renders a nonempty sector")
	check(mask.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cooldown sample cannot capture input")
	check(get_tree().get_nodes_in_group("weapon_runtime_effects").is_empty(),"no gameplay runtime registered")
	check(EnemyRegistry.get_registered_enemies().is_empty(),"no warmup enemies created")
	check(WARMUP.PLASMA._core_frames.size() == 16,"existing plasma preparation completed")
	sample.free()
	check(WARMUP.FLAME.visual_count == count_before,"flame sample count restored after cleanup")
	check(WARMUP.FLAME.flow_texture == null,"temporary flow texture lifetime preserved")
	# The enchantment fire clock is paused during entry: loading must explicitly
	# submit its real MultiMesh without advancing it or leaving a live clock.
	var fire_sample := Node2D.new()
	add_child(fire_sample)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	seed(20261021)
	expected_random = randf()
	seed(20261021)
	HIT_WARMUP.prepare(fire_sample, [], null)
	check(randf() == expected_random, "fire prewarm preserves gameplay RNG")
	var ground_sample := find_ground_sample(fire_sample)
	check(ground_sample != null and ground_sample.material.shader == HIT_WARMUP.GROUND.SHADER, "entry prepares the native ground-coverage material")
	var ground_draws := [0]
	if ground_sample != null:
		ground_sample.draw.connect(func(): ground_draws[0] += 1)
		check(ground_sample.terminal_axes.is_equal_approx(HIT_WARMUP.FOOTPRINT.axes(30.0)) and ground_sample.growth == 1.0 and ground_sample.opacity == 1.0, "ground prewarm covers a nonempty full-size footprint")
		check(not ground_sample is CollisionObject2D and ground_sample.get_child_count() == 0, "ground prewarm has no gameplay body or children")
	await frames(2)
	check(ground_draws[0] > 0 and ground_sample.is_visible_in_tree(), "paused loading submits the ground sample draw")
	var fire_clock: Node = HIT_WARMUP.FIRE.clock
	check(is_instance_valid(fire_clock) and fire_clock.get_viewport() == fire_sample.get_viewport(), "fire batch belongs to the loading viewport")
	check(is_zero_approx(fire_clock.elapsed), "paused prewarm does not advance the flame clock")
	var fire_batch: MultiMeshInstance2D = fire_clock.batches[43]
	check(fire_batch.visible and fire_batch.multimesh.visible_instance_count == 1 and fire_batch.material.shader == HIT_WARMUP.FIRE.FIRE_SHADER, "paused prewarm submits the actual fire shader and batch")
	check(get_tree().get_nodes_in_group("fire_patches").is_empty() and EnemyRegistry.get_registered_enemies().is_empty(), "fire prewarm creates no damage field or enemy")
	var new_parent := Node2D.new()
	add_child(new_parent)
	fire_sample.reparent(new_parent, true)
	await frames(2)
	fire_clock = HIT_WARMUP.FIRE.clock
	fire_clock.flush()
	check(HIT_WARMUP.FIRE.visual_count == 1 and fire_clock.sources.size() == 1, "reparent registers fire exactly once in the replacement clock")
	var rebound_buffer: PackedFloat32Array = fire_clock.buffers[43]
	check(rebound_buffer[0] == 14.0 and rebound_buffer[5] == 22.0 and rebound_buffer[11] == 1.0, "replacement clock receives geometry even when slot and epoch numbers repeat")
	fire_sample.free()
	new_parent.free()
	await frames(2)
	check(HIT_WARMUP.FIRE.visual_count == 0 and not is_instance_valid(HIT_WARMUP.FIRE.clock) and HIT_WARMUP.FIRE.shared_material == null, "sample cleanup releases fire clock and material")
	check(not is_instance_valid(ground_sample), "ground sample is released with its loading owner")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	# Cancel at each new await point while actual loading owns the samples.
	CombatSettings.combat_guide_seen = true
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	var flow := game.get_main_flow_coordinator()
	for stage in WARMUP.KINDS.size():
		menu._on_start_battle_pressed()
		await frames(3)
		menu._on_character_confirm_pressed()
		var loading := menu.dungeon_loading
		var reached := false
		for i in 2000:
			if is_instance_valid(loading._samples):
				var flames := 0
				var plasma := false
				for node in loading._samples.get_children():
					if node.get_script() == WARMUP.FLAME: flames += 1
					if node.has_meta("aligned_atlas_surfaces") and node.get_child_count()==16: plasma = true
				reached = (flames == stage+1) if stage < 2 else plasma if stage == 2 else loading._samples.has_node("CooldownRenderWarmup")
			if reached or not loading.active: break
			await frames()
		check(reached,"reached warmup stage %d"%stage)
		var native_bolt_ready := false
		if is_instance_valid(loading._samples):
			for node in loading._samples.get_children():
				if node.get_script() == loading.BOLT:
					native_bolt_ready = not node.rim_enabled and node.cached_instances != null and node.cached_mesh == null and node.quad_count > 0
		check(native_bolt_ready, "entry draws the runtime instanced lightning path %d" % stage)
		check(is_instance_valid(HIT_WARMUP.FIRE.clock) and HIT_WARMUP.FIRE.clock.batches.has(43) and HIT_WARMUP.FIRE.clock.batches[43].multimesh.visible_instance_count == 1, "entry draws the enchantment fire batch %d" % stage)
		var loading_ground := find_ground_sample(loading._samples)
		check(loading_ground != null and loading_ground.is_visible_in_tree() and loading.curtain.modulate.a == 1.0, "ground sample stays under the opaque loading curtain %d" % stage)
		flow.enter_start_page()
		await frames(10)
		check(not loading.active and loading._samples == null and not loading.visible,"cancel clears warmup and curtain %d"%stage)
		check((game.get_node("SceneDirector") as GameSceneDirector).battle_root == null,"cancel cannot resume stale battle %d"%stage)
		check(WARMUP.FLAME.visual_count == count_before,"cancel releases flame samples %d"%stage)
		var fire_released := HIT_WARMUP.FIRE.visual_count == 0 and not is_instance_valid(HIT_WARMUP.FIRE.clock)
		if not fire_released:
			var sources: Array = []
			for node in get_tree().get_nodes_in_group("pixel_fire_visuals"): sources.append(str(node.get_path()))
			print("FIRE_CANCEL ", JSON.stringify({"stage": stage, "count": HIT_WARMUP.FIRE.visual_count, "clock_valid": is_instance_valid(HIT_WARMUP.FIRE.clock), "sources": sources}))
		check(fire_released, "cancel releases enchantment fire sample %d" % stage)
		check(not is_instance_valid(loading_ground), "cancel releases the ground sample %d" % stage)
	game.queue_free()
	await frames(4)
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("WEAPON_WARMUP_TEST checks=",checks," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
