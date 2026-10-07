shader_type canvas_item;
render_mode unshaded;

// Move every part of the sprite together, preserving its shape.
uniform float breath_amount = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec2 source_uv = UV;
	source_uv.y += breath_amount;
	COLOR = texture(TEXTURE, source_uv) * sprite_tint;
	if (source_uv.y < 0.0 || source_uv.y > 1.0) {
		COLOR.a = 0.0;
	}
}
