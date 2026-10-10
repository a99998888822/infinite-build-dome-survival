extends Node
## Real GameRoot, reaction resolver, lightning scheduler and damage contacts.
const BASE := "res://artifacts/validation/element_reaction_text_install_20261010/"
const TEXT = preload("res://scripts/effects/element_reaction_text.gd")
const REACTION = preload("res://scripts/effects/element_reaction_resolver.gd")
const CASES := ["thunder_fire", "conduct_chain", "conduct_repeat", "mixed"]
var game: GameRoot
var battle: BattleRoot
var host: Node2D
var targets: Array[EnemyController] = []
var weapon: WeaponInstance
var event: DamageEvent
var home := Vector2.ZERO
var receipts: Array = []
var hits: Array = []
var failures: Array = []
var checks := 0
var tick := 0
var captured := 0
var report := {}
var graphical := false
var output_base := BASE

func _ready() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await get_tree().create_timer(200, true, false, true).timeout
	push_error("REACTION_TEXT_TIMEOUT")
	get_tree().quit(99)

func frames(count: int = 2) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func reset(offsets: Array) -> void:
	if is_instance_valid(host): host.queue_free()
	for text in get_tree().get_nodes_in_group(TEXT.GROUP): text.cancel()
	for effect in get_tree().get_nodes_in_group("combat_particle_counters"):
		if effect is LightningParticleEffect or effect is ElectricSparkEffect: effect.queue_free()
	for target in targets:
		if is_instance_valid(target): target.queue_free()
	targets.clear()
	await frames(3)
	host = Node2D.new()
	battle.player.get_parent().add_child(host)
	for i in offsets.size():
		var target := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		host.add_child(target)
		target.global_position = home + offsets[i]
		target.current_hp = 100000
		target.set_physics_process(false)
		target.damage_received.connect(func(id: String, damage: int): hits.append([tick,i,id,damage]))
		targets.append(target)
	weapon = WeaponInstance.new()
	weapon.initialize("weapon_void_blade", battle.player)
	weapon.use_active_range_rules = true
	weapon._attached_item_instances = [{"effect_ids":["lightning","electric_spark"],"effect_parameters":{"chain_count":2,"chain_interval":0.18}}]
	event = DamageEvent.create({"damage":12,"original_damage":12,"source_weapon_id":weapon.weapon_id,"source_player":battle.player})
	await frames(3)
	receipts.clear()
	hits.clear()
	tick = 0
	seed(49007)

func condition(index: int, element: String) -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	REACTION.apply_element(targets[index],element,{"parent":host,"hit_position":targets[index].global_position,"damage":12,"original_damage":12,"burn_tick_damage":0,"source_id":weapon.weapon_id})
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)

func ground(center: Vector2, radius: float = 32.0) -> LightningParticleEffect:
	return LightningParticleEffect.spawn_ground_strike(host,center,weapon,event,"",182,radius)

func chain() -> void:
	LightningParticleEffect.spawn(host,home,targets[0],weapon,event,Vector2.RIGHT)

func advance() -> void:
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for label in get_tree().get_nodes_in_group(TEXT.GROUP):
		if not label.is_queued_for_deletion(): label._physics_process(1.0/60)
	# Match the autoload scheduler's normal order before scene effect processing.
	EffectScheduler._process(1.0/60)
	for tween in get_tree().get_processed_tweens(): tween.custom_step(1.0/60)
	for target in targets:
		if target.has_meta(&"combat_feedback_r02"): target.get_meta(&"combat_feedback_r02")._physics_process(1.0/60)
		for child in target.get_children():
			if child.get_script() in [preload("res://scripts/effects/enemy_status_visual.gd"),preload("res://scripts/effects/lightning_status_visual.gd")]: child._process(1.0/60)
	for node in get_tree().get_nodes_in_group("combat_particle_counters") + get_tree().get_nodes_in_group("element_reaction_cues") + get_tree().get_nodes_in_group("particle_light_field"):
		if not node.is_queued_for_deletion() and node.has_method("_process"): node._process(1.0/60)
	AudioManager._process(1.0/60)
	AudioManager.flush_combat_audio(true)
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	tick += 1

