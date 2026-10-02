shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1152.0,768.0);
uniform float transition_bottom = 238.0;
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	vec3 ground_color = COLOR.rgb/max(source.rgb,vec3(.001));
	vec3 color = mix(source.rgb,ground_color,.40);
	float root = smoothstep(COLOR.a-3.0/32.0,COLOR.a,UV.y);
	float foreground = smoothstep(transition_bottom-15.0,transition_bottom+18.0,SCREEN_UV.y*view_size.y);
	COLOR = vec4(color*(1.0-root*.08),source.a*foreground);
}
