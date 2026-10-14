shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size = vec2(1280.0,720.0);
uniform float fade_start = 95.0;
uniform float fade_end = 215.0;
uniform sampler2D player_texture : filter_nearest, repeat_disable;
uniform vec3 player_uv_x;
uniform vec3 player_uv_y;
uniform vec2 player_frame_origin;
uniform vec2 player_frame_size = vec2(1.0);
uniform vec2 player_pixel;
uniform float shadow_strength = 0.0;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}

float hero_alpha(vec2 point) {
	if (point.x<0.0 || point.y<0.0 || point.x>=1.0 || point.y>=1.0) { return 0.0; }
	return texture(player_texture,player_frame_origin+point*player_frame_size).a;
}

void fragment() {
	// Paint on opaque stone pixels only. Exposed parts of the real animated
	// character retain their normal rendering and never receive a duplicate.
	if (shadow_strength>0.0) {
		vec2 point = vec2(dot(player_uv_x,vec3(world_point,1.0)),dot(player_uv_y,vec3(world_point,1.0)));
		float body = hero_alpha(point);
		float rim = max(max(hero_alpha(point+vec2(player_pixel.x,0.0)),hero_alpha(point-vec2(player_pixel.x,0.0))),
			max(hero_alpha(point+vec2(0.0,player_pixel.y)),hero_alpha(point-vec2(0.0,player_pixel.y))));
		COLOR.rgb = mix(COLOR.rgb,vec3(.36,.40,.39),max(0.0,rim-body)*.45*shadow_strength);
		COLOR.rgb = mix(COLOR.rgb,vec3(.052,.047,.070),body*.84*shadow_strength);
	}
	float edge = sin(SCREEN_UV.x*view_size.x/129.0)*5.0+sin(SCREEN_UV.x*view_size.x/47.0)*2.0;
	float depth = smoothstep(fade_start+edge,fade_end+edge,SCREEN_UV.y*view_size.y);
	COLOR.rgb *= .83+.17*depth;
	COLOR.a *= depth;
}
