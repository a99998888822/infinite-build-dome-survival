uniform float horizon_y = 128.0;
uniform float fold_height = 0.0;
uniform vec2 ui_view_size = vec2(1152.0, 648.0);

float horizon_nearness(vec2 screen_uv) {
	return smoothstep(0.0, max(fold_height, 1.0), screen_uv.y * ui_view_size.y - horizon_y);
}

vec3 horizon_haze(vec3 color, vec2 screen_uv) {
	float haze = (1.0 - horizon_nearness(screen_uv)) * step(1.0, fold_height);
	return mix(color, vec3(0.030, 0.048, 0.045), haze * 0.55);
}
