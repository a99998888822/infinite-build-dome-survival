shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/sunlight/sunlight.gdshaderinc"
uniform vec2 view_size = vec2(2560.0,1440.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
uniform vec2 object_root;
void fragment() {
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	float direct = sun_at(ground_plane(object_root));
	COLOR = vec4(.048,.058,.060,texture(TEXTURE,UV).a*(.05+.24*direct)*depth);
}
