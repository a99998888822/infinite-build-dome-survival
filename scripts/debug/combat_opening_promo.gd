extends Node
## A staged take using production movement, casts, AI, collisions and audio.
const FPS := 60
const TOTAL := 540
const BOW := "weapon_void_blade"
const TOME := "weapon_star_tome"
var session: RecordingSession
var battle: BattleRoot
var player: PlayerController
var controller: ActiveCombatController
var bow: WeaponInstance
var tome: WeaponInstance
var wolf: UnderworldWolf
var output_dir := ""
var failures: Array[String] = []
var report: Dictionary = {"fps": FPS, "frames": TOTAL, "events": [], "samples": [], "scripted_inputs": true}
var frame := 0
var blink_frame := -1
var return_frame := -1
var anchor := Vector2.ZERO
var destination := Vector2.ZERO
var aim := Vector2.ZERO
var last_wolf_state := ""
var shots := 0
var final_shot := false
var kite_shot := false
var contact_frames: Array = []
var return_clearance := INF
var return_visual_gap := INF
var sprite_bounds_cache: Dictionary = {}
var starting_hp := 0
var preview := false
var photo_frames := [0, 12, 26, 36, 48, 60, 72, 126, 150, 180, 210, 260, 320, 380, 440, 460, 480, 500, 539]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--preview": preview = true
	if output_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		push_error("Requires --transient-session --capture-dir")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("Use the private desktop helper")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func event(action: String, details: Dictionary = {}) -> void:
	details.merge({"frame": frame, "seconds": float(frame) / FPS, "action": action}, true)
	report.events.append(details)

