shader_type canvas_item;
render_mode unshaded;

// Production resistance overlay: warm outline, 0.88 cycles per second.
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

vec3 warm_spectrum(float phase) {
	vec3 colors[3] = vec3[3](
		vec3(1.0, 0.88, 0.22), vec3(1.0, 0.45, 0.10), vec3(1.0, 0.15, 0.08));
	float index = fract(phase) * 3.0;
	return mix(colors[int(index)], colors[(int(index) + 1) % 3], smoothstep(0.0, 1.0, fract(index)));
}

void fragment() {
	vec4 source = texture(source_texture, UV);
	vec2 local_uv = (UV - frame_uv.xy) / (frame_uv.zw - frame_uv.xy);
	float angle = atan(local_uv.y - 0.46, local_uv.x - 0.5) / 6.2831853;
	vec3 hue = warm_spectrum(angle - elapsed * 0.88);
	float edge = surrounding(UV, TEXTURE_PIXEL_SIZE * width_source_pixels);
	float rim = surrounding(UV, TEXTURE_PIXEL_SIZE * (width_source_pixels + 2.0));
	vec4 outline = vec4(mix(hue * 0.35, hue, edge), max(edge, rim * 0.42) * strength);
	COLOR = source.a > 0.15 ? vec4(0.0) : outline;
}
