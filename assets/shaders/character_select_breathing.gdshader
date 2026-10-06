shader_type canvas_item;
render_mode unshaded;

// Stretch the chest around a fixed waist. Head keeps its shape; legs stay still.
uniform float breath_amount = 0.0;
uniform float shoulder_y = 0.375; // Row 24 in the shared 64px character canvas.
uniform float waist_y = 0.5625;   // Row 36; everything below is sampled unchanged.
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec2 source_uv = UV;
	float head_lift = (waist_y - shoulder_y) * breath_amount;
	if (UV.y < shoulder_y - head_lift) {
		source_uv.y += head_lift;
	} else if (UV.y < waist_y) {
		source_uv.y = waist_y - (waist_y - UV.y) / (1.0 + breath_amount);
	}
	COLOR = texture(TEXTURE, source_uv) * sprite_tint;
}
