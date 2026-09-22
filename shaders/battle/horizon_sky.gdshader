shader_type canvas_item;
render_mode unshaded;

uniform float sky_height = 72.0;

void fragment() {
	vec4 sky = COLOR;
	float bottom_distance = (1.0 - UV.y) * sky_height;
	float haze = 1.0 - smoothstep(0.0, 9.0, floor(bottom_distance));
	// The last sky pixels share the distant wetland's dark, muted atmosphere.
	sky.rgb = mix(sky.rgb, vec3(0.034, 0.052, 0.050), haze * 0.85);
	COLOR = sky;
}
