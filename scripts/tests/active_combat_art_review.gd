extends Node
## Interactive art review built on the real GameRoot and weapon runtimes.
## Fixtures: all 11 weapons, stationary durable targets, no wave spawning.
## Numerical balance and cleanup phases remain separate work.

const INDICATOR = preload("res://scripts/battle/weapon_attack_indicator.gd")
const MARKER = preload("res://scripts/battle/move_destination_marker.gd")
const BAR = preload("res://scripts/ui/active_combat_weapon_bar.gd")
const IDS := ["weapon_void_blade", "weapon_plasma_cannon", "weapon_iron_grenade_cannon",
	"weapon_kunyu_ritual_tome", "weapon_rentier_purse", "weapon_copper_lamp",
	"weapon_mutant_tentacle", "weapon_earth_hammer", "weapon_camp_dagger",
	"weapon_nightwatch_spear", "weapon_meteor_flail"]
const REVIEW_COOLDOWNS := [1.6, 4.2, 5.0, 4.0, 2.8, 5.0, 3.6, 5.5, 1.5, 2.4, 4.0]

var game: GameRoot
var battle: BattleRoot
var flow: MainFlowCoordinator
var player: PlayerController
var loadout: WeaponLoadout
var weapons: Array[WeaponInstance] = []
var states: Array[Dictionary] = []
var targets: Array[EnemyController] = []
var indicator: WeaponAttackIndicator
var marker: MoveDestinationMarker
var bar: ActiveCombatWeaponBar
var ui: CanvasLayer
var heading_label: Label
var helper: Label
var movement_button: Button
var page_button: Button
var selected := -1
var page := 0
var destination := Vector2.ZERO
var has_destination := false
var last_direction := Vector2.RIGHT
var keyboard_mode := false
var keys: Dictionary = {}
var right_held := false
var review_ready := false
var capture_dir := ""
var automatic := false
var synthetic_pointer := Vector2(155, 0)
var hit_counts: Dictionary = {}
var sequence_index := 0
var sequence_ticks: Array[int] = []
var assertions := 0
var failures: Array[String] = []


