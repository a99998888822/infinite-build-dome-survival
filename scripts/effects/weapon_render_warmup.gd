extends RefCounted
## Render-only first-use resources, drawn beneath the dungeon entry curtain.
## Cover these shared paths even when the weapon is acquired later in the run.
const FLAME = preload("res://scripts/effects/copper_lamp_flame.gd")
const JET = preload("res://scripts/effects/cannon_jet_flame.gd")
const PLASMA = preload("res://scripts/effects/plasma_ball_visual.gd")
const ATLAS = preload("res://scripts/effects/aligned_atlas.gd")
const COOLDOWN = preload("res://shaders/ui/weapon_cooldown.gdshader")
const FURNACE_SABER = preload("res://scripts/effects/candidate_weapon_art.gd")
const KINDS: Array[String] = ["lamp", "cannon", "plasma", "cooldown", "furnace", "saber"]

static func prepare(parent: Node2D, kind: String) -> void:
	if kind == "furnace" or kind == "saber":
		var effect: Node2D
		if kind == "furnace":
			effect = FURNACE_SABER.ring(parent, Vector2.ZERO)
		else:
			effect = FURNACE_SABER.cut(parent, Vector2(-150, 0), Vector2(150, 0))
		effect.manual_clock = true
		effect.sample(0.25 if kind == "furnace" else 0.05)
		return
	if kind == "cooldown":
		# The HUD keeps this material hidden until the first cast. Submit its
		# real ColorRect path under the curtain without changing weapon state.
		var mask := ColorRect.new()
		mask.name = "CooldownRenderWarmup"
		mask.size = Vector2(48, 48)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.material = ShaderMaterial.new()
		mask.material.shader = COOLDOWN
		mask.material.set_shader_parameter("remaining", 0.5)
		parent.add_child(mask)
		return
	if kind == "plasma":
		# Prepare the existing deterministic core frames and upload each texture.
		# No projectile identity, damage, targeting or random stream is involved.
		PLASMA._prepare_core_frames()
		var canvas := Node2D.new()
		parent.add_child(canvas)
		for frame in PLASMA._core_frames.size():
			var point := Vector2(frame % 4, frame / 4) * 28.0
			ATLAS.draw(canvas, PLASMA._core_frames[frame], Rect2(point, Vector2(24,24)),
				Rect2(0,0,24,24), Color.WHITE, Transform2D.IDENTITY, 1.0, false)
		return
	if kind != "lamp" and kind != "cannon": return
	# Instantiate only the visual base: CannonJetFlame's runtime, groups, audio
	# and weapon ownership are deliberately not activated by this sample.
	var flame := FLAME.new()
	if kind == "cannon": flame.flame_material.shader = JET.JET_SHADER
	parent.add_child(flame)
	flame.configure(Vector2.RIGHT, 120.0, 60.0, 0.2, false)
	if kind == "cannon": flame.flame_material.set_shader_parameter("opacity", 1.0)
