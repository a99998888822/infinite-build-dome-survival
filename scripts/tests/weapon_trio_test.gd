extends "res://scripts/tests/pixel_combat_effect_test.gd"

const LAMP := "weapon_copper_lamp"
const TENTACLE := "weapon_mutant_tentacle"
const HAMMER := "weapon_earth_hammer"
var player: PlayerController
var loadout: WeaponLoadout
var hits: Array[Dictionary] = []
var emitted: Array[Dictionary] = []


func fixture(id: String, positions: Array, attachments: Array = []) -> void:
	await setup(positions)
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	player.start_weapon_ids.clear()
	player.item_inventory.clear()
	loadout = WeaponLoadout.new()
	host.add_child(loadout)
	loadout.initialize(player)
	check(loadout.equip_weapon(id), "equip " + id)
	weapon = loadout.get_weapon_instance(id)
	if attachments.size() > weapon.get_attachment_slot_count():
		loadout.upgrade_weapon(id)
		loadout.upgrade_weapon(id)
	for item_id in attachments:
		var item := player.item_inventory.add_item_from_base(item_id, "trio_test")
		check(loadout.attach_item_to_weapon(id, item.item_instance_id), "attach " + str(item_id))
	weapon.runtime_stats.crit_chance = 0
	hits.clear()
	emitted.clear()
	await frames()


func observe(effect: DirectedWeaponRuntime) -> void:
	effect.set_physics_process(false)
	effect.target_hit.connect(func(id: int, damage: int, child: bool): hits.append({"id": id, "damage": damage, "child": child}))


func lamp() -> CopperLamp:
	var effect := loadout._ensure_directed_runtime(weapon) as CopperLamp
	observe(effect)
	return effect


func tentacle() -> MutantTentacle:
	var effect := loadout._ensure_directed_runtime(weapon) as MutantTentacle
	observe(effect)
	effect.try_attack(Vector2.RIGHT)
	return effect


func hammer() -> EarthHammer:
	var effect := EarthHammer.new()
	host.add_child(effect)
	effect.initialize(weapon, Vector2.RIGHT)
	observe(effect)
	effect.node_created.connect(func(i: int, point: Vector2): emitted.append({"index": i, "point": point}))
	return effect


func advance(effect: DirectedWeaponRuntime, duration: float, step: float = 0.01) -> void:
	var left := duration
	while left > 0.000001 and not effect.cancelled:
		var delta := minf(step, left)
		effect._physics_process(delta)
		left -= delta


func wall(at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 120)
	collider.shape = shape
	body.add_child(collider)
	host.add_child(body)
	body.position = at


func effect_count(script: Script) -> int:
	var count := 0
	for child in host.get_children():
		if child.get_script() == script: count += 1
	return count


