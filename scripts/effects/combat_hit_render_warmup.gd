extends RefCounted
## Render-only samples, owned by the opaque dungeon loading curtain.
const ATLAS = preload("res://scripts/effects/aligned_atlas.gd")
const MOBILITY = preload("res://scripts/effects/mobility_atlas_effect.gd")
const FIRE = preload("res://scripts/effects/pixel_fire_visual.gd")
const GROUND = preload("res://scripts/effects/spell_ground_area.gd")
const FOOTPRINT = preload("res://scripts/effects/spell_footprint.gd")
const WHITE = preload("res://assets/shaders/enemy_hit_white.gdshader")

static func prepare(parent: Node2D, weapons: Array, body_texture: Texture2D) -> void:
	# Enchantment seeds/statuses use a separate shader from the lamp's jet.
	# Loading pauses the shared clock, so explicitly submit the real fire batch.
	var fire := FIRE.new()
	parent.add_child(fire)
	fire.setup_single(Vector2(14, 22), 2)
	FIRE.clock.flush()
	# Fire seeds land on a separate ground-coverage shader. Draw its real path
	# during the same opaque loading frame, without creating a gameplay field.
	var ground := GROUND.new()
	parent.add_child(ground)
	ground.setup(FOOTPRINT.axes(30.0), Color(0.65, 0.19, 0.04, 0.22), Color(1.0, 0.42, 0.07, 0.6))
	# Hidden pooled Labels allocate nodes but never rasterize their glyphs.
	# Draw both sizes and every magnitude style before a crowd can be hit.
	for critical in [false, true]:
		for amount in [1, 100, 10000, 1000000]:
			var label := Label.new()
			label.theme = EnemyController._get_damage_number_theme(amount, critical)
			label.text = "0123456789"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(label)
	if body_texture != null:
		var body := Sprite2D.new()
		body.texture = body_texture
		body.region_enabled = true
		body.region_rect = Rect2(Vector2.ZERO, body_texture.get_size().min(Vector2(96, 96)))
		var material := ShaderMaterial.new()
		material.shader = WHITE
		material.set_shader_parameter("white_amount", 1.0)
		body.material = material
		parent.add_child(body)
	for weapon: WeaponInstance in weapons:
		if str(weapon.weapon_data.get("projectile_behavior", "")) != "dash_blade": continue
		for key in ["dash_trail", "dash_circle"]:
			var clip: Array = MOBILITY.CLIPS[key]
			var sprite := Sprite2D.new()
			sprite.texture = clip[0]
			sprite.hframes = clip[2]
			sprite.offset = clip[1] * 0.5 - clip[4]
			parent.add_child(sprite)
			ATLAS.configure_sprite(sprite, 2.0)
		break