func _run() -> void:
	seed(1023)
	L10n.set_locale("zh_CN", false)
	CampProgression.begin_transient_session()
	CombatSettings.combat_guide_seen = true
	CombatSettings.set_option("keyboard_movement", false, false)
	CombatSettings.set_option("quick_cast", false, false)
	CombatSettings.set_option("show_hints", false, false)
	for id in [BOW, TOME]: CombatSettings.set_weapon_auto_cast(id, false, false)
	for bus in [AudioManager.BUS_MASTER, AudioManager.BUS_SFX]:
		AudioManager.set_bus_volume(bus, 100, false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), false)
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 0, false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_BGM), true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"wave": 5, "level": 10, "countdown": 0, "hud": true,
		"weapons": [{"id": BOW, "level": 5, "attachments": ["scroll_water", "scroll_ice"]}, {"id": TOME, "level": 1, "attachments": []}],
		"relics": [{"id": "relic_split_crystal_warhead", "count": 1}, {"id": "relic_twin_chamber_magazine", "count": 1}]}, true)
	report["config"] = config
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		_finish()
		return
	check(session.begin(), "Failed to begin battle")
	battle = session.battle
	player = battle.player
	controller = battle.active_controller
	battle.wave_manager.set_process(false)
	battle.wave_manager.clear_battle_entities()
	controller.set_process(false)
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	bow = battle.loadout.get_weapon_instance(BOW)
	tome = battle.loadout.get_weapon_instance(TOME)
	check(int(bow.get_stat("projectile_count")) == 5, "Bow must fire five projectiles")
	report["projectiles"] = bow.get_stat("projectile_count")
	report["bow_cooldown"] = bow.get_active_cooldown_seconds()
	player.global_position = Vector2(-120, 30)
	player._clear_move_input()
	player.restore_full_health()
	player._invincibility_timer = 0
	starting_hp = player.current_hp
	player.health_damage_taken.connect(_record_damage)
	# A fixed camera makes departure and return readable in one continuous shot.
	var camera := Camera2D.new()
	player.get_parent().add_child(camera)
	camera.global_position = Vector2(-25, 40)
	camera.zoom = Vector2(1.4, 1.4)
	camera.make_current()
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	var placements := [Vector2(120, -100), Vector2(220, -50), Vector2(240, 50), Vector2(340, -10), Vector2(330, 140),
		Vector2(-140, 570), Vector2(650, 450), Vector2(-350, 480), Vector2(-290, -240), Vector2(20, -380), Vector2(200, -380)]
	for at: Vector2 in placements:
		battle.wave_manager.spawn_enemy("enemy_mutated_grub", at)
	for at: Vector2 in [Vector2(-420, 210), Vector2(260, -200), Vector2(-440, -280)]:
		battle.wave_manager.spawn_enemy("enemy_echo_bat", at)
	wolf = battle.wave_manager.spawn_enemy("enemy_underworld_wolf", Vector2(-540, -150)) as UnderworldWolf
	wolf.transition("chase", &"idle")
	wolf.sprite.show()
	wolf.leap_cooldown = 2.7
	wolf.breath_cooldown = 4.0
	# Native HUD retains health and weapon/return state; remove unrelated counters.
	await frames(15)
	for node in [battle.hud.stats_drawer, battle.hud._weapon_damage_meter, battle.hud._performance_line, battle.hud._economy_log_layer, battle.hud.battle_top_bar, battle.hud.exp_panel, battle.hud._wave_toast]:
		if is_instance_valid(node): node.hide()
	battle.hud.set_process(false)
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	report["controls"] = "right-click movement; number key selection + left-click cast; native number-key return"
	_move(Vector2(-120, -82))
	_key(KEY_1)
	aim = Vector2(200, -65)
	_point(aim)
	report["start_frame"] = Engine.get_frames_drawn()
	for index in TOTAL:
		frame = index
		if not is_instance_valid(wolf) or not player.alive:
			check(false, "Take interrupted at frame " + str(frame))
			break
		_choreograph()
		_point(aim)
		controller._update_indicator()
		controller._update_cursor_icon()
		_update_bar()
		_audit_spacing()
		if wolf.state != last_wolf_state:
			event("wolf_" + wolf.state, {"position": _xy(wolf.global_position), "target": _xy(wolf.locked_point)})
			last_wolf_state = wolf.state
		if index % 6 == 0:
			report.samples.append({"frame": index, "player": _xy(player.global_position), "hp": player.current_hp, "wolf": _xy(wolf.global_position), "wolf_state": wolf.state,
				"enemies": EnemyRegistry.get_registered_enemies().size(), "ice_fields": get_tree().get_nodes_in_group("ice_fields").size()})
		if index % 60 == 0: print("TAKE ", index, " player=", player.global_position, " hp=", player.current_hp, " wolf=", wolf.global_position, " ", wolf.state)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if photo_frames.has(frame): get_viewport().get_texture().get_image().save_png(output_dir.path_join("frame_%03d.png" % frame))
		await get_tree().process_frame
	check(blink_frame >= 0, "Missing blink")
	check(return_frame > blink_frame, "Missing return")
	check(shots >= 4, "Expected four bow volleys")
	check(player.current_hp == starting_hp, "Take must finish without health loss")
	check(contact_frames.is_empty(), "Player touched an enemy")
	check(return_clearance >= 20.0, "Return path needs a visible body gap")
	check(return_visual_gap >= 8.0, "Return path overlaps a visible enemy silhouette")
	report["spacing"] = {"contact_frames": contact_frames, "return_min_body_gap": return_clearance, "return_min_visual_gap": return_visual_gap}
	var wolf_hits := wolf.damage_events if is_instance_valid(wolf) else -1
	check(wolf_hits == 0, "Wolf hit player")
	report["health"] = {"start": starting_hp, "end": player.current_hp, "wolf_damage_events": wolf_hits}
	report["shots"] = shots
	_finish()

func _xy(point: Vector2) -> Array:
	return [snappedf(point.x, 0.1), snappedf(point.y, 0.1)]

func _record_damage(previous: int, remaining: int, _maximum: int) -> void:
	var nearby: Array = []
	for enemy in EnemyRegistry.get_registered_enemies():
		if enemy.global_position.distance_to(player.global_position) < 160:
			nearby.append({"id": enemy.enemy_id, "position": _xy(enemy.global_position)})
	event("damage_taken", {"before": previous, "after": remaining, "position": _xy(player.global_position), "nearby": nearby})