func _ready() -> void:
	process_physics_priority = -10
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--art-capture" or arg == "--art-check":
			automatic = true
	_boot.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _boot() -> void:
	CampProgression.begin_transient_session()
	seed(410042026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	await frames(12)
	if automatic:
		get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	flow = game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter", [IDS[0]])
	await frames(4)
	if not flow.confirm_character_selection():
		push_error("ART_REVIEW could not enter the production battle")
		get_tree().quit(2)
		return
	battle = (game.get_node("SceneDirector") as GameSceneDirector).battle_root as BattleRoot
	battle.set_process(false)
	# This fixture owns its input/scheduling; formal combat is covered separately.
	battle.active_controller.enabled = false
	battle.active_controller.clear_input()
	battle.loadout.set_active_combat_enabled(false)
	battle.player.active_controls = false
	# The review owns Esc priority; BattleRoot otherwise opens its overlay first.
	battle.set_process_unhandled_input(false)
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_enemies()
	player = battle.player
	loadout = battle.loadout
	player.set_process_input(false)
	player.current_hp = 5000
	await frames(3)
	for id in IDS:
		var weapon := loadout.get_weapon_instance(id)
		if weapon == null:
			weapon = WeaponInstance.new()
			weapon.initialize(id, player)
			weapon.principal_getter = Callable(loadout, "get_current_principal")
			loadout.weapon_instances.append(weapon)
		weapons.append(weapon)
		states.append({"left": 0.0, "total": REVIEW_COOLDOWNS[states.size()], "active": false, "body": null, "action_left": 0.0})
	# Review fixture intentionally shows all weapons, beyond a normal starting loadout.
	for i in 7:
		var enemy := load("res://scenes/enemy/mutated_grub.tscn").instantiate() as EnemyController
		enemy.auto_initialize_on_ready = false
		player.get_parent().add_child(enemy)
		enemy.initialize("enemy_mutated_grub", player)
		enemy.current_hp = 100000
		enemy.set_physics_process(false)
		enemy.damage_received.connect(_record_hit)
		targets.append(enemy)
	_place_targets()
	indicator = INDICATOR.new()
	player.get_parent().add_child(indicator)
	marker = MARKER.new()
	player.get_parent().add_child(marker)
	_build_ui()
	flow.state_changed.connect(_flow_changed)
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	review_ready = true
	_select_weapon(0)
	if automatic:
		await frames(8)
		await _capture_suite()


func _record_hit(id: String, _damage: int) -> void:
	hit_counts[id] = int(hit_counts.get(id, 0)) + 1


func _place_targets() -> void:
	var points := [Vector2(52, 0), Vector2(105, -65), Vector2(145, 35), Vector2(190, -45), Vector2(245, 0), Vector2(130, 85), Vector2(-95, -60)]
	for i in targets.size():
		targets[i].global_position = player.global_position + points[i]


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 14
	add_child(ui)
	bar = BAR.new()
	ui.add_child(bar)
	bar.setup(weapons)
	var panel := PanelContainer.new()
	panel.position = Vector2(330, 70)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.016, 0.035, 0.043, 0.86)
	style.border_color = Color(0.30, 0.48, 0.53, 0.70)
	style.set_border_width_all(1)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	heading_label = Label.new()
	heading_label.add_theme_font_size_override("font_size", 18)
	heading_label.add_theme_color_override("font_color", Color("d7f1ff"))
	content.add_child(heading_label)
	helper = Label.new()
	helper.add_theme_font_size_override("font_size", 13)
	helper.add_theme_color_override("font_color", Color("a9c7cd"))
	helper.text = "美术交互预览 · 静止测试目标 · 试用冷却，非最终数值\n数字键选武器 / 左键释放 / 右键移动 / Esc 取消或暂停"
	content.add_child(helper)
	var row := HBoxContainer.new()
	content.add_child(row)
	movement_button = Button.new()
	movement_button.text = "移动：鼠标右键"
	movement_button.focus_mode = Control.FOCUS_NONE
	movement_button.pressed.connect(_toggle_movement)
	row.add_child(movement_button)
	page_button = Button.new()
	page_button.text = "审阅下一组武器 [Tab]"
	page_button.focus_mode = Control.FOCUS_NONE
	page_button.pressed.connect(_switch_page)
	row.add_child(page_button)
	var hud := battle.hud as BattleHud
	hud.exp_label.hide()
	hud._experience_frame.hide()
	hud.exp_bar.custom_minimum_size.y = 4
	hud.exp_bar.size.y = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("68c691")
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.03, 0.06, 0.05, 0.70)
	hud.exp_bar.add_theme_stylebox_override("fill", fill)
	hud.exp_bar.add_theme_stylebox_override("background", back)
	hud.exp_bar.value = 38
	hud._performance_line.hide()
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	if bar == null:
		return
	bar.apply_layout()
	var hud := battle.hud as BattleHud
	hud.exp_panel.offset_top = -14
	hud.exp_panel.offset_bottom = -10
	if hud._bond_row != null:
		hud._bond_row.position.y = get_viewport().get_visible_rect().size.y - bar.slot_size - 55


func _combat() -> bool:
	return review_ready and flow.get_current_state() == MainFlowCoordinator.STATE_WAVE_COMBAT


func _flow_changed(_previous: String, current: String) -> void:
	_cancel_aim()
	has_destination = false
	right_held = false
	keys.clear()
	player.set_mobile_move_direction(Vector2.ZERO)
	marker.clear_destination()
	ui.visible = current == MainFlowCoordinator.STATE_WAVE_COMBAT
	if ui.visible:
		_layout.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and review_ready:
		_cancel_aim()
		keys.clear()
		right_held = false
		has_destination = false
		player.set_mobile_move_direction(Vector2.ZERO)
		marker.clear_destination()


func _input(event: InputEvent) -> void:
	if not review_ready or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		keys[key.keycode] = key.pressed
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if selected >= 0:
			_cancel_aim()
		elif flow.get_current_state() == MainFlowCoordinator.STATE_ESC_OVERLAY:
			flow.close_esc_overlay()
		elif _combat():
			flow.request_esc_overlay()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _combat() or automatic:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB:
			_switch_page()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
			_select_weapon(int(key.keycode - KEY_1) + page * 10)
		elif key.keycode == KEY_0:
			_select_weapon(9 + page * 10)
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			right_held = mouse.pressed
			if mouse.pressed:
				_cancel_aim()
				if not keyboard_mode:
					_request_move(_pointer())
		elif mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and selected >= 0:
			_fire(selected)


func _pointer() -> Vector2:
	return player.global_position + synthetic_pointer if automatic else player.get_global_mouse_position()


