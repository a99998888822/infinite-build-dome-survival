shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float night = 0.0;
void fragment() {
	vec2 p = (floor(UV*vec2(36.0,44.0))+.5)/vec2(36.0,44.0);
	float light = pow(max(0.0,1.0-length((p-.5)*2.0)),2.0);
	COLOR = vec4(.12,.62,1.0,light*.56*night);
}
