shader_type canvas_item;
render_mode unshaded;

// Stretch around the opaque sprite's sole; breathing never lifts the feet.
uniform float breath_amount = 0.0;
uniform float foot_y = 0.90625;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec2 source_uv = UV;
	source_uv.y = foot_y + (UV.y - foot_y) / (1.0 + breath_amount);
	COLOR = texture(TEXTURE, source_uv) * sprite_tint;
	if (source_uv.y < 0.0 || source_uv.y > 1.0) {
		COLOR.a = 0.0;
	}
}
