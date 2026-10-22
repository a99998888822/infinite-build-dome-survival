extends Node
# Headless/transient runs must pass -- --show-combat-guide to exercise the
# first-visit guide; CombatSettings deliberately suppresses it otherwise.
var checks := 0
var failures := 0
var capture_dir := ""
var game: GameRoot
var menu: MainMenuUIController
var flow: MainFlowCoordinator

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://scenes/core/game_root.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(12)
	menu = game.get_node("UiRoot/MainMenuUIController")
	flow = game.get_main_flow_coordinator()
	menu._on_start_battle_pressed()
	await frames()
	var loading := menu.dungeon_loading
	var began := Time.get_ticks_usec()
	menu._on_character_confirm_pressed()
	check(Time.get_ticks_usec() - began < 100000, "confirm returns before expensive scene creation")
	check(loading.active and loading.visible and loading.curtain.modulate.a == 1.0, "black loading screen appears immediately")
	check(flow.get_bound_player() == null, "battle creation waits for loading frame")
	var ticket := loading._ticket
	menu._on_character_confirm_pressed()
	check(loading._ticket == ticket, "double click cannot start a second run")
	check(L10n.text(loading.caption.text) == "正在进入地下城", "loading caption is localized")
	await capture("loading_black")
	if not capture_dir.is_empty():
		await frames(8)
		await capture("loading_dots")
	var count := 0
	var frozen := true
	var no_early_enemies := true
	var modal_prepared := false
	var modal_covered := true
	var modal_matches := true
	var night_prepared := false
	var night_matches := true
	var night_rng_recorded := false
	var night_rng_state := 0
	var rock_prepared := false
	var rock_matches := true
	while loading.active and count < 1200:
		if flow._bound_wave_manager != null and not night_rng_recorded:
			night_rng_state = flow._bound_wave_manager.evacuation.rng.state
			night_rng_recorded = true
		if is_instance_valid(loading._modal_sample):
			modal_prepared = true
			var sample := loading._modal_sample.get_child(0) as ColorRect
			var live_battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root
			var source := live_battle.get_node("ModalBackdrop/Backdrop") as ColorRect
			modal_covered = modal_covered and loading.visible and loading.curtain.modulate.a == 1.0 and loading._modal_sample.layer < loading.layer
			modal_matches = modal_matches and sample.is_visible_in_tree() and sample.get_viewport() == source.get_viewport() and sample.material == source.material and not source.visible
			var rock := loading._samples.get_node_or_null("EntryRockWarmup") as Sprite2D
			if rock != null:
				rock_prepared = true
				var scenery := live_battle.loadout._get_visual_root().get_node("Backdrop") as CavernSunlightBackdrop
				rock_matches = rock_matches and rock.is_visible_in_tree() and rock.get_viewport() == live_battle.player.get_viewport() and rock.texture == scenery.prop_textures[0] and rock.material.shader == CavernSunlightBackdrop.ROCK_SHADER and rock.material.get_shader_parameter("face_mask") == CavernSunlightBackdrop.ROCK_FACE_MASK and rock.material.get_shader_parameter("cloud_texture") == CavernSunlightBackdrop.CLOUD_TEXTURE
				rock_matches = rock_matches and not scenery.lit_objects.has(rock) and not scenery.occluding_rocks.has(rock)
			var night_layer := loading._modal_sample.get_node_or_null("EntryNightWarmup") as CanvasLayer
			if night_layer != null:
				night_prepared = true
				var visual: Node2D = flow._bound_wave_manager.evacuation.visual
				var night_sample := night_layer.get_child(0) as ColorRect
				# CanvasLayer redirects drawing; get_viewport() still reports tree ancestry.
				night_matches = night_matches and night_layer.layer < loading.layer and night_sample.is_visible_in_tree() and night_layer.custom_viewport == visual.night_layer.custom_viewport and night_layer.custom_viewport == get_tree().root and night_sample.material == visual.night_material and not visual.night_rect.visible
				var shaders := []
				for child in loading._samples.get_children():
					if child is CanvasItem and child.material is ShaderMaterial:
						shaders.append(child.material.shader)
				for shader in [visual.BANK_SHADER, visual.SHADOW_SHADER, visual.LAMP_SHADER]:
					night_matches = night_matches and shaders.has(shader)
				night_matches = night_matches and loading._samples.find_children("*", "CollisionObject2D", true, false).is_empty()
		frozen = frozen and bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
		var player := flow.get_bound_player()
		if player != null:
			no_early_enemies = no_early_enemies and flow._bound_wave_manager.get_living_enemy_count() == 0
			frozen = frozen and player.global_position == Vector2.ZERO
			if flow._bound_wave_manager.running:
				frozen = frozen and is_equal_approx(flow._bound_wave_manager.wave_time_left, float(flow.current_wave_duration_seconds))
		await frames(1)
		count += 1
	check(not loading.active, "loading completes within frame budget")
	check(frozen, "player and wave clock remain frozen throughout preparation and fade")
	check(no_early_enemies, "scene preparation never spawns live enemies under the curtain")
	check(modal_prepared and modal_covered, "modal shader is drawn only beneath the fully opaque loading curtain")
	check(modal_matches, "modal warmup shares the live material and UI viewport without opening the backdrop")
	check(loading._modal_sample == null and loading.get_node_or_null("EntryModalWarmup") == null, "modal warmup is removed before the reveal")
	check(not loading.visible and not bool(GameGlobal.get_runtime_flag("battle_loading", true)), "loading barrier releases on success")
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", true)), "combat starts and resumes after reveal")
	var battle := (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	check(night_prepared and night_matches, "entry draws night and shelter materials in their real viewports without gameplay bodies")
	check(rock_prepared and rock_matches and modal_covered, "entry draws the rock receiver in the world viewport under black without registering scenery")
	var evacuation: NightEvacuation = battle.wave_manager.evacuation
	check(night_rng_recorded and evacuation.rng.state == night_rng_state, "night preparation does not consume shelter placement randomness")
	check(not evacuation.active and evacuation.spawned_count == 0 and evacuation.visual.building == null and not evacuation.visual.night_rect.visible, "entry leaves night, shelter and pursuit inactive")
	var lamp_data := DataRegistry.get_record("weapons", "weapon_copper_lamp")
	var hud := battle.hud as BattleHud
	var reward_popup := (game.get_node("UiRoot/ShopUIController") as ShopUIController).shop_popup
	check(not reward_popup.visible and reward_popup._offer_cards.is_empty() and reward_popup.weapon_strip._weapon_buttons.size() == battle.loadout.weapon_instances.size(), "entry prepares the real weapon row without opening rewards")
	var prepared_buttons := reward_popup.weapon_strip._weapon_buttons.duplicate()
	reward_popup.set_loadout(battle.loadout)
	check(reward_popup.weapon_strip._weapon_buttons == prepared_buttons, "first reward binding retains the row prepared under black")
	check(not hud._stat_value_labels.is_empty() and not hud.is_stats_drawer_open(), "attribute rows are prepared before reveal without opening the drawer")
	check(is_equal_approx(hud.stats_drawer.offset_left, BattleHud.DRAWER_CLOSED_LEFT), "attribute drawer returns to its closed position before reveal")
	check(AudioManager._prepared_loop_streams.has(str(lamp_data.spray_loop_sfx)), "entry prepares the spray source even before acquiring the lamp")
	for enemy_data: Dictionary in DataRegistry.get_table("enemies"):
		if not bool(enemy_data.get("enabled", true)): continue
		check(battle.wave_manager.enemy_scene_cache.has(str(enemy_data.scene)), "enemy scene is resident before reveal: " + str(enemy_data.id))
	var backdrop := battle.loadout._get_visual_root().get_node("Backdrop") as CavernBattleBackdrop
	check(backdrop.is_initial_stream_ready(), "all initial scenery cells are present before reveal")
	var cached := true
	for layout: Dictionary in battle.player.get_combat_frame_layouts():
		cached = cached and backdrop.foot_bounds_cache.get(layout.texture, {}).has(layout.grid)
	check(cached, "all action alpha bounds are cached before first movement and attack")
	check(battle.loadout._get_visual_root().get_node_or_null("EntryRenderWarmup") == null, "render samples leave no live effects behind")
	var fire_script = preload("res://scripts/effects/pixel_fire_visual.gd")
	check(fire_script.visual_count == 0 and not is_instance_valid(fire_script.clock) and fire_script.shared_material == null, "successful entry leaves no prewarm fire or shared clock")
	check(battle.loadout._projectile_sequence == 0 and battle.loadout.weapon_instances[0].volley_index == 0, "warmup does not fire weapons or consume cooldowns")
	await capture("battle_revealed")
	flow.enter_start_page()
	await frames(8)
	menu._on_start_battle_pressed()
	menu._on_character_confirm_pressed()
	await frames(3)
	flow.enter_start_page()
	await frames(8)
	check(not loading.active and not loading.visible and not bool(GameGlobal.get_runtime_flag("battle_loading", true)), "reset cancels an in-progress load and clears the barrier")
	check((game.get_node("SceneDirector") as GameSceneDirector).battle_root == null, "cancelled load cannot attach a stale battle later")
	var prepared_types := 0
	for enemy_data: Dictionary in DataRegistry.get_table("enemies"):
		if bool(enemy_data.get("enabled", true)): prepared_types += 1
	for stage in range(1, prepared_types + 1):
		menu._on_start_battle_pressed()
		menu._on_character_confirm_pressed()
		var reached := false
		for attempt in 1200:
			if flow._bound_wave_manager != null and flow._bound_wave_manager.enemy_scene_cache.size() == stage:
				reached = true
				break
			if not loading.active: break
			await frames(1)
		check(reached and loading.active and loading.curtain.modulate.a == 1.0, "enemy preparation stage stays under black curtain: %d" % stage)
		flow.enter_start_page()
		await frames(8)
		check(not loading.active and not loading.visible and (game.get_node("SceneDirector") as GameSceneDirector).battle_root == null, "enemy preparation cancellation cannot resume a stale entry: %d" % stage)
	menu._on_start_battle_pressed()
	menu._on_character_confirm_pressed()
	for attempt in 1200:
		if is_instance_valid(loading._modal_sample) or not loading.active: break
		await frames(1)
	var cancelled_sample := loading._modal_sample
	var cancelled_night := cancelled_sample.get_node_or_null("EntryNightWarmup") if is_instance_valid(cancelled_sample) else null
	check(is_instance_valid(cancelled_sample) and is_instance_valid(cancelled_night), "cancellation reaches modal and night preparation")
	flow.enter_start_page()
	await frames(8)
	check(not is_instance_valid(cancelled_sample) and not is_instance_valid(cancelled_night) and loading._modal_sample == null and not loading.active, "cancelling preparation frees modal and night layers and stops entry")
	check(reward_popup._loadout == null and reward_popup.weapon_strip._loadout == null and reward_popup.weapon_strip._weapon_buttons.is_empty() and reward_popup.weapon_strip._cast_mode_buttons.is_empty(), "cancelling prepared entry releases weapon row and old loadout")
	loading.begin(flow, "invalid_character", [], "1")
	await loading.finished
	await frames(4)
	check(flow.current_mode == MainFlowCoordinator.MODE_BOOT and not loading.active and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", true)), "failed initialization returns to menu without a stuck pause")
	CombatSettings.combat_guide_seen = false
	menu._on_start_battle_pressed()
	menu._on_character_confirm_pressed()
	await loading.finished
	check(flow.current_state == MainFlowCoordinator.STATE_COMBAT_GUIDE and bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)), "first-time guide remains paused after the fade")
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.combat_guide.skip_button.pressed.emit()
	await frames()
	check(flow.current_state == MainFlowCoordinator.STATE_WAVE_COMBAT and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", true)), "guide dismissal starts the wave normally")
	flow.enter_start_page()
	await frames(8)
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("BATTLE_LOADING checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
