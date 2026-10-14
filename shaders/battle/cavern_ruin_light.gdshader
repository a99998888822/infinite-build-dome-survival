shader_type canvas_item;
render_mode unshaded;
void fragment() {
	// Distant stone catches a little light from above, then joins the dark band.
	float light = mix(1.08,.38,smoothstep(.08,.95,UV.y));
	COLOR.rgb *= vec3(.96,.98,1.0)*light;
	COLOR.a *= 1.0-smoothstep(.70,1.0,UV.y)*.45;
}
