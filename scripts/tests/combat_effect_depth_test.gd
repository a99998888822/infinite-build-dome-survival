extends Node
## Production battle + real spell/projectile/batch paths. GPU checks compare
## opaque foreground pixels, rather than only testing assigned Z values.
const FIRE = preload("res://scripts/effects/pixel_fire_visual.gd")
const PARTICLES = preload("res://scripts/effects/particle_world.gd")
const BOLT_HIT = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
var game: GameRoot
var battle: BattleRoot
var ground: CavernPopulationBackdrop
var enemy: EnemyController
var effect_host: Node2D
var surfaces: Array[CanvasItem] = []
var output := ""
var checks := 0
var failures := 0

func _ready() -> void:
	WindowSettings._startup_applied = true
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(9)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(99))

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", note)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func _run() -> void:
	CampProgression.begin_transient_session()
	get_window().unfocusable = true
	get_window().size = Vector2i(1280,720)
	get_tree().node_added.connect(func(node: Node):
		if node is CavernPopulationBackdrop: node.population_seed = 20261022)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_window().add_child(game)
	get_tree().current_scene = game
	await frames(16)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [])
	check(flow.confirm_character_selection(), "enter real battle")
	await frames(30)
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	ground = get_tree().get_first_node_in_group("battle_cavern") as CavernPopulationBackdrop
	for i in 1200:
		if ground.is_initial_stream_ready(): break
		await frames(1)
	check(ground.is_initial_stream_ready(), "production grass streaming ready")
	battle.set_process(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.active_controller.enabled = false
	battle.player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	effect_host = Node2D.new()
	effect_host.name = "HighParentDepthProbe"
	# Catch effects that accidentally inherit their simulation owner's layer.
	effect_host.z_index = 500
	PARTICLES.find_render_world(battle.player).add_child(effect_host)
	_spawn_effects()
	await frames(3)
	enemy = battle.wave_manager.spawn_enemy("enemy_mutated_grub", Vector2(120,20))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.process_mode = Node.PROCESS_MODE_DISABLED
	ground.environment_time = 10
	ground.shadow_enabled = false
	ground._update_area()
	if is_instance_valid(FIRE.clock):
		FIRE.clock.advance(0.18)
		FIRE.clock.set_process(false)
	_collect_surfaces(battle.player.get_viewport())
	check(surfaces.size() >= 8, "spell, projectile, fire, particle and ground surfaces exercised")
	_check_drawables(effect_host)
	var particle_world := PARTICLES._find_world(battle.player)
	check(_effective_z(particle_world) < 0, "shared particle pool below actors")
	if is_instance_valid(FIRE.clock):
		for batch: MultiMeshInstance2D in FIRE.clock.batches.values():
			check(_effective_z(batch) < 0, "viewport-owned fire batch below actors")
	check(ground.ground.z_index < ground.decals.z_index and ground.decals.z_index < CombatRenderWorld.GRASS_Z, "floor and ground decorations stay behind grass")
	var grass_valid := true
	var grass_batches := 0
	for group: Dictionary in ground.grass_cells.values():
		for band: Dictionary in group.bands:
			for batch: MultiMeshInstance2D in [band.back,band.front]:
				grass_batches += 1
				grass_valid = grass_valid and _effective_z(batch) == CombatRenderWorld.GRASS_Z
	check(grass_batches > 0 and grass_valid, "all streamed grass batches use the layer below effects")
	for surface in surfaces:
		check(_effective_z(surface) > CombatRenderWorld.GRASS_Z and _effective_z(surface) < _effective_z(enemy.sprite),
			"effect between grass and actors: " + str(surface.get_path()))
	if DisplayServer.get_name() != "headless":
		for player_y in [-120,120]:
			battle.player.global_position = Vector2(-150,player_y)
			ground._update_area()
			await _check_gpu(str(player_y))
	# Release the frozen fixture while its shared render services still exist.
	surfaces.clear()
	effect_host.queue_free()
	await frames()
	game.queue_free()
	await frames()
	CampProgression.end_transient_session()
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	print("COMBAT_EFFECT_DEPTH_TEST checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _spawn_effects() -> void:
	var weapon := WeaponInstance.new()
	weapon.weapon_id = "depth_probe"
	weapon.weapon_data = {"hit_radius":14.0,"tags":[]}
	weapon.runtime_stats = {"area_size":0.0,"damage_area_size":0.0}
	weapon._attached_item_instances = [{"effect_parameters":{}}]
	var event := DamageEvent.create({"damage":1,"original_damage":1,"source_weapon_id":"depth_probe"})
	for kind in ["water_wave","ice_field","black_hole","light_sword","electric_spark"]:
		weapon._attached_item_instances[0].effect_ids = ["water" if kind == "water_wave" else kind]
		var script: Script = load("res://scripts/effects/"+kind+"_effect.gd")
		script.spawn(effect_host, Vector2(120,30), weapon, event)
		var effect: Node2D
		for child in effect_host.get_children():
			if child.get_script() == script: effect = child as Node2D
		check(effect != null, "spawn " + kind)
		if effect == null: continue
		effect.set_process(false)
		if kind == "water_wave": effect._elapsed = 0.22
		if kind == "light_sword":
			effect._elapsed = 0.76
			effect._strike_started = true
		if kind == "black_hole": effect._elapsed = 0.15
		effect.queue_redraw()
	var flame := FIRE.new()
	effect_host.add_child(flame)
	flame.position = Vector2(100,30)
	flame.setup_field(70)
	preload("res://scripts/effects/enchantment_block_vfx.gd").spawn_shockwave(effect_host,Vector2(120,30),100,0).set_process(false)
	var bolt := LightningParticleEffect.new()
	effect_host.add_child(bolt)
	bolt.set_process(false)
	bolt._create_bolt_path(Vector2(30,-70),Vector2(170,70))
	BOLT_HIT.spawn(effect_host,Vector2(120,20),Vector2.RIGHT,1.0,{"skip_lights":true}).set_process(false)
	PARTICLES.emit_profile(effect_host,"impact_green",Vector2(120,20),Vector2.RIGHT)
	var actual_weapon := battle.loadout.get_weapon_instance("weapon_void_blade")
	var projectile := ProjectileInstance.new()
	effect_host.add_child(projectile)
	var texture := load(str(actual_weapon.weapon_data.projectile_texture)) as Texture2D
	check(projectile.initialize(actual_weapon,event,"depth_probe",Vector2(120,20),Vector2.RIGHT,200,texture,1.0),"real projectile initialized")
	projectile.set_physics_process(false)

func _effective_z(item: CanvasItem) -> int:
	var result := item.z_index
	if item.z_as_relative:
		var parent := item.get_parent() as CanvasItem
		if parent != null: result += _effective_z(parent)
	return result

func _check_drawables(node: Node) -> void:
	if node is CanvasItem and (node is Sprite2D or node is MultiMeshInstance2D or node.has_method("_draw")):
		check(_effective_z(node) > CombatRenderWorld.GRASS_Z and _effective_z(node) <= CombatRenderWorld.REACTION_Z, "render role is independent of high simulation parent: "+str(node.get_path()))
	for child in node.get_children(): _check_drawables(child)

func _collect_surfaces(node: Node) -> void:
	if node is CanvasItem and not node.z_as_relative and node.z_index > CombatRenderWorld.GRASS_Z and node.z_index < 0:
		surfaces.append(node)
	for child in node.get_children(): _collect_surfaces(child)

func _effects_visible(value: bool) -> void:
	for surface in surfaces: surface.visible = value

func _grass_visible(value: bool) -> void:
	for group: Dictionary in ground.grass_cells.values():
		for band: Dictionary in group.bands:
			band.back.visible = value
			band.front.visible = value

func _grass_layer(value: int) -> void:
	for group: Dictionary in ground.grass_cells.values():
		for band: Dictionary in group.bands:
			band.back.z_index = value
			band.front.z_index = value

func _image() -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	return battle.player.get_viewport().get_texture().get_image()

func _check_gpu(id: String) -> void:
	var viewport := battle.player.get_viewport()
	_hide_foreground(viewport)
	_effects_visible(false)
	var reference := await _image()
	ground.ground.hide()
	ground.decals.hide()
	viewport.transparent_bg = true
	var foreground_mask := await _image()
	_grass_visible(false)
	var actor_mask := await _image()
	ground.roots.hide()
	_effects_visible(true)
	var effect_mask := await _image()
	ground.roots.show()
	viewport.transparent_bg = false
	ground.ground.show()
	ground.decals.show()
	var no_grass := await _image()
	_grass_visible(true)
	var layered := await _image()
	var area := Rect2i(viewport.get_canvas_transform()*Rect2(-30,-110,310,270))
	area = area.intersection(Rect2i(Vector2i.ZERO,reference.get_size()))
	var covered := 0
	var leaked := 0
	var visible_effect := 0
	var grass_overlaps := 0
	var grass_leaks := 0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var delta := reference.get_pixel(x,y)-layered.get_pixel(x,y)
			var changed := absf(delta.r)+absf(delta.g)+absf(delta.b) > 0.025
			if actor_mask.get_pixel(x,y).a > 0.999:
				covered += 1
				if changed: leaked += 1
			elif changed: visible_effect += 1
			if foreground_mask.get_pixel(x,y).a > 0.999 and actor_mask.get_pixel(x,y).a < 0.01 and effect_mask.get_pixel(x,y).a > 0.999:
				grass_overlaps += 1
				var grass_delta := layered.get_pixel(x,y)-no_grass.get_pixel(x,y)
				if absf(grass_delta.r)+absf(grass_delta.g)+absf(grass_delta.b)>0.025: grass_leaks += 1
	check(covered > 300, "opaque enemy pixels tested " + id)
	check(leaked == 0, "effects never cover opaque enemies " + id + " leaks=" + str(leaked))
	check(visible_effect > 100, "effects remain visible in the battlefield " + id)
	check(grass_overlaps > 30, "opaque effects overlap real grass " + id + " pixels=" + str(grass_overlaps))
	check(grass_leaks == 0, "grass never covers opaque effects " + id + " leaks=" + str(grass_leaks))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		reference.save_png(output.path_join("reference_"+id+".png"))
		layered.save_png(output.path_join("layered_"+id+".png"))
		# Recreate the previous grass/actor plane, changing only grass depth.
		_grass_layer(0)
		var previous := await _image()
		previous.save_png(output.path_join("below_grass_"+id+".png"))
		_grass_layer(CombatRenderWorld.GRASS_Z)


func _hide_foreground(node: Node) -> void:
	# This existing GPU fixture isolates ground art; foreground and actor-local
	# occlusion are covered by combat_layer_semantics_test.
	if node is CanvasItem and not node.z_as_relative and node.z_index > 0 and node.z_index <= CombatRenderWorld.REACTION_Z:
		node.hide()
	for child in node.get_children(): _hide_foreground(child)
