shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/battle/meadow/sunlight/sunlight.gdshaderinc"
uniform vec2 view_size = vec2(2560.0,1440.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
uniform vec2 object_root;
uniform bool contact_only = false;
uniform sampler2D face_mask : filter_nearest, repeat_disable;
uniform bool has_face_mask = false;
uniform bool mask_flip = false;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	float height = max(0.0,object_root.y-world_point.y);
	vec2 plane = ground_plane(vec2(world_point.x,object_root.y))-vec2(.42,.32)*height;
	float face = .35 + .45*(1.0-UV.y);
	if (has_face_mask) face = texture(face_mask,vec2(mask_flip ? 1.0-UV.x : UV.x,UV.y)).r;
	if (!contact_only) COLOR.rgb = receive_sun(COLOR.rgb,plane,face,1.0);
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR.rgb *= .83+.17*depth;
	COLOR.a *= depth;
}
