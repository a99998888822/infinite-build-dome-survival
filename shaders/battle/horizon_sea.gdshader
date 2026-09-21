shader_type canvas_item;
render_mode unshaded;

uniform vec2 band_size = vec2(800.0, 82.0);
uniform vec3 horizon_color : source_color = vec3(0.020, 0.115, 0.125);
uniform vec3 near_water_color : source_color = vec3(0.035, 0.205, 0.205);
uniform vec3 wave_color : source_color = vec3(0.180, 0.415, 0.390);
uniform vec3 dusk_glow_color : source_color = vec3(0.305, 0.105, 0.075);


float hash21(vec2 value) {
	value = fract(value * vec2(127.1, 311.7));
	value += dot(value, value + 19.19);
	return fract(value.x * value.y);
}


void fragment() {
	vec2 safe_size = max(band_size, vec2(1.0));
	vec2 pixel = floor(UV * safe_size);
	vec2 uv = (pixel + vec2(0.5)) / safe_size;
	float y = clamp(uv.y, 0.0, 1.0);
	float compressed_depth = pow(max(y, 0.012), 0.46);

	float broad_band = floor(compressed_depth * 28.0);
	float band_noise = hash21(vec2(floor(pixel.x / 24.0), broad_band));
	float wave_phase = fract(compressed_depth * 28.0 + band_noise * 0.30 + TIME * 0.055);
	float wave_line = 1.0 - smoothstep(0.035, 0.115, abs(wave_phase - 0.5));
	float segment = step(0.40, hash21(vec2(floor(pixel.x / 13.0), broad_band + 7.0)));
	float distant_emphasis = mix(0.90, 0.28, y);
	float wave = wave_line * segment * distant_emphasis;

	float secondary_phase = fract(compressed_depth * 15.0 - TIME * 0.035 + hash21(vec2(broad_band, 4.0)) * 0.22);
	float secondary_wave = (1.0 - smoothstep(0.025, 0.10, abs(secondary_phase - 0.5))) * 0.26;
	secondary_wave *= step(0.57, hash21(vec2(floor(pixel.x / 21.0), broad_band + 19.0)));

	vec3 color = mix(horizon_color, near_water_color, smoothstep(0.08, 0.92, y));
	float horizon_glow = 1.0 - smoothstep(0.0, 0.16, y);
	color = mix(color, dusk_glow_color, horizon_glow * 0.34);
	color = mix(color, wave_color, clamp(wave * 0.40 + secondary_wave, 0.0, 0.48));

	float lower_fade = 1.0 - smoothstep(0.68, 1.0, y);
	float dither = hash21(pixel);
	float broken_edge = smoothstep(0.05, 0.72, lower_fade + (dither - 0.5) * 0.22);
	float alpha = mix(0.97, 0.58, y) * broken_edge;
	COLOR = vec4(color, alpha);
}
