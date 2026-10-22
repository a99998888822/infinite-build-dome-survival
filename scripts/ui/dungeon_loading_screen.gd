extends CanvasLayer
class_name DungeonLoadingScreen
## Owns the entry barrier: render black first, prepare, then reveal a paused battle.
signal finished(success: bool)
const FONT = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const PARTICLES = preload("res://scripts/effects/particle_world.gd")
const HIT_BURST = preload("res://scripts/effects/lightning_hit_sprite_burst.gd")
const BOLT = preload("res://scripts/effects/lightning_pixel_bolt.gd")
const REFLECTION = preload("res://scripts/effects/light_reflection_effect.gd")
const HIT_RENDER_WARMUP = preload("res://scripts/effects/combat_hit_render_warmup.gd")
const WEAPON_RENDER_WARMUP = preload("res://scripts/effects/weapon_render_warmup.gd")
var active := false
var curtain: ColorRect
var caption: Label
var dots: Array[Label] = []
var _row: Control
var _time := 0.0
var _ticket := 0
var _flow: MainFlowCoordinator
var _samples: Node2D
var _modal_sample: CanvasLayer
var _fade: Tween

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)
	_row = Control.new()
	curtain.add_child(_row)
	caption = _label("ui.loading.dungeon")
	_row.add_child(caption)
	for i in 3:
		var dot := _label(".")
		_row.add_child(dot)
		dots.append(dot)
	get_viewport().size_changed.connect(_layout)
	L10n.locale_changed.connect(_layout)
	_layout()
	hide()

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("d6d4cd"))
	return label

