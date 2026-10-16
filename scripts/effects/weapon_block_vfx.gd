extends RefCounted
## Render-only authored pixel masses. Playback follows each weapon's own clock.
const CLIPS := {
	"grenade": [preload("res://assets/sprites/weapons/effects/block_vfx/grenade.png"), Vector2(128, 128), 12],
	"tome": [preload("res://assets/sprites/weapons/effects/block_vfx/tome.png"), Vector2(96, 128), 10],
	"tentacle": [preload("res://assets/sprites/weapons/effects/block_vfx/tentacle.png"), Vector2(160, 128), 8],
	"hammer": [preload("res://assets/sprites/weapons/effects/block_vfx/hammer.png"), Vector2(128, 128), 8],
	"spear": [preload("res://assets/sprites/weapons/effects/block_vfx/spear.png"), Vector2(192, 64), 7],
}


static func draw(canvas: CanvasItem, key: String, progress: float, destination: Rect2, tint: Color = Color.WHITE) -> void:
	if progress < 0.0 or progress >= 1.0: return
	var clip: Array = CLIPS[key]
	var size: Vector2 = clip[1]
	var frame := clampi(int(progress * int(clip[2])), 0, int(clip[2]) - 1)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect_region(clip[0], destination, Rect2(Vector2(frame * size.x, 0), size), tint)
