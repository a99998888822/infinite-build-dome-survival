extends Node2D
## Original project drawing; pixelfx references and adaptation notes are in the review page.
var kind := "upgrade"
var elapsed := 0.0
var duration := 1.0
var active := false
var _frame := -1

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	CombatRenderWorld.set_actor_local(self)
	z_index = -1
	hide()

func restart(effect_kind: String, seconds: float) -> void:
	kind = effect_kind
	elapsed = 0.0
	duration = seconds
	_frame = -1
	active = true
	show()
	queue_redraw()

func advance(delta: float, remaining: float) -> void:
	if not active: return
	elapsed += maxf(delta, 0.0)
	if remaining <= 0.0:
		clear()
		return
	var frame := int(elapsed * 18.0)
	if frame != _frame:
		_frame = frame
		queue_redraw()

func clear() -> void:
	active = false
	hide()

func _block(point: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2((point / 2.0).round() * 2.0, size), color)

func _ring(center: Vector2, radius: Vector2, color: Color, phase: float = 0.0) -> void:
	for i in 32:
		var angle := TAU * float(i) / 32.0
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		_block(point, Vector2(2, 2), color.lightened(0.25) if (i + int(phase * 18.0)) % 9 < 2 else color)

func _star(point: Vector2, color: Color, length: float) -> void:
	_block(point - Vector2(length, 0), Vector2(length * 2 + 2, 2), color)
	_block(point - Vector2(0, length), Vector2(2, length * 2 + 2), color)

func _draw() -> void:
	if not active: return
	var t := floorf(elapsed * 18.0) / 18.0
	var bright := Color("ffe5a1") if kind == "upgrade" else Color("fffef2")
	var mid := Color("d49a42") if kind == "upgrade" else Color("e4d59e")
	var ending := 1.0 - smoothstep(0.85, 1.0, t / duration)
	bright.a = ending
	mid.a = ending
	# A broken stepped oval marks immunity without covering the body.
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var point := Vector2(cos(angle) * 23.0, 36.0 + sin(angle) * 7.0)
		_block(point, Vector2(4, 2), bright if (i + int(t * 9.0)) % 6 < 2 else mid)
	# Ground gathering, rising hoops and small glints borrow pixelfx timing,
	# but use the project's square clusters, no bloom or full-height light shaft.
	if kind == "upgrade":
		if t < 0.22:
			var gather := 1.0 - t / 0.22
			for i in 8:
				var angle := TAU * float(i) / 8.0
				var point := Vector2(cos(angle) * (18.0 + 20.0 * gather), 36.0 + sin(angle) * 9.0 * gather)
				_block(point, Vector2(4, 2), bright)
		for i in 3:
			var age := t - 0.10 - float(i) * 0.14
			if age > 0.0 and age < 0.5:
				var fade := 1.0 - smoothstep(0.28, 0.5, age)
				_ring(Vector2(0, 34.0 - age * 135.0), Vector2(20.0 + age * 8.0, 5.0), Color(bright, fade), t)
		for i in 6:
			var age := t - 0.36 - float(i) * 0.06
			if age > 0.0 and age < 0.25:
				var point := Vector2(float((i * 19) % 61 - 30), -10.0 - float(i % 3) * 13.0)
				_star(point, bright, 2.0 * sin(age / 0.25 * PI))
	else:
		# Sparse glints accompany the feathers without an overhead halo.
		for i in 4:
			var age := t - 0.52 - float(i) * 0.07
			if age > 0.0 and age < 0.25:
				_star(Vector2((-1.0 if i % 2 == 0 else 1.0) * (30.0 + i * 5.0), -25.0 - i * 5.0), bright, 2.0 * sin(age / 0.25 * PI))
	var burst := clampf(t / minf(duration, 0.8), 0.0, 1.0)
	if burst >= 1.0: return
	if kind == "upgrade":
		for i in 12:
			var x := float((i * 17) % 37 - 18)
			var y := 30.0 - burst * (30.0 + float(i % 4) * 9.0)
			_block(Vector2(x, y), Vector2(2, 6 if i % 3 == 0 else 4), bright if i % 3 == 0 else mid)
