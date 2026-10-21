shader_type canvas_item;
render_mode unshaded;
uniform sampler2D actor_texture : filter_nearest, repeat_disable;
uniform vec3 actor_uv_x;
uniform vec3 actor_uv_y;
uniform vec2 actor_frame_origin;
uniform vec2 actor_frame_size = vec2(1.0);
uniform vec2 actor_pixel;
uniform float strength = 1.0;
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float actor_alpha(vec2 point) {
	if (point.x < 0.0 || point.y < 0.0 || point.x >= 1.0 || point.y >= 1.0) { return 0.0; }
	return texture(actor_texture, actor_frame_origin + point * actor_frame_size).a;
}

void fragment() {
	vec2 point = vec2(dot(actor_uv_x, vec3(world_point, 1.0)), dot(actor_uv_y, vec3(world_point, 1.0)));
	float body = actor_alpha(point);
	float rim = max(max(actor_alpha(point + vec2(actor_pixel.x, 0.0)), actor_alpha(point - vec2(actor_pixel.x, 0.0))),
		max(actor_alpha(point + vec2(0.0, actor_pixel.y)), actor_alpha(point - vec2(0.0, actor_pixel.y))));
	float body_alpha = body * .84 * strength;
	float rim_alpha = max(0.0, rim - body) * .45 * strength * (1.0 - body_alpha);
	float alpha = body_alpha + rim_alpha;
	vec3 ink = (vec3(.052, .047, .070) * body_alpha + vec3(.36, .40, .39) * rim_alpha) / max(alpha, .0001);
	float edge = sin(SCREEN_UV.x * view_size.x / 129.0) * 5.0 + sin(SCREEN_UV.x * view_size.x / 47.0) * 2.0;
	float depth = smoothstep(fade_start + edge, fade_end + edge, SCREEN_UV.y * view_size.y);
	COLOR = vec4(ink * (.83 + .17 * depth), alpha * COLOR.a * depth);
}
