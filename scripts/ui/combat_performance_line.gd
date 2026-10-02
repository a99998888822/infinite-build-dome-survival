extends Label
## Sample at 2 Hz; do not traverse scene nodes in every rendered frame.

var elapsed := 0.0
var sample: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 10)
	add_theme_color_override("font_color", Color("b8c9b6"))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	tooltip_text = "实时帧率、存活怪物、共享粒子与闪电采样点。每0.5秒更新。"
	refresh()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.5:
		elapsed = 0
		refresh()


func refresh() -> void:
	var enemies := 0
	for enemy in EnemyRegistry.get_registered_enemies():
		if is_instance_valid(enemy) and enemy.is_alive(): enemies += 1
	var particles := 0
	for source in get_tree().get_nodes_in_group("combat_particle_counters"):
		if source.is_queued_for_deletion(): continue
		particles += source.get_active_particle_count()
	sample = {"fps": Engine.get_frames_per_second(), "enemies": enemies, "particles": particles,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	text = "FPS %d   怪物 %d   粒子 %d" % [sample.fps, enemies, particles]
