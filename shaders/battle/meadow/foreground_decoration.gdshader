shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1152.0,768.0);
uniform float transition_bottom = 238.0;
void fragment() {
	COLOR.a *= smoothstep(transition_bottom-15.0,transition_bottom+18.0,SCREEN_UV.y*view_size.y);
}
