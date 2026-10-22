extends Node
## Deterministic marketing take using the production finance UI and attachment API.
## Launch with --transient-session and the private-desktop capture helper.

const FPS := 60
const INTRO := 30
const FLIGHT := [33, 33, 36]
const OVERLAP := 9
const LAND := 18
const END_HOLD := 120
const IDS := ["scroll_multishot", "scroll_electric_spark", "scroll_wisdom"]
const WEAPON := "weapon_earth_hammer"
const TRAIL = preload("res://scripts/debug/promo_pixel_trail.gd")
const WIND = preload("res://assets/audio/sfx/combat/wind_01.wav")
const CLICK = preload("res://assets/audio/sfx/finance/interest_tick.wav")
var session: RecordingSession
var popup: FinancePopup
var workbench: EnchantmentWorkbench
var output_dir := ""
var stage_only := false
var failures: Array[String] = []
var report: Dictionary = {"fps": FPS, "intro_frames": INTRO, "icon_size": [32, 32], "bgm_percent": 0, "sfx_percent": 100, "events": [], "paths": []}
var items: Array[Dictionary] = []
var cards: Array[EnchantmentInventoryCard] = []
var targets: Array[Vector2] = []
var overlay: Control
var ribbons: Array[Node2D] = []
var flyers: Array[TextureRect] = []
var rendered := 0
var slot_origins: Array[Vector2] = []
var photo_frames: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--stage-only": stage_only = true
	if output_dir.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		push_error("Use --transient-session --capture-dir=<directory>")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		push_error("GPU recording requires the private-desktop helper")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	L10n.set_locale("zh_CN", false)
	CampProgression.begin_transient_session()
	AudioManager.set_bus_volume(AudioManager.BUS_MASTER, 100, false)
	AudioManager.set_bus_volume(AudioManager.BUS_BGM, 0, false)
	AudioManager.set_bus_volume(AudioManager.BUS_SFX, 100, false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_BGM), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_MASTER), false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioManager.BUS_SFX), false)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.content_scale_size = Vector2i(1920, 1080)
	session = RecordingSession.new()
	add_child(session)
	var config := RecordingSession.default_config()
	config.merge({"entry": "bank", "countdown": 0, "relics": [], "weapons": [{"id": WEAPON, "level": 4, "attachments": []}]}, true)
	var error := await session.prepare(config)
	check(error.is_empty(), error)
	if not failures.is_empty():
		_finish()
		return
	check(session.begin(), "Finance entry failed")
	await frames(15)
	popup = session.game.find_child("FinancePopup", true, false) as FinancePopup
	check(popup != null and popup.visible, "Finance popup is not visible")
	if popup == null:
		_finish()
		return
	popup.interest_arrival.stop()
	session.battle.wave_manager.goblin_trades.cancel()
	popup.cancel_trade("recording")
	popup.configure(session.flow.get_preparation_payload())
	popup._select_tab("enchant")
	workbench = popup.workbench
	workbench._select_weapon(WEAPON)
	var weapon := session.battle.loadout.get_weapon_instance(WEAPON)
	check(weapon.level == 4 and weapon.get_attachment_slot_count() == 3, "Expected level 4 and three slots")
	check(weapon.get_attached_item_instances().is_empty(), "Initial slots must be empty")
	# Backpack reads wisdom / lightning / multishot, so right-to-left flight
	# preserves the requested final slot order: multishot / lightning / wisdom.
	items.resize(3)
	for i in range(2, -1, -1):
		items[i] = session.battle.player.item_inventory.add_item_from_base(IDS[i], "recording")
	workbench.refresh()
	await frames(10)
	# Keep all three cards visible from frame zero. Independent cards retain
	# their original backpack positions while real attachment operations refresh.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	for i in 3:
		var source := workbench._inventory.get_child(2 - i) as EnchantmentInventoryCard
		check(str(source.item_instance.base_item_id) == IDS[i], "Backpack source order mismatch")
		var card := EnchantmentInventoryCard.new()
		overlay.add_child(card)
		card.configure(items[i], false)
		card.position = source.get_global_rect().position
		card.size = source.size
		cards.append(card)
		var slot := _slot(i)
		targets.append(slot._art.get_global_rect().get_center())
		slot_origins.append(slot._art.position)
	workbench._inventory.modulate.a = 0.0
	# Every flight and landing owns its effect, allowing real overlap.
	for i in 3:
		var ribbon := TRAIL.new()
		overlay.add_child(ribbon)
		ribbons.append(ribbon)
	for i in 3:
		var flying := TextureRect.new()
		flying.size = Vector2(32, 32)
		flying.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flying.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flying.hide()
		overlay.add_child(flying)
		flyers.append(flying)
	await frames(10)
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for player in AudioManager._sfx_players: player.stop()
	popup._tooltip.hide()
	get_viewport().gui_release_focus()
	for i in 3:
		check(cards[i]._art.size == Vector2(32, 32), "Backpack icon must remain 32px")
		check(cards[i].visible and cards[i].modulate.a == 1.0, "All backpack cards must be visible initially")
		if i > 0: check(cards[i].position.x < cards[i - 1].position.x, "Flights must start right to left")
	report["initial_backpack_left_to_right"] = [IDS[2], IDS[1], IDS[0]]
	report["overlap_frames"] = OVERLAP
	var starts: Array[int] = []
	var next_start := INTRO
	for i in 3:
		starts.append(next_start)
		photo_frames[next_start + 3] = "highlight_%d" % i
		photo_frames[next_start + int(FLIGHT[i] * 0.55)] = "flight_%d" % i
		photo_frames[next_start + FLIGHT[i] + 3] = "land_%d" % i
		if i > 0:
			photo_frames[next_start + 5] = "overlap_%d" % i
			check(next_start < starts[i - 1] + FLIGHT[i - 1], "Flights must overlap before landing")
		next_start += FLIGHT[i] - OVERLAP
	var total: int = starts[2] + FLIGHT[2] + LAND + END_HOLD
	photo_frames[0] = "empty_slots"
	photo_frames[total - 1] = "final"
	if stage_only: total = 1
	report["frames"] = total
	report["start_frame"] = Engine.get_frames_drawn()
	report["end_hold_frames"] = END_HOLD
	for frame in total:
		rendered = frame
		for i in 3:
			var local := frame - starts[i]
			var ribbon := ribbons[i]
			var flying := flyers[i]
			if local == 0: _launch(i)
			if local >= 0 and local < FLIGHT[i]:
				var u := float(local) / float(FLIGHT[i])
				var eased := u * u * (3.0 - 2.0 * u)
				ribbon.seek(eased)
				flying.position = (ribbon.at(eased) - Vector2(16, 16)).round()
				flying.self_modulate = Color(1.65, 1.65, 1.4).lerp(Color.WHITE, minf(1.0, float(local) / 10.0))
				cards[i].modulate.a = maxf(0.0, 1.0 - float(local) / 8.0)
			if local == FLIGHT[i]: _land(i)
			if local >= FLIGHT[i] and local < FLIGHT[i] + LAND:
				var u := float(local - FLIGHT[i]) / float(LAND)
				ribbon.impact = u
				ribbon.seek(1.0, maxf(0.0, 1.0 - u * 3.0))
				_slot(i)._art.position = slot_origins[i] + Vector2(0, roundf(-3.0 * sin(u * TAU) * (1.0 - u)))
			if local == FLIGHT[i] + LAND:
				ribbon.impact = -1.0
				ribbon.seek(-1.0)
				_slot(i)._art.position = slot_origins[i]
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if photo_frames.has(frame): get_viewport().get_texture().get_image().save_png(output_dir.path_join(str(photo_frames[frame]) + ".png"))
		await get_tree().process_frame
	if not stage_only:
		var attached := weapon.get_attached_item_instances()
		check(attached.size() == 3, "Final attachment count is not three")
		for i in mini(attached.size(), 3): check(str(attached[i].base_item_id) == IDS[i], "Attachment order mismatch")
		report["final_attachments"] = attached.map(func(item): return item.base_item_id)
	_finish()


