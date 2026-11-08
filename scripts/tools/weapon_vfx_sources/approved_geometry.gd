extends RefCounted
## Experiment-only drawing. No combat callbacks, RNG, or global registration.
const GRID := 2.0

static func poly(canvas: CanvasItem, vertices: Array, color: Color) -> void:
	var top := INF
	var bottom := -INF
	for p: Vector2 in vertices:
		top = minf(top,p.y)
		bottom = maxf(bottom,p.y)
	for row in range(floori(top/GRID),ceili(bottom/GRID)):
		var y := (row+0.5)*GRID
		var cuts: Array[float] = []
		for i in vertices.size():
			var a: Vector2 = vertices[i]
			var b: Vector2 = vertices[(i+1)%vertices.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y): cuts.append(a.x+(y-a.y)*(b.x-a.x)/(b.y-a.y))
		cuts.sort()
		for i in range(0,cuts.size()-1,2):
			var left := roundf(cuts[i]/GRID)*GRID
			var right := roundf(cuts[i+1]/GRID)*GRID
			if right > left: canvas.draw_rect(Rect2(left,row*GRID,right-left,GRID),color)

static func transformed(canvas: CanvasItem, vertices: Array, color: Color, origin: Vector2, direction: Vector2, scale := Vector2.ONE) -> void:
	var points: Array = []
	for p: Vector2 in vertices: points.append(origin+(p*scale).rotated(direction.angle()))
	poly(canvas,points,color)

static func tentacle(canvas: CanvasItem, direction: Vector2, dimensions: Vector2, elapsed: float) -> void:
	var t := floorf(elapsed*60.0)/60.0
	if t < -0.045 or t > 0.105: return
	var fade := 1.0-smoothstep(0.025,0.105,t)
	var color := Color("754568")
	color.a = fade*0.64
	# A narrow bent whip wake leaves the authored flesh silhouette dominant.
	transformed(canvas,[Vector2(44,-8),Vector2(90,-20),Vector2(134,-11),Vector2(147,0),Vector2(126,-3),Vector2(89,-12)],color,Vector2.ZERO,direction,dimensions)
	if t >= 0.0 and t < 0.065:
		var center := Vector2(137,3)*dimensions
		var at := center.rotated(direction.angle())
		var pink := Color("c885aa")
		pink.a = 1.0-t/0.065
		transformed(canvas,[Vector2(-10,-2),Vector2(-3,-5),Vector2(7,-3),Vector2(14,0),Vector2(4,4),Vector2(-6,3)],pink,at,direction)
		for i in 3:
			var p := at+Vector2(10+i*5,-5+i*5).rotated(direction.angle())
			canvas.draw_rect(Rect2((p/2.0).round()*2.0,Vector2(4,2)),Color(0.55,0.29,0.44,pink.a*0.7))

static func spear(canvas: CanvasItem, direction: Vector2, tip: float, half_width: float, elapsed: float, duration: float) -> void:
	if elapsed < 0 or elapsed > duration+0.08: return
	var fade := 1.0-smoothstep(duration*0.6,duration+0.08,elapsed)
	var width := clampf(half_width*1.18,12,30)*fade
	var back := maxf(25,tip-132)
	var shape := [Vector2(back,0),Vector2(tip-48,-width),Vector2(tip+5,0),Vector2(tip-48,width)]
	transformed(canvas,shape,Color(0.24,0.43,0.40,0.95*fade),Vector2.ZERO,direction)
	transformed(canvas,[Vector2(back+20,0),Vector2(tip-32,-width*0.64),Vector2(tip+6,0),Vector2(tip-32,width*0.64)],Color(0.57,0.81,0.74,fade),Vector2.ZERO,direction)
	transformed(canvas,[Vector2(tip-56,-3),Vector2(tip+6,0),Vector2(tip-56,3)],Color(0.92,0.98,0.87,fade),Vector2.ZERO,direction)

