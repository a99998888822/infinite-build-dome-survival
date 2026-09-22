shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_origin = vec2(0.0);
uniform vec2 surface_size = vec2(1152.0, 648.0);
uniform vec2 player_position = vec2(0.0);
uniform float environment_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

#include "res://shaders/battle/wetland_horizon.gdshaderinc"

void fragment() {
	vec2 p = floor(UV * surface_size + world_origin);
	float basin = noise21(p / vec2(170.0, 100.0));
	float grit = floor(noise21(p / 5.0) * 4.0) / 4.0;
	float wet = smoothstep(0.36, 0.70, basin);
	vec3 color = mix(vec3(0.054, 0.083, 0.074), vec3(0.026, 0.065, 0.065), wet);
	color += (grit - 0.5) * 0.018;
	float broken = step(0.82, hash21(floor(p / vec2(13.0, 5.0))));
	float glint = step(0.92, fract(p.y / 13.0)) * broken * wet;
	color += vec3(0.012, 0.035, 0.031) * glint * (0.6 + 0.4 * sin(environment_time * 0.7 + p.x * 0.05));
	float player_light = 1.0 - smoothstep(12.0, 115.0, length((p - player_position) * vec2(1.0, 1.4)));
	color += vec3(0.014, 0.018, 0.011) * player_light;
	color = horizon_surface(color, p, SCREEN_UV, environment_time);
	COLOR = vec4(color, 1.0);
}
