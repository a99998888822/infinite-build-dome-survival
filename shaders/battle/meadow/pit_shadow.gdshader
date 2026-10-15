shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1280.0,720.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
uniform float shadow_opacity = .22;

void fragment() {
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR = vec4(.055,.070,.052,texture(TEXTURE,UV).a*shadow_opacity*depth);
}
