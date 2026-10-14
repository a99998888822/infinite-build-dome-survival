shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1152.0,768.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
void fragment() {
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR.rgb *= .83+.17*depth;
	COLOR.a *= depth;
}
