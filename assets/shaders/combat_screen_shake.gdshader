shader_type canvas_item;
render_mode unshaded;

uniform vec2 shake_uv = vec2(0.0);
varying vec4 presentation_tint;

void vertex() {
	presentation_tint = COLOR;
}

void fragment() {
	// Extend the last pixel at the viewport edge instead of exposing a dark strip.
	vec2 half_pixel = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 sample_uv = clamp(UV - shake_uv, half_pixel, vec2(1.0) - half_pixel);
	COLOR = texture(TEXTURE, sample_uv) * presentation_tint;
}
