shader_type canvas_item;
render_mode unshaded;

// Preview-only material. UV limits isolate the current atlas frame.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float elapsed = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float width_source_pixels = 3.0;
uniform sampler2D source_texture : filter_nearest, repeat_disable;

float silhouette(vec2 uv) {
	if (uv.x < frame_uv.x || uv.y < frame_uv.y || uv.x >= frame_uv.z || uv.y >= frame_uv.w) {
		return 0.0;
	}
	return step(0.15, texture(source_texture, uv).a);
}

float surrounding(vec2 uv, vec2 step_uv) {
	float a = 0.0;
	a = max(a, silhouette(uv + vec2(step_uv.x, 0.0)));
	a = max(a, silhouette(uv - vec2(step_uv.x, 0.0)));
	a = max(a, silhouette(uv + vec2(0.0, step_uv.y)));
	a = max(a, silhouette(uv - vec2(0.0, step_uv.y)));
	a = max(a, silhouette(uv + step_uv * 0.7071));
	a = max(a, silhouette(uv - step_uv * 0.7071));
	a = max(a, silhouette(uv + vec2(step_uv.x, -step_uv.y) * 0.7071));
	a = max(a, silhouette(uv + vec2(-step_uv.x, step_uv.y) * 0.7071));
	return a;
}

vec3 rainbow(float phase) {
	vec3 colors[7] = vec3[7](
		vec3(1.0, 0.28, 0.35), vec3(1.0, 0.59, 0.19),
		vec3(1.0, 0.91, 0.28), vec3(0.36, 0.94, 0.46),
		vec3(0.22, 0.88, 1.0), vec3(0.40, 0.47, 1.0),
		vec3(0.86, 0.36, 1.0));
	float index = fract(phase) * 7.0;
	return mix(colors[int(index)], colors[(int(index) + 1) % 7], smoothstep(0.0, 1.0, fract(index)));
}

void fragment() {
	vec4 source = texture(source_texture, UV);
	vec2 local_uv = (UV - frame_uv.xy) / (frame_uv.zw - frame_uv.xy);
	float angle = atan(local_uv.y - 0.46, local_uv.x - 0.5) / 6.2831853;
	vec3 hue = rainbow(angle - elapsed * 0.22);
	float edge = surrounding(UV, TEXTURE_PIXEL_SIZE * width_source_pixels);
	float rim = surrounding(UV, TEXTURE_PIXEL_SIZE * (width_source_pixels + 2.0));
	vec4 outline = vec4(mix(hue * 0.35, hue, edge), max(edge, rim * 0.42) * strength);
	COLOR = source.a > 0.15 ? source : outline;
}
