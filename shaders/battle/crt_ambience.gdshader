shader_type canvas_item;
render_mode unshaded;

uniform float time_seconds = 0.0;


void fragment() {
	float scanline_row = mod(floor(UV.y / SCREEN_PIXEL_SIZE.y), 3.0);
	float scanline = 0.075 * (1.0 - step(0.5, scanline_row));
	vec2 edge = min(UV, vec2(1.0) - UV);
	float edge_distance = min(edge.x, edge.y);
	float vignette = 1.0 - smoothstep(0.0, 0.24, edge_distance);
	float flicker = 0.93 + sin(time_seconds * 2.7) * 0.025;
	float alpha = clamp((scanline + vignette * 0.23) * flicker, 0.0, 0.35);
	COLOR = vec4(0.0, 0.008, 0.0, alpha);
}