func _slot(index: int) -> EnchantmentSlotCard:
	return workbench._slots.get_child(index * 2) as EnchantmentSlotCard


func _launch(index: int) -> void:
	var ribbon := ribbons[index]
	var flying := flyers[index]
	FinanceUIStyle.bank_button(cards[index], true)
	cards[index].self_modulate = Color(1.4, 1.4, 1.2)
	var start := cards[index]._art.get_global_rect().get_center()
	var end := targets[index]
	var paths := [
		PackedVector2Array([start, start + Vector2(-95, -5), end + Vector2(-90, -110), end]),
		PackedVector2Array([start, start + Vector2(310, 100), end + Vector2(330, -95), end]),
		PackedVector2Array([start, start + Vector2(70, 185), end + Vector2(-150, 150), end]),
	]
	ribbon.points = paths[index]
	ribbon.impact = -1.0
	flying.texture = cards[index]._art.texture
	flying.position = (start - Vector2(16, 16)).round()
	flying.show()
	cards[index]._art.modulate.a = 0.0
	report.paths.append({"item": IDS[index], "points": Array(paths[index]).map(func(p): return [p.x, p.y])})
	report.events.append({"frame": rendered, "action": "highlight", "item": IDS[index]})
	report.events.append({"frame": rendered, "action": "flight", "item": IDS[index], "source_column": 3 - index, "target_slot": index + 1})
	_sound(WIND, -12.0, 1.0 + index * 0.06)


func _land(index: int) -> void:
	var result := session.flow.submit_enchantment_operation("attach", WEAPON, str(items[index].item_instance_id))
	check(bool(result.get("success", false)), "Attachment failed: " + str(result))
	workbench.refresh()
	workbench._inventory.modulate.a = 0.0
	flyers[index].hide()
	cards[index].hide()
	# Recreated controls settle next frame; use the original stable slot geometry.
	ribbons[index].target_rect = Rect2(targets[index] - Vector2(34, 19), Vector2(68, 53))
	report.events.append({"frame": rendered, "action": "land", "item": IDS[index]})
	_sound(CLICK, -7.0, 1.0 + index * 0.12)
	if index == 2: workbench._inventory.modulate.a = 1.0


func _sound(stream: AudioStream, gain: float, pitch: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = AudioManager.BUS_SFX
	player.volume_db = gain
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _finish() -> void:
	report["failures"] = failures
	report["audio"] = {"bgm_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), "bgm_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))}
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ENCHANTMENT_PROMO_DONE failures=", failures.size(), " frames=", report.get("frames", 0))
	get_tree().quit(0 if failures.is_empty() else 1)