func _run() -> void:
	CampProgression.begin_transient_session()
	await setup([])
	player = PlayerController.new()
	player.auto_initialize_on_ready = false
	host.add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	loadout = WeaponLoadout.new()
	host.add_child(loadout)
	check(loadout.initialize(player) and player.get_start_weapon_ids() == ["weapon_void_blade"], "beginner starts with wooden bow")
	check(loadout.get_weapon_instance("weapon_void_blade") != null and loadout.get_weapon_instance("weapon_void_blade").has_effect("lightning"), "beginner keeps the starter lightning attachment on wooden bow")
	await fixture(LAMP, [Vector2(121, 0), Vector2(90, 50), Vector2(-70, 0)])
	var fire := lamp()
	var starts: Array = []
	fire.spray_started.connect(func(): starts.append(fire.age))
	advance(fire, 0.02)
	check(fire.target == enemies[2] and fire.heading.x < 0 and fire.firing, "lamp selects nearest alive enemy in any direction")
	check(hits.size() == 1 and hits[0].id == enemies[2].get_instance_id(), "lamp cone excludes rear/off-axis/out-of-range enemies")
	enemies[2].position = Vector2(200, 0)
	var previous_heading := fire.heading
	advance(fire, 0.16)
	check(fire.target == enemies[1] and is_equal_approx(absf(previous_heading.angle_to(fire.heading)), deg_to_rad(28.8)), "lamp turns at 180 degrees per second towards the next nearest target")
	check(fire.heading.x < 0 and hits.size() == 1, "retargeting cannot snap or damage outside the current flame cone")
	advance(fire, 0.74)
	check(fire.heading.is_equal_approx(enemies[1].position.normalized()) and hits.size() > 1, "turn reaches its target without overshoot and the flame damages its visible cone")
	for enemy in enemies: enemy.position.x += 200
	var old_hits := hits.size()
	previous_heading = fire.heading
	var heat_before := fire.heat
	advance(fire, 0.2)
	check(fire.firing and fire.burst_active and hits.size() == old_hits and fire.target == null, "losing targets keeps the current burst without out-of-range damage")
	check(fire.heading == previous_heading and fire.heat > heat_before and starts.size() == 1, "empty fire keeps direction, builds heat and never restarts the attack ledger")
	enemies[0].position = Vector2(80, 0)
	advance(fire, 2.0)
	check(fire.cooling > 0 and not fire.firing, "sustained flame overheats")
	old_hits = hits.size()
	advance(fire, 0.3)
	check(hits.size() == old_hits, "cooldown cannot deal damage")
	advance(fire, 2.6)
	check(fire.firing and hits.size() > old_hits, "cooldown ends and target resumes fire")
	var old_age := fire.age
	var old_heat := fire.heat
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(fire, 2)
	check(fire.age == old_age and fire.heat == old_heat, "pause freezes flame and heat")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	loadout.remove_weapon(LAMP)
	check(fire.cancelled and not fire.visible, "unloading lamp cancels runtime")

	await fixture(LAMP, [Vector2(80, 0)])
	wall(Vector2(40, 0))
	await frames()
	fire = lamp()
	advance(fire, 0.2)
	check(not fire.firing and hits.is_empty(), "wall prevents flame acquisition and damage")

	await fixture(LAMP, [Vector2(180, 0)])
	fire = lamp()
	advance(fire, 0.2)
	check(not fire.firing and fire.heat == 0, "idle lamp still requires an in-range target to begin")
	enemies[0].position = Vector2(80, 0)
	advance(fire, 0.1)
	enemies[0].alive = false
	weapon.attack_timer = 99
	advance(fire, 1.69)
	check(fire.firing and fire.target == null and fire.heat > 0.99, "target death and a changed cooldown cannot interrupt a started spray")
	advance(fire, 0.02)
	check(not fire.firing and not fire.burst_active and fire.cooling > 0, "empty spray still overheats after 1.8 seconds")
	advance(fire, 2.7)
	check(not fire.firing and fire.cooling == 0, "finishing cooldown without targets cannot start another spray")

	await fixture(TENTACLE, [Vector2(60, 0), Vector2(120, 15), Vector2(-35, 0), Vector2(60, 65), Vector2(180, 0)])
	var idle_limb := loadout._ensure_directed_runtime(weapon) as MutantTentacle
	check(not idle_limb.attacking and not idle_limb.visible, "idle tentacle is hidden")
	var limb := tentacle()
	check(limb.visible and limb.pose_index() == 0 and weapon.get_actual_attack_interval_seconds() == 2.4, "attack reveals curled tentacle without changing cooldown")
	for removed in ["每轮拍击", "拍击区域", "回收不重复伤害"]:
		check(not weapon.build_full_stats_text().contains(removed), "tentacle tooltip omits " + removed)
	advance(limb, 0.0954)
	check(hits.is_empty() and limb.pose_index() == 8, "fast uncoiling completes before the final slam")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(limb, 0.5)
	check(is_equal_approx(limb.age, 0.0954) and hits.is_empty(), "pause freezes tentacle animation and contact")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	advance(limb, 0.0043)
	check(hits.is_empty() and limb.pose_index() == 12, "fast slam reaches the last airborne pose before damage")
	advance(limb, 0.0004)
	check(hits.size() == 2 and hits.all(func(hit): return hit.damage == 24) and limb.pose_index() == 13, "100ms impact pose deals rectangle damage exactly once")
	check(enemies[2].current_hp == 10000 and enemies[3].current_hp == 10000 and enemies[4].current_hp == 10000, "tentacle excludes rear/outside width and reach")
	advance(limb, 0.112)
	check(limb.pose_index() == 18 and hits.size() == 2, "full recovery animation completes without repeated damage")
	advance(limb, 0.008)
	check(not limb.attacking and not limb.visible, "tentacle disappears after its 220ms attack")
	weapon.runtime_stats.projectile_count = 2
	hits.clear()
	limb.try_attack(Vector2.RIGHT)
	advance(limb, 0.23, 0.23)
	check(hits.size() == 4, "additional projectile becomes another complete slap without missed long-frame contacts")

	await fixture(TENTACLE, [Vector2(80, 0)])
	limb = tentacle()
	# At 600px/s the previous 280ms windup passed this target before contact.
	for _i in 13:
		player.position.x += 600.0 / 120.0
		advance(limb, 1.0 / 120.0)
	check(hits.size() == 1 and limb.global_position == player.global_position, "fast-moving tentacle hits before passing the target and follows the player")
	advance(limb, 0.12)
	check(hits.size() == 1 and not limb.visible, "fast-moving attack recovers without repeated hits")

	await fixture(TENTACLE, [Vector2(60, 0)], ["scroll_split"])
	limb = tentacle()
	advance(limb, 0.11)
	check(hits.any(func(hit): return hit.child) and limb.split_used, "real hit creates one generation of weak side slaps")
	var split_hits := hits.size()
	advance(limb, 0.3)
	check(hits.size() == split_hits, "recovery and split effects do not recursively hit")
	check(not limb.visible and limb.branches.is_empty(), "split tentacles also disappear after recovery")
	player.alive = false
	advance(limb, 0.1)
	check(limb.cancelled, "player death cancels tentacle")

	await fixture(HAMMER, [Vector2(40, 0), Vector2(104, 0), Vector2(200, 70), Vector2(-60, 0)])
	var quake := hammer()
	check(is_zero_approx(quake.hammer_opacity()), "hammer starts invisible")
	advance(quake, 0.55)
	check(hits.is_empty() and emitted.is_empty() and quake.hammer_opacity() > 0.9, "slow appearance does not prematurely damage")
	advance(quake, 0.071)
	check(emitted.size() == 1 and hits.size() == 1, "60ms slam starts first ground node")
	player.position = Vector2(200, 200)
	advance(quake, 0.401, 0.401)
	check(emitted.size() == 5 and emitted[4].point == Vector2(296, 0), "absolute scheduling emits five locked-origin nodes across a long frame")
	check(emitted[1].point - emitted[0].point == Vector2(64, 0), "approved 64px spacing")
	check(hits.size() == 2 and quake.hammer_opacity() == 0, "hammer disappears while the wave damages each enemy only once")
	old_age = quake.age
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	advance(quake, 1)
	check(quake.age == old_age, "pause freezes pending wave")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	loadout.remove_weapon(HAMMER)
	check(quake.cancelled, "unloading hammer cancels pending nodes")

	await fixture(HAMMER, [], ["scroll_electric_spark", "scroll_split"])
	quake = hammer()
	advance(quake, 1.03, 1.03)
	check(emitted.size() == 5 and hits.is_empty(), "empty ground still produces five impacts")
	check(effect_count(ElectricSparkEffect) == 5, "exactly one lightning warning per main node, even on empty ground")
	check(quake.nodes.size() > 5 and effect_count(ElectricSparkEffect) == 5, "split cracks do not duplicate enchantment chains")
	var pierce := player.item_inventory.add_item_from_base("scroll_pierce", "trio_test")
	check(not weapon.get_attachment_incompatibility(pierce).is_empty(), "ineffective pierce is rejected before consuming a slot")
	weapon.runtime_stats.projectile_count = 99
	check(weapon.get_ground_node_count() == 8 and weapon.get_attack_range() == 488, "additional nodes are capped at eight")

	await fixture(HAMMER, [], ["scroll_lightning"])
	quake = hammer()
	advance(quake, 1.03, 1.03)
	check(effect_count(LightningParticleEffect) == 0, "chain lightning has no fake victim or no-target visual")
	await fixture(HAMMER, [Vector2(90, 60)], ["scroll_lightning"])
	quake = hammer()
	advance(quake, 0.621, 0.621)
	check(effect_count(LightningParticleEffect) == 1 and hits.is_empty(), "ground node finds a nearby real chain target outside native rectangle")
	await frames()
	check(enemies[0].current_hp < 10000, "real lightning chain damages chosen target")

	await fixture(HAMMER, [Vector2(40, 0), Vector2(105, 0)])
	wall(Vector2(76, 0))
	await frames()
	quake = hammer()
	advance(quake, 1.1, 1.1)
	check(emitted.size() == 1 and hits.size() == 1 and quake.blocked, "terrain blocks further cracks and their damage")

	for kind in ["water", "light_sword", "black_hole", "fire", "explosion", "ice", "wind"]:
		await fixture(HAMMER, [], ["scroll_" + kind])
		quake = hammer()
		advance(quake, 0.621, 0.621)
		var effect_script: Script = load("res://scripts/effects/" + ({"water":"water_wave", "fire":"fire_seed", "ice":"ice_field", "wind":"wind_blade"}.get(kind, kind)) + (".gd" if kind == "fire" else "_effect.gd"))
		# The existing fire dispatcher emits four seeds per impact; other kinds
		# create one effect node. Verify one dispatch, not one visual particle.
		var expected := FireSeed.MAX_VISUAL_SEEDS_PER_IMPACT if kind == "fire" else 1
		check(effect_count(effect_script) == expected, "empty ground invokes existing " + kind + " effect once")
	await fixture(HAMMER, [Vector2(60, 0)], ["scroll_wind"])
	quake = hammer()
	advance(quake, 0.621, 0.621)
	var hp := enemies[0].current_hp
	for node in host.get_children():
		if node is WindBladeEffect:
			node.global_position = enemies[0].global_position
			node._damage_path_enemies()
	check(enemies[0].current_hp < hp and enemies[0]._knockback_timer > 0, "ground wind applies real hit damage and knockback without recursive blades")
	check(effect_count(WindBladeEffect) == 1, "ground wind hit does not spawn recursive blades")

	for id in [LAMP, TENTACLE, HAMMER]:
		await fixture(id, [])
		for level in range(2,6): check(loadout.upgrade_weapon(id), "upgrade %s to %d" % [id,level])
		check(not weapon.upgrade() and weapon.get_attachment_slot_count() == 2, "rarity slots and level cap " + id)
		var pool := ShopOfferGenerator.new().build_shop_candidate_pool({"load_capacity":100,"current_load":0,"luck":350})
		check(pool.any(func(offer): return offer.target_id == id), "shop/reward candidate " + id)
		check(load(weapon.weapon_data.icon).get_size() == Vector2(64,64), "installed icon " + id)
		check(not weapon.build_full_stats_text().is_empty(), "weapon stats tooltip " + id)
	var validator := DataValidator.new()
	check(validator.validate_all(DataRegistry.tables, DataRegistry.records_by_id), "full configuration validation")
	for error in validator.errors: print(error)
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	await get_tree().create_timer(0.25).timeout
	CampProgression.end_transient_session()
	print("WEAPON_TRIO_TEST checks=",checks," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
