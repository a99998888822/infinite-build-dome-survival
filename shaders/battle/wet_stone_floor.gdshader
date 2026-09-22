shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/battle/horizon_depth.gdshaderinc"

uniform float environment_time = 0.0;
uniform vec3 wet_tint : source_color = vec3(0.025, 0.145, 0.150);
uniform vec3 water_highlight : source_color = vec3(0.155, 0.390, 0.365);
uniform vec3 moss_tint : source_color = vec3(0.285, 0.405, 0.120);
uniform float wet_start : hint_range(0.0, 1.5) = 0.50;
uniform float wet_end : hint_range(0.0, 1.5) = 1.02;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.72;


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 345.45));
	value += dot(value, value + 34.345);
	return fract(value.x * value.y);
}


float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	local = local * local * (3.0 - 2.0 * local);
	float bottom_left = hash21(cell);
	float bottom_right = hash21(cell + vec2(1.0, 0.0));
	float top_left = hash21(cell + vec2(0.0, 1.0));
	float top_right = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(bottom_left, bottom_right, local.x), mix(top_left, top_right, local.x), local.y);
}


float ripple_ring(vec2 uv, vec2 center, float phase) {
	vec2 delta = (uv - center) * vec2(1.0, 1.85);
	float cycle = fract(environment_time * 0.105 + phase);
	float radius = mix(0.012, 0.115, cycle);
	float ring_distance = abs(length(delta) - radius);
	float ring = 1.0 - smoothstep(0.0015, 0.0045, ring_distance);
	float envelope = smoothstep(0.0, 0.08, cycle) * (1.0 - smoothstep(0.58, 0.92, cycle));
	float broken_arc = smoothstep(0.18, 0.52, value_noise(floor((uv - center) * vec2(180.0, 90.0)) + phase * 31.0));
	return ring * envelope * broken_arc;
}


void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pixel = floor(UV * texture_size);
	vec2 snapped_uv = (pixel + vec2(0.5)) / texture_size;
	vec4 texel = texture(TEXTURE, snapped_uv);

	vec2 centered = snapped_uv - vec2(0.5);
	float radius = length(centered) * 2.0;
	float broad_noise = value_noise(snapped_uv * vec2(7.0, 5.0));
	float detail_noise = value_noise(snapped_uv * vec2(31.0, 19.0));
	float irregular_edge = (broad_noise - 0.5) * 0.13 + (detail_noise - 0.5) * 0.035;
	float wetness = smoothstep(wet_start, wet_end, radius + irregular_edge);

	float luminance = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	float dark_pool = smoothstep(0.40, 0.93, 1.0 - luminance) * smoothstep(0.34, 0.78, radius);
	wetness = clamp(max(wetness, dark_pool * 0.62), 0.0, 1.0);

	vec3 wet_color = texel.rgb * 0.52 + wet_tint * 0.48;
	vec3 color = mix(texel.rgb, wet_color, wetness * wet_strength);

	float horizontal_glint = 1.0 - smoothstep(0.0, 0.95, abs(sin(pixel.x * 0.072 + environment_time * 0.38 + broad_noise * 7.0)));
	float glint_row = step(0.9, fract((pixel.y + floor(broad_noise * 13.0)) / 11.0));
	float glint_break = step(0.63, hash21(floor(pixel / vec2(18.0, 5.0))));
	float glint = horizontal_glint * glint_row * glint_break * wetness * 0.11;
	color = mix(color, water_highlight, glint);

	float existing_moss = smoothstep(0.012, 0.105, texel.g - max(texel.r, texel.b));
	vec2 moss_cell = floor(pixel / 9.0);
	vec2 moss_local = fract(pixel / 9.0) - vec2(0.5);
	float moss_seed = hash21(moss_cell);
	float moss_shape = (1.0 - step(0.34, length(moss_local))) * step(0.935, moss_seed);
	float moss_region = smoothstep(0.48, 0.78, radius) * (1.0 - smoothstep(0.88, 1.16, radius));
	float moss = clamp(existing_moss * 0.55 + moss_shape * moss_region * 0.42, 0.0, 1.0);
	color = mix(color, moss_tint * mix(0.48, 0.75, detail_noise), moss);

	float ripples = 0.0;
	ripples += ripple_ring(snapped_uv, vec2(0.135, 0.690), 0.06);
	ripples += ripple_ring(snapped_uv, vec2(0.875, 0.655), 0.27);
	ripples += ripple_ring(snapped_uv, vec2(0.790, 0.250), 0.48);
	ripples += ripple_ring(snapped_uv, vec2(0.310, 0.855), 0.69);
	ripples += ripple_ring(snapped_uv, vec2(0.075, 0.410), 0.87);
	ripples = clamp(ripples, 0.0, 1.0) * wetness;
	color = mix(color, water_highlight, ripples * 0.36);

	COLOR = vec4(horizon_haze(color, SCREEN_UV), texel.a);
}