func labels(kind: String = "") -> Array:
	return get_tree().get_nodes_in_group(TEXT.GROUP).filter(func(node: Node): return not node.is_queued_for_deletion() and (kind.is_empty() or node.kind == kind))

func count(kind: String) -> int:
	return receipts.filter(func(item: Array): return item[1] == kind).size()

func run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN",false)
	preload("res://scripts/tests/cast_policy_test_support.gd").apply(false)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames(4)
	if not flow.confirm_character_selection(): get_tree().quit(3); return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root
	battle.set_process(false)
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.active_controller.indicator.hide()
	battle.active_controller.cursor_icon.hide()
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	battle.player.set_physics_process(false)
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	await frames(12)
	battle.hud.set_process(false)
	battle.combat_guide.hide()
	home = battle.player.global_position
	AudioManager.stop_bgm()
	Engine.time_scale = 0
	get_tree().node_added.connect(func(node: Node):
		if node.get_script() == TEXT: receipts.append([tick,node.kind,node.text]))
	await test_rules()
	for id in CASES:
		for variant in ["before","r04"]: await run_case(id,variant)
		for key in ["health","hits","states","rng_next"]:
			check(report[id+"_before"][key] == report[id+"_r04"][key],id+" preserves "+key)
	var path := "validation/gpu_capture.json" if graphical else "validation/headless.json"
	FileAccess.open(output_base+path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captured":captured,"cases":report},"\t"))
	GameGlobal.clear_runtime_flag(TEXT.FLAG)
	Engine.time_scale = 1
	game.queue_free()
	await frames(6)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("REACTION_TEXT_DONE checks=",checks," captured=",captured," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func test_rules() -> void:
	GameGlobal.clear_runtime_flag(TEXT.FLAG)
	check(TEXT.enabled(),"approved reaction text is default on")
	await reset([Vector2(90,0)])
	condition(0,"water")
	ground(targets[0].global_position)
	advance()
	check(count("conduct")==1 and not targets[0].has_status("wet"),"production default displays the actual conduction")
	GameGlobal.set_runtime_flag(TEXT.FLAG,false)
	await reset([Vector2(90,0)])
	condition(0,"water")
	ground(targets[0].global_position)
	advance()
	check(count("conduct")==0 and not targets[0].has_status("wet"),"comparison override preserves reaction behavior without text")
	GameGlobal.clear_runtime_flag(TEXT.FLAG)
	await reset([Vector2(90,-14),Vector2(110,12),Vector2(130,0)])
	for i in 3: condition(i,"fire")
	var bolt := ground(home+Vector2(110,0),40)
	advance()
	check(count("thunder_fire")==1 and targets.all(func(e: EnemyController): return not e.has_status("burning")),"one ground strike detonates several targets but shows one name")
	check(labels("thunder_fire")[0].text == "雷火爆燃","exact orange reaction name")
	var prior := hits.size()
	GameGlobal.set_runtime_flag("battle_runtime_paused",false)
	bolt._strike_ground(home+Vector2(110,0))
	GameGlobal.set_runtime_flag("battle_runtime_paused",true)
	check(count("thunder_fire")==1 and hits.size()==prior,"visual lightning echo does not repeat damage or text")
	for i in 3: condition(i,"fire")
	ground(home+Vector2(110,0),40)
	advance()
	check(count("thunder_fire")==2,"a new independent strike gets its own name")
	await reset([Vector2(70,0),Vector2(145,-10),Vector2(230,10)])
	for i in 3: condition(i,"fire")
	chain()
	for i in 40: advance()
	check(count("thunder_fire")==1,"one chain instance displays thunderfire once")
	await reset([Vector2(70,0),Vector2(145,-10),Vector2(230,10)])
	for i in 3: condition(i,"water")
	chain()
	for i in 30: advance()
	check(count("conduct")==3 and targets.all(func(e: EnemyController): return not e.has_status("wet")),"each wet chain target produces one conduction name")
	check(labels("conduct").all(func(label: Label): return label.text=="导电" and label.get_theme_font_size("font_size")==14),"exact blue-white text and 14 px review size")
	await reset([Vector2(110,0)])
	for i in 5:
		condition(0,"water")
		ground(targets[0].global_position)
		advance()
	check(count("conduct")==5,"five rapid actual conductions produce five names without throttling")
	var text_nodes := labels()
	var contact_origin := true
	for label in text_nodes:
		if (label.origin + label.size * 0.5).distance_to(targets[0].global_position) > 1.0: contact_origin=false
		if label.global_position.x != label.origin.x or label.global_position.y > label.origin.y: contact_origin=false
	check(contact_origin,"every repeated label starts at contact and moves straight upward")
	var age: float = text_nodes[0].age
	text_nodes[0]._physics_process(0.4)
	check(text_nodes[0].age==age,"pause freezes text")
	ground(targets[0].global_position)
	advance()
	check(count("conduct")==5,"dry target does not repeat conduction")
	for i in 60: advance()
	check(labels().is_empty(),"text expires without accumulating nodes")
	await reset([Vector2(110,0)])
	condition(0,"water")
	targets[0].current_hp = 1
	ground(targets[0].global_position)
	advance()
	check(count("conduct")==1 and not targets[0].alive,"lethal contact still shows the actual reaction")
	var still_visible: Label = labels()[0]
	targets[0].queue_free()
	await frames()
	check(is_instance_valid(still_visible),"target removal does not cut off the floating text")
	battle.wave_manager.clear_battle_entities()
	check(still_visible.is_queued_for_deletion() and not still_visible.visible,"wave cleanup clears reaction labels immediately")
	await reset([Vector2(110,0)])
	condition(0,"fire")
	condition(0,"water")
	condition(0,"ice")
	check(receipts.is_empty(),"steam and freeze do not receive extra text")

func run_case(id: String, variant: String) -> void:
	if variant == "before": GameGlobal.set_runtime_flag(TEXT.FLAG,false)
	else: GameGlobal.clear_runtime_flag(TEXT.FLAG)
	var offsets := [Vector2(90,-16),Vector2(110,12),Vector2(130,0)]
	if id=="conduct_chain": offsets=[Vector2(70,0),Vector2(145,-10),Vector2(230,10)]
	if id=="conduct_repeat": offsets=[Vector2(110,0)]
	await reset(offsets)
	for i in targets.size(): condition(i,"fire" if id=="thunder_fire" or (id=="mixed" and i==0) else "water")
	for f in 96:
		if f==12:
			if id=="conduct_chain": chain()
			elif id!="conduct_repeat": ElectricSparkEffect.spawn(host,home+Vector2(110,0),weapon,event)
		if id=="conduct_repeat" and f in [12,24,36]:
			condition(0,"water")
			ground(targets[0].global_position)
		for sub in 2: advance()
		if graphical and f in [12,25,34,40,50]:
			await frames(1)
			await RenderingServer.frame_post_draw
			var screenshot := get_tree().root.get_texture().get_image()
			var clip := screenshot.get_region(Rect2i(400,150,700,420))
			clip.save_png(output_base+"frames/%s_%s_%03d.png"%[id,variant,f])
			if f==34: screenshot.save_png(output_base+"validation/"+id+"_"+variant+"_context.png")
			captured+=1
		else: await frames(1)
	var sorted_hits := hits.duplicate(true)
	sorted_hits.sort_custom(func(a: Array,b: Array): return JSON.stringify(a)<JSON.stringify(b))
	report[id+"_"+variant]={"text":receipts.duplicate(true),"health":targets.map(func(e:EnemyController):return e.current_hp),"hits":sorted_hits,"states":targets.map(func(e:EnemyController):return [e.has_status("wet"),e.has_status("burning"),e._stunned_remaining]),"rng_next":randf()}
	if variant=="r04":
		check(count("thunder_fire")== (1 if id in ["thunder_fire","mixed"] else 0),id+" exact thunderfire count")
		check(count("conduct")== (3 if id in ["conduct_chain","conduct_repeat"] else 2 if id=="mixed" else 0),id+" exact conduction count")
	print("R04_CLIP ",id," ",variant," texts=",receipts)