func _select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	_cancel_aim()
	if weapons[index].is_copper_lamp() or weapons[index].is_ritual_tome():
		_fire(index)
		return
	selected = index
	indicator.show()
	heading_label.text = "%02d  %s · 瞄准" % [index + 1, str(weapons[index].weapon_data.display_name)]


func _cancel_aim() -> void:
	selected = -1
	if indicator != null:
		indicator.hide()


func _request_move(point: Vector2) -> void:
	destination = point
	has_destination = true
	marker.show_destination(point)


func _toggle_movement() -> void:
	keyboard_mode = not keyboard_mode
	has_destination = false
	right_held = false
	keys.clear()
	marker.clear_destination()
	player.set_mobile_move_direction(Vector2.ZERO)
	movement_button.text = "移动：方向键 / WASD" if keyboard_mode else "移动：鼠标右键"


func _switch_page() -> void:
	page = 1 - page
	bar.set_preview_page(page)
	_cancel_aim()
	heading_label.text = "第二组 · 按 1 选择流星摆锤" if page == 1 else "第一组 · 按 1—9 / 0 选择武器"


func _physics_process(_delta: float) -> void:
	if not _combat():
		return
	var direction := Vector2.ZERO
	if keyboard_mode:
		direction.x = float(bool(keys.get(KEY_D, false)) or bool(keys.get(KEY_RIGHT, false))) - float(bool(keys.get(KEY_A, false)) or bool(keys.get(KEY_LEFT, false)))
		direction.y = float(bool(keys.get(KEY_S, false)) or bool(keys.get(KEY_DOWN, false))) - float(bool(keys.get(KEY_W, false)) or bool(keys.get(KEY_UP, false)))
		direction = direction.normalized()
	elif has_destination:
		if right_held and not automatic:
			destination = _pointer()
			marker.global_position = destination
		var distance := player.global_position.distance_to(destination)
		if distance < 4:
			has_destination = false
			marker.clear_destination()
		else:
			direction = player.global_position.direction_to(destination)
	if not direction.is_zero_approx():
		last_direction = direction
	player.set_mobile_move_direction(direction)


func _process(delta: float) -> void:
	if not _combat():
		return
	if selected >= 0:
		indicator.global_position = player.global_position
		indicator.configure(weapons[selected], _pointer() - player.global_position, _can_fire(selected))
	for i in states.size():
		var state := states[i]
		if state.active:
			state.action_left = maxf(0, state.action_left - delta)
			var body: Variant = state.body
			var playing := false
			if is_instance_valid(body) and not body.cancelled:
				if body is CopperLamp:
					body.manual_direction = last_direction
					playing = body.burst_active
				elif body is MutantTentacle:
					playing = body.attacking
				elif body is MeteorFlail:
					playing = body.is_swinging()
				elif body.has_method("is_attacking"):
					playing = body.is_attacking()
			if not playing and state.action_left <= 0:
				state.active = false
				state.left = state.total
				if is_instance_valid(body) and (body is CopperLamp or body is MutantTentacle):
					body.cancel()
				state.body = null
		else:
			state.left = maxf(0, state.left - delta)
		bar.update_slot(i, state.left, state.total, state.active, selected == i)


func _can_fire(index: int) -> bool:
	return not states[index].active and float(states[index].left) <= 0


