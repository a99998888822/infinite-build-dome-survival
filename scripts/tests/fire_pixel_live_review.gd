extends "res://scripts/tests/fire_pixel_review_base.gd"
const FIRE = preload("res://scripts/effects/pixel_fire_visual.gd")

var sample_elapsed := 0.0
var fire_caption: Label

func _run() -> void:
	if "--main-smoke" in OS.get_cmdline_user_args():
		await _run_main_smoke()
		return
	if output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	CampProgression.begin_transient_session()
	var count := 30 if tier == "all" else tier.to_int()
	await run_case("fire", count)
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	CampProgression.end_transient_session()
	print("FIRE_COMBAT_COMPLETE failures=", failures)
	get_tree().quit(1 if failures else 0)

func _run_main_smoke() -> void:
	var main := preload("res://scenes/core/game_root.tscn").instantiate()
	add_child(main)
	await frames(120)
	# Stop menu Ogg playback before quitting, rather than truncating it mid-frame.
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	main.queue_free()
	await get_tree().create_timer(0.2).timeout
	print("MAIN_SMOKE_COMPLETE failures=0")
	get_tree().quit()

func setup(spell: String, count: int) -> Dictionary:
	var stats := await super.setup(spell, count)
	var layer := CanvasLayer.new()
	layer.layer = 70
	game.add_child(layer)
	fire_caption = Label.new()
	fire_caption.position = Vector2(24, 156)
	fire_caption.add_theme_font_size_override("font_size", 15)
	fire_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	fire_caption.add_theme_constant_override("shadow_offset_x", 2)
	fire_caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(fire_caption)
	return stats

func _process(delta: float) -> void:
	sample_elapsed += delta
	if sample_elapsed < 0.2 or not is_instance_valid(fire_caption): return
	sample_elapsed = 0.0
	var nodes := get_tree().get_nodes_in_group("pixel_fire_visuals")
	var tongues := 0
	for node in nodes: tongues += node.tongue_count
	var batches: int = FIRE.clock.batches.size() if is_instance_valid(FIRE.clock) else 0
	fire_caption.text = "正式像素火焰 V3 · 火焰组 %d / 火舌 %d / 批次 %d\n主体与火星由着色器绘制，不计入 CPU 粒子数" % [nodes.size(), tongues, batches]

func sample_metrics() -> Dictionary:
	var result := super.sample_metrics()
	result.flame_sources = get_tree().get_nodes_in_group("pixel_fire_visuals").size()
	result.flame_batches = FIRE.clock.batches.size() if is_instance_valid(FIRE.clock) else 0
	result.flame_tongues = 0
	for node in get_tree().get_nodes_in_group("pixel_fire_visuals"): result.flame_tongues += node.tongue_count
	return result
