extends CavernSunlightBackdrop
## Frozen pre-streaming planner; independent regression oracle.
func _original_population(key: Vector2i) -> Array[Dictionary]:
	var solids := _solid_plan(key)
	var rng: RandomNumberGenerator = solids.rng
	var plan: Array[Dictionary] = solids.entries
	var nearby: Array[Dictionary] = solids.nearby
	var origin := Vector2(key)*CELL
	# Pick the greener candidate in each small ground patch, then place a tight
	# cluster there. This is evaluated only on cell creation, never every frame.
	var grass_points: Array[Vector2] = []
	for row in 5:
		for col in 10:
			var center := origin+Vector2((col+.5)*53,(row+.5)*49)
			var best := -1.0
			for attempt in 4:
				var candidate := origin+Vector2((col+.5)*53,(row+.5)*49)+Vector2(rng.randf_range(-19,19),rng.randf_range(-16,16))
				var score := sample_surface(candidate).a
				if score>best:
					best = score
					center = candidate
			if best<.36: continue
			for blade in rng.randi_range(3,6):
				var point := center+Vector2(rng.randf_range(-22,22),rng.randf_range(-13,13))
				point = point.clamp(origin+Vector2(8,8),origin+CELL-Vector2(8,8)).round()
				var surface := sample_surface(point)
				if surface.a<.30: continue
				var on_base := false
				for other: Dictionary in nearby:
					var d: Vector2 = point-other.point
					if absf(d.x)<68 and d.y>-24 and d.y<5: on_base = true
				if on_base: continue
				var clear := true
				for previous: Vector2 in grass_points:
					if point.distance_squared_to(previous)<100: clear = false; break
				if not clear: continue
				for entry: Dictionary in plan:
					if entry.kind=="rubble" and point.distance_to(entry.point)<28: clear = false; break
				if not clear: continue
				grass_points.append(point)
				var index := rng.randi_range(0,2) if surface.a>.52 else (3 if rng.randf()<.25 else 0)
				var entry := _placement("grass",index,point,rng.randf_range(.95,1.25),rng.randf()<.5)
				entry.tint = Color(.74,.80,.77) if index!=3 else Color(.76,.79,.73)
				entry.suitability = surface.a
				plan.append(entry)
	# Sparse, staggered tufts soften the visible lower edge of every object.
	# Size the fringe to the artwork, including padding and high-density stones.
	var companions: Array[Dictionary] = []
	for solid: Dictionary in plan:
		if solid.kind not in ["prop","rubble"]: continue
		var row: Dictionary = config.props[solid.index] if solid.kind=="prop" else config.rubble[solid.index]
		var bounds := _scenery_bounds(row.texture)
		var factor := float(solid.scale)/float(row.get("texture_density",1.0))
		var anchor: Vector2 = solid.anchor
		var width := bounds.size.x*factor
		var center_x := (bounds.get_center().x-anchor.x)*factor
		if solid.flip: center_x = -center_x
		var bottom := (bounds.end.y-anchor.y)*factor
		var count := clampi(ceili(width/24.0),2,6)
		var tuft_height := clampf(bounds.size.y*factor*.42,10.0,22.0)
		for i in count:
			var across := (float(i)+rng.randf_range(.15,.85))/float(count)-.5
			# Stay just in front of the host's depth boundary, even for padded art.
			var offset_y := maxf(1.0,bottom+rng.randf_range(1,3))
			var point: Vector2 = solid.point+Vector2(center_x+across*width*.94,offset_y)
			var surface := sample_surface(point)
			var index := rng.randi_range(0,1) if surface.a>=.30 else 3
			var grass_height := _scenery_bounds(config.grass[index].texture).size.y
			var scale := tuft_height/grass_height*rng.randf_range(.9,1.1)
			var entry := _placement("grass",index,point,scale,rng.randf()<.5)
			entry.tint = Color(.74,.80,.77) if index!=3 else Color(.76,.79,.73)
			entry.suitability = surface.a
			entry.companion = true
			entry.host_point = solid.point
			companions.append(entry)
	plan.append_array(companions)
	return plan

func original_plan(key: Vector2i) -> Array[Dictionary]:
	# Keep the approved grass assets around this battle's sparse object layout.
	var plan: Array[Dictionary] = _original_population(key)
	var solids := _solid_plan(key)
	var rng: RandomNumberGenerator = solids.rng
	var origin := Vector2(key)*CELL
	for entry: Dictionary in plan:
		if entry.kind=="grass":
			entry.tint = Color(.65,.73,.70) if entry.index!=3 else Color(.66,.69,.65)
	# A second, shorter layer joins tufts into meadow patches. Density follows
	# the continuous biome mask, preserving bare paths without a tiled grid.
	for row in 7:
		for col in 17:
			var center := origin+Vector2((col+.5)*CELL.x/17,(row+.5)*CELL.y/7)
			center += Vector2(rng.randf_range(-13,13),rng.randf_range(-12,12))
			var moisture := sample_surface(center).a
			if moisture<.5 or rng.randf()>moisture: continue
			for blade in rng.randi_range(4,7):
				var point := center+Vector2(rng.randf_range(-22,22),rng.randf_range(-13,13))
				point = point.clamp(origin+Vector2(3,3),origin+CELL-Vector2(3,3)).round()
				var surface := sample_surface(point)
				if surface.a<.43: continue
				var clear := true
				for solid: Dictionary in solids.entries:
					var d: Vector2 = point-solid.point
					if solid.kind=="prop" and absf(d.x)<66 and d.y>-22 and d.y<7: clear = false
					if solid.kind=="rubble" and d.length()<16: clear = false
				if not clear: continue
				var entry := _placement("grass",rng.randi_range(0,2),point,rng.randf_range(.48,.78),rng.randf()<.5)
				var shade := rng.randf_range(.93,1.04)
				entry.tint = Color(.60*shade,.67*shade,.65*shade)
				entry.suitability = surface.a
				entry.undergrowth = true
				plan.append(entry)
	if shelter_clearance.has_area():
		plan = plan.filter(func(entry: Dictionary): return not shelter_clearance.has_point(entry.point))
	return plan

