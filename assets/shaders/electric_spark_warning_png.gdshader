shader_type canvas_item;
render_mode unshaded;
uniform sampler2D shape_frames : filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform float radius_scale = 1.0;
uniform float fade = 1.0;
varying flat float direction_frame;
varying flat float brightness;

void vertex() {
	float row_phase = INSTANCE_CUSTOM.x * 1.9;
	float ratio = INSTANCE_CUSTOM.y;
	float angle = elapsed * (5.0 + INSTANCE_CUSTOM.x * 0.7) + ratio * TAU + row_phase;
	float wave = sin(elapsed * 13.0 + ratio * 15.0 + row_phase) * 2.8;
	vec2 position = vec2(cos(angle) * (23.0 + wave), sin(angle) * (14.0 + wave * 0.45)) * radius_scale;
	VERTEX += round(position);
	direction_frame = mod(floor((angle + PI * 0.5) / TAU * 256.0 + 0.5), 256.0);
	brightness = (0.55 + 0.45 * sin(elapsed * 18.0 + ratio * TAU + row_phase)) * fade;
}

void fragment() {
	vec2 tile = vec2(mod(direction_frame,16.0),floor(direction_frame/16.0));
	vec3 coverage = texture(shape_frames, (tile + UV) / 16.0).rgb;
	// Keep the original circle / outer rectangle / inner rectangle blend order.
	float glow_a = coverage.r * brightness * 0.12;
	float outer_a = coverage.g * brightness * 0.72;
	float inner_a = coverage.b * brightness;
	float alpha = glow_a;
	vec3 premultiplied = vec3(1.0,0.72,0.08) * glow_a;
	premultiplied = vec3(1.0,0.62,0.06) * outer_a + premultiplied * (1.0-outer_a);
	alpha = outer_a + alpha * (1.0-outer_a);
	premultiplied = vec3(1.0,0.94,0.34) * inner_a + premultiplied * (1.0-inner_a);
	alpha = inner_a + alpha * (1.0-inner_a);
	COLOR = vec4(premultiplied / max(alpha,0.00001),alpha);
}
