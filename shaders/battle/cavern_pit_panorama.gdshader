shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/cavern_pit_palette.gdshaderinc"
varying vec4 cave_tint;

void vertex() { cave_tint = COLOR; }

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Preserve the original purple backdrop; the pit mask now matches it.
	vec3 difference = abs(source.rgb - CAVE_MATTE);
	float detail = smoothstep(1.0 / 255.0, 12.0 / 255.0,
		max(difference.r, max(difference.g, difference.b)));
	vec3 lit = source.rgb * cave_tint.rgb;
	COLOR = vec4(mix(CAVE_MATTE, lit, detail), source.a * cave_tint.a);
}
