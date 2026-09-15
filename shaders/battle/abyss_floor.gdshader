shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_offset = vec2(0.0);


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 345.45));
	value += dot(value, value + 34.345);
	return fract(value.x * value.y);
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

	vec3 floor_color = vec3(0.105, 0.125, 0.098);
	floor_color += (block_noise - 0.5) * vec3(0.028, 0.034, 0.023);
	floor_color += (noise - 0.5) * vec3(0.020, 0.026, 0.018);
	vec3 mortar_color = vec3(0.050, 0.061, 0.045);
	vec3 color = mix(floor_color, mortar_color, mortar);

	float fleck = step(0.992, noise) * (1.0 - mortar);
	float moss = step(0.975, hash21(cell + floor(world_position / 7.0))) * (1.0 - mortar);
	color = mix(color, vec3(0.160, 0.285, 0.151), fleck * 0.62);
	color = mix(color, vec3(0.160, 0.325, 0.160), moss * 0.56);
	COLOR = vec4(color, 1.0);
}