func _audit_spacing() -> void:
	var player_body := player.get_node("CollisionShape2D") as CollisionShape2D
	var player_rect := player_body.global_transform * player_body.shape.get_rect()
	var nearest_gap := INF
	var nearest_id := ""
	var visual_gap := INF
	var nearest_visual := ""
	var player_art := _sprite_bounds(player.sprite)
	for enemy in EnemyRegistry.get_registered_enemies():
		if not enemy.alive: continue
		var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
		if body == null or body.disabled: continue
		if enemy._is_touching_player(): contact_frames.append({"frame": frame, "enemy": enemy.enemy_id, "position": _xy(enemy.global_position)})
		var bounds := body.global_transform * body.shape.get_rect()
		var dx := maxf(0.0, maxf(bounds.position.x - player_rect.end.x, player_rect.position.x - bounds.end.x))
		var dy := maxf(0.0, maxf(bounds.position.y - player_rect.end.y, player_rect.position.y - bounds.end.y))
		var gap := Vector2(dx, dy).length()
		if gap < nearest_gap:
			nearest_gap = gap
			nearest_id = enemy.enemy_id
		var art := _sprite_bounds(enemy.sprite)
		var vx := maxf(0.0, maxf(art.position.x - player_art.end.x, player_art.position.x - art.end.x))
		var vy := maxf(0.0, maxf(art.position.y - player_art.end.y, player_art.position.y - art.end.y))
		var distance := Vector2(vx, vy).length()
		if distance < visual_gap:
			visual_gap = distance
			nearest_visual = enemy.enemy_id
	if return_frame >= 0:
		return_clearance = minf(return_clearance, nearest_gap)
		return_visual_gap = minf(return_visual_gap, visual_gap)
	if frame % 6 == 0:
		event("spacing", {"body_gap": nearest_gap, "nearest": nearest_id, "visual_gap": visual_gap, "nearest_visual": nearest_visual})

func _sprite_bounds(sprite: Sprite2D) -> Rect2:
	var extent := sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	var key := str(sprite.texture.get_rid()) + ":" + str(sprite.frame)
	if not sprite_bounds_cache.has(key):
		var bitmap := sprite.texture.get_image()
		if bitmap.is_compressed(): bitmap.decompress()
		var region := Rect2i(Vector2(sprite.frame_coords) * extent, extent)
		sprite_bounds_cache[key] = Rect2(bitmap.get_region(region).get_used_rect())
	var used: Rect2 = sprite_bounds_cache[key]
	if sprite.flip_h: used.position.x = extent.x - used.end.x
	if sprite.flip_v: used.position.y = extent.y - used.end.y
	used.position += sprite.get_rect().position
	return sprite.global_transform * used

func _point(target: Vector2) -> void:
	var world := player.get_viewport()
	controller._has_pointer_position = true
	controller._pointer_position = (world.get_canvas_transform() * target) * get_viewport().get_visible_rect().size / world.get_visible_rect().size

func _cast(weapon: WeaponInstance, target: Vector2) -> bool:
	var before := player.global_position
	var result := battle.loadout.active_casting.can_cast(weapon)
	_point(target)
	if weapon.is_return_ready():
		# In the production mouse-movement scheme a second number key returns.
		_key(KEY_2)
		result = result and not weapon.is_return_ready()
	else:
		if controller.selected_weapon != weapon: _key(KEY_1 if weapon == bow else KEY_2)
		_click(MOUSE_BUTTON_LEFT)
		result = result and controller.selected_weapon == null
	check(result, "Cast failed: " + weapon.weapon_id + " at " + str(frame))
	if result:
		event("cast", {"weapon": weapon.weapon_id, "from": _xy(before), "at": _xy(player.global_position), "target": _xy(target)})
		if weapon == bow: shots += 1
	return result

