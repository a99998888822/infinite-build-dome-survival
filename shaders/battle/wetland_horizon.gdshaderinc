// A compressed continuation of the wetland, evaluated behind all stone/actors.
#include "res://shaders/battle/horizon_depth.gdshaderinc"
uniform vec2 world_units_per_pixel = vec2(1.0);
uniform sampler2D sky_texture : source_color, filter_nearest, repeat_disable;

vec3 horizon_surface(vec3 ground_color, vec2 p, vec2 screen_uv, float time) {
	vec2 screen_pixel = floor(screen_uv * ui_view_size);
	float depth = (screen_pixel.y - horizon_y) / max(fold_height, 1.0);
	if (fold_height <= 0.0 || depth < 0.0 || depth >= 1.0) {
		return ground_color;
	}
	float x = p.x / max(world_units_per_pixel.x, 0.001);
	float bend = sin(x * 0.013 + time * 0.82) * sin(x * 0.004 - time * 0.31);
	float d = clamp(depth + bend * 1.3 / fold_height, 0.0, 1.0);
	// Logarithmic depth bunches texture towards the horizon, with a derivative
	// of 1 at the near end so the unchanged world surface joins smoothly.
	float depth_offset = log(0.14 + 0.86 * d) / 0.86 - (d - 1.0);
	vec2 projected = p + vec2(0.0, depth_offset * fold_height * world_units_per_pixel.y);
	float basin = noise21(projected / vec2(170.0, 100.0));
	vec3 water = mix(vec3(0.054, 0.083, 0.074), vec3(0.026, 0.065, 0.065), smoothstep(0.36, 0.70, basin));
	water = mix(vec3(0.026, 0.043, 0.043), water, smoothstep(0.0, 0.85, d));
	float phase_y = projected.y / max(world_units_per_pixel.y, 0.001) / 12.0;
	float row = floor(phase_y);
	float phase = fract(phase_y + time * 0.032 + noise21(vec2(x / 42.0, row)) * 0.22);
	float thickness = clamp(1.0 / (12.0 * (0.14 + 0.86 * d)), 0.08, 0.27);
	float wave = 1.0 - smoothstep(thickness * 0.4, thickness, abs(phase - 0.5));
	float broken = step(0.48, hash21(vec2(floor(x / 19.0), row)));
	float far_envelope = 1.0 - smoothstep(0.15, 0.96, d);
	float wave_strength = wave * broken * far_envelope;
	vec2 reflection_uv = vec2(clamp(screen_uv.x + bend / ui_view_size.x, 0.0, 1.0), 1.0 - d * 0.78);
	vec3 reflected_sky = texture(sky_texture, reflection_uv).rgb;
	float luminance = dot(reflected_sky, vec3(0.299, 0.587, 0.114));
	reflected_sky = mix(vec3(luminance), reflected_sky, 0.48);
	water += reflected_sky * (0.06 + wave_strength * 0.18) * far_envelope;
	water += vec3(0.019, 0.032, 0.029) * wave_strength;
	// A dim, interrupted turn at the far edge; never a continuous bright seam.
	float crest = (1.0 - smoothstep(1.0, 4.0, depth * fold_height));
	crest *= smoothstep(0.42, 0.70, noise21(vec2(x / 48.0, 5.0)));
	water += vec3(0.031, 0.017, 0.012) * crest;
	float irregular = (noise21(vec2(x / 37.0, 11.0)) - 0.5) * 0.12;
	float blend = 1.0 - smoothstep(0.30, 1.0, clamp(d + irregular * sin(d * 3.14159), 0.0, 1.0));
	return mix(ground_color, water, blend);
}
