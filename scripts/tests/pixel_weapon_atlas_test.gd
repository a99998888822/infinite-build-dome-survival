extends "res://scripts/tests/meteor_flail_test.gd"
## Verify authored trail pixels stay behind the actual head across live swing variants.
var _trail_pixels: Dictionary = {}

func pixels_for_frame(frame: int) -> PackedVector2Array:
	if not _trail_pixels.has(frame):
		var image := MeteorFlail.TRAIL.get_image().get_region(Rect2i(frame * 320, 0, 320, 320))
		var bounds := image.get_used_rect()
		var points := PackedVector2Array()
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				if image.get_pixel(x, y).a > 0.5:
					points.append(Vector2(x + 0.5, y + 0.5) - Vector2(160,160))
		_trail_pixels[frame] = points
	return _trail_pixels[frame]

func _run() -> void:
	CampProgression.begin_transient_session()
	var flail := await fixture([])
	weapon.use_active_range_rules = true
	flail._add_swing(1.2, 0.03, 0.32, 0.4, true, 1)
	check(MeteorFlail.TRAIL.get_size() == Vector2(5760,320), "production flail atlas has all eighteen frames")
	check(WindBladeEffect.ATLAS.get_size() == Vector2(1536,96), "production wind atlas has all twelve frames")
	for bonus in [0, 100]:
		weapon.runtime_stats.area_size = bonus
		for direction in [Vector2.RIGHT, Vector2(-0.6,0.8)]:
			flail.heading = direction
			for swing in flail.swings:
				var begin := float(swing.start) + float(swing.windup)
				var duration := float(swing.duration)
				check(flail.trail_frame_for_swing(swing, begin - 0.001) == -1 and flail.trail_frame_for_swing(swing, begin + duration + 0.001) == -1, "trail is absent during windup and recovery")
				for progress in [0.0, 0.11, 0.5, 0.89, 1.0]:
					var at_time: float = begin + duration * progress
					var frame := flail.trail_frame_for_swing(swing, at_time)
					check(frame >= 4 and frame <= 14, "normal and delayed split swings select occupied frames")
					if frame < 4 or frame > 14: continue
					var transform := flail.trail_transform_for_swing(swing, at_time, frame)
					var head := flail.head_position(swing, at_time)
					var points := pixels_for_frame(frame)
					var aligned := not points.is_empty()
					var nearest := INF
					for pixel in points:
						var point := transform * pixel
						var behind := head.angle_to(point) * float(swing.sign)
						aligned = aligned and behind <= 0.04 and behind >= -0.52
						aligned = aligned and point.length() <= head.length() * 1.03 and point.length() >= head.length() * 0.80
						nearest = minf(nearest, point.distance_to(head))
					check(aligned and nearest < 16.0 * head.length() / 144.0, "actual atlas pixels follow the head for direction, reverse, range and split variants")
	flail.cancel()
	weapon.runtime_stats.area_size = 0
	var origin := Vector2(25,10)
	var direction := Vector2(-0.6,0.8)
	WindBladeEffect.spawn(host, origin, direction, 480.0, 0.92, weapon, weapon.calculate_damage_events()[0])
	var wind := host.get_child(host.get_child_count()-1) as WindBladeEffect
	wind.set_process(false)
	wind._process(0.23)
	check(wind.position.is_equal_approx(origin + direction * 110.4) and is_equal_approx(wind.rotation, direction.angle()), "atlas wind keeps real travel speed and heading")
	GameGlobal.set_runtime_flag("battle_runtime_paused", true)
	wind._process(0.5)
	check(is_equal_approx(wind._elapsed,0.23), "pause freezes the wind animation clock")
	GameGlobal.set_runtime_flag("battle_runtime_paused", false)
	wind._process(0.70)
	check(wind.is_queued_for_deletion(), "custom wind lifetime still releases the effect")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	CampProgression.end_transient_session()
	print("PIXEL_WEAPON_ATLAS checks=",checks," failures=",failures)
	get_tree().quit(0 if failures == 0 else 1)
