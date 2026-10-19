extends Node
## Compare observable presentation against the frozen pre-optimization script.
const BASELINE = preload("res://scripts/tests/fixtures/shared_baseline_enemy_hit_visual.gd")
const CURRENT = preload("res://scripts/effects/enemy_hit_visual.gd")
var visuals: Array[Node] = []
var checks := 0
var failures := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func compare(label: String) -> void:
	var old: Node = visuals[0]
	var current: Node = visuals[1]
	for key in ["elapsed", "applied_offset", "flash_white", "_pulse_frame"]:
		check(old.get(key) == current.get(key), label + " " + key)
	for key in ["offset", "position", "scale", "global_transform", "flip_h"]:
		check(old.sprite.get(key) == current.sprite.get(key), label + " sprite " + key)
	check(old.is_processing() == current.is_processing(), label + " processing")
	check((old.sprite.material == old.white_material) == (current.sprite.material == current.white_material), label + " material selection")
	check((old.sprite.material == old.original_material) == (current.sprite.material == current.original_material), label + " original material")
	if old.white_material != null:
		check(old.white_material.get_shader_parameter("white_amount") == current.white_material.get_shader_parameter("white_amount"), label + " white amount")

func pulse(white: bool, label: String) -> void:
	for visual in visuals: visual.pulse(white)
	compare(label)

func run() -> void:
	CampProgression.begin_transient_session()
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	for factory in [BASELINE, CURRENT]:
		var host := Node2D.new()
		add_child(host)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.material = CanvasItemMaterial.new()
		host.add_child(sprite)
		var visual: Node = factory.new()
		host.add_child(visual)
		visuals.append(visual)
	pulse(true, "first hit")
	for i in 100:
		for visual in visuals: visual.pulse(true)
	compare("100 same-frame hits")
	for visual in visuals: visual.sprite.offset += Vector2(7, -9)
	pulse(true, "animation offset edit")
	for visual in visuals:
		visual.sprite.scale = Vector2(1.5, 0.7)
		visual.sprite.rotation = 0.3
		visual.sprite.flip_h = true
	pulse(true, "animation scale rotation facing")
	for visual in visuals:
		visual.get_parent().transform = Transform2D(0.7, Vector2(2, 0.8), 0.15, Vector2(80, 110))
	pulse(true, "parent transform edit")
	for visual in visuals: visual.sprite.material = CanvasItemMaterial.new()
	pulse(true, "material replacement")
	for visual in visuals:
		visual.pulse(true)
		visual.sprite.material = CanvasItemMaterial.new()
	compare("material replacement after last hit retains ordering")
	pulse(false, "white to shake-only")
	pulse(false, "repeat shake-only")
	pulse(true, "shake-only to white")
	for visual in visuals:
		visual.elapsed = 0.1
		visual._sync()
	compare("fade")
	pulse(true, "restart during fade")
	for visual in visuals: visual.reset()
	compare("reset")
	for visual in visuals:
		visual.pulse(true)
		visual.pulse(true)
		visual.reset()
	compare("reset after repeated poses")
	pulse(true, "same-frame hit after reset")
	for visual in visuals: visual.set_process(false)
	pulse(true, "externally disabled processing")
	await get_tree().process_frame
	pulse(true, "next-frame hit")
	for visual in visuals: visual._process(0.05)
	compare("hit frame keeps full white pose")
	for visual in visuals:
		visual._pulse_frame = -1
		visual._process(0.1)
	compare("elapsed fade")
	for visual in visuals: visual._process(0.2)
	compare("expired shake restores material")
	pulse(false, "new shake-only after expiration")
	for visual in visuals:
		visual.reset()
		visual.sprite.queue_free()
	await get_tree().process_frame
	for visual in visuals: visual.pulse(true)
	check(visuals[0].elapsed == visuals[1].elapsed, "freed sprite ignored")
	for visual in visuals: visual.get_parent().queue_free()
	await get_tree().process_frame
	CampProgression.end_transient_session()
	print("HIT_VISUAL_COALESCING checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
