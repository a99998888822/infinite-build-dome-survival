shader_type canvas_item;
render_mode unshaded, blend_add;

void fragment() {
	// A broad, quiet overhead light footprint; no texture blur or moving rays.
	vec2 local = (SCREEN_UV-vec2(.5,.53))/vec2(.52,.39);
	float pool = pow(max(0.0,1.0-dot(local,local)),1.25);
	COLOR = vec4(vec3(.85,.88,.75),pool*.038);
}