static func rocks(canvas: CanvasItem, point: Vector2, direction: Vector2, elapsed: float, length: float, child: bool, size: float, clearance: float) -> void:
	if elapsed < 0 or elapsed > 1.25: return
	var t := floorf(elapsed*18.0)/18.0
	var fade := 1.0-smoothstep(0.78,1.25,t)
	var run := minf(length,112.0)*size
	var start := 0.0 if child else -run*0.42
	var end := run*0.5 if not child else run
	start = maxf(start,clearance-point.dot(direction))
	if start >= end: return
	var side := Vector2(-direction.y,direction.x)
	var seed_value := floori(point.dot(direction)/maxf(length,1.0))
	# Short bent cuts, interrupted by earth bridges and overlapping rock roots.
	for segment in 4:
		if posmod(segment+seed_value,5)==2: continue
		var x0 := lerpf(start,end,segment/4.0)
		var x1 := lerpf(start,end,(segment+0.86)/4.0)
		var y0 := sin(seed_value*2.3+segment*2.1)*5.0*size
		var y1 := sin(seed_value*2.3+(segment+1)*2.1)*5.0*size
		var slit := [Vector2(x0,y0-2),Vector2((x0+x1)*0.5,y1-4),Vector2(x1,y1-2),Vector2(x1,y1+2),Vector2((x0+x1)*0.5,y1+3),Vector2(x0,y0+2)]
		transformed(canvas,slit,Color(0.16,0.12,0.10,fade),point,direction)
	var count := 4+posmod(seed_value*7,3)
	for i in count:
		var variation := absf(sin(seed_value*5.73+i*3.19))
		var u := clampf((i+0.35+sin(seed_value*3.1+i*4.7)*0.26)/float(count),0.08,0.92)
		var delay := i*0.018
		var rise := 1.0-pow(1.0-clampf((t-delay)/0.12,0,1),3)
		var sink := 1.0-smoothstep(0.5+delay,1.1+delay,t)
		var height := lerpf(23,43,variation)*size*rise*sink*(0.7 if child else 1.0)
		var width := lerpf(8,15,absf(cos(seed_value*4.7+i*2.1)))*size
		var lean := sin(seed_value*2.9+i*3.7)*16.0*size
		var base := lerpf(-2,8,variation)*size
		for sign_value in [-1.0,1.0]:
			var asymmetric := sin(seed_value*4.3+i*2.7+sign_value*1.4)
			var rock_height := height*(1.0+asymmetric*0.18)
			var rock_width := width*(1.0+cos(i*3.3+sign_value)*0.12)
			var rock_lean := lean+asymmetric*7.0*size
			var center: Vector2 = point+direction*(lerpf(start,end,u)+asymmetric*6.0*size)+side*(base+asymmetric*3)*sign_value
			var local_scale := Vector2(1,sign_value*0.80)
			var body := [Vector2(-rock_width,-3),Vector2(-rock_width*0.7, rock_height*0.48),Vector2(rock_lean-3,rock_height),Vector2(rock_lean+4,rock_height-3),Vector2(rock_width,rock_height*0.30),Vector2(rock_width,-3)]
			transformed(canvas,body,Color(0.34,0.29,0.24,fade),center,direction,local_scale)
			transformed(canvas,[Vector2(-rock_width,-3),Vector2(-rock_width*0.7,rock_height*0.48),Vector2(rock_lean-3,rock_height),Vector2(rock_lean,rock_height*0.36),Vector2(2,-3)],Color(0.56,0.48,0.36,fade),center,direction,local_scale)
			transformed(canvas,[Vector2(rock_lean-3,rock_height),Vector2(rock_lean+4,rock_height-3),Vector2(rock_lean,rock_height*0.36)],Color(0.70,0.62,0.47,fade),center,direction,local_scale)
			if t < 0.30:
				var p: Vector2 = center+direction*(lean+t*20)+side*sign_value*(base+sin(t/0.30*PI)*12)
				canvas.draw_rect(Rect2((p/2).round()*2,Vector2(4,2)),Color(0.49,0.36,0.23,(1-t/0.30)*0.85))

static func arrow(canvas: CanvasItem, direction: Vector2, elapsed: float) -> void:
	# The steel arrowhead stays compact; the wake is shorter than the shaft.
	var length := minf(24,elapsed*450)
	transformed(canvas,[Vector2(-16-length,0),Vector2(-18,-2),Vector2(-12,0),Vector2(-18,2)],Color(0.62,0.65,0.45,0.48),Vector2.ZERO,direction,Vector2.ONE*2)
	transformed(canvas,[Vector2(10,0),Vector2(2,-4),Vector2(4,0),Vector2(2,4)],Color("bfc6b0"),Vector2.ZERO,direction,Vector2.ONE*2)
	transformed(canvas,[Vector2(-14,-1),Vector2(4,-1),Vector2(4,1),Vector2(-14,1)],Color("856340"),Vector2.ZERO,direction,Vector2.ONE*2)
	transformed(canvas,[Vector2(-15,0),Vector2(-21,-4),Vector2(-19,0),Vector2(-21,4)],Color("747f59"),Vector2.ZERO,direction,Vector2.ONE*2)
