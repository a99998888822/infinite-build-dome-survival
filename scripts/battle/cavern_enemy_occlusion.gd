extends RefCounted
## Pooled, stone-masked silhouettes. Actor art and hit materials stay untouched.
const SHADER = preload("res://shaders/battle/cavern_enemy_occlusion.gdshader")
const POOL_META := &"enemy_occlusion_pool"

static func update(rocks: Array[Sprite2D], enabled: bool, horizon: CavernBattleHorizon) -> int:
	var count := 0
	var actors: Array[Sprite2D] = []
	if enabled and not rocks.is_empty():
		for node in EnemyRegistry.get_registered_enemies():
			var enemy := node as EnemyController
			if enemy == null or not enemy.alive or enemy.is_queued_for_deletion(): continue
			var source := enemy.sprite
			if source != null and source.texture != null and source.is_visible_in_tree(): actors.append(source)
	for rock in rocks:
		var pool: Array = rock.get_meta(POOL_META, [])
		var used := 0
		var rock_area := rock.global_transform * rock.get_rect()
		for source in actors:
			if source.get_viewport() != rock.get_viewport() or source.get_parent().global_position.y >= rock.global_position.y: continue
			var rect := source.get_rect()
			if not rock_area.intersects(source.global_transform * rect): continue
			if used == pool.size():
				var overlay := Sprite2D.new()
				overlay.name = "EnemyOcclusion"
				overlay.material = ShaderMaterial.new()
				(overlay.material as ShaderMaterial).shader = SHADER
				overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				rock.add_child(overlay)
				pool.append(overlay)
			var overlay: Sprite2D = pool[used]
			overlay.texture = rock.texture
			overlay.offset = rock.offset
			overlay.flip_h = rock.flip_h
			overlay.flip_v = rock.flip_v
			overlay.show()
			var inverse := source.global_transform.affine_inverse()
			var row_x := Vector3(inverse.x.x, inverse.y.x, inverse.origin.x - rect.position.x) / rect.size.x
			var row_y := Vector3(inverse.x.y, inverse.y.y, inverse.origin.y - rect.position.y) / rect.size.y
			if source.flip_h: row_x = -row_x + Vector3(0, 0, 1)
			if source.flip_v: row_y = -row_y + Vector3(0, 0, 1)
			var material := overlay.material as ShaderMaterial
			var texture := source.texture
			var frame_size := texture.get_size() / Vector2(source.hframes, source.vframes)
			var frame_origin := Vector2(source.frame_coords) * frame_size
			# SpriteFrames (knight/wolf) use cropped atlas resources, whereas
			# grub/bat use hframes. A shader sampler receives the entire atlas.
			if texture is AtlasTexture:
				frame_origin += texture.region.position
				texture = texture.atlas
			material.set_shader_parameter("actor_texture", texture)
			material.set_shader_parameter("actor_uv_x", row_x)
			material.set_shader_parameter("actor_uv_y", row_y)
			material.set_shader_parameter("actor_frame_origin", frame_origin / texture.get_size())
			material.set_shader_parameter("actor_frame_size", frame_size / texture.get_size())
			material.set_shader_parameter("actor_pixel", Vector2.ONE / rect.size)
			material.set_shader_parameter("strength", source.modulate.a * source.self_modulate.a)
			material.set_shader_parameter("view_size", horizon.view_size)
			material.set_shader_parameter("fade_start", horizon.far_height() * .62)
			material.set_shader_parameter("fade_end", horizon.ground_fade_end())
			used += 1
		for index in range(used, pool.size()): (pool[index] as Sprite2D).hide()
		rock.set_meta(POOL_META, pool)
		count += used
	return count
