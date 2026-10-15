shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/sunlight/sunlight.gdshaderinc"
uniform vec2 view_size = vec2(2560.0,1440.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
varying float atlas_column;
varying vec4 grass_color;
varying vec2 receiver_point;
void vertex() {
	atlas_column = INSTANCE_CUSTOM.r;
	grass_color = COLOR;
	vec2 root = INSTANCE_CUSTOM.gb;
	float tip = UV.y*UV.y;
	VERTEX.x += sin(sun_time*1.05 + root.x*.021 + root.y*.012)*tip*1.25;
	vec2 position = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	float height = max(0.0, root.y-position.y);
	receiver_point = ground_plane(vec2(position.x,root.y)) - vec2(.42,.32)*height;
}
void fragment() {
	vec2 atlas_uv = vec2((UV.x+atlas_column)*.25,1.0-UV.y);
	vec4 source = texture(TEXTURE,atlas_uv)*grass_color;
	float face = smoothstep(.15,.9,UV.y);
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR = vec4(receive_sun(source.rgb,receiver_point,face,1.0)*(.83+.17*depth),source.a*depth);
}