func _fire(index: int) -> bool:
	if not _combat() or not _can_fire(index):
		return false
	var weapon := weapons[index]
	var offset := _pointer() - player.global_position
	var aim := offset.normalized() if offset.length_squared() > 0.01 else last_direction
	var visual_root := loadout._get_visual_root()
	weapon.begin_attack()
	var body: Node2D = null
	if weapon.is_copper_lamp():
		var lamp := CopperLamp.new()
		visual_root.add_child(lamp)
		lamp.initialize(weapon)
		lamp.manual_control = true
		lamp.manual_direction = last_direction
		lamp.externally_driven = true
		lamp.burst_active = true
		body = lamp
	elif weapon.is_mutant_tentacle():
		var tentacle := MutantTentacle.new()
		visual_root.add_child(tentacle)
		tentacle.initialize(weapon)
		tentacle.try_attack(aim)
		body = tentacle
	elif weapon.is_earth_hammer():
		var hammer := EarthHammer.new()
		visual_root.add_child(hammer)
		hammer.initialize(weapon, aim)
		body = hammer
	elif weapon.is_camp_dagger():
		var dagger := CampDagger.new()
		visual_root.add_child(dagger)
		dagger.initialize(weapon, aim)
		dagger.configure_continuous_combo()
		body = dagger
	elif weapon.is_nightwatch_spear():
		var spear := NightwatchSpear.new()
		visual_root.add_child(spear)
		spear.initialize(weapon, aim)
		body = spear
	elif weapon.is_meteor_flail():
		var flail := MeteorFlail.new()
		visual_root.add_child(flail)
		flail.initialize(weapon, aim)
		body = flail
	elif weapon.is_ritual_tome():
		var domain := RitualDomain.new()
		visual_root.add_child(domain)
		domain.initialize(weapon, true)
		body = domain
	elif weapon.is_grenade():
		for point in INDICATOR.grenade_landings(weapon, offset):
			var grenade := GrenadeProjectile.new()
			visual_root.add_child(grenade)
			grenade.initialize(weapon, weapon.calculate_damage_events()[0], player.global_position, player.global_position + point)
			grenade.elliptical_blast = true
			grenade.blast_radius = AttackFootprint.grenade_blast_axes(weapon).x
	elif weapon.is_coin_purse():
		loadout._fire_coins(weapon, aim)
	else:
		loadout._spawn_projectiles(weapon, weapon.calculate_damage_events()[0], player.global_position + aim * weapon.get_attack_range(), weapon.get_attack_range())
	if not weapon.is_coin_purse():
		weapon.volley_index += 1
	weapon.attack_timer = 0
	states[index].active = true
	states[index].body = body
	states[index].action_left = 0.18
	if weapon.is_grenade():
		states[index].action_left = float(weapon.weapon_data.get("grenade_flight_seconds", 0.45)) + GrenadeProjectile.BLAST_LIFETIME
	heading_label.text = "%02d  %s · 已释放" % [index + 1, str(weapon.weapon_data.display_name)]
	_cancel_aim()
	return true


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error("ART_REVIEW " + message)


func _save_frame(name: String, sequence: bool = false) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	_check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "save " + name)
	if sequence:
		image.save_png(capture_dir.path_join("frames/frame_%04d.png" % sequence_index))
		sequence_ticks.append(Engine.get_physics_frames())
		sequence_index += 1


func _capture_suite() -> void:
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
		DirAccess.make_dir_recursive_absolute(capture_dir.path_join("indicators"))
	_check(weapons.size() == 11, "all eleven weapons")
	_select_weapon(8)
	_select_weapon(9)
	_check(selected == 9, "latest number selection wins")
	_cancel_aim()
	_check(selected == -1 and not indicator.visible, "cancel hides indicator")
	var initial := player.global_position
	heading_label.text = "右键目的地 · 用户提供的 8 帧动画"
	_request_move(initial + Vector2(120, 140))
	for i in 24:
		await frames(2)
		if i % 3 == 0:
			await _save_frame("movement_%02d" % i, true)
	_check(player.global_position.distance_to(initial) > 20, "right-click destination moves player")
	_check(last_direction.y > 0, "two-dimensional move direction retained")
	has_destination = false
	player.set_mobile_move_direction(Vector2.ZERO)
	marker.clear_destination()
	player.global_position = initial
	last_direction = Vector2.RIGHT
	_place_targets()
	for index in weapons.size():
		if index > 0:
			loadout._clear_weapon_runtime(weapons[index - 1])
			# Let the previous attack's numbers finish before taking the next art plate.
			await frames(40)
		synthetic_pointer = Vector2(155, 0)
		for target in targets:
			target.current_hp = 100000
		if weapons[index].is_copper_lamp() or weapons[index].is_ritual_tome():
			# Show instant-weapon footprints only on the review plate.
			indicator.configure(weapons[index], Vector2.RIGHT * 150)
			indicator.global_position = player.global_position
			indicator.show()
			heading_label.text = "%02d  %s · 范围审阅（实战按键即放）" % [index + 1, str(weapons[index].weapon_data.display_name)]
		else:
			_select_weapon(index)
		await frames(5)
		await _save_frame("aim_%02d" % (index + 1), true)
		await _export_indicator(index)
		if weapons[index].is_grenade():
			for direction in [Vector2.RIGHT, Vector2(1, -1), Vector2.DOWN]:
				synthetic_pointer = direction * 1500
				await frames(3)
				await _save_frame("grenade_clamped_%d" % int(direction.angle() * 100), true)
			synthetic_pointer = Vector2(155, 0)
		var before := int(hit_counts.get(IDS[index], 0))
		_check(_fire(index), "cast " + IDS[index])
		_check(selected == -1, "release exits aim " + IDS[index])
		_check(not _fire(index), "same weapon cannot reenter " + IDS[index])
		var observations := 72 if weapons[index].is_ritual_tome() else 24
		for i in observations:
			await frames(2)
			if i in [2, 7, 14, 23, 32, 44, 56, 71]:
				await _save_frame("cast_%02d_%02d" % [index + 1, i], true)
		if weapons[index].is_ritual_tome():
			_check(not states[index].active and states[index].left > 0, "tome cooldown follows all sequential marks")
		_check(int(hit_counts.get(IDS[index], 0)) > before, "production weapon hits target " + IDS[index])
		if index == 0:
			_check(float(states[index].left) > 0, "cooldown begins after ranged action")
	# An actual overlapping attack pair demonstrates independent state and HUD.
	for i in [5, 7]:
		states[i].left = 0
		states[i].active = false
	_fire(5)
	_fire(7)
	_check(states[5].active and states[7].active, "different weapons execute concurrently")
	await frames(10)
	await _save_frame("parallel_attacks", true)
	_select_weapon(8)
	await frames(3)
	await _save_frame("battle_overview")
	flow.request_esc_overlay()
	await frames(22)
	_check(not ui.visible, "battle-only bar hidden in Esc")
	_check(battle.esc_overlay.weapon_strip.visible, "original Esc weapon strip remains")
	await _save_frame("esc_original_layout")
	flow.close_esc_overlay()
	await frames(6)
	_check(ui.visible, "battle bar restored after Esc")
	var report := {"real_game_root": true, "fixture": "all 11 weapons, stationary durable enemies, trial cooldowns, no wave spawning",
		"assertions": assertions, "failures": failures, "weapon_hits": hit_counts, "sequence_frames": sequence_index, "sequence_physics_ticks": sequence_ticks,
		"source_move_sheet": "res://assets/ui/combat/move_destination.png", "weapon_ids": IDS}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("review_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("ACTIVE_COMBAT_ART_REVIEW checks=", assertions, " failures=", failures.size(), " hits=", hit_counts)
	review_ready = false
	states.clear()
	weapons.clear()
	targets.clear()
	game.queue_free()
	await frames(4)
	AudioManager.stop_combat_sfx()
	# The automated process exits here; drain UI and music voices as well as combat.
	for sound in AudioManager.get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.stream = null
	await get_tree().create_timer(0.3).timeout
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)