func _key(code: Key) -> void:
	var input := InputEventKey.new()
	input.physical_keycode = code
	input.pressed = true
	controller._unhandled_input(input)
	input.pressed = false
	controller._unhandled_input(input)
	event("key", {"keycode": code})

func _click(button: MouseButton) -> void:
	var input := InputEventMouseButton.new()
	input.button_index = button
	input.position = controller._pointer_position
	input.pressed = true
	controller._input(input)
	controller._unhandled_input(input)
	input.pressed = false
	controller._input(input)
	controller._unhandled_input(input)
	event("click", {"button": button, "world": _xy(controller.pointer_world())})

func _move(target: Vector2) -> void:
	_point(target)
	_click(MOUSE_BUTTON_RIGHT)

func _choreograph() -> void:
	if blink_frame < 0:
		if frame == 48: _move(Vector2(-34, -18))
		if frame == 94: _move(Vector2(-34, 99))
		if frame == 144: _move(Vector2(-78, 99))
		if frame == 12: _cast(bow, aim)
		if frame == 116:
			aim = Vector2(200, 120)
			_key(KEY_1)
		if frame == 142: _cast(bow, aim)
		if wolf.state == "leap_charge":
			aim = player.global_position + Vector2(230, 160)
			if controller.selected_weapon != tome:
				_key(KEY_S)
				_key(KEY_2)
		if wolf.state == "leap":
			if wolf.state_time >= 0.28:
				anchor = player.global_position
				destination = anchor + Vector2(230, 160)
				if _cast(tome, destination):
					blink_frame = frame
					event("blink", {"anchor": _xy(anchor), "destination": _xy(player.global_position)})
					photo_frames.append(frame + 1)
	else:
		if return_frame < 0:
			# Right-click waypoints skirt the pursuit while the wolf recovers.
			if frame == blink_frame + 1: _move(anchor + Vector2(400, 190))
			if frame == blink_frame + 93:
				aim = anchor + Vector2(540, 240)
				_key(KEY_1)
			if frame >= blink_frame + 110 and not kite_shot:
				kite_shot = _cast(bow, aim)
			if frame == blink_frame + 118: _move(anchor + Vector2(450, 105))
			if wolf.state == "breath_charge":
				aim = anchor
				if wolf.state_time >= 0.80:
					if _cast(tome, anchor):
						return_frame = frame
						event("return", {"at": _xy(player.global_position), "wolf": _xy(wolf.global_position)})
						photo_frames.append(frame + 1)
						photo_frames.append(frame + 12)
						photo_frames.append(frame + 24)
		else:
			var elapsed := frame - return_frame
			if elapsed == 1: _move(anchor + Vector2(-220, -50))
			if elapsed == 16:
				aim = wolf.global_position + Vector2(60, 0)
				_key(KEY_1)
			if elapsed >= 32 and not final_shot and battle.loadout.active_casting.can_cast(bow):
				final_shot = _cast(bow, aim)

func _update_bar() -> void:
	for i in battle.loadout.weapon_instances.size():
		var weapon := battle.loadout.weapon_instances[i]
		var state := battle.loadout.active_casting.state_for(weapon)
		battle.hud.combat_bar.update_slot(i, float(state.remaining), float(state.total), bool(state.executing), controller.selected_weapon == weapon)

func _finish() -> void:
	report["failures"] = failures
	report["audio"] = {"bgm_percent": 0, "sfx_percent": 100, "bgm_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), "bgm_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("COMBAT_OPENING_DONE failures=", failures.size(), " shots=", shots, " blink=", blink_frame, " return=", return_frame)
	# Drain transient weapon/effect owners after the selected movie interval.
	CombatHitFeedback.clear()
	bow = null
	tome = null
	controller = null
	player = null
	wolf = null
	battle = null
	sprite_bounds_cache.clear()
	if is_instance_valid(session):
		await session.dispose()
		session.queue_free()
	await frames(8)
	CampProgression.end_transient_session()
	get_tree().quit(0 if failures.is_empty() else 1)