func _layout() -> void:
	var text_width := FONT.get_string_size(L10n.text("ui.loading.dungeon"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	caption.size = Vector2(text_width, 36)
	_row.position = get_viewport().get_visible_rect().size - Vector2(text_width + 36 + 64, 76)
	for i in dots.size(): dots[i].position.x = text_width + i * 10

func _process(delta: float) -> void:
	if not active: return
	_time += minf(delta, 0.05)
	for i in dots.size():
		dots[i].position.y = -3.0 * pow(maxf(0.0, sin(_time * TAU / 1.25 - i * 0.55)), 2.0)

func _input(_event: InputEvent) -> void:
	if active: get_viewport().set_input_as_handled()

func begin(flow: MainFlowCoordinator, character: String, modifiers: Array, difficulty: String) -> void:
	if active: return
	active = true
	_ticket += 1
	_flow = flow
	_flow.flow_reset.connect(cancel)
	_time = 0.0
	curtain.modulate.a = 1.0
	GameGlobal.set_runtime_flag("battle_loading", true)
	_flow._set_battle_runtime_paused(true)
	show()
	_enter(_ticket, character, modifiers.duplicate(true), difficulty)

func _present_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func _valid(ticket: int) -> bool:
	return active and ticket == _ticket and is_instance_valid(_flow) and is_inside_tree()

func _enter(ticket: int, character: String, modifiers: Array, difficulty: String) -> void:
	# A deferred call alone runs before drawing; wait for an actual presented frame.
	await _present_frame()
	if not _valid(ticket): return
	_flow.enter_battle_selection(character, [], modifiers, difficulty)
	await _present_frame()
	if not _valid(ticket): return
	if not _flow.confirm_character_selection(true):
		_fail()
		return
	await _present_frame()
	if not _valid(ticket): return
	var player := _flow.get_bound_player()
	var loadout := _flow.get_bound_loadout()
	var world := loadout._get_visual_root()
	var backdrop := world.get_node_or_null("Backdrop") as CavernBattleBackdrop
	if backdrop == null:
		_fail()
		return
	# First spawns otherwise synchronously read scenes and their dependencies.
	# Prepare one type per presented frame, including later-wave variants.
	for enemy_data: Dictionary in DataRegistry.get_table("enemies"):
		if not bool(enemy_data.get("enabled", true)): continue
		if not _flow._bound_wave_manager.prepare_enemy_scene(enemy_data):
			_fail()
			return
		await _present_frame()
		if not _valid(ticket): return
	# Cache every action's alpha bounds before gameplay; get_image() can stall the GPU.
	for layout: Dictionary in player.get_combat_frame_layouts():
		backdrop.cache_player_frame_bounds(layout.texture, layout.grid)
		await _present_frame()
		if not _valid(ticket): return
	while not backdrop.is_initial_stream_ready():
		await _present_frame()
		if not _valid(ticket): return
	_samples = Node2D.new()
	_samples.name = "EntryRenderWarmup"
	world.add_child(_samples)
	_samples.global_position = player.global_position
	if backdrop is CavernSunlightBackdrop:
		(backdrop as CavernSunlightBackdrop).prepare_render_warmup(_samples)
	_prepare_modal_backdrop()
	if is_instance_valid(_modal_sample):
		_flow._bound_wave_manager.evacuation.visual.prepare_render_warmup(_samples, _modal_sample)
	HIT_RENDER_WARMUP.prepare(_samples, loadout.weapon_instances, player.sprite.texture)
	# Draw real materials below the opaque curtain. Hidden/offscreen nodes do not
	# compile the first-use GPU variants. These samples have no gameplay bodies.
	for layout: Dictionary in player.get_combat_frame_layouts():
		var sprite := Sprite2D.new()
		sprite.texture = layout.texture
		sprite.hframes = layout.grid.x
		sprite.material = player.sprite.material
		_samples.add_child(sprite)
	for weapon in loadout.weapon_instances:
		var texture := loadout._load_weapon_texture(weapon, "projectile_texture")
		if texture != null:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			_samples.add_child(sprite)
	var particles := PARTICLES.new()
	_samples.add_child(particles)
	particles.emit_event(PARTICLES.PARTICLE_EVENT_SCRIPT.create({"profile_id": "projectile_trail",
		"global_position": player.global_position, "direction": Vector2.RIGHT, "intensity": 1.0}))
	var bolt := BOLT.new()
	_samples.add_child(bolt)
	bolt.points = PackedVector2Array([Vector2.ZERO, Vector2(20, -12), Vector2(50, 0)])
	# Match the native lightning path: an instanced, untextured white core.
	# The former rimmed ArrayMesh sample did not exercise this draw variant.
	bolt.rim_enabled = false
	bolt.build(true)
	HIT_BURST.spawn(_samples, player.global_position, Vector2.RIGHT, 1.0, {"visual_cap": 2, "skip_lights": true})
	# Exercise the actual reflection draw paths while the curtain is opaque.
	# These samples never enter spawn()/damage/audio/visual-budget registration.
	for tier in 3:
		var reflection := REFLECTION.new()
		_samples.add_child(reflection)
		reflection.set_process(false)
		reflection.global_position = player.global_position
		reflection._visual_tier = tier
		reflection._elapsed = 0.24
		reflection._orientation = float(tier - 1) * 0.4
		reflection.queue_redraw()
	await _present_frame()
	if not _valid(ticket): return
	await _present_frame()
	if not _valid(ticket): return
	_clear_modal_sample()
	# Each first-use shader/texture family gets a presented loading frame.
	# Keep samples onscreen until drawn; merely loading a Shader is insufficient.
	# Keep launch and loop sources resident before weapon casts can read them.
	AudioManager.prepare_weapon_launch_sfx()
	AudioManager.prepare_weapon_loop_sfx()
	for kind in WEAPON_RENDER_WARMUP.KINDS:
		WEAPON_RENDER_WARMUP.prepare(_samples, kind)
		await _present_frame()
		if not _valid(ticket): return
	_clear_samples()
	if not _flow.start_confirmed_battle():
		_fail()
		return
	var paused_after_entry := bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false))
	_flow._set_battle_runtime_paused(true)
	await _present_frame()
	if not _valid(ticket): return
	_fade = create_tween()
	_fade.tween_property(curtain, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade.finished
	if not _valid(ticket): return
	# Input and simulation resume only after the complete battle has been revealed.
	_flow._set_battle_runtime_paused(paused_after_entry)
	_complete(true)

func _prepare_modal_backdrop() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is GameRoot:
		ancestor = ancestor.get_parent()
	if ancestor == null: return
	var director := ancestor.get_node_or_null("SceneDirector") as GameSceneDirector
	if director == null or not is_instance_valid(director.battle_root): return
	# Prepare the real inventory row before the first reward. The popup stays
	# closed; reset_run releases this binding if entry is cancelled or reset.
	var shop_ui := ancestor.get_node_or_null("UiRoot/ShopUIController") as ShopUIController
	if shop_ui != null and shop_ui.shop_popup != null:
		shop_ui.shop_popup.set_loadout(_flow.get_bound_loadout())
	var source := director.battle_root.get_node_or_null("ModalBackdrop/Backdrop") as ColorRect
	if source == null: return
	# Screen-reading materials need a real draw in the UI viewport: a separate
	# SubViewport does not prepare this viewport's screen-copy allocation.
	# Share the live material without changing the HUD's visibility or state.
	_modal_sample = CanvasLayer.new()
	_modal_sample.name = "EntryModalWarmup"
	_modal_sample.layer = (source.get_parent() as CanvasLayer).layer
	add_child(_modal_sample)
	var sample := source.duplicate(0) as ColorRect
	_modal_sample.add_child(sample)
	sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sample.show()

func _clear_modal_sample() -> void:
	if is_instance_valid(_modal_sample):
		_modal_sample.hide()
		_modal_sample.queue_free()
	_modal_sample = null

func _clear_samples() -> void:
	_clear_modal_sample()
	if is_instance_valid(_samples):
		_samples.hide()
		_samples.queue_free()
	_samples = null

func _fail() -> void:
	var flow := _flow
	_complete(false)
	flow.enter_start_page()

func _complete(success: bool) -> void:
	_clear_samples()
	active = false
	GameGlobal.set_runtime_flag("battle_loading", false)
	if is_instance_valid(_flow) and _flow.flow_reset.is_connected(cancel): _flow.flow_reset.disconnect(cancel)
	hide()
	finished.emit(success)

func cancel() -> void:
	if not active: return
	_ticket += 1
	if _fade != null: _fade.kill()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	_complete(false)

func _exit_tree() -> void:
	cancel()