func _export_indicator(index: int) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var art := INDICATOR.new()
	viewport.add_child(art)
	art.position = Vector2(384, 384)
	art.configure(weapons[index], Vector2(155, 0))
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_check(_image_has_player_gap(image, art.clearance - 1), "transparent player clearance " + IDS[index])
	_check(image.save_png(capture_dir.path_join("indicators/" + IDS[index] + ".png")) == OK, "export " + IDS[index])
	if weapons[index].is_grenade():
		art.configure(weapons[index], Vector2(34, 0))
		await frames(3)
		await RenderingServer.frame_post_draw
		image = viewport.get_texture().get_image()
		_check(_image_has_player_gap(image, art.clearance - 1), "near grenade reticle also clears player collider")
	viewport.queue_free()
	if weapons[index].is_ritual_tome():
		await _verify_restored_tome(index)


func _verify_restored_tome(index: int) -> void:
	# Compare the active cast with the untouched original drawing at the same age.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var baseline: PackedByteArray
	for active in [false, true]:
		var domain := RitualDomain.new()
		viewport.add_child(domain)
		domain.initialize(weapons[index], active)
		domain.set_physics_process(false)
		domain.position = Vector2(384, 384)
		domain.elapsed = 1.4
		domain.domain_layer.queue_redraw()
		await frames(3)
		await RenderingServer.frame_post_draw
		var screenshot := viewport.get_texture().get_image()
		if active:
			_check(screenshot.get_data() == baseline, "active tome pixels match original star seal and particles")
			_check(screenshot.save_png(capture_dir.path_join("tome_restored_effect.png")) == OK, "save restored tome reference")
		else:
			baseline = screenshot.get_data()
		domain.queue_free()
		await frames(2)
	viewport.queue_free()


func _image_has_player_gap(image: Image, radius: float) -> bool:
	for x in range(-ceili(radius), ceili(radius) + 1):
		for y in range(-ceili(radius), ceili(radius) + 1):
			if Vector2(x, y).length() < radius and image.get_pixel(384 + x, 384 + y).a > 0.01:
				return false
	return true
