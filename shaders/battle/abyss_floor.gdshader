shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_offset = vec2(0.0);
uniform float time_seconds = 0.0;
uniform float wave_index = 1.0;
uniform float danger_level = 0.0;


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 345.45));
	value += dot(value, value + 34.345);
	return fract(value.x * value.y);
}


float pixel_line(float distance_to_line, float width) {
	return 1.0 - step(width, abs(distance_to_line));
}


void fragment() {
	vec2 world_position = (UV - vec2(0.5)) / SCREEN_PIXEL_SIZE + world_offset;
	vec2 cell_size = vec2(56.0, 24.0);
	vec2 cell = floor(world_position / cell_size);
	vec2 local = fract(world_position / cell_size);
	float row = mod(cell.y, 2.0);
	float shifted_x = fract(local.x + row * 0.5);
	float horizontal_joint = step(0.945, local.y);
	float vertical_joint = step(0.978, shifted_x);
	float mortar = max(horizontal_joint, vertical_joint);
	float noise = hash21(floor(world_position));
	float block_noise = hash21(cell);
	float cell_detail = hash21(cell + vec2(17.1, 4.7));

	vec3 floor_color = vec3(0.105, 0.125, 0.098);
	floor_color += (block_noise - 0.5) * vec3(0.032, 0.038, 0.026);
	floor_color += (noise - 0.5) * vec3(0.024, 0.030, 0.020);
	vec3 mortar_color = vec3(0.045, 0.054, 0.041);
	vec3 color = mix(floor_color, mortar_color, mortar);

	// Pixel-sized edge wear gives each stone a readable bevel without a texture.
	float edge_distance = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
	float worn_edge = (1.0 - step(0.075, edge_distance)) * (1.0 - mortar);
	color += vec3(0.022, 0.027, 0.018) * worn_edge;

	// Deterministic short cracks make the repeated tile pattern less mechanical.
	float crack_enabled = step(0.66, cell_detail) * (1.0 - mortar);
	float crack_y = 0.22 + hash21(cell + vec2(2.4, 9.1)) * 0.56;
	float crack_x = 0.20 + hash21(cell + vec2(8.2, 1.7)) * 0.58;
	float crack_horizontal = pixel_line(local.y - crack_y, 0.018) * step(0.12, local.x) * (1.0 - step(0.72, local.x));
	float crack_vertical = pixel_line(shifted_x - crack_x, 0.020) * step(0.14, local.y) * (1.0 - step(0.66, local.y));
	float crack_branch = pixel_line(local.y - (crack_y + (local.x - 0.5) * 0.22), 0.014) * step(0.30, local.x) * (1.0 - step(0.62, local.x));
	float crack = max(crack_horizontal, max(crack_vertical, crack_branch)) * crack_enabled;
	color = mix(color, vec3(0.030, 0.039, 0.029), crack * 0.82);

	float fleck = step(0.992, noise) * (1.0 - mortar);
	float moss = step(0.972, hash21(cell + floor(world_position / 7.0))) * (1.0 - mortar);
	float moss_pulse = 0.82 + 0.18 * sin(time_seconds * 0.9 + cell.x * 0.7 + cell.y * 0.45);
	color = mix(color, vec3(0.160, 0.285, 0.151), fleck * 0.62);
	color = mix(color, vec3(0.160, 0.325, 0.160), moss * 0.56 * moss_pulse);

	// Subtle concentric arena marks are camera-relative, so they remain readable while exploring.
	vec2 camera_uv = UV - vec2(0.5);
	float radial = length(camera_uv * vec2(1.0, 1.78));
	float ring_outer = 1.0 - step(0.010, abs(radial - 0.39));
	float ring_inner = 1.0 - step(0.007, abs(radial - 0.245));
	float ring_segments = step(0.28, fract(sin(floor(atan(camera_uv.y, camera_uv.x) * 18.0) + wave_index * 2.7) * 43758.5453));
	float ring_mask = max(ring_outer, ring_inner) * ring_segments;
	float pulse = 0.55 + 0.45 * sin(time_seconds * (1.15 + danger_level * 0.9) + radial * 28.0);
	color = mix(color, vec3(0.190, 0.245, 0.145), ring_mask * (0.10 + danger_level * 0.05) * pulse);

	// Darken the perimeter and introduce a restrained late-wave violet cast.
	float perimeter = smoothstep(0.33, 0.72, radial);
	vec3 danger_tint = vec3(0.105, 0.055, 0.125) * danger_level;
	color = mix(color, color * 0.72 + danger_tint, perimeter * (0.32 + danger_level * 0.18));
	COLOR = vec4(color, 1.0);
}
